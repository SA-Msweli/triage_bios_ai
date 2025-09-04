import 'package:logger/logger.dart';
import '../../../../shared/services/gemini_service.dart';
import '../../../../shared/services/health_service.dart';
import '../../domain/entities/patient_vitals.dart';
import '../../domain/entities/triage_result.dart';

/// Main triage service that orchestrates AI assessment with vitals integration
class TriageService {
  static final TriageService _instance = TriageService._internal();
  factory TriageService() => _instance;
  TriageService._internal();

  final Logger _logger = Logger();
  late final GeminiService _geminiService;
  late final HealthService _healthService;
  bool _isInitialized = false;

  /// Initialize the triage service with required dependencies
  Future<void> initialize({required String geminiApiKey}) async {
    if (_isInitialized) {
      _logger.w('TriageService already initialized');
      return;
    }

    _geminiService = GeminiService();
    await _geminiService.initialize(apiKey: geminiApiKey);
    _healthService = HealthService();
    _isInitialized = true;

    _logger.i('TriageService initialized successfully');
  }

  /// Perform comprehensive triage assessment with vitals enhancement
  Future<TriageResult> performTriageAssessment({
    required String symptoms,
    PatientVitals? providedVitals,
    Map<String, dynamic>? demographics,
    bool includeVitals = true,
  }) async {
    _ensureInitialized();

    try {
      _logger.i(
        'Starting triage assessment for symptoms: ${symptoms.length > 50 ? '${symptoms.substring(0, 50)}...' : symptoms}',
      );

      PatientVitals? vitals = providedVitals;

      // Try to get latest vitals if not provided and requested
      if (vitals == null && includeVitals) {
        try {
          vitals = await _healthService.getLatestVitals();
          if (vitals != null) {
            _logger.i(
              'Retrieved vitals from health service: HR=${vitals.heartRate}, SpO2=${vitals.oxygenSaturation}',
            );
          }
        } catch (e) {
          _logger.w('Failed to retrieve vitals, continuing without: $e');
        }
      }

      // Perform AI assessment using Gemini
      final result = await _geminiService.assessSymptoms(
        symptoms: symptoms,
        vitals: vitals,
        demographics: demographics,
      );

      _logger.i(
        'Triage assessment completed: Score=${result.severityScore}, Level=${result.urgencyLevelString}',
      );

      // Log vitals contribution if available
      if (result.vitalsContribution != null && result.vitalsContribution! > 0) {
        _logger.i(
          'Vitals contributed +${result.vitalsContribution} points to severity score',
        );
      }

      return result;
    } catch (e) {
      _logger.e('Triage assessment failed: $e');
      rethrow;
    }
  }

  /// Get the latest vitals from connected health devices
  Future<PatientVitals?> getLatestVitals() async {
    _ensureInitialized();

    try {
      return await _healthService.getLatestVitals();
    } catch (e) {
      _logger.e('Failed to get latest vitals: $e');
      return null;
    }
  }

  /// Check if health permissions are granted
  Future<bool> hasHealthPermissions() async {
    _ensureInitialized();

    try {
      return await _healthService.hasHealthPermissions();
    } catch (e) {
      _logger.e('Failed to check health permissions: $e');
      return false;
    }
  }

  /// Request health permissions from the user
  Future<void> requestHealthPermissions() async {
    _ensureInitialized();

    try {
      await _healthService.requestPermissions();
      _logger.i('Health permissions requested');
    } catch (e) {
      _logger.e('Failed to request health permissions: $e');
      rethrow;
    }
  }

  /// Check if the Gemini AI service is healthy
  Future<bool> isGeminiHealthy() async {
    _ensureInitialized();

    try {
      final healthStatus = await _geminiService.getHealthStatus();
      return healthStatus['gemini'] == true;
    } catch (e) {
      _logger.e('Gemini AI health check failed: $e');
      return false;
    }
  }

  /// Perform a quick system health check
  Future<Map<String, bool>> performHealthCheck() async {
    _ensureInitialized();

    final results = <String, bool>{};

    // Check Gemini AI service
    try {
      results['gemini'] = await isGeminiHealthy();
    } catch (e) {
      results['gemini'] = false;
    }

    // Check health service permissions
    try {
      results['health_permissions'] = await _healthService
          .hasHealthPermissions();
    } catch (e) {
      results['health_permissions'] = false;
    }

    _logger.i('Health check completed: $results');
    return results;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'TriageService not initialized. Call initialize() first.',
      );
    }
  }
}
