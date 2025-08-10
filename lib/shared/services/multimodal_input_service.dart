import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import '../interfaces/speech_interface.dart';
import '../factories/speech_factory.dart';

/// Service for handling multi-modal input (voice, images, text)
class MultiModalInputService {
  static final MultiModalInputService _instance =
      MultiModalInputService._internal();
  factory MultiModalInputService() => _instance;
  MultiModalInputService._internal();

  final Logger _logger = Logger();
  SpeechInterface? _speechService;
  final ImagePicker _imagePicker = ImagePicker();

  bool _speechEnabled = false;
  bool _isListening = false;

  /// Initialize the service
  Future<bool> initialize() async {
    try {
      // Use factory to create appropriate speech service
      _speechService = await SpeechFactory.createWithFallback();
      
      _speechEnabled = await _speechService!.initialize(
        onError: (error) => _logger.e('Speech recognition error: $error'),
        onStatus: (status) => _logger.d('Speech recognition status: $status'),
      );

      _logger.i(
        'MultiModal input service initialized. Speech enabled: $_speechEnabled',
      );
      return true;
    } catch (e) {
      _logger.e('Failed to initialize MultiModal input service: $e');
      return false;
    }
  }

  /// Check if speech recognition is available
  bool get isSpeechEnabled => _speechEnabled;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Start voice input for symptoms
  Future<VoiceInputResult> startVoiceInput({
    Duration? timeout,
    Function(String)? onPartialResult,
  }) async {
    if (!_speechEnabled) {
      return VoiceInputResult.error('Speech recognition not available');
    }

    if (_isListening) {
      return VoiceInputResult.error('Already listening');
    }

    try {
      String recognizedText = '';
      bool completed = false;

      _isListening = true;

      await _speechService!.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          if (onPartialResult != null) {
            onPartialResult(recognizedText);
          }

          if (result.finalResult) {
            completed = true;
            _isListening = false;
          }
        },
        listenFor: timeout ?? const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        onSoundLevelChange: (level) {
          // Could be used for UI feedback
        },
        cancelOnError: true,
      );

      // Wait for completion or timeout
      int attempts = 0;
      while (!completed && _isListening && attempts < 300) {
        // 30 seconds max
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      _isListening = false;

      if (recognizedText.isEmpty) {
        return VoiceInputResult.error('No speech detected');
      }

      // Process and enhance the recognized text
      final processedText = _processVoiceInput(recognizedText);

      _logger.i('Voice input completed: "$processedText"');

      return VoiceInputResult.success(
        originalText: recognizedText,
        processedText: processedText,
        confidence: 0.9, // Default confidence since we can't access it directly
      );
    } catch (e) {
      _isListening = false;
      _logger.e('Voice input failed: $e');
      return VoiceInputResult.error('Voice input failed: $e');
    }
  }

  /// Stop voice input
  Future<void> stopVoiceInput() async {
    if (_isListening) {
      await _speechService!.stop();
      _isListening = false;
      _logger.i('Voice input stopped');
    }
  }

  /// Process voice input to improve medical relevance
  String _processVoiceInput(String rawText) {
    String processed = rawText.toLowerCase().trim();

    // Common speech-to-text corrections for medical terms
    final medicalCorrections = {
      'chest pane': 'chest pain',
      'chest paying': 'chest pain',
      'shortness of breath': 'difficulty breathing',
      'short of breath': 'difficulty breathing',
      'can\'t breathe': 'difficulty breathing',
      'hard to breathe': 'difficulty breathing',
      'dizzy': 'dizziness',
      'nauseous': 'nausea',
      'throwing up': 'vomiting',
      'puking': 'vomiting',
      'tummy ache': 'abdominal pain',
      'stomach ache': 'abdominal pain',
      'belly pain': 'abdominal pain',
      'head ache': 'headache',
      'migraine': 'severe headache',
      'fever': 'high temperature',
      'chills': 'fever and chills',
      'sweating': 'excessive sweating',
      'heart racing': 'rapid heart rate',
      'heart pounding': 'palpitations',
    };

    // Apply corrections
    for (final correction in medicalCorrections.entries) {
      processed = processed.replaceAll(correction.key, correction.value);
    }

    // Capitalize first letter
    if (processed.isNotEmpty) {
      processed = processed[0].toUpperCase() + processed.substring(1);
    }

    return processed;
  }

  /// Capture image for symptom documentation
  Future<ImageInputResult> captureImage({
    ImageSource source = ImageSource.camera,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality ?? 85,
      );

      if (image == null) {
        return ImageInputResult.cancelled();
      }

      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Basic image analysis (size, format validation)
      final analysis = await _analyzeImage(imageFile, imageBytes);

      _logger.i(
        'Image captured: ${image.path}, Size: ${imageBytes.length} bytes',
      );

      return ImageInputResult.success(
        imagePath: image.path,
        imageBytes: imageBytes,
        analysis: analysis,
      );
    } catch (e) {
      _logger.e('Image capture failed: $e');
      return ImageInputResult.error('Failed to capture image: $e');
    }
  }

  /// Select multiple images from gallery
  Future<MultiImageInputResult> selectMultipleImages({
    int? maxImages,
    int? imageQuality,
  }) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: imageQuality ?? 85,
      );

      if (images.isEmpty) {
        return MultiImageInputResult.cancelled();
      }

      // Limit number of images
      final limitedImages = maxImages != null && images.length > maxImages
          ? images.take(maxImages).toList()
          : images;

      final List<ImageData> imageDataList = [];

      for (final image in limitedImages) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final analysis = await _analyzeImage(imageFile, imageBytes);

        imageDataList.add(
          ImageData(path: image.path, bytes: imageBytes, analysis: analysis),
        );
      }

      _logger.i('Selected ${imageDataList.length} images');

      return MultiImageInputResult.success(imageDataList);
    } catch (e) {
      _logger.e('Multiple image selection failed: $e');
      return MultiImageInputResult.error('Failed to select images: $e');
    }
  }

  /// Basic image analysis (without AI - just metadata and validation)
  Future<ImageAnalysis> _analyzeImage(
    File imageFile,
    Uint8List imageBytes,
  ) async {
    try {
      final String fileName = imageFile.path.split('/').last;
      final String fileExtension = fileName.split('.').last.toLowerCase();
      final int fileSize = imageBytes.length;

      // Validate image format
      final bool isValidFormat = [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
      ].contains(fileExtension);

      // Basic quality assessment based on file size
      String qualityAssessment;
      if (fileSize > 2000000) {
        // > 2MB
        qualityAssessment = 'High quality';
      } else if (fileSize > 500000) {
        // > 500KB
        qualityAssessment = 'Good quality';
      } else if (fileSize > 100000) {
        // > 100KB
        qualityAssessment = 'Moderate quality';
      } else {
        qualityAssessment = 'Low quality';
      }

      // Generate basic recommendations
      final List<String> recommendations = [];

      if (!isValidFormat) {
        recommendations.add(
          'Image format not optimal for medical documentation',
        );
      }

      if (fileSize < 100000) {
        recommendations.add(
          'Image quality may be too low for detailed analysis',
        );
      }

      if (fileSize > 5000000) {
        recommendations.add('Image file is very large - consider compressing');
      }

      // Medical image type suggestions (basic heuristics)
      String suggestedType = 'General symptom documentation';
      if (fileName.toLowerCase().contains('skin') ||
          fileName.toLowerCase().contains('rash')) {
        suggestedType = 'Skin condition documentation';
      } else if (fileName.toLowerCase().contains('wound') ||
          fileName.toLowerCase().contains('cut')) {
        suggestedType = 'Wound documentation';
      }

      return ImageAnalysis(
        fileName: fileName,
        fileSize: fileSize,
        format: fileExtension,
        isValidFormat: isValidFormat,
        qualityAssessment: qualityAssessment,
        suggestedType: suggestedType,
        recommendations: recommendations,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Image analysis failed: $e');
      return ImageAnalysis.error(e.toString());
    }
  }

  /// Get available locales for speech recognition
  Future<List<String>> getAvailableLocales() async {
    if (!_speechEnabled || _speechService == null) return [];

    try {
      return await _speechService!.locales();
    } catch (e) {
      _logger.e('Failed to get available locales: $e');
      return [];
    }
  }

  /// Check microphone permission
  Future<bool> checkMicrophonePermission() async {
    if (_speechService == null) return false;
    
    try {
      return await _speechService!.hasPermission;
    } catch (e) {
      _logger.e('Failed to check microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    if (_speechService == null) return false;
    
    try {
      return await _speechService!.initialize();
    } catch (e) {
      _logger.e('Failed to request microphone permission: $e');
      return false;
    }
  }
}

/// Result classes for different input types

class VoiceInputResult {
  final bool success;
  final String? originalText;
  final String? processedText;
  final double? confidence;
  final String? error;

  VoiceInputResult._({
    required this.success,
    this.originalText,
    this.processedText,
    this.confidence,
    this.error,
  });

  factory VoiceInputResult.success({
    required String originalText,
    required String processedText,
    required double confidence,
  }) {
    return VoiceInputResult._(
      success: true,
      originalText: originalText,
      processedText: processedText,
      confidence: confidence,
    );
  }

  factory VoiceInputResult.error(String error) {
    return VoiceInputResult._(success: false, error: error);
  }
}

class ImageInputResult {
  final bool success;
  final bool cancelled;
  final String? imagePath;
  final Uint8List? imageBytes;
  final ImageAnalysis? analysis;
  final String? error;

  ImageInputResult._({
    required this.success,
    required this.cancelled,
    this.imagePath,
    this.imageBytes,
    this.analysis,
    this.error,
  });

  factory ImageInputResult.success({
    required String imagePath,
    required Uint8List imageBytes,
    required ImageAnalysis analysis,
  }) {
    return ImageInputResult._(
      success: true,
      cancelled: false,
      imagePath: imagePath,
      imageBytes: imageBytes,
      analysis: analysis,
    );
  }

  factory ImageInputResult.cancelled() {
    return ImageInputResult._(success: false, cancelled: true);
  }

  factory ImageInputResult.error(String error) {
    return ImageInputResult._(success: false, cancelled: false, error: error);
  }
}

class MultiImageInputResult {
  final bool success;
  final bool cancelled;
  final List<ImageData>? images;
  final String? error;

  MultiImageInputResult._({
    required this.success,
    required this.cancelled,
    this.images,
    this.error,
  });

  factory MultiImageInputResult.success(List<ImageData> images) {
    return MultiImageInputResult._(
      success: true,
      cancelled: false,
      images: images,
    );
  }

  factory MultiImageInputResult.cancelled() {
    return MultiImageInputResult._(success: false, cancelled: true);
  }

  factory MultiImageInputResult.error(String error) {
    return MultiImageInputResult._(
      success: false,
      cancelled: false,
      error: error,
    );
  }
}

class ImageData {
  final String path;
  final Uint8List bytes;
  final ImageAnalysis analysis;

  ImageData({required this.path, required this.bytes, required this.analysis});
}

class ImageAnalysis {
  final String fileName;
  final int fileSize;
  final String format;
  final bool isValidFormat;
  final String qualityAssessment;
  final String suggestedType;
  final List<String> recommendations;
  final DateTime timestamp;
  final String? error;

  ImageAnalysis({
    required this.fileName,
    required this.fileSize,
    required this.format,
    required this.isValidFormat,
    required this.qualityAssessment,
    required this.suggestedType,
    required this.recommendations,
    required this.timestamp,
    this.error,
  });

  factory ImageAnalysis.error(String error) {
    return ImageAnalysis(
      fileName: 'Unknown',
      fileSize: 0,
      format: 'Unknown',
      isValidFormat: false,
      qualityAssessment: 'Unable to assess',
      suggestedType: 'Unknown',
      recommendations: ['Image analysis failed'],
      timestamp: DateTime.now(),
      error: error,
    );
  }
}
