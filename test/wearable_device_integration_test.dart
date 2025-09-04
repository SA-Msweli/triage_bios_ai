import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../lib/shared/models/firestore/device_status_firestore.dart';
import '../lib/shared/models/firestore/vitals_threshold_firestore.dart';
import '../lib/features/triage/domain/entities/patient_vitals.dart';

void main() {
  group('Wearable Device Integration Tests', () {
    group('DeviceStatusFirestore', () {
      test('should detect when device needs attention', () {
        // Arrange
        final deviceStatus = DeviceStatusFirestore(
          id: 'test_device',
          deviceName: 'Test Device',
          platform: 'Test Platform',
          isConnected: false, // Disconnected device
          lastSync: DateTime.now().subtract(Duration(hours: 1)),
          batteryLevel: 0.15, // Low battery
          dataQuality: 0.8,
          supportedDataTypes: ['heart_rate'],
          lastUpdated: DateTime.now(),
          connectionIssues: true,
          syncFailures: 5, // Multiple failures
        );

        // Act & Assert
        expect(deviceStatus.needsAttention, isTrue);
        expect(
          deviceStatus.healthStatus,
          equals(DeviceHealthStatus.disconnected),
        );
      });

      test('should calculate connectivity score correctly', () {
        // Arrange
        final healthyDevice = DeviceStatusFirestore(
          id: 'healthy_device',
          deviceName: 'Healthy Device',
          platform: 'Test Platform',
          isConnected: true,
          lastSync: DateTime.now().subtract(Duration(minutes: 2)),
          batteryLevel: 0.85,
          dataQuality: 0.95,
          supportedDataTypes: ['heart_rate', 'blood_oxygen'],
          lastUpdated: DateTime.now(),
          connectionIssues: false,
          syncFailures: 0,
        );

        // Act
        final connectivityScore = healthyDevice.connectivityScore;

        // Assert
        expect(connectivityScore, greaterThan(0.8));
        expect(connectivityScore, lessThanOrEqualTo(1.0));
      });
    });

    group('VitalsThresholdFirestore', () {
      test('should detect threshold violations correctly', () {
        // Arrange
        final thresholds = VitalsThresholdFirestore.createDefault(
          id: 'test_threshold',
          patientId: 'test_patient',
        );

        // Act & Assert - Normal vitals
        expect(
          thresholds.checkThresholds(
            heartRate: 75.0,
            oxygenSaturation: 98.0,
            temperature: 98.6,
            systolicBP: 120.0,
            diastolicBP: 80.0,
          ),
          isFalse,
        );

        // Act & Assert - Critical vitals
        expect(
          thresholds.checkThresholds(
            heartRate: 140.0, // Above max
            oxygenSaturation: 85.0, // Below min
            temperature: 103.0, // Above max
            systolicBP: 190.0, // Above max
          ),
          isTrue,
        );
      });

      test('should calculate severity score correctly', () {
        // Arrange
        final thresholds = VitalsThresholdFirestore.createDefault(
          id: 'test_threshold',
          patientId: 'test_patient',
        );

        // Act - Critical vitals
        final severityScore = thresholds.calculateSeverityScore(
          heartRate: 140.0,
          oxygenSaturation: 85.0,
          temperature: 103.0,
        );

        // Assert
        expect(severityScore, greaterThan(0.0));
        expect(severityScore, lessThanOrEqualTo(5.0));
      });

      test('should generate violation messages', () {
        // Arrange
        final thresholds = VitalsThresholdFirestore.createDefault(
          id: 'test_threshold',
          patientId: 'test_patient',
        );

        // Act
        final violations = thresholds.getViolations(
          heartRate: 140.0,
          oxygenSaturation: 85.0,
          temperature: 103.0,
        );

        // Assert
        expect(violations, isNotEmpty);
        expect(violations.length, equals(3));
        expect(
          violations.any((v) => v.contains('Heart rate too high')),
          isTrue,
        );
        expect(
          violations.any((v) => v.contains('Oxygen saturation too low')),
          isTrue,
        );
        expect(
          violations.any((v) => v.contains('Temperature too high')),
          isTrue,
        );
      });
    });
  });

  group('Error Handling Tests', () {
    test('should handle invalid vitals data gracefully', () {
      // Arrange
      final invalidVitals = PatientVitals(
        heartRate: -1, // Invalid heart rate
        oxygenSaturation: 150.0, // Invalid oxygen saturation
        temperature: 200.0, // Invalid temperature
        timestamp: DateTime.now(),
        deviceSource: 'Invalid Device',
        dataQuality: -0.5, // Invalid quality
      );

      // Act & Assert - Temperature of 200°F is definitely critical
      expect(
        invalidVitals.hasCriticalVitals,
        isTrue,
      ); // Temperature > 101.5 is critical
    });

    test('should handle missing device data', () {
      // Arrange
      final deviceStatus = DeviceStatusFirestore(
        id: 'missing_data_device',
        deviceName: 'Missing Data Device',
        platform: 'Test Platform',
        isConnected: false,
        lastSync: DateTime.now().subtract(Duration(days: 1)),
        batteryLevel: 0.0,
        dataQuality: 0.0,
        supportedDataTypes: [],
        lastUpdated: DateTime.now(),
        connectionIssues: true,
        syncFailures: 10,
      );

      // Act & Assert
      expect(deviceStatus.needsAttention, isTrue);
      expect(deviceStatus.connectivityScore, equals(0.0));
    });
  });
}
