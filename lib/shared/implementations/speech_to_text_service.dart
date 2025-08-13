import 'package:logger/logger.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;  // Disabled - dependency removed
import '../interfaces/speech_interface.dart';

/// Disabled implementation of speech recognition - speech_to_text dependency removed
/// This service provides fallback responses for all speech-related functionality
class SpeechToTextService implements SpeechInterface {
  final Logger _logger = Logger();
  // final stt.SpeechToText _speechToText = stt.SpeechToText();  // Disabled - dependency removed

  static const bool _isInitialized = false;
  static const bool _isListening = false;
  static const String _lastRecognizedWords = '';

  @override
  Future<bool> initialize({
    Function(String)? onError,
    Function(String)? onStatus,
  }) async {
    // Speech-to-text service completely disabled - dependency removed
    _logger.w(
      'Speech-to-text service disabled - dependency removed for compatibility',
    );
    return false;
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
    // Speech-to-text service completely disabled - dependency removed
    _logger.w('Speech listening not available - service disabled');
    throw Exception('Speech-to-text service disabled - dependency removed');
  }

  @override
  Future<void> stop() async {
    // Speech-to-text service completely disabled - dependency removed
    _logger.i('Speech stop called (service disabled)');
  }

  @override
  Future<bool> get isAvailable async {
    return _isInitialized; // Speech-to-text service disabled - dependency removed
  }

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async {
    return false; // Speech-to-text service disabled - dependency removed
  }

  @override
  Future<List<String>> locales() async {
    return []; // Speech-to-text service disabled - dependency removed
  }

  @override
  String get lastRecognizedWords => _lastRecognizedWords;
}
