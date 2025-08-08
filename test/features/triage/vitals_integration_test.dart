import 'package:flutter_test/flutter_test.dart';
import 'package:triage_bios_ai/features/triage/domain/entities/patient_vitals.dart';
import 'package:triage_bios_ai/shared/services/health_service.dart';

void main() {
  group('Vitals Integration Tests', () {
    test(
      'should calculate correct vitals severity boost for normal vitals',
      () {
        // Arrange
        final vitals = PatientVitals(
          heartRate: 75,
          bloodPressure: '120/80',
          temperature: 98.6,
          oxygenSaturation: 98.0,
          timestamp: DateTime.now(),
          deviceSource: 'Test Device',
        );

        // Act
        final boost = vitals.vitalsSeverityBoost;

        // Assert
        expect(
          boost,
          equals(0.0),
          reason: 'Normal vitals should not boost severity',
        );
      },
    );

    test(
      'should calculate correct vitals severity boost for elevated heart rate',
      () {
        // Arrange
        final vitals = PatientVitals(
          heartRate: 130, // Tachycardia
          bloodPressure: '120/80',
          temperature: 98.6,
          oxygenSaturation: 98.0,
          timestamp: DateTime.now(),
          deviceSource: 'Test Device',
        );

        // Act
        final boost = vitals.vitalsSeverityBoost;

        // Assert
        expect(
          boost,
          equals(2.0),
          reason: 'Tachycardia should boost severity by 2.0',
        );
      },
    );

    test(
      'should calculate correct vitals severity boost for low oxygen saturation',
      () {
        // Arrange
        final vitals = PatientVitals(
          heartRate: 75,
          bloodPressure: '120/80',
          temperature: 98.6,
          oxygenSaturation: 88.0, // Critical hypoxemia
          timestamp: DateTime.now(),
          deviceSource: 'Test Device',
        );

        // Act
        final boost = vitals.vitalsSeverityBoost;

        // Assert
        expect(
          boost,
          equals(3.0),
          reason: 'Critical hypoxemia should boost severity by 3.0',
        );
      },
    );

    test('should calculate correct vitals severity boost for high fever', () {
      // Arrange
      final vitals = PatientVitals(
        heartRate: 75,
        bloodPressure: '120/80',
        temperature: 103.5, // High fever
        oxygenSaturation: 98.0,
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act
      final boost = vitals.vitalsSeverityBoost;

      // Assert
      expect(
        boost,
        equals(2.5),
        reason: 'High fever should boost severity by 2.5',
      );
    });

    test(
      'should calculate correct vitals severity boost for multiple abnormal vitals',
      () {
        // Arrange
        final vitals = PatientVitals(
          heartRate: 130, // +2.0
          bloodPressure: '120/80',
          temperature: 102.0, // +1.5
          oxygenSaturation: 88.0, // +3.0
          timestamp: DateTime.now(),
          deviceSource: 'Test Device',
        );

        // Act
        final boost = vitals.vitalsSeverityBoost;

        // Assert
        expect(
          boost,
          equals(3.0),
          reason: 'Multiple abnormal vitals should be capped at 3.0',
        );
      },
    );

    test('should detect critical vitals correctly', () {
      // Arrange
      final criticalVitals = PatientVitals(
        heartRate: 45, // Bradycardia
        bloodPressure: '200/130', // Hypertensive crisis
        temperature: 104.0, // High fever
        oxygenSaturation: 85.0, // Critical hypoxemia
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act & Assert
      expect(
        criticalVitals.hasCriticalVitals,
        isTrue,
        reason: 'Should detect critical vitals',
      );
    });

    test('should not detect critical vitals for normal values', () {
      // Arrange
      final normalVitals = PatientVitals(
        heartRate: 75,
        bloodPressure: '120/80',
        temperature: 98.6,
        oxygenSaturation: 98.0,
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act & Assert
      expect(
        normalVitals.hasCriticalVitals,
        isFalse,
        reason: 'Should not detect critical vitals for normal values',
      );
    });

    test('should handle missing vitals gracefully', () {
      // Arrange
      final partialVitals = PatientVitals(
        heartRate: 75,
        // Missing other vitals
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act
      final boost = partialVitals.vitalsSeverityBoost;
      final hasCritical = partialVitals.hasCriticalVitals;

      // Assert
      expect(
        boost,
        equals(0.0),
        reason: 'Missing vitals should not boost severity',
      );
      expect(
        hasCritical,
        isFalse,
        reason: 'Missing vitals should not be critical',
      );
    });

    test('should parse blood pressure correctly for hypertensive crisis', () {
      // Arrange
      final hypertensiveVitals = PatientVitals(
        heartRate: 75,
        bloodPressure: '190/125', // Hypertensive crisis
        temperature: 98.6,
        oxygenSaturation: 98.0,
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act & Assert
      expect(
        hypertensiveVitals.hasCriticalVitals,
        isTrue,
        reason: 'Should detect hypertensive crisis',
      );
    });

    test('should parse blood pressure correctly for hypotension', () {
      // Arrange
      final hypotensiveVitals = PatientVitals(
        heartRate: 75,
        bloodPressure: '85/55', // Hypotension
        temperature: 98.6,
        oxygenSaturation: 98.0,
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act & Assert
      expect(
        hypotensiveVitals.hasCriticalVitals,
        isTrue,
        reason: 'Should detect hypotension',
      );
    });

    test('should handle invalid blood pressure format gracefully', () {
      // Arrange
      final invalidBPVitals = PatientVitals(
        heartRate: 75,
        bloodPressure: 'invalid', // Invalid format
        temperature: 98.6,
        oxygenSaturation: 98.0,
        timestamp: DateTime.now(),
        deviceSource: 'Test Device',
      );

      // Act & Assert
      expect(
        invalidBPVitals.hasCriticalVitals,
        isFalse,
        reason: 'Should handle invalid BP format gracefully',
      );
    });
  });

  group('Health Service Integration Tests', () {
    late HealthService healthService;

    setUp(() {
      healthService = HealthService();
    });

    test('should initialize health service without errors', () {
      // This test verifies that the health service can be instantiated
      // without throwing exceptions
      expect(healthService, isNotNull);
    });

    test('should handle health permissions check gracefully', () async {
      // This test verifies that permission checking doesn't crash
      // Note: In a real device test, this would check actual permissions
      final hasPermissions = await healthService.hasHealthPermissions();
      expect(hasPermissions, isA<bool>());
    });
  });
}
