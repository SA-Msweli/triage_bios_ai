import 'package:flutter_test/flutter_test.dart';
import 'package:triage_bios_ai/features/triage/data/datasources/triage_service.dart';
import 'package:triage_bios_ai/features/triage/domain/entities/patient_vitals.dart';

void main() {
  group('TriageService Tests', () {
    late TriageService triageService;

    setUp(() {
      triageService = TriageService();
      // Initialize with mock API key for testing
      triageService.initialize(geminiApiKey: 'test_api_key');
    });

    test('should perform basic triage assessment without vitals', () async {
      // Arrange
      const symptoms = 'I have a headache and feel dizzy';

      // Act
      final result = await triageService.performTriageAssessment(
        symptoms: symptoms,
        includeVitals: false,
      );

      // Assert
      expect(result.assessmentId, isNotEmpty);
      expect(result.severityScore, greaterThanOrEqualTo(0));
      expect(result.severityScore, lessThanOrEqualTo(10));
      expect(result.explanation, isNotEmpty);
      expect(result.keySymptoms, isNotEmpty);
      expect(result.recommendedActions, isNotEmpty);
    });

    test('should perform triage assessment with mock vitals', () async {
      // Arrange
      const symptoms = 'I have chest pain and difficulty breathing';
      final vitals = PatientVitals(
        heartRate: 130, // Elevated
        oxygenSaturation: 92.0, // Low
        temperature: 98.6,
        bloodPressure: '140/90',
        timestamp: DateTime.now(),
        deviceSource: 'test_device',
      );

      // Act
      final result = await triageService.performTriageAssessment(
        symptoms: symptoms,
        providedVitals: vitals,
      );

      // Assert
      expect(
        result.severityScore,
        greaterThan(5.0),
      ); // Should be higher due to symptoms + vitals
      expect(
        result.vitalsContribution,
        greaterThan(0),
      ); // Vitals should contribute
      expect(result.vitals, equals(vitals));
      expect(result.vitalsExplanation, contains('vitals'));
    });

    test('should handle critical vitals correctly', () async {
      // Arrange
      const symptoms = 'I feel unwell';
      final criticalVitals = PatientVitals(
        heartRate: 45, // Bradycardia
        oxygenSaturation: 88.0, // Critical hypoxemia
        temperature: 104.0, // High fever
        bloodPressure: '200/130', // Hypertensive crisis
        timestamp: DateTime.now(),
        deviceSource: 'test_device',
      );

      // Act
      final result = await triageService.performTriageAssessment(
        symptoms: symptoms,
        providedVitals: criticalVitals,
      );

      // Assert
      expect(
        result.severityScore,
        greaterThanOrEqualTo(8.0),
      ); // Should be critical
      expect(result.isCritical, isTrue);
      expect(result.requiresImmediateAttention, isTrue);
      expect(result.urgencyLevelString, equals('CRITICAL'));
      expect(
        result.vitalsContribution,
        greaterThan(2.0),
      ); // Significant vitals boost
    });

    test('should perform health check', () async {
      // Act
      final healthStatus = await triageService.performHealthCheck();

      // Assert
      expect(healthStatus, isA<Map<String, bool>>());
      expect(healthStatus.containsKey('gemini'), isTrue);
      expect(healthStatus.containsKey('health_permissions'), isTrue);
    });

    test('should handle different urgency levels correctly', () async {
      // Test non-urgent
      var result = await triageService.performTriageAssessment(
        symptoms: 'I have a minor headache',
        includeVitals: false,
      );
      expect(
        result.severityScore,
        lessThanOrEqualTo(6.0),
      ); // Headache is standard priority

      // Test urgent symptoms
      result = await triageService.performTriageAssessment(
        symptoms: 'I have severe abdominal pain',
        includeVitals: false,
      );
      expect(result.severityScore, greaterThan(4.0));
    });
  });
}
