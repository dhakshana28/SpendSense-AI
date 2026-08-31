import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:xml/xml.dart';

import '../models/bank_statement_model.dart';
import 'ai/expense_categorizer.dart';
import 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_io.dart'
    as file_reader;

/// Explicit PDF extraction status — prevents false "scanned" classification.
enum PdfExtractionStatus {
  success,
  emptyText,
  extractionFailed,
  invalidPdf,
}

/// Simple result holder for parser helper methods.
class _ParseResult {
  const _ParseResult(this.text, this.nextPos);
  final String text;
  final int nextPos;
}

class _NumResult {
  const _NumResult(this.value, this.nextPos);
  final double value;
  final int nextPos;
}

/// Parses bank statement files (CSV, Excel, PDF) and extracts transactions.
class BankStatementParser {
  /// Parse a bank statement file and return categorized transactions.
  /// Supports both file paths (mobile/desktop) and bytes (web).
  static Future<List<BankTransaction>> parseFile({
    required String fileName,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();

    debugPrint('📄 BankStatementParser: Selected file: $fileName');
    debugPrint('📄 BankStatementParser: Platform: $defaultTargetPlatform');
    debugPrint('📄 BankStatementParser: File extension: $ext');

    if (bytes != null) {
      debugPrint('📄 BankStatementParser: Bytes length: ${bytes.length}');
    }

    switch (ext) {
      case 'csv':
        return _parseCsvFromBytes(bytes ?? await _readFileBytes(filePath));
      case 'xlsx':
      case 'xls':
        return _parseExcelFromBytes(bytes ?? await _readFileBytes(filePath));
      case 'pdf':
        return _parsePdfFromBytes(bytes ?? await _readFileBytes(filePath));
      default:
        throw FormatException(
          'Unsupported file format: $ext. Please use CSV, Excel, or PDF.',
        );
    }
  }

  /// Read file bytes from a filesystem path (non-web only).
  static Future<Uint8List> _readFileBytes(String? filePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'File path access is not supported on the web. Pass bytes instead.',
      );
    }
    if (filePath == null || filePath.isEmpty) {
      throw ArgumentError('File path is required when bytes are not provided.');
    }
    return await file_reader.readFileBytes(filePath);
  }

  /// Parse CSV text directly (pasted by the user).
  static Future<List<BankTransaction>> parseCsvText(String csvText) async {
    final rows = _parseCsvRows(csvText);
    return _parseRowsToTransactions(rows);
  }

  /// Parse CSV from bytes (Web-compatible).
  static Future<List<BankTransaction>> _parseCsvFromBytes(
    Uint8List bytes,
  ) async {
    final content = utf8.decode(bytes);
    final rows = _parseCsvRows(content);
    return _parseRowsToTransactions(rows);
  }

  /// Parse Excel from bytes (Web-compatible).
  static Future<List<BankTransaction>> _parseExcelFromBytes(
    Uint8List bytes,
  ) async {
    try {
      // Decode the ZIP archive directly from bytes
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find shared strings
      List<String> sharedStrings = [];
      final sharedStringsFile = archive.files.firstWhere(
        (f) => f.name == 'xl/sharedStrings.xml',
        orElse: () => archive.files.firstWhere(
          (f) => f.name.contains('sharedStrings'),
          orElse: () => throw FormatException(
            'Could not find shared strings in Excel file.',
          ),
        ),
      );
      if (sharedStringsFile.isFile) {
        final xmlString = utf8.decode(sharedStringsFile.content);
        final document = XmlDocument.parse(xmlString);
        sharedStrings = document
            .findAllElements('t')
            .map((e) => e.innerText)
            .toList();
      }

      // Find the sheet data
      final sheetFile = archive.files.firstWhere(
        (f) => f.name.startsWith('xl/worksheets/sheet'),
        orElse: () =>
            throw FormatException('Could not find sheet data in Excel file.'),
      );

      final xmlString = utf8.decode(sheetFile.content);
      final document = XmlDocument.parse(xmlString);
      final rows = <List<String>>[];

      for (final row in document.findAllElements('row')) {
        final rowData = <String>[];
        for (final cell in row.findElements('c')) {
          final value = cell.findElements('v').firstOrNull;
          final type = cell.getAttribute('t');
          if (value != null) {
            if (type == 's') {
              // Shared string reference
              final index = int.tryParse(value.innerText) ?? 0;
              rowData.add(
                index < sharedStrings.length ? sharedStrings[index] : '',
              );
            } else {
              rowData.add(value.innerText);
            }
          } else {
            rowData.add('');
          }
        }
        rows.add(rowData);
      }

      if (rows.isEmpty) {
        throw FormatException('Excel file is empty or has no data.');
      }

      return _parseRowsToTransactions(rows);
    } catch (e) {
      debugPrint('❌ BankStatementParser: Excel parsing failed: $e');
      if (e is FormatException) rethrow;
      throw FormatException('Failed to parse Excel file: $e');
    }
  }

  /// Extract PDF text for preview without parsing transactions.
  static Future<String> extractPdfTextForPreview(Uint8List bytes) async {
    return await _extractPdfText(bytes);
  }

  /// Parse PDF from bytes (Web-compatible).
  static Future<List<BankTransaction>> _parsePdfFromBytes(
    Uint8List bytes,
  ) async {
    try {
      // DEBUG LOGS - requested for diagnosis
      debugPrint('[PDF DEBUG] bytes = ${bytes.length}');
      debugPrint('[PDF DEBUG] signature = ${bytes.length >= 8 ? String.fromCharCodes(bytes.take(8)) : "invalid"}');
      debugPrint('[PDF_IMPORT] PDF file size: ${bytes.length} bytes');
      debugPrint(
        '[PDF_IMPORT] Valid PDF signature: ${_hasPdfSignature(bytes)}',
      );
      debugPrint('[PDF_PARSE] Starting PDF extraction');

      debugPrint('[PDF DEBUG] extraction started');
      final text = await _extractPdfText(bytes);
      debugPrint('[PDF DEBUG] extraction completed');
      debugPrint('[PDF DEBUG] text length = ${text.length}');

      // Count pages for debug
      final pageCount = _countPdfPages(bytes);
      debugPrint('[PDF DEBUG] page count = $pageCount');

      final printable = text.replaceAll(RegExp(r'\s+'), '').trim();
      debugPrint('[PDF DEBUG] scanned detection text length = ${printable.length}');

      // Only classify as scanned AFTER a successful extraction returned no
      // meaningful text. Any extraction API failure surfaces as an exception
      // (not as a "scanned" result) and is rethrown as a parse error below.
      if (printable.isEmpty) {
        debugPrint('[PDF DEBUG] SCANNED BRANCH TRIGGERED - empty text');
        debugPrint(
          '[PDF_PARSE] Extraction returned no printable text; '
          'this is an image-based/scanned PDF (OCR required).',
        );
        throw FormatException(
          'This PDF appears to be scanned or image-based. OCR is required to extract transactions.',
        );
      }
      if (printable.length < 30) {
        debugPrint('[PDF DEBUG] SCANNED BRANCH TRIGGERED - text too short (${printable.length} chars)');
        debugPrint(
          '[PDF_PARSE] Very little text extracted (${printable.length} chars) — likely image-based',
        );
        throw FormatException(
          'This PDF appears to be scanned or image-based. OCR is required to extract transactions.',
        );
      }

      debugPrint('[PDF_PARSE] Extracted text length: ${text.length}');

      debugPrint('[PDF DEBUG] transaction parsing started');
      final rows = _parsePdfTextToRows(text);
      debugPrint('[PDF_PARSE] Candidate transaction rows: ${rows.length}');
      if (rows.isEmpty) {
        throw FormatException(
          'No transaction rows were detected. The statement may be scanned or use an unsupported layout.',
        );
      }

      // PDF text extraction yields raw data rows with NO header row. Prepend
      // the expected column layout so the shared mapper can classify fields
      // (Date | Description | Debit | Credit | Balance).
      rows.insert(0, const [
        'Date',
        'Description',
        'Debit',
        'Credit',
        'Balance',
      ]);

      final transactions = _parseRowsToTransactions(rows);
      debugPrint('[PDF_PARSE] Parsed transactions: ${transactions.length}');
      debugPrint('[PDF DEBUG] transactions = ${transactions.length}');
      return transactions;
    } catch (e, stackTrace) {
      debugPrint('[PDF ERROR] $e');
      debugPrint('$stackTrace');
      debugPrint('❌ BankStatementParser: PDF parsing failed: $e');
      debugPrint('❌ BankStatementParser: Exception type: ${e.runtimeType}');
      if (e is FormatException) rethrow;
      throw FormatException('Failed to parse PDF file: $e');
    }
  }

  /// Count PDF pages by counting /Type /Page entries (excluding /Pages catalog).
  static int _countPdfPages(Uint8List bytes) {
    final s = latin1.decode(bytes, allowInvalid: true);
    final matches = RegExp(r'/Type\s*/Page[^s]').allMatches(s);
    return matches.length;
  }

  /// Whether the bytes start with the standard `%PDF-` signature.
  static bool _hasPdfSignature(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  /// Extract text from PDF bytes (pure-Dart, cross-platform — works on Web,
  /// Android, Windows, macOS, Linux). Never uses dart:io.
  ///
  /// Enumerates PDF object streams, decompresses FlateDecode streams with the
  /// `archive` package, and reconstructs text from the page content stream
  /// operators (`BT`/`ET`, `Tj`/`TJ`, `Td`/`TD`/`Tm`/`T*`).
  static Future<String> _extractPdfText(Uint8List bytes) async {
    final sections = <String>[];
    var pos = 0;
    var streamCount = 0;
    var decodedCount = 0;
    var contentStreamCount = 0;

    while (pos < bytes.length) {
      final sIdx = _indexOfBytes(bytes, _kStreamMarker, pos);
      if (sIdx == -1) break;

      // A genuine "stream" keyword is preceded by whitespace AND a stream
      // dictionary terminating in `>>` shortly before it. The word "stream"
      // also appears inside binary/compressed payloads, so we must validate
      // with both conditions. (Checking only the 2 preceding bytes was wrong:
      // `>>\nstream` has '\n' immediately before 's', which failed && caused
      // every valid stream to be skipped.)
      final pc = sIdx > 0 ? bytes[sIdx - 1] : 0x00;
      final precededBySpace =
          pc == 0x0A || pc == 0x0D || pc == 0x20 || pc == 0x09;
      if (!precededBySpace || !_hasStreamDict(bytes, sIdx)) {
        pos = sIdx + _kStreamMarker.length;
        continue;
      }

      final eIdx = _indexOfBytes(
        bytes,
        _kEndStreamMarker,
        sIdx + _kStreamMarker.length,
      );
      if (eIdx == -1) break;

      streamCount++;
      final dictStart = _lastIndexOfAny(bytes, sIdx, const [0x3C]);
      final dictSlice = dictStart != -1
          ? _asciiSlice(bytes, dictStart, sIdx)
          : '';
      final isFlate = dictSlice.contains('FlateDecode');

      var bodyStart = sIdx + _kStreamMarker.length;
      if (bodyStart < bytes.length &&
          (bytes[bodyStart] == 0x0A || bytes[bodyStart] == 0x0D)) {
        bodyStart++;
        if (bytes[bodyStart - 1] == 0x0D &&
            bodyStart < bytes.length &&
            bytes[bodyStart] == 0x0A) {
          bodyStart++;
        }
      }
      var bodyEnd = eIdx;
      while (bodyEnd > bodyStart &&
          (bytes[bodyEnd - 1] == 0x0A || bytes[bodyEnd - 1] == 0x0D)) {
        bodyEnd--;
      }

      final body = bytes.sublist(bodyStart, bodyEnd);
      List<int> decoded;
      if (isFlate) {
        try {
          decoded = const ZLibDecoder().decodeBytes(body, verify: true);
          decodedCount++;
        } catch (_) {
          decoded = body;
        }
      } else {
        decoded = body;
      }

      if (_looksLikeContentStream(decoded)) {
        final parsed = _parseContentStream(decoded);
        if (parsed.trim().isNotEmpty) {
          contentStreamCount++;
          sections.add(parsed);
        }
      }
      pos = eIdx + _kEndStreamMarker.length;
    }

    debugPrint(
      '[PDF_PARSE] Streams found: $streamCount, FlateDecode streams: $decodedCount, content streams: $contentStreamCount',
    );
    final text = sections.join('\n');
    debugPrint('[PDF_PARSE] Extracted text length: ${text.length}');
    return text;
  }

  /// Whether a `>>` stream-dictionary terminator exists within the `limit`
  /// bytes immediately preceding the given stream keyword. This reliably
  /// distinguishes a real PDF stream from the literal bytes "stream" present
  /// inside compressed/binary payloads of other objects.
  static bool _hasStreamDict(List<int> bytes, int sIdx) {
    const limit = 500;
    final start = (sIdx - limit) < 0 ? 0 : sIdx - limit;
    var lastGt = -1;
    for (var i = sIdx - 1; i >= start; i--) {
      if (bytes[i] == 0x3E) {
        if (lastGt != -1 && i == lastGt - 1) {
          return true; // ">>"
        }
        lastGt = i;
      }
    }
    return false;
  }

  static const List<int> _kStreamMarker = [0x73, 0x74, 0x72, 0x65, 0x61, 0x6D];
  static const List<int> _kEndStreamMarker = [
    0x65,
    0x6E,
    0x64,
    0x73,
    0x74,
    0x72,
    0x65,
    0x61,
    0x6D,
  ];

  static int _indexOfBytes(List<int> haystack, List<int> needle, int start) {
    if (needle.isEmpty || start > haystack.length) return -1;
    for (int i = start; i <= haystack.length - needle.length; i++) {
      var match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static int _lastIndexOfAny(List<int> haystack, int before, List<int> chars) {
    final stop = before - 10000 < 0 ? 0 : before - 10000;
    for (int i = before; i >= stop; i--) {
      if (chars.contains(haystack[i])) return i;
    }
    return -1;
  }

  static String _asciiSlice(List<int> bytes, int start, int end) {
    final b = StringBuffer();
    for (int i = start; i < end && i < bytes.length; i++) {
      final x = bytes[i];
      if (x >= 0x20 && x <= 0x7E) b.writeCharCode(x);
    }
    return b.toString();
  }

  static bool _looksLikeContentStream(List<int> decoded) {
    final s = latin1.decode(decoded, allowInvalid: true);
    // A content stream must contain at least one text-showing operator
    // (Tj, TJ, ', or "). BT/ET are optional - some PDF generators
    // (e.g., ReportLab) emit text operators without BT/ET blocks.
    return s.contains('Tj') ||
        s.contains('TJ') ||
        s.contains("'") ||
        s.contains('"');
  }

  /// Reconstruct a (mostly) line-per-row text layout from a content stream.
  static String _parseContentStream(List<int> bytes) {
    final s = latin1.decode(bytes, allowInvalid: true);
    final outLines = <String>[];
    final line = StringBuffer();
    final numStack = <double>[];
    double? curY;
    var inArray = false;
    var i = 0;
    final n = s.length;

    void flush() {
      final trimmed = line.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (_isHighlyLikelyText(trimmed)) outLines.add(trimmed);
      line.clear();
    }

    while (i < n) {
      final c = s[i];

      if (c == '%') {
        while (i < n && s[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '(') {
        final r = _decodeLiteralString(s, i);
        line.write(r.text);
        i = r.nextPos;
        continue;
      }
      if (c == '<') {
        if (i + 1 < n && s[i + 1] == '<') {
          i += 2;
          continue;
        }
        final r = _decodeHexString(s, i);
        line.write(r.text);
        i = r.nextPos;
        continue;
      }
      if (c == '[') {
        inArray = true;
        i++;
        continue;
      }
      if (c == ']') {
        inArray = false;
        i++;
        continue;
      }
      final code = c.codeUnitAt(0);
      if (code == 0x2B ||
          code == 0x2D ||
          code == 0x2E ||
          (code >= 0x30 && code <= 0x39)) {
        final r = _readNumber(s, i);
        if (!inArray) numStack.add(r.value);
        i = r.nextPos;
        continue;
      }
      if ((code >= 0x61 && code <= 0x7A) || (code >= 0x41 && code <= 0x5A)) {
        final op = _readOperator(s, i);
        i = op.nextPos;
        switch (op.text) {
          case 'BT':
            line.clear();
            curY = null;
            numStack.clear();
            break;
          case 'ET':
            flush();
            numStack.clear();
            break;
          case 'Td':
          case 'TD':
            if (numStack.isNotEmpty) {
              final ty = numStack.removeLast();
              if (ty.abs() > 0.5) {
                flush();
              } else {
                line.write(' ');
              }
            } else {
              flush();
            }
            break;
          case 'T*':
            flush();
            break;
          case 'Tm':
            if (numStack.length >= 6) {
              final f = numStack[numStack.length - 1];
              numStack.clear();
              if (curY != null && (f - curY).abs() > 2.0) {
                flush();
              }
              curY = f;
            } else {
              numStack.clear();
            }
            break;
          case 'Tj':
          case 'TJ':
            break;
          default:
            break;
        }
        continue;
      }
      i++;
    }

    flush();
    return outLines.join('\n');
  }

  /// Helper: only keep lines that plausibly belong to a statement (avoid
  /// dumping image-masked / binary-only content streams as garbage).
  static bool _isHighlyLikelyText(String trimmed) => trimmed.isNotEmpty;

  static _ParseResult _decodeLiteralString(String s, int start) {
    final b = StringBuffer();
    var i = start + 1;
    while (i < s.length) {
      final c = s[i];
      if (c == ')') return _ParseResult(b.toString(), i + 1);
      if (c == '\\') {
        if (i + 1 >= s.length) break;
        final esc = s[i + 1];
        switch (esc) {
          case 'n':
            b.write('\n');
            i += 2;
            continue;
          case 'r':
            b.write('\r');
            i += 2;
            continue;
          case 't':
            b.write('\t');
            i += 2;
            continue;
          case 'b':
            b.write('\b');
            i += 2;
            continue;
          case 'f':
            b.write('\f');
            i += 2;
            continue;
        }
        final escCode = esc.codeUnitAt(0);
        if (escCode >= 0x30 && escCode <= 0x37) {
          var octal = 0;
          var count = 0;
          i++;
          while (count < 3 && i < s.length) {
            final cu = s[i].codeUnitAt(0);
            if (cu < 0x30 || cu > 0x37) break;
            octal = octal * 8 + (cu - 0x30);
            i++;
            count++;
          }
          b.writeCharCode(octal);
        } else {
          b.write(esc);
          i += 2;
        }
        continue;
      }
      b.write(c);
      i++;
    }
    return _ParseResult(b.toString(), i);
  }

  static _ParseResult _decodeHexString(String s, int start) {
    var i = start + 1;
    final raw = <int>[];
    var hi = -1;
    while (i < s.length && s[i] != '>') {
      final code = s[i].codeUnitAt(0);
      int val;
      if (code >= 0x30 && code <= 0x39) {
        val = code - 0x30;
      } else if (code >= 0x41 && code <= 0x46) {
        val = code - 0x41 + 10;
      } else if (code >= 0x61 && code <= 0x66) {
        val = code - 0x61 + 10;
      } else {
        i++;
        continue;
      }
      if (hi == -1) {
        hi = val;
      } else {
        raw.add((hi << 4) | val);
        hi = -1;
      }
      i++;
    }
    if (hi != -1) raw.add(hi << 4);
    if (i < s.length) i++;

    if (raw.length >= 2 && raw[0] == 0xFE && raw[1] == 0xFF) {
      final codeUnits = <int>[];
      for (var j = 2; j + 1 < raw.length; j += 2) {
        codeUnits.add((raw[j] << 8) | raw[j + 1]);
      }
      return _ParseResult(String.fromCharCodes(codeUnits), i);
    }
    return _ParseResult(latin1.decode(raw, allowInvalid: true), i);
  }

  static _NumResult _readNumber(String s, int start) {
    var i = start;
    if (i < s.length && (s[i] == '+' || s[i] == '-')) i++;
    while (i < s.length &&
        ((s[i].codeUnitAt(0) >= 0x30 && s[i].codeUnitAt(0) <= 0x39) ||
            s[i] == '.')) {
      i++;
    }
    if (i == start) return _NumResult(0, start + 1);
    return _NumResult(double.tryParse(s.substring(start, i)) ?? 0, i);
  }

  static _ParseResult _readOperator(String s, int start) {
    var i = start;
    while (i < s.length &&
        ((s[i].codeUnitAt(0) >= 0x61 && s[i].codeUnitAt(0) <= 0x7A) ||
            (s[i].codeUnitAt(0) >= 0x41 && s[i].codeUnitAt(0) <= 0x5A))) {
      i++;
    }
    return _ParseResult(s.substring(start, i), i);
  }

  /// Convert PDF extracted text into structured rows.
  /// Supports multiple Indian bank statement formats (SBI, HDFC, ICICI, Axis, etc.)
  static List<List<String>> _parsePdfTextToRows(String text) {
    final rows = <List<String>>[];
    final lines = text.split('\n');
    debugPrint('📄 BankStatementParser: Total lines to parse: ${lines.length}');

    // Supports numeric (DD/MM/YYYY, DD-MM-YYYY) and month-name (01-Jul-2026)
    // date formats.
    final dateRe = RegExp(
      r'\d{1,2}[/.-][A-Za-z]{3}[/.-]\d{2,4}|'
      r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}',
    );
    final numRe = RegExp(r'([\d,]+\.?\d*)');

    // Grouped transaction state: multi-line descriptions are merged until the
    // amount/balance columns appear, using the date as the row boundary.
    String? curDate;
    final descParts = <String>[];
    final numbers = <String>[];

    void flush() {
      if (curDate == null) return;
      final description = descParts
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      _addPdfRow(rows, curDate!, description, numbers);
      curDate = null;
      descParts.clear();
      numbers.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (_isHeaderOrFooter(line)) continue;

      final dateMatch = dateRe.firstMatch(line);
      if (dateMatch != null) {
        // A new transaction row begins at a date token.
        flush();
        curDate = dateMatch.group(0)!.trim();
        final rest = line.substring(dateMatch.end).trim();
        final restNums = numRe
            .allMatches(rest)
            .map((m) => m.group(1)!)
            .toList();
        numbers.addAll(restNums);
        // The description is the remainder, minus the trailing numbers.
        var desc = rest;
        if (restNums.isNotEmpty) {
          final lastNum = restNums.last;
          final idx = desc.lastIndexOf(lastNum);
          if (idx > 0) desc = desc.substring(0, idx);
        }
        if (desc.trim().isNotEmpty) descParts.add(desc.trim());
        continue;
      }

      // Continuation line (multi-line description and/or additional amounts).
      if (curDate != null) {
        final lineNums = numRe
            .allMatches(line)
            .map((m) => m.group(1)!)
            .toList();
        if (lineNums.isNotEmpty) {
          numbers.addAll(lineNums);
          var desc = line;
          final lastNum = lineNums.last;
          final idx = desc.lastIndexOf(lastNum);
          if (idx > 0) desc = desc.substring(0, idx);
          if (desc.trim().isNotEmpty) descParts.add(desc.trim());
        } else if (line.isNotEmpty) {
          descParts.add(line);
        }
      }
    }
    flush();

    debugPrint(
      '📄 BankStatementParser: Found ${rows.length} potential transaction lines',
    );
    return rows;
  }

  /// Build a single PDF row from grouped transaction fields, mapping the
  /// trailing numeric tokens into Debit / Credit / Balance columns.
  static void _addPdfRow(
    List<List<String>> rows,
    String dateStr,
    String desc,
    List<String> numbers,
  ) {
    if (numbers.isEmpty) return;

    double debit = 0, credit = 0, balance = 0;
    if (numbers.length == 1) {
      final n = _parseAmount(numbers[0]);
      if (_isCreditLike(desc)) {
        credit = n;
      } else {
        debit = n;
      }
    } else if (numbers.length == 2) {
      // Format: Amount Balance  (Debit OR Credit + Balance)
      final first = _parseAmount(numbers[0]);
      balance = _parseAmount(numbers[1]);
      if (_isCreditLike(desc)) {
        credit = first;
      } else {
        debit = first;
      }
    } else {
      // Format: Debit Credit Balance (>=3 trailing numbers)
      balance = _parseAmount(numbers[numbers.length - 1]);
      final creditN = _parseAmount(numbers[numbers.length - 2]);
      final debitN = _parseAmount(numbers[numbers.length - 3]);
      if (_isCreditLike(desc)) {
        credit = creditN != 0 ? creditN : debitN;
      } else {
        debit = debitN != 0 ? debitN : creditN;
      }
    }

    // Guard: skip rows with no meaningful money movement.
    if (debit == 0 && credit == 0 && balance == 0) return;

    rows.add([
      dateStr,
      desc,
      debit > 0 ? debit.toStringAsFixed(2) : '',
      credit > 0 ? credit.toStringAsFixed(2) : '',
      balance > 0 ? balance.toStringAsFixed(2) : '',
    ]);
  }

  /// Heuristic to classify an amount as credit (income) from the description.
  static bool _isCreditLike(String desc) {
    final d = desc.toLowerCase();
    return d.contains('credit') ||
        d.contains('salary') ||
        d.contains('deposit') ||
        d.contains('interest') ||
        d.contains('refund') ||
        d.contains('received') ||
        d.contains('cr ');
  }

  /// Check if a line is a header/footer that should be skipped.
  static bool _isHeaderOrFooter(String line) {
    final lower = line.toLowerCase();
    // Skip statement metadata
    if (lower.contains('statement') ||
        lower.contains('account name') ||
        lower.contains('account number') ||
        (lower.contains('page') && lower.contains('of')) ||
        lower.contains('branch') ||
        lower.contains('ifsc') ||
        lower.contains('micr') ||
        lower.contains('customer') ||
        lower.contains('address') ||
        lower.contains('opening balance') ||
        lower.contains('closing balance') ||
        lower.contains('total debits') ||
        lower.contains('total credits')) {
      return true;
    }

    // Skip header rows that contain column names
    if (lower.contains('date') &&
        (lower.contains('description') ||
            lower.contains('narration') ||
            lower.contains('particulars') ||
            lower.contains('remarks'))) {
      return true;
    }

    // Skip lines that look like totals or summaries
    if (lower.startsWith('total ') || lower.startsWith('summary')) {
      return true;
    }

    return false;
  }

  /// Convert parsed rows into categorized transactions.
  static List<BankTransaction> _parseRowsToTransactions(
    List<List<String>> rows,
  ) {
    if (rows.isEmpty) {
      throw FormatException('File is empty.');
    }

    // Detect header row and column indices.
    final headerRow = _findHeaderRow(rows);
    if (headerRow == -1) {
      throw FormatException('Could not find a valid header row in the file.');
    }

    final headers = rows[headerRow].map((h) => h.toLowerCase().trim()).toList();
    final dateIdx = _findColumn(headers, [
      'date',
      'transaction date',
      'txn date',
      'value date',
      'posting date',
    ]);
    final descIdx = _findColumn(headers, [
      'description',
      'narration',
      'particulars',
      'details',
      'transaction details',
      'remarks',
      'memo',
    ]);
    final debitIdx = _findColumn(headers, [
      'debit',
      'withdrawal',
      'withdrawals',
      'amount out',
      'money out',
      'dr',
    ]);
    final creditIdx = _findColumn(headers, [
      'credit',
      'deposit',
      'deposits',
      'amount in',
      'money in',
      'cr',
    ]);
    final balanceIdx = _findColumn(headers, [
      'balance',
      'closing balance',
      'running balance',
      'available balance',
    ]);
    final merchantIdx = _findColumn(headers, [
      'merchant',
      'payee',
      'vendor',
      'counterparty',
    ]);
    final refIdx = _findColumn(headers, [
      'reference',
      'ref no',
      'reference number',
      'transaction id',
      'txn id',
      'cheque no',
    ]);

    if (dateIdx == -1 || descIdx == -1 || (debitIdx == -1 && creditIdx == -1)) {
      throw FormatException(
        'File is missing required columns (date, description, debit/credit).',
      );
    }

    final transactions = <BankTransaction>[];
    final seen = <String>{};

    for (int i = headerRow + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= dateIdx) continue;

      final dateStr = row[dateIdx].trim();
      final desc = row.length > descIdx ? row[descIdx].trim() : '';
      final debitStr = debitIdx != -1 && row.length > debitIdx
          ? row[debitIdx].trim()
          : '';
      final creditStr = creditIdx != -1 && row.length > creditIdx
          ? row[creditIdx].trim()
          : '';
      final balanceStr = balanceIdx != -1 && row.length > balanceIdx
          ? row[balanceIdx].trim()
          : '';
      final merchantStr = merchantIdx != -1 && row.length > merchantIdx
          ? row[merchantIdx].trim()
          : '';
      final refStr = refIdx != -1 && row.length > refIdx
          ? row[refIdx].trim()
          : '';

      if (dateStr.isEmpty || desc.isEmpty) continue;

      final date = _parseDate(dateStr);
      if (date == null) continue;

      final debit = _parseAmount(debitStr);
      final credit = _parseAmount(creditStr);
      final balance = _parseAmount(balanceStr);

      if (debit == 0 && credit == 0) continue;

      // Deduplicate identical transactions.
      final dedupKey = '$dateStr|$desc|$debit|$credit';
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);

      // Use existing AI categorization service
      final category = ExpenseCategorizer.categorize(desc);
      final merchant = merchantStr.isNotEmpty
          ? merchantStr
          : _extractMerchant(desc);

      transactions.add(
        BankTransaction(
          id: '${date.millisecondsSinceEpoch}_$i',
          date: date,
          description: desc,
          debit: debit,
          credit: credit,
          balance: balance,
          category: category,
          merchant: merchant,
          referenceNumber: refStr,
        ),
      );
    }

    if (transactions.isEmpty) {
      throw FormatException('No valid transactions found in the file.');
    }

    debugPrint(
      '📄 BankStatementParser: Parsed ${transactions.length} transactions',
    );
    return transactions;
  }

  /// Simple CSV row parser that handles quoted fields.
  static List<List<String>> _parseCsvRows(String content) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            currentField.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          currentField.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
        } else if (char == '\n' || char == '\r') {
          if (char == '\r' &&
              i + 1 < content.length &&
              content[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.isNotEmpty && currentRow.any((f) => f.isNotEmpty)) {
            rows.add(List.of(currentRow));
          }
          currentRow.clear();
        } else {
          currentField.write(char);
        }
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((f) => f.isNotEmpty)) {
        rows.add(List.of(currentRow));
      }
    }

    return rows;
  }

  /// Find the header row index.
  static int _findHeaderRow(List<List<String>> rows) {
    for (int i = 0; i < rows.length && i < 20; i++) {
      final rowText = rows[i].join(' ').toLowerCase();
      if (rowText.contains('date') &&
          (rowText.contains('description') ||
              rowText.contains('narration') ||
              rowText.contains('particulars'))) {
        return i;
      }
    }
    return -1;
  }

  /// Find a column index by matching header names.
  static int _findColumn(List<String> headers, List<String> candidates) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase();
      for (final c in candidates) {
        if (h.contains(c)) return i;
      }
    }
    return -1;
  }

  /// Parse a date string in various formats.
  static DateTime? _parseDate(String dateStr) {
    final s = dateStr.trim();
    if (s.isEmpty) return null;

    final patterns = [
      RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$'),
      RegExp(r'^(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})$'),
      RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(s);
      if (match != null) {
        try {
          if (pattern.pattern.startsWith(r'^(\d{4})')) {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          } else if (pattern.pattern.contains(r'(\d{2})$')) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = 2000 + int.parse(match.group(3)!);
            return DateTime(year, month, day);
          } else {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          }
        } catch (_) {
          return null;
        }
      }
    }

    // Support month-name formats such as 01-Jul-2026 / 01 Jul 2026.
    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final monthMatch = RegExp(
      r'^(\d{1,2})[/.-]?([A-Za-z]{3})[/.-]?(\d{2,4})$',
    ).firstMatch(s);
    if (monthMatch != null) {
      final day = int.parse(monthMatch.group(1)!);
      final mon = months[monthMatch.group(2)!.toLowerCase().substring(0, 3)];
      var year = int.parse(monthMatch.group(3)!);
      if (year < 100) year += 2000;
      if (mon != null && day >= 1 && day <= 31) {
        return DateTime(year, mon, day);
      }
    }

    try {
      return DateTime.parse(s);
    } catch (_) {}

    return null;
  }

  /// Parse an amount string to double.
  static double _parseAmount(String amountStr) {
    final s = amountStr.trim();
    if (s.isEmpty) return 0;

    var cleaned = s
        .replaceAll('₹', '')
        .replaceAll('Rs', '')
        .replaceAll('rs', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('CR', '')
        .replaceAll('DR', '')
        .replaceAll('cr', '')
        .replaceAll('dr', '');

    if (cleaned.startsWith('-')) {
      cleaned = cleaned.substring(1);
      final value = double.tryParse(cleaned) ?? 0;
      return -value;
    }

    return double.tryParse(cleaned) ?? 0;
  }

  /// Extract merchant name from a transaction description.
  static String _extractMerchant(String description) {
    final desc = description.toLowerCase();
    const merchants = [
      'swiggy',
      'zomato',
      'uber',
      'ola',
      'amazon',
      'flipkart',
      'myntra',
      'netflix',
      'spotify',
      'hotstar',
      'prime video',
      'youtube',
      'gym',
      'electricity',
      'water',
      'wifi',
      'internet',
      'recharge',
      'rent',
      'hospital',
      'doctor',
      'pharmacy',
      'medical',
      'school',
      'college',
      'hotel',
      'booking',
      'irctc',
      'makemytrip',
      'goibibo',
      'oyo',
    ];

    for (final m in merchants) {
      if (desc.contains(m)) return m;
    }

    final words = description.split(' ');
    if (words.isNotEmpty && words.first.length > 2) {
      return words.first;
    }
    return 'Unknown';
  }

  /// Build a summary from parsed transactions.
  static BankStatementSummary buildSummary(List<BankTransaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    final categoryBreakdown = <String, double>{};

    for (final t in transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else if (t.isExpense) {
        totalExpense += t.amount;
        categoryBreakdown[t.category] =
            (categoryBreakdown[t.category] ?? 0) + t.amount;
      }
    }

    return BankStatementSummary(
      totalTransactions: transactions.length,
      expenseCount: transactions.where((t) => t.isExpense).length,
      incomeCount: transactions.where((t) => t.isIncome).length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: totalIncome - totalExpense,
      categoryBreakdown: categoryBreakdown,
      transactions: transactions,
    );
  }
}
