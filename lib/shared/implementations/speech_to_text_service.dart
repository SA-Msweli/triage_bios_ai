import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../interfaces/speech_interface.dart';

/// Implementation of speech recognition using speech_to_text package
class SpeechToTextService implements SpeechInterface {
  final Logger _logger = Logger();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';

  @override
  Future<bool> initialize({
    Function(String)? onError,
    Function(String)? onStatus,
  }) async {
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _logger.e('Speech recognition error: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          _logger.d('Speech recognition status: $status');
          onStatus?.call(status);
          _isListening = status == 'listening';
        },
      );

      _logger.i('Speech service initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      _logger.e('Failed to initialize speech service: $e');
      return false;
    }
  }

  @override
  Future<void> listen({
    required Function(SpeechResult) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
    String? localeId,
    Function(double)? onSoundLevelChange,
    bool cancelOnError = true,
  }) async {
    if (!_isInitialized) {
      throw Exception('Speech service not initialized');
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          final speechResult = SpeechResult(
            recognizedWords: result.recognizedWords,
            finalResult: result.finalResult,
            confidence: result.confidence,
            hasConfidenceRating: result.hasConfidenceRating,
          );
          onResult(speechResult);
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        onSoundLevelChange: onSoundLevelChange,
        // Note: Using deprecated parameters for compatibility
        // ignore: deprecated_member_use
        partialResults: partialResults,
        // ignore: deprecated_member_use
        cancelOnError: cancelOnError,
      );

      _isListening = true;
      _logger.i('Started listening for speech');
    } catch (e) {
      _logger.e('Failed to start listening: $e');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speechToText.stop();
      _isListening = false;
      _logger.i('Stopped listening for speech');
    } catch (e) {
      _logger.e('Failed to stop listening: $e');
      rethrow;
    }
  }

  @override
  Future<bool> get isAvailable async {
    return _speechToText.isAvailable;
  }

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async {
    return _speechToText.hasPermission;
  }

  @override
  Future<List<String>> locales() async {
    try {
      final locales = await _speechToText.locales();
      return locales.map((locale) => locale.localeId).toList();
    } catch (e) {
      _logger.e('Failed to get locales: $e');
      return ['en_US'];
    }
  }

  @override
  String get lastRecognizedWords => _lastRecognizedWords;
}
