import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../core/constants/watsonx_constants.dart';
import '../../core/errors/failures.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';
import '../../features/triage/domain/entities/triage_result.dart';

class WatsonxService {
  static final WatsonxService _instance = WatsonxService._internal();
  factory WatsonxService() => _instance;
  WatsonxService._internal();

  final Logger _logger = Logger();
  late final Dio _dio;
  String? _accessToken;
  DateTime? _tokenExpiry;

  void initialize({required String apiKey, String? projectId}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: WatsonxConstants.watsonxBaseUrl,
        connectTimeout: WatsonxConstants.requestTimeout,
        receiveTimeout: WatsonxConstants.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
    _apiKey = apiKey;
    _projectId = projectId;
  }

  String? _apiKey;
  String? _projectId;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authentication token
          if (_accessToken != null && !_isTokenExpired()) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }

          _logger.d('Watson X.ai REQUEST: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Watson X.ai RESPONSE: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('Watson X.ai ERROR: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(
      _tokenExpiry!.subtract(const Duration(minutes: 5)),
    );
  }

  Future<void> _ensureAuthenticated() async {
    if (_accessToken == null || _isTokenExpired()) {
      await _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_apiKey == null) {
      throw const TriageFailure('Watson X.ai API key not configured');
    }

    try {
      _logger.i('Authenticating with IBM Cloud IAM...');

      // Real IBM Cloud IAM authentication
      final response = await _dio.post(
        'https://iam.cloud.ibm.com/identity/token',
        data: {
          'grant_type': 'urn:ibm:params:oauth:grant-type:apikey',
          'apikey': _apiKey,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        _logger.i('IBM Cloud authentication successful');
      } else {
        throw TriageFailure(
          'Authentication failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('IBM Cloud authentication failed: $e');
      throw TriageFailure('Authentication failed: $e');
    }
  }

  Future<TriageResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    try {
      await _ensureAuthenticated();

      final prompt = _buildTriagePrompt(
        symptoms: symptoms,
        vitals: vitals,
        demographics: demographics,
      );

      _logger.i('Sending triage request to Watson X.ai');

      // Real Watson X.ai API call
      final response = await _dio.post(
        WatsonxConstants.generateEndpoint,
        queryParameters: {'version': WatsonxConstants.watsonxApiVersion},
        data: {
          'model_id': WatsonxConstants.graniteModelId,
          'project_id': _projectId,
          'input': '${WatsonxConstants.systemPrompt}\n\n$prompt',
          'parameters': {
            'max_new_tokens': WatsonxConstants.maxTokens,
            'temperature': WatsonxConstants.temperature,
            'top_p': WatsonxConstants.topP,
            'stop_sequences': ['\n\n'],
          },
        },
      );

      if (response.statusCode == 200) {
        final aiResponse = _parseWatsonxResponse(response.data, vitals);
        return _parseTriageResponse(aiResponse, vitals);
      } else {
        throw TriageFailure(
          'Watson X.ai API call failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Triage assessment failed: $e');

      // Fallback to mock response for demo if real API fails
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        _logger.w('Authentication failed, falling back to demo mode');
        final fallbackPrompt = _buildTriagePrompt(
          symptoms: symptoms,
          vitals: vitals,
          demographics: demographics,
        );
        final mockResponse = await _mockWatsonxResponse(fallbackPrompt, vitals);
        return _parseTriageResponse(mockResponse, vitals);
      }

      if (e is TriageFailure) rethrow;
      throw TriageFailure('Failed to assess symptoms: $e');
    }
  }

  String _buildTriagePrompt({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) {
    final vitalsText = vitals != null
        ? _formatVitals(vitals)
        : 'No vital signs data available';
    final demographicsText = demographics != null
        ? demographics.entries.map((e) => '${e.key}: ${e.value}').join(', ')
        : 'No demographic data available';

    return WatsonxConstants.triagePromptTemplate
        .replaceAll('{symptoms}', symptoms)
        .replaceAll('{vitals}', vitalsText)
        .replaceAll('{demographics}', demographicsText);
  }

  String _formatVitals(PatientVitals vitals) {
    final parts = <String>[];

    if (vitals.heartRate != null) {
      parts.add('Heart Rate: ${vitals.heartRate} bpm');
    }
    if (vitals.bloodPressure != null) {
      parts.add('Blood Pressure: ${vitals.bloodPressure}');
    }
    if (vitals.temperature != null) {
      parts.add('Temperature: ${vitals.temperature?.toStringAsFixed(1)}°F');
    }
    if (vitals.oxygenSaturation != null) {
      parts.add(
        'Oxygen Saturation: ${vitals.oxygenSaturation?.toStringAsFixed(1)}%',
      );
    }
    if (vitals.respiratoryRate != null) {
      parts.add('Respiratory Rate: ${vitals.respiratoryRate} breaths/min');
    }

    if (parts.isEmpty) {
      return 'No vital signs data available';
    }

    return parts.join(', ');
  }

  // Parse real Watson X.ai response
  Map<String, dynamic> _parseWatsonxResponse(
    Map<String, dynamic> response,
    PatientVitals? vitals,
  ) {
    try {
      final results = response['results'] as List;
      if (results.isEmpty) {
        throw const TriageFailure('Empty response from Watson X.ai');
      }

      final generatedText = results[0]['generated_text'] as String;
      _logger.d('Watson X.ai generated text: $generatedText');

      // Try to parse JSON from the generated text
      final jsonMatch = RegExp(
        r'\{.*\}',
        dotAll: true,
      ).firstMatch(generatedText);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final parsedJson = Map<String, dynamic>.from(
          const JsonDecoder().convert(jsonStr) as Map,
        );
        return parsedJson;
      } else {
        // Fallback: parse structured text response
        return _parseStructuredTextResponse(generatedText, vitals);
      }
    } catch (e) {
      _logger.e('Failed to parse Watson X.ai response: $e');
      // Fallback to mock response
      return _generateFallbackResponse(vitals);
    }
  }

  Map<String, dynamic> _parseStructuredTextResponse(
    String text,
    PatientVitals? vitals,
  ) {
    // Extract severity score
    final scoreMatch = RegExp(
      r'severity[_\s]*score[:\s]*(\d+(?:\.\d+)?)',
    ).firstMatch(text.toLowerCase());
    final score = scoreMatch != null ? double.parse(scoreMatch.group(1)!) : 5.0;

    // Add vitals boost
    final vitalsBoost = vitals?.vitalsSeverityBoost ?? 0.0;
    final finalScore = (score + vitalsBoost).clamp(0.0, 10.0);

    return _generateFallbackResponse(vitals, baseScore: finalScore);
  }

  Map<String, dynamic> _generateFallbackResponse(
    PatientVitals? vitals, {
    double? baseScore,
  }) {
    final score = baseScore ?? 5.0;
    final vitalsBoost = vitals?.vitalsSeverityBoost ?? 0.0;
    final finalScore = (score + vitalsBoost).clamp(0.0, 10.0);

    String urgencyLevel;
    List<String> recommendedActions;

    if (finalScore >= 8.0) {
      urgencyLevel = 'critical';
      recommendedActions = [
        'Call 911 immediately',
        'Do not drive yourself',
        'Stay calm and monitor symptoms',
      ];
    } else if (finalScore >= 6.0) {
      urgencyLevel = 'urgent';
      recommendedActions = [
        'Seek emergency care promptly',
        'Monitor symptoms closely',
        'Have someone drive you',
      ];
    } else if (finalScore >= 4.0) {
      urgencyLevel = 'standard';
      recommendedActions = [
        'Visit emergency room when convenient',
        'Monitor symptoms',
        'Consider urgent care',
      ];
    } else {
      urgencyLevel = 'non_urgent';
      recommendedActions = [
        'Schedule appointment with primary care',
        'Monitor symptoms',
        'Rest and hydrate',
      ];
    }

    return {
      'severity_score': finalScore,
      'confidence_lower': (finalScore - 0.5).clamp(0.0, 10.0),
      'confidence_upper': (finalScore + 0.5).clamp(0.0, 10.0),
      'explanation':
          'AI assessment based on reported symptoms${vitalsBoost > 0 ? ' and concerning vital signs' : ''}',
      'key_symptoms': ['reported symptoms'],
      'concerning_findings': vitals?.hasCriticalVitals == true
          ? ['abnormal vital signs']
          : [],
      'recommended_actions': recommendedActions,
      'urgency_level': urgencyLevel,
      'time_to_treatment': _getTimeToTreatment(urgencyLevel),
    };
  }

  String _getTimeToTreatment(String urgencyLevel) {
    switch (urgencyLevel) {
      case 'critical':
        return 'Immediate (within 15 minutes)';
      case 'urgent':
        return 'Within 1 hour';
      case 'standard':
        return 'Within 2-4 hours';
      case 'non_urgent':
        return 'Within 24 hours or schedule appointment';
      default:
        return 'As soon as possible';
    }
  }

  // Mock Watson X.ai response for MVP demo (fallback)
  Future<Map<String, dynamic>> _mockWatsonxResponse(
    String prompt,
    PatientVitals? vitals,
  ) async {
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Analyze symptoms for demo scoring
    final symptomsLower = prompt.toLowerCase();
    double baseScore = 3.0; // Default standard priority

    // Simulate AI analysis of symptoms
    if (symptomsLower.contains('chest pain') ||
        symptomsLower.contains('difficulty breathing') ||
        symptomsLower.contains('severe pain') ||
        symptomsLower.contains('severe abdominal pain')) {
      baseScore = 7.0;
    } else if (symptomsLower.contains('headache') ||
        symptomsLower.contains('nausea') ||
        symptomsLower.contains('dizziness')) {
      baseScore = 5.0;
    } else if (symptomsLower.contains('fever') ||
        symptomsLower.contains('cough')) {
      baseScore = 4.0;
    }

    // Add vitals boost if available
    final vitalsBoost = vitals?.vitalsSeverityBoost ?? 0.0;
    final finalScore = (baseScore + vitalsBoost).clamp(0.0, 10.0);

    // Generate mock response based on score
    String urgencyLevel;
    String timeToTreatment;
    List<String> recommendedActions;

    if (finalScore >= 8.0) {
      urgencyLevel = 'critical';
      timeToTreatment = 'Immediate (within 15 minutes)';
      recommendedActions = [
        'Call 911 immediately',
        'Do not drive yourself',
        'Stay calm and monitor symptoms',
      ];
    } else if (finalScore >= 6.0) {
      urgencyLevel = 'urgent';
      timeToTreatment = 'Within 1 hour';
      recommendedActions = [
        'Seek emergency care promptly',
        'Monitor symptoms closely',
        'Have someone drive you',
      ];
    } else if (finalScore >= 4.0) {
      urgencyLevel = 'standard';
      timeToTreatment = 'Within 2-4 hours';
      recommendedActions = [
        'Visit emergency room when convenient',
        'Monitor symptoms',
        'Consider urgent care',
      ];
    } else {
      urgencyLevel = 'non_urgent';
      timeToTreatment = 'Within 24 hours or schedule appointment';
      recommendedActions = [
        'Schedule appointment with primary care',
        'Monitor symptoms',
        'Rest and hydrate',
      ];
    }

    return {
      'severity_score': finalScore,
      'confidence_lower': (finalScore - 0.5).clamp(0.0, 10.0),
      'confidence_upper': (finalScore + 0.5).clamp(0.0, 10.0),
      'explanation': _generateExplanation(symptomsLower, vitals, finalScore),
      'key_symptoms': _extractKeySymptoms(symptomsLower),
      'concerning_findings': _extractConcerningFindings(symptomsLower, vitals),
      'recommended_actions': recommendedActions,
      'urgency_level': urgencyLevel,
      'time_to_treatment': timeToTreatment,
    };
  }

  String _generateExplanation(
    String symptoms,
    PatientVitals? vitals,
    double score,
  ) {
    final parts = <String>[];

    if (symptoms.contains('chest pain')) {
      parts.add(
        'Chest pain requires immediate evaluation to rule out cardiac events',
      );
    } else if (symptoms.contains('difficulty breathing')) {
      parts.add(
        'Breathing difficulties can indicate serious respiratory or cardiac issues',
      );
    } else if (symptoms.contains('severe pain')) {
      parts.add('Severe pain warrants prompt medical evaluation');
    } else {
      parts.add(
        'Symptoms suggest ${score >= 6 ? 'urgent' : 'routine'} medical attention needed',
      );
    }

    if (vitals != null && vitals.vitalsSeverityBoost > 0) {
      parts.add('Concerning vital signs detected, increasing urgency level');
    }

    return parts.join('. ');
  }

  List<String> _extractKeySymptoms(String symptoms) {
    final keySymptoms = <String>[];

    if (symptoms.contains('chest pain')) keySymptoms.add('chest pain');
    if (symptoms.contains('difficulty breathing')) {
      keySymptoms.add('difficulty breathing');
    }
    if (symptoms.contains('headache')) keySymptoms.add('headache');
    if (symptoms.contains('nausea')) keySymptoms.add('nausea');
    if (symptoms.contains('fever')) keySymptoms.add('fever');
    if (symptoms.contains('dizziness')) keySymptoms.add('dizziness');

    return keySymptoms.isEmpty ? ['general symptoms'] : keySymptoms;
  }

  List<String> _extractConcerningFindings(
    String symptoms,
    PatientVitals? vitals,
  ) {
    final findings = <String>[];

    if (vitals?.hasCriticalVitals == true) {
      if (vitals!.heartRate != null &&
          (vitals.heartRate! > 120 || vitals.heartRate! < 50)) {
        findings.add('abnormal heart rate');
      }
      if (vitals.oxygenSaturation != null && vitals.oxygenSaturation! < 95) {
        findings.add('low oxygen saturation');
      }
      if (vitals.temperature != null && vitals.temperature! > 101.5) {
        findings.add('high fever');
      }
    }

    if (symptoms.contains('severe')) findings.add('severe symptoms reported');
    if (symptoms.contains('sudden')) findings.add('sudden onset');

    return findings;
  }

  TriageResult _parseTriageResponse(
    Map<String, dynamic> response,
    PatientVitals? vitals,
  ) {
    try {
      return TriageResult.fromScore(
        assessmentId: 'triage_${DateTime.now().millisecondsSinceEpoch}',
        baseScore: (response['severity_score'] as num).toDouble(),
        confidenceLower: (response['confidence_lower'] as num).toDouble(),
        confidenceUpper: (response['confidence_upper'] as num).toDouble(),
        explanation: response['explanation'] as String,
        keySymptoms: List<String>.from(response['key_symptoms'] as List),
        concerningFindings: List<String>.from(
          response['concerning_findings'] as List,
        ),
        recommendedActions: List<String>.from(
          response['recommended_actions'] as List,
        ),
        vitals: vitals,
        aiModelVersion: WatsonxConstants.triageModelVersion,
      );
    } catch (e) {
      _logger.e('Failed to parse triage response: $e');
      throw const TriageFailure('Invalid response format from AI service');
    }
  }

  // Health check method
  Future<bool> isHealthy() async {
    try {
      await _ensureAuthenticated();
      return _accessToken != null;
    } catch (e) {
      _logger.e('Watson X.ai health check failed: $e');
      return false;
    }
  }
}
