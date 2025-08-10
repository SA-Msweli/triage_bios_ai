/// Simple speech result wrapper
class SpeechResult {
  final String recognizedWords;
  final bool finalResult;
  final double confidence;
  final bool hasConfidenceRating;

  SpeechResult({
    required this.recognizedWords,
    required this.finalResult,
    required this.confidence,
    required this.hasConfidenceRating,
  });
}

/// Interface for speech recognition services
abstract class SpeechInterface {
  /// Initialize the speech recognition service
  Future<bool> initialize({
    Function(String)? onError,
    Function(String)? onStatus,
  });

  /// Start listening for speech input
  Future<void> listen({
    required Function(SpeechResult) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
    String? localeId,
    Function(double)? onSoundLevelChange,
    bool cancelOnError = true,
  });

  /// Stop listening for speech input
  Future<void> stop();

  /// Check if speech recognition is available
  Future<bool> get isAvailable;

  /// Check if currently listening
  bool get isListening;

  /// Check if speech recognition has permission
  Future<bool> get hasPermission;

  /// Get available locales for speech recognition
  Future<List<String>> locales();

  /// Get the last recognized words with confidence
  String get lastRecognizedWords;
}
