import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  late stt.SpeechToText _speechToText;
  bool _sttInitialized = false;
  bool _isListening = false;

  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsInitialized = false;
  bool _isSpeaking = false;

  static const Map<String, String> _localeMap = {'en': 'en_US', 'ar': 'ar_SA'};

  final Function(String text, bool isFinal) onSpeechRecognized;
  final Function(String error) onError;
  final Function(bool listening) onListeningChanged;
  final Function(bool speaking) onSpeakingChanged;

  SpeechService({
    required this.onSpeechRecognized,
    required this.onError,
    required this.onListeningChanged,
    required this.onSpeakingChanged,
  });

  Future<bool> initialize({String language = 'en'}) async {
    try {
      _speechToText = stt.SpeechToText();
      _sttInitialized = await _speechToText.initialize(
        onError: (error) {
          if (error.errorMsg == 'error_speech_timeout' ||
              error.errorMsg == 'error_no_match') {
            return;
          }
          onError('STT Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          _isListening = (status == 'listening');
          onListeningChanged(_isListening);
        },
      );

      await _flutterTts.setLanguage(_localeMap[language] ?? 'en_US');
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakingChanged(true);
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingChanged(false);
      });
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        onSpeakingChanged(false);
        onError('TTS Error: $msg');
      });

      _ttsInitialized = true;
      return _sttInitialized && _ttsInitialized;
    } catch (e) {
      onError('SpeechService init failed: $e');
      return false;
    }
  }

  bool get isListening => _isListening;
  bool get isSttReady => _sttInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isTtsReady => _ttsInitialized;

  Future<void> _handleResult(stt.SpeechRecognitionResult result) async {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    if (result.finalResult) {
      // Small delay to ensure we captured everything before stopping
      await stopListening();
      onSpeechRecognized(text, true);
    } else {
      onSpeechRecognized(text, false);
    }
  }

  Future<void> startListening({String language = 'en'}) async {
    if (!_sttInitialized || _isListening) return;
    final locale = _localeMap[language] ?? 'en_US';
    try {
      await _speechToText.listen(
        onResult: _handleResult,
        localeId: locale,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4), // Increased pause timeout
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      _isListening = false;
      onListeningChanged(false);
      onError('Failed to start listening: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    _isListening = false;
    onListeningChanged(false);
  }

  Future<void> speak(String text, {String language = 'en'}) async {
    if (!_ttsInitialized || _isSpeaking || text.isEmpty) return;
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(_localeMap[language] ?? 'en_US');
      await _flutterTts.setSpeechRate(language == 'ar' ? 0.35 : 0.4);
      await _flutterTts.speak(text);
    } catch (e) {
      onError('Failed to speak: $e');
    }
  }

  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;
    await _flutterTts.stop();
    _isSpeaking = false;
    onSpeakingChanged(false);
  }

  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
  }
}
