import 'dart:io';
import 'package:logger/logger.dart';
import '../interfaces/speech_interface.dart';
import '../implementations/speech_to_text_service.dart';

/// Factory for creating speech recognition services
class SpeechFactory {
  static final Logger _logger = Logger();

  /// Create the appropriate speech service for the current platform
  static Future<SpeechInterface> create() async {
    try {
      // For now, we use speech_to_text for all platforms
      // In the future, we could add platform-specific implementations
      return SpeechToTextService();
    } catch (e) {
      _logger.e('Failed to create speech service: $e');
      rethrow;
    }
  }

  /// Create speech service with fallback to mock implementation
  static Future<SpeechInterface> createWithFallback() async {
    try {
      final service = await create();
      final initialized = await service.initialize();
      
      if (initialized) {
        return service;
      } else {
        _logger.w('Primary speech service failed, using mock implementation');
        return MockSpeechService();
      }
    } catch (e) {
      _logger.w('Speech service creation failed, using mock implementation: $e');
      return MockSpeechService();
    }
  }

  /// Check if speech recognition is supported on current platform
  static bool get isPlatformSupported {
    return Platform.isAndroid || Platform.isIOS;
  }
}

/// Mock speech service for testing and fallback
class MockSpeechService implements SpeechInterface {
  final Logger _logger = Logger();
  bool _isListening = false;

  @override
  Future<bool> initialize({
    Function(String)? onError,
    Function(String)? onStatus,
  }) async {
    _logger.i('Mock speech service initialized');
    return true;
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
    _isListening = true;
    _logger.i('Mock speech service started listening');
    
    // Simulate speech recognition after a delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate partial result
    if (partialResults) {
      onResult(SpeechResult(
        recognizedWords: 'chest pain',
        finalResult: false,
        confidence: 0.8,
        hasConfidenceRating: true,
      ));
    }
    
    // Simulate final result
    await Future.delayed(const Duration(seconds: 1));
    onResult(SpeechResult(
      recognizedWords: 'chest pain and shortness of breath',
      finalResult: true,
      confidence: 0.9,
      hasConfidenceRating: true,
    ));
    
    _isListening = false;
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    _logger.i('Mock speech service stopped');
  }

  @override
  Future<bool> get isAvailable async => true;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<List<String>> locales() async {
    return ['en_US', 'es_ES', 'fr_FR'];
  }

  @override
  String get lastRecognizedWords => 'chest pain and shortness of breath';
}