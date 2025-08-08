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
    _dio = Dio(BaseOptions(
      baseUrl: WatsonxConstants.watsonxBaseUrl,
      connectTimeout: WatsonxConstants.requestTimeout,
      receiveTimeout: WatsonxConstants.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

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
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
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
      // For MVP, we'll simulate authentication
      // In production, this would call the actual Watson X.ai auth endpoint
      _logger.i('Authenticating with Watson X.ai...');
      
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock successful authentication
      _accessToken = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
      
      _logger.i('Watson X.ai authentication successful');
    } catch (e) {
      _logger.e('Watson X.ai authentication failed: $e');
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
      
      // For MVP demo, we'll use a mock response that simulates Watson X.ai
      // In production, this would call the actual Watson X.ai API
      final response = await _mockWatsonxResponse(prompt, vitals);
      
      return _parseTriageResponse(response, vitals);
    } catch (e) {
      _logger.e('Triage assessment failed: $e');
      if (e is TriageFailure) rethrow;
      throw TriageFailure('Failed to assess symptoms: $e');
    }
  }

  String _buildTriagePrompt({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) {
    final vitalsText = vitals != null ? _formatVitals(vitals) : 'No vital signs data available';
    final demographicsText = demographics != null ? 
        demographics.entries.map((e) => '${e.key}: ${e.value}').join(', ') : 
        'No demographic data available';

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
      parts.add('Oxygen Saturation: ${vitals.oxygenSaturation?.toStringAsFixed(1)}%');
    }
    if (vitals.respiratoryRate != null) {
      parts.add('Respiratory Rate: ${vitals.respiratoryRate} breaths/min');
    }
    
    if (parts.isEmpty) {
      return 'No vital signs data available';
    }
    
    return parts.join(', ');
  }

  // Mock Watson X.ai response for MVP demo
  Future<Map<String, dynamic>> _mockWatsonxResponse(String prompt, PatientVitals? vitals) async {
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
      recommendedActions = ['Call 911 immediately', 'Do not drive yourself', 'Stay calm and monitor symptoms'];
    } else if (finalScore >= 6.0) {
      urgencyLevel = 'urgent';
      timeToTreatment = 'Within 1 hour';
      recommendedActions = ['Seek emergency care promptly', 'Monitor symptoms closely', 'Have someone drive you'];
    } else if (finalScore >= 4.0) {
      urgencyLevel = 'standard';
      timeToTreatment = 'Within 2-4 hours';
      recommendedActions = ['Visit emergency room when convenient', 'Monitor symptoms', 'Consider urgent care'];
    } else {
      urgencyLevel = 'non_urgent';
      timeToTreatment = 'Within 24 hours or schedule appointment';
      recommendedActions = ['Schedule appointment with primary care', 'Monitor symptoms', 'Rest and hydrate'];
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

  String _generateExplanation(String symptoms, PatientVitals? vitals, double score) {
    final parts = <String>[];
    
    if (symptoms.contains('chest pain')) {
      parts.add('Chest pain requires immediate evaluation to rule out cardiac events');
    } else if (symptoms.contains('difficulty breathing')) {
      parts.add('Breathing difficulties can indicate serious respiratory or cardiac issues');
    } else if (symptoms.contains('severe pain')) {
      parts.add('Severe pain warrants prompt medical evaluation');
    } else {
      parts.add('Symptoms suggest ${score >= 6 ? 'urgent' : 'routine'} medical attention needed');
    }
    
    if (vitals != null && vitals.vitalsSeverityBoost > 0) {
      parts.add('Concerning vital signs detected, increasing urgency level');
    }
    
    return parts.join('. ');
  }

  List<String> _extractKeySymptoms(String symptoms) {
    final keySymptoms = <String>[];
    
    if (symptoms.contains('chest pain')) keySymptoms.add('chest pain');
    if (symptoms.contains('difficulty breathing')) keySymptoms.add('difficulty breathing');
    if (symptoms.contains('headache')) keySymptoms.add('headache');
    if (symptoms.contains('nausea')) keySymptoms.add('nausea');
    if (symptoms.contains('fever')) keySymptoms.add('fever');
    if (symptoms.contains('dizziness')) keySymptoms.add('dizziness');
    
    return keySymptoms.isEmpty ? ['general symptoms'] : keySymptoms;
  }

  List<String> _extractConcerningFindings(String symptoms, PatientVitals? vitals) {
    final findings = <String>[];
    
    if (vitals?.hasCriticalVitals == true) {
      if (vitals!.heartRate != null && (vitals.heartRate! > 120 || vitals.heartRate! < 50)) {
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

  TriageResult _parseTriageResponse(Map<String, dynamic> response, PatientVitals? vitals) {
    try {
      return TriageResult.fromScore(
        assessmentId: 'triage_${DateTime.now().millisecondsSinceEpoch}',
        baseScore: (response['severity_score'] as num).toDouble(),
        confidenceLower: (response['confidence_lower'] as num).toDouble(),
        confidenceUpper: (response['confidence_upper'] as num).toDouble(),
        explanation: response['explanation'] as String,
        keySymptoms: List<String>.from(response['key_symptoms'] as List),
        concerningFindings: List<String>.from(response['concerning_findings'] as List),
        recommendedActions: List<String>.from(response['recommended_actions'] as List),
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