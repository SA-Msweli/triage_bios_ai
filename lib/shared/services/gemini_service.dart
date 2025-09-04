import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../core/constants/gemini_constants.dart';
import '../../core/errors/failures.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';
import '../../features/triage/domain/entities/triage_result.dart';
import 'medical_algorithm_service.dart';
import 'vitals_trend_service.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final Logger _logger = Logger();
  final MedicalAlgorithmService _medicalService = MedicalAlgorithmService();
  final VitalsTrendService _trendService = VitalsTrendService();

  late Dio _dio;
  String? _apiKey;
  bool _isInitialized = false;

  /// Initialize the Gemini service with API credentials
  Future<void> initialize({required String apiKey}) async {
    if (_isInitialized) return;

    _apiKey = apiKey;

    _dio = Dio(
      BaseOptions(
        baseUrl: GeminiConstants.geminiBaseUrl,
        connectTimeout: GeminiConstants.requestTimeout,
        receiveTimeout: GeminiConstants.requestTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add interceptors for logging and error handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_apiKey != null) {
            options.queryParameters['key'] = _apiKey!;
          }

          _logger.d('Gemini AI REQUEST: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Gemini AI RESPONSE: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('Gemini AI ERROR: ${error.message}');
          handler.next(error);
        },
      ),
    );

    _isInitialized = true;
    _logger.i('Gemini AI service initialized successfully');
  }

  /// Ensure the service is authenticated and ready
  Future<void> _ensureAuthenticated() async {
    if (!_isInitialized) {
      throw const TriageFailure('Gemini AI service not initialized');
    }

    if (_apiKey == null) {
      throw const TriageFailure('Gemini AI API key not configured');
    }
  }

  /// Assess patient symptoms using Gemini AI with vitals enhancement
  Future<TriageResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    try {
      await _ensureAuthenticated();

      // Build the prompt for Gemini
      final prompt = _buildTriagePrompt(symptoms, vitals, demographics);

      Map<String, dynamic>? aiResponse;

      // Try Gemini AI first if credentials available
      try {
        _logger.i('Sending triage request to Gemini AI');

        // Real Gemini AI API call
        final response = await _dio.post(
          GeminiConstants.generateEndpoint,
          data: {
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': GeminiConstants.temperature,
              'topK': GeminiConstants.topK,
              'topP': GeminiConstants.topP,
              'maxOutputTokens': GeminiConstants.maxTokens,
            },
            'safetySettings': GeminiConstants.safetySettings,
          },
        );

        if (response.statusCode == 200) {
          aiResponse = _parseGeminiResponse(response.data, vitals);
        }
      } catch (e) {
        _logger.w('Gemini AI unavailable, using medical algorithms: $e');
        // Will fall back to medical algorithms below
      }

      // If AI failed, use medical algorithms as fallback
      if (aiResponse == null) {
        _logger.i('Using medical algorithm fallback for triage assessment');
        final medicalResult = await _medicalService.analyzePatient(
          symptoms: symptoms,
          vitals: vitals,
          demographics: demographics,
        );

        // Convert medical result to expected format
        aiResponse = {
          'severity_score': medicalResult.finalScore,
          'confidence_lower': (medicalResult.confidence - 0.1).clamp(0.0, 1.0),
          'confidence_upper': (medicalResult.confidence + 0.1).clamp(0.0, 1.0),
          'explanation': medicalResult.clinicalReasoning,
          'key_symptoms': <String>[],
          'concerning_findings': medicalResult.riskFactors,
          'recommended_actions': medicalResult.recommendations,
          'urgency_level': medicalResult.esiLevel <= 2 ? 'urgent' : 'standard',
          'time_to_treatment': medicalResult.esiLevel <= 2
              ? 'within 1 hour'
              : 'within 2-4 hours',
          'ai_source': 'medical_algorithm',
        };
      }

      // Enhance with vitals trend analysis if available
      if (vitals != null) {
        final trendAnalysis = await _trendService.analyzeTrends(hoursBack: 24);

        // Adjust severity based on concerning trends
        if (trendAnalysis.deteriorationRisk == DeteriorationRisk.high ||
            trendAnalysis.overallStability == StabilityLevel.unstable) {
          final currentSeverity = aiResponse['severity_score'] as double;
          aiResponse['severity_score'] = (currentSeverity + 1.0).clamp(
            0.0,
            10.0,
          );
          aiResponse['explanation'] =
              '${aiResponse['explanation']} [Severity increased due to concerning vital trends]';
        }
      }

      // Create TriageResult using the fromScore factory method
      return TriageResult.fromScore(
        assessmentId: DateTime.now().millisecondsSinceEpoch.toString(),
        baseScore: aiResponse['severity_score'] as double,
        confidenceLower: aiResponse['confidence_lower'] as double,
        confidenceUpper: aiResponse['confidence_upper'] as double,
        explanation: aiResponse['explanation'] as String,
        keySymptoms: List<String>.from(aiResponse['key_symptoms'] ?? []),
        concerningFindings: List<String>.from(
          aiResponse['concerning_findings'] ?? [],
        ),
        recommendedActions: List<String>.from(
          aiResponse['recommended_actions'] ?? [],
        ),
        vitals: vitals,
        aiModelVersion: aiResponse['ai_source'] as String? ?? 'gemini-pro',
      );
    } catch (e) {
      _logger.e('Failed to assess symptoms: $e');
      rethrow;
    }
  }

  /// Build triage prompt for Gemini AI
  String _buildTriagePrompt(
    String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  ) {
    final vitalsText = vitals != null
        ? 'Heart Rate: ${vitals.heartRate ?? 'N/A'} bpm, '
              'Blood Pressure: ${vitals.bloodPressure ?? 'N/A'}, '
              'Temperature: ${vitals.temperature ?? 'N/A'}°C, '
              'Oxygen Saturation: ${vitals.oxygenSaturation ?? 'N/A'}%, '
              'Respiratory Rate: ${vitals.respiratoryRate ?? 'N/A'} breaths/min'
        : 'No vital signs available';

    final demographicsText = demographics != null
        ? 'Age: ${demographics['age'] ?? 'N/A'}, '
              'Gender: ${demographics['gender'] ?? 'N/A'}, '
              'Medical History: ${demographics['medical_history'] ?? 'None reported'}'
        : 'No demographic data available';

    return GeminiConstants.triagePromptTemplate
        .replaceAll('{symptoms}', symptoms)
        .replaceAll('{vitals}', vitalsText)
        .replaceAll('{demographics}', demographicsText);
  }

  // Parse real Gemini AI response
  Map<String, dynamic> _parseGeminiResponse(
    Map<String, dynamic> response,
    PatientVitals? vitals,
  ) {
    try {
      final candidates = response['candidates'] as List;
      if (candidates.isEmpty) {
        throw const TriageFailure('Empty response from Gemini AI');
      }

      final content = candidates[0]['content'];
      final parts = content['parts'] as List;
      if (parts.isEmpty) {
        throw const TriageFailure('No content parts in Gemini AI response');
      }

      final generatedText = parts[0]['text'] as String;
      _logger.d('Gemini AI generated text: $generatedText');

      // Try to parse JSON from the generated text
      final jsonMatch = RegExp(
        r'\{.*\}',
        dotAll: true,
      ).firstMatch(generatedText);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Ensure required fields exist with defaults
        return {
          'severity_score': (parsed['severity_score'] ?? 5.0).toDouble(),
          'confidence_lower': (parsed['confidence_lower'] ?? 0.7).toDouble(),
          'confidence_upper': (parsed['confidence_upper'] ?? 0.9).toDouble(),
          'explanation': parsed['explanation'] ?? 'AI assessment completed',
          'key_symptoms': parsed['key_symptoms'] ?? [],
          'concerning_findings': parsed['concerning_findings'] ?? [],
          'recommended_actions': parsed['recommended_actions'] ?? [],
          'urgency_level': parsed['urgency_level'] ?? 'standard',
          'time_to_treatment':
              parsed['time_to_treatment'] ?? 'within 2-4 hours',
          'ai_source': 'gemini',
        };
      } else {
        // Fallback parsing if JSON not found
        return _fallbackParseResponse(generatedText, vitals);
      }
    } catch (e) {
      _logger.e('Failed to parse Gemini AI response: $e');
      // Return fallback response
      return _fallbackParseResponse('', vitals);
    }
  }

  /// Fallback response parsing when JSON parsing fails
  Map<String, dynamic> _fallbackParseResponse(
    String text,
    PatientVitals? vitals,
  ) {
    // Extract severity score from text if possible
    double severityScore = 5.0;
    final severityMatch = RegExp(
      r'severity[:\s]*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (severityMatch != null) {
      severityScore = double.tryParse(severityMatch.group(1)!) ?? 5.0;
    }

    return {
      'severity_score': severityScore,
      'confidence_lower': 0.6,
      'confidence_upper': 0.8,
      'explanation': text.isNotEmpty
          ? text.substring(0, text.length > 200 ? 200 : text.length)
          : 'AI assessment completed with limited parsing',
      'key_symptoms': <String>[],
      'concerning_findings': <String>[],
      'recommended_actions': ['Seek medical evaluation'],
      'urgency_level': severityScore >= 7 ? 'urgent' : 'standard',
      'time_to_treatment': severityScore >= 7
          ? 'within 1 hour'
          : 'within 2-4 hours',
      'ai_source': 'gemini_fallback',
    };
  }

  /// Get service health status
  Future<Map<String, bool>> getHealthStatus() async {
    try {
      await _ensureAuthenticated();

      // Simple health check - try to make a minimal request
      final response = await _dio
          .post(
            GeminiConstants.generateEndpoint,
            data: {
              'contents': [
                {
                  'parts': [
                    {'text': 'Health check'},
                  ],
                },
              ],
              'generationConfig': {'maxOutputTokens': 10},
            },
          )
          .timeout(Duration(seconds: 5));

      return {
        'gemini': response.statusCode == 200,
        'initialized': _isInitialized,
      };
    } catch (e) {
      _logger.w('Gemini AI health check failed: $e');
      return {'gemini': false, 'initialized': _isInitialized};
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
    _isInitialized = false;
  }
}
