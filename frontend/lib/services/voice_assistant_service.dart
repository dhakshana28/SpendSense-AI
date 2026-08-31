import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceAssistantService {
  static final SpeechToText _speechToText = SpeechToText();

  static bool get isAvailable => _speechToText.isAvailable;

  static Future<bool> initialize() async {
    return await _speechToText.initialize(
      onError: (error) {
        // Handle error silently
      },
    );
  }

  static Future<String?> listen() async {
    if (!_speechToText.isAvailable) {
      await initialize();
    }

    if (!_speechToText.isListening) {
      final completer = Completer<String?>();
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            completer.complete(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          localeId: 'en_IN',
        ),
      ); // ignore: deprecated_member_use
      return completer.future;
    }

    return null;
  }

  static void stopListening() {
    _speechToText.stop();
  }

  static void cancelListening() {
    _speechToText.cancel();
  }
}