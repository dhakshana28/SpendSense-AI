import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Central backend configuration for the SpendSense AI app.
///
/// The Gemini API key lives ONLY on the backend server environment.
/// Flutter never calls Google Gemini directly and never ships a secret.
class ApiConfig {
  ApiConfig._();

  static const String prefKeyCustomBackendUrl = 'custom_backend_url';
  static const String prefKeyCustomAuthKey = 'custom_backend_auth_key';

  /// Set via `--dart-define=API_BASE_URL=...` or `--dart-define=BACKEND_BASE_URL=...`.
  static const String _dartDefineBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment('BACKEND_BASE_URL', defaultValue: ''),
  );

  /// Set via `--dart-define=BACKEND_LAN_URL=...`.
  static const String _dartDefineLanUrl = String.fromEnvironment(
    'BACKEND_LAN_URL',
    defaultValue: '',
  );

  /// Set via `--dart-define=BACKEND_PUBLIC_URL=...`.
  static const String _dartDefinePublicUrl = String.fromEnvironment(
    'BACKEND_PUBLIC_URL',
    defaultValue: '',
  );

  /// Set via `--dart-define=BACKEND_AUTH_KEY=...`.
  static const String _dartDefineAuthKey = String.fromEnvironment(
    'BACKEND_AUTH_KEY',
    defaultValue: '',
  );

  /// Default production remote HTTPS URL hosted 24/7 on Render.
  /// Works independently of personal PC across Wi-Fi and mobile data.
  static const String defaultProductionBackendUrl = 'https://spendsense-ai-backend.onrender.com';

  /// Default production auth key matching the secure backend deployment.
  static const String defaultProductionAuthKey = 'ss_key_8e4f9b2d1c6a7e305928416d8a7c2e0b';

  static String? _customBaseUrl;
  static String? _customAuthKey;
  static String? _activeBaseUrl;

  /// Loads any user-saved custom backend URL and auth key from persistent storage.
  static Future<void> loadSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKeyCustomBackendUrl)?.trim() ?? '';
      if (saved.isNotEmpty) {
        final formatted = trimTrailingSlash(saved);
        if (formatted.contains('trycloudflare.com') && defaultProductionBackendUrl.isNotEmpty) {
          debugPrint('[ApiConfig] Discarding temporary quick tunnel override in favor of 24/7 cloud backend.');
          await prefs.remove(prefKeyCustomBackendUrl);
          _customBaseUrl = null;
          _activeBaseUrl = null;
        } else {
          _customBaseUrl = formatted;
          _activeBaseUrl = _customBaseUrl;
          debugPrint('[ApiConfig] Loaded custom backend URL: $_customBaseUrl');
        }
      }
      final savedKey = prefs.getString(prefKeyCustomAuthKey)?.trim() ?? '';
      if (savedKey.isNotEmpty) {
        _customAuthKey = savedKey;
        debugPrint('[ApiConfig] Loaded custom auth key.');
      }
    } catch (_) {
      // SharedPreferences is only available with initialized Flutter bindings.
    }
  }

  /// Sets or clears a persistent custom backend URL in SharedPreferences.
  static Future<void> setCustomBaseUrl(String? url) async {
    final clean = url?.trim() ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (clean.isNotEmpty) {
        final formatted = trimTrailingSlash(clean);
        await prefs.setString(prefKeyCustomBackendUrl, formatted);
        _customBaseUrl = formatted;
        _activeBaseUrl = formatted;
        debugPrint('[ApiConfig] Saved custom backend URL: $formatted');
      } else {
        await prefs.remove(prefKeyCustomBackendUrl);
        _customBaseUrl = null;
        _activeBaseUrl = null;
        debugPrint('[ApiConfig] Cleared custom backend URL');
      }
    } catch (e) {
      debugPrint('[ApiConfig] Error saving custom URL: $e');
    }
  }

  /// Sets or clears a persistent custom backend authentication key.
  static Future<void> setCustomAuthKey(String? key) async {
    final clean = key?.trim() ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (clean.isNotEmpty) {
        await prefs.setString(prefKeyCustomAuthKey, clean);
        _customAuthKey = clean;
        debugPrint('[ApiConfig] Saved custom auth key.');
      } else {
        await prefs.remove(prefKeyCustomAuthKey);
        _customAuthKey = null;
        debugPrint('[ApiConfig] Cleared custom auth key.');
      }
    } catch (e) {
      debugPrint('[ApiConfig] Error saving custom auth key: $e');
    }
  }

  /// Automatically discovers the active public tunnel URL or LAN URL by probing the PC
  /// on the local Wi-Fi network at `/api/tunnel-info`.
  ///
  /// When found, saves the discovered URL to persistent storage so the app connects
  /// seamlessly without requiring an APK rebuild or manual configuration.
  static Future<String?> autoDiscoverTunnelUrlFromLan({
    List<String>? candidateLanIps,
  }) async {
    final defaultIps = <String>[
      if (dotenv.isInitialized && (dotenv.env['BACKEND_LAN_URL'] ?? '').isNotEmpty)
        dotenv.env['BACKEND_LAN_URL']!,
      'http://192.168.1.9:8000',
      'http://10.0.2.2:8000',
      'http://127.0.0.1:8000',
      'http://localhost:8000',
    ];
    final probeList = candidateLanIps ?? defaultIps;
    final distinct = probeList.map(trimTrailingSlash).toSet().toList();

    for (final base in distinct) {
      try {
        final uri = Uri.parse('$base/api/tunnel-info');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) {
            final pubUrl = (decoded['publicUrl'] ?? '').toString().trim();
            final targetUrl = pubUrl.isNotEmpty ? pubUrl : base;
            await setCustomBaseUrl(targetUrl);
            debugPrint('[ApiConfig] Auto-discovered backend at $base (using: $targetUrl)');
            return targetUrl;
          }
        }
      } catch (_) {
        // Continue probing other candidates
      }
    }
    return null;
  }

  /// Returns the configured auth key for backend authentication.
  static String get authKey {
    if (_customAuthKey != null && _customAuthKey!.isNotEmpty) {
      return _customAuthKey!;
    }
    if (_dartDefineAuthKey.isNotEmpty) {
      return _dartDefineAuthKey;
    }
    if (dotenv.isInitialized) {
      final key = (dotenv.env['BACKEND_AUTH_KEY'] ?? '').trim();
      if (key.isNotEmpty) return key;
    }
    return defaultProductionAuthKey;
  }

  /// Synchronous setter for in-memory / test overrides.
  static void setCustomBaseUrlSync(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _customBaseUrl = trimTrailingSlash(url.trim());
      _activeBaseUrl = _customBaseUrl;
    } else {
      _customBaseUrl = null;
      _activeBaseUrl = null;
    }
  }

  /// Currently configured custom backend URL (if any).
  static String? get customBaseUrl => _customBaseUrl;

  /// Sets the runtime resolved backend URL after a successful health check probe.
  static void setActiveBaseUrl(String url) {
    if (url.trim().isNotEmpty) {
      _activeBaseUrl = trimTrailingSlash(url.trim());
    }
  }

  /// Clears the cached active base URL so the next probe re-discovers a live host.
  static void resetActiveBaseUrl() {
    _activeBaseUrl = null;
  }

  /// Ordered list of candidate backend URLs to probe for health on startup or refresh.
  static List<String> get candidateBaseUrls {
    final list = <String>[];

    // 1. User-customized backend URL from in-app settings (highest priority)
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      list.add(trimTrailingSlash(_customBaseUrl!));
    }

    // 2. Production Remote HTTPS URL (from dart-define, .env, or default constant)
    if (_dartDefinePublicUrl.isNotEmpty) {
      list.add(trimTrailingSlash(_dartDefinePublicUrl));
    }

    String envPublic = '';
    String envBase = '';
    String envLan = '';
    if (dotenv.isInitialized) {
      envPublic = (dotenv.env['BACKEND_PUBLIC_URL'] ?? '').trim();
      envBase = (dotenv.env['API_BASE_URL'] ?? dotenv.env['BACKEND_BASE_URL'] ?? '').trim();
      envLan = (dotenv.env['BACKEND_LAN_URL'] ?? '').trim();
    }
    if (envPublic.isNotEmpty) list.add(trimTrailingSlash(envPublic));
    if (_dartDefineBaseUrl.isNotEmpty) list.add(trimTrailingSlash(_dartDefineBaseUrl));
    if (envBase.isNotEmpty) list.add(trimTrailingSlash(envBase));

    if (defaultProductionBackendUrl.isNotEmpty) {
      list.add(trimTrailingSlash(defaultProductionBackendUrl));
    }

    // 3. Explicit active URL if already resolved
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      list.add(trimTrailingSlash(_activeBaseUrl!));
    }

    // 4. Local Development Targets (LAN / Loopback / USB / Emulator) - dev only
    if (!kReleaseMode) {
      if (_dartDefineLanUrl.isNotEmpty) {
        list.add(trimTrailingSlash(_dartDefineLanUrl));
      }
      if (envLan.isNotEmpty) list.add(trimTrailingSlash(envLan));

      if (kIsWeb) {
        list.add('http://localhost:8000');
        list.add('http://127.0.0.1:8000');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Physical Android phone over USB (requires `adb reverse tcp:8000 tcp:8000`)
        list.add('http://127.0.0.1:8000');
        // Android emulator reaches host loopback via 10.0.2.2
        list.add('http://10.0.2.2:8000');
        list.add('http://10.0.3.2:8000');
        list.add('http://localhost:8000');
      } else {
        list.add('http://localhost:8000');
        list.add('http://127.0.0.1:8000');
      }
    }

    // Preserve custom URL at top priority if explicitly specified by user or test
    final distinct = list.map(trimTrailingSlash).where((u) => u.isNotEmpty).toSet().toList();
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      final custom = trimTrailingSlash(_customBaseUrl!);
      distinct.remove(custom);
      final httpsUrls = distinct.where((u) => u.startsWith('https://')).toList();
      final otherUrls = distinct.where((u) => !u.startsWith('https://')).toList();
      return [custom, ...httpsUrls, ...otherUrls];
    }

    final httpsUrls = distinct.where((u) => u.startsWith('https://')).toList();
    final otherUrls = distinct.where((u) => !u.startsWith('https://')).toList();
    return [...httpsUrls, ...otherUrls];
  }

  /// Currently active or default base URL.
  static String get baseUrl {
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      return _activeBaseUrl!;
    }
    final candidates = candidateBaseUrls;
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    return 'http://127.0.0.1:8000';
  }

  static String get healthUrl => '$baseUrl/health';
  static String get apiHealthUrl => '$baseUrl/api/health';
  static String get chatUrl => '$baseUrl/api/ai/chat';
  static String get deepHealthUrl => '$baseUrl/api/ai/health/deep';

  static String trimTrailingSlash(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
