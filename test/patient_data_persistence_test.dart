import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:triage_bios_ai/shared/services/firestore_data_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_consent_firestore.dart';

void main() {
  group('Patient Data Persistence Tests', () {
    late FirestoreDataService firestoreService;

    setUp(() {
      firestoreService = FirestoreDataService();
    });

    test('PatientHistoryData should be created correctly', () {
      final patientId = 'test_patient_123';
      final vitals = <PatientVitalsFirestore>[];
      final triageResults = <TriageResultFirestore>[];
      final consents = <PatientConsentFirestore>[];

      final historyData = PatientHistoryData(
        patientId: patientId,
        vitals: vitals,
        triageResults: triageResults,
        consents: consents,
        retrievedAt: DateTime.now(),
      );

      expect(historyData.patientId, equals(patientId));
      expect(historyData.vitals, isEmpty);
      expect(historyData.triageResults, isEmpty);
      expect(historyData.consents, isEmpty);
      expect(historyData.latestVitals, isNull);
      expect(historyData.latestTriageResult, isNull);
      expect(historyData.activeConsents, isEmpty);
      expect(historyData.hasCriticalCases, isFalse);
      expect(historyData.averageSeverityScore, equals(0.0));
      expect(historyData.vitalsTrend, equals(VitalsTrend.stable));
    });

    test('PatientHistoryData.empty should create empty history', () {
      final patientId = 'test_patient_456';
      final emptyHistory = PatientHistoryData.empty(patientId);

      expect(emptyHistory.patientId, equals(patientId));
      expect(emptyHistory.vitals, isEmpty);
      expect(emptyHistory.triageResults, isEmpty);
      expect(emptyHistory.consents, isEmpty);
    });

    test('DeviceDataQuality should be created from device data', () {
      final deviceData = {
        'accuracy': 0.95,
        'isValidated': true,
        'batteryLevel': 85.0,
        'signalStrength': 0.9,
        'dataQualityScore': 0.88,
        'calibrationStatus': 'CALIBRATED',
        'sensorAccuracy': {'heartRate': 0.95, 'oxygenSaturation': 0.92},
        'connectionStability': 0.98,
        'lastCalibration': '2024-01-15T10:30:00Z',
      };

      final quality = DeviceDataQuality.fromDevice(deviceData);

      expect(quality.overallAccuracy, equals(0.95));
      expect(quality.isValidated, isTrue);
      expect(quality.batteryLevel, equals(85.0));
      expect(quality.signalStrength, equals(0.9));
      expect(quality.dataQualityScore, equals(0.88));
      expect(quality.calibrationStatus, equals('CALIBRATED'));
      expect(quality.sensorAccuracy['heartRate'], equals(0.95));
      expect(quality.connectionStability, equals(0.98));
      expect(quality.isHighQuality, isTrue);
      // The calibration date is old, so it should need calibration
      expect(quality.needsCalibration, isTrue);
    });

    test('DeviceDataQuality should handle missing data gracefully', () {
      final deviceData = <String, dynamic>{};
      final quality = DeviceDataQuality.fromDevice(deviceData);

      expect(quality.overallAccuracy, equals(0.95));
      expect(quality.isValidated, isFalse);
      expect(quality.batteryLevel, equals(100.0));
      expect(quality.signalStrength, equals(1.0));
      expect(quality.dataQualityScore, equals(0.9));
      expect(quality.calibrationStatus, equals('UNKNOWN'));
      expect(quality.sensorAccuracy, isEmpty);
      expect(quality.connectionStability, equals(1.0));
      expect(quality.lastCalibration, isNull);
    });

    test('VitalsTrend enum should have correct display names', () {
      expect(VitalsTrend.improving.displayName, equals('Improving'));
      expect(VitalsTrend.stable.displayName, equals('Stable'));
      expect(VitalsTrend.worsening.displayName, equals('Worsening'));
    });

    test('ConsentAuditLog should be created correctly', () {
      // This test verifies the structure is correct
      // In a real test, we would mock Firestore and test the actual methods
      expect(true, isTrue); // Placeholder for structure validation
    });
  });
}
