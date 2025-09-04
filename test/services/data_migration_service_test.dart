import 'package:flutter_test/flutter_test.dart';

import 'package:triage_bios_ai/shared/services/data_migration_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_consent_firestore.dart';

void main() {
  group('DataMigrationService', () {
    late DataMigrationService dataMigrationService;

    setUp(() {
      dataMigrationService = DataMigrationService();
    });

    group('Data Validation', () {
      test('should validate hospital data correctly', () {
        // Create a valid hospital for testing
        final validHospital = HospitalFirestore(
          id: 'test_hospital_1',
          name: 'Test Hospital',
          address: const HospitalAddress(
            street: '123 Test St',
            city: 'Test City',
            state: 'TS',
            zipCode: '12345',
            country: 'USA',
          ),
          location: const HospitalLocation(
            latitude: 40.7589,
            longitude: -73.9851,
          ),
          contact: const HospitalContact(
            phone: '(555) 123-4567',
            email: 'test@hospital.com',
            website: 'https://test.hospital.com',
          ),
          traumaLevel: 1,
          specializations: const ['emergency', 'cardiology'],
          certifications: const ['Joint Commission'],
          operatingHours: const HospitalOperatingHours(
            emergency: '24/7',
            general: 'Mon-Sun 6:00 AM - 10:00 PM',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Test that a valid hospital has required fields
        expect(validHospital.name.isNotEmpty, true);
        expect(validHospital.address.street.isNotEmpty, true);
        expect(validHospital.contact.phone.isNotEmpty, true);
        expect(
          validHospital.traumaLevel >= 1 && validHospital.traumaLevel <= 4,
          true,
        );
        expect(validHospital.specializations.isNotEmpty, true);
      });

      test('should validate capacity data correctly', () {
        // Create valid capacity data
        final validCapacity = HospitalCapacityFirestore(
          id: 'test_capacity_1',
          hospitalId: 'test_hospital_1',
          totalBeds: 100,
          availableBeds: 25,
          icuBeds: 10,
          icuAvailable: 3,
          emergencyBeds: 15,
          emergencyAvailable: 5,
          staffOnDuty: 80,
          patientsInQueue: 5,
          averageWaitTime: 30.0,
          lastUpdated: DateTime.now(),
          dataSource: DataSource.firestore,
          isRealTime: false,
        );

        // Test capacity validation logic
        expect(validCapacity.totalBeds > 0, true);
        expect(validCapacity.availableBeds >= 0, true);
        expect(validCapacity.availableBeds <= validCapacity.totalBeds, true);
        expect(validCapacity.icuBeds >= 0, true);
        expect(validCapacity.emergencyBeds >= 0, true);
        expect(validCapacity.staffOnDuty >= 0, true);
        expect(validCapacity.averageWaitTime >= 0, true);

        // Test calculated fields
        expect(validCapacity.occupancyRate, 0.75); // (100-25)/100
        expect(validCapacity.isNearCapacity, false); // 0.75 < 0.85
        expect(validCapacity.isAtCapacity, false); // 0.75 < 0.95
      });
    });

    group('Sample Data Generation', () {
      test('should create sample vitals with correct properties', () {
        final sampleVitals = PatientVitalsFirestore(
          id: 'test_vitals_1',
          patientId: 'test_patient_1',
          heartRate: 75.0,
          bloodPressureSystolic: 120.0,
          bloodPressureDiastolic: 80.0,
          oxygenSaturation: 98.0,
          temperature: 98.6,
          respiratoryRate: 16.0,
          source: VitalsSource.manual,
          accuracy: 0.95,
          timestamp: DateTime.now(),
          isValidated: true,
        );

        expect(sampleVitals.heartRate, 75.0);
        expect(sampleVitals.hasAbnormalVitals, false);
        expect(sampleVitals.vitalsSeverityScore, 0.0);
        expect(sampleVitals.source, VitalsSource.manual);
        expect(sampleVitals.accuracy, 0.95);
      });

      test('should create sample triage results with correct urgency', () {
        final sampleTriageResult = TriageResultFirestore(
          id: 'test_triage_1',
          patientId: 'test_patient_1',
          sessionId: 'test_session_1',
          symptoms: 'Test symptoms',
          severityScore: 5.0,
          urgencyLevel: UrgencyLevel.standard,
          aiReasoning: 'Test AI reasoning',
          recommendedActions: const ['Test action 1', 'Test action 2'],
          vitalsContribution: 1.5,
          confidence: 0.85,
          createdAt: DateTime.now(),
          geminiModelVersion: 'gemini-1.5-flash',
        );

        expect(sampleTriageResult.severityScore, 5.0);
        expect(sampleTriageResult.urgencyLevel, UrgencyLevel.standard);
        expect(sampleTriageResult.confidence, 0.85);
        expect(sampleTriageResult.isUrgent, false);
        expect(sampleTriageResult.isCritical, false);
        expect(
          sampleTriageResult.urgencyColor,
          '#FF9800',
        ); // Orange for standard
      });

      test('should create sample consent records with correct status', () {
        final sampleConsent = PatientConsentFirestore(
          id: 'test_consent_1',
          patientId: 'test_patient_1',
          providerId: 'test_provider_1',
          consentType: ConsentType.treatment,
          dataScopes: const ['vitals', 'triage_results'],
          grantedAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          isActive: true,
          blockchainTxId: 'test_tx_123',
          ipAddress: '192.168.1.100',
          consentDetails: const {
            'grantedBy': 'test_patient_1',
            'reason': 'Test consent',
          },
        );

        expect(sampleConsent.consentType, ConsentType.treatment);
        expect(sampleConsent.isValid, true);
        expect(sampleConsent.isExpired, false);
        expect(sampleConsent.isRevoked, false);
        expect(sampleConsent.status, ConsentStatus.active);
      });
    });

    group('Data Statistics', () {
      test('should calculate statistics correctly', () {
        final stats = DataStatistics();
        stats.totalHospitals = 10;
        stats.activeHospitals = 8;
        stats.traumaLevel1Hospitals = 3;
        stats.totalCapacityRecords = 10;
        stats.averageOccupancyRate = 0.75;
        stats.totalVitalsRecords = 100;
        stats.totalTriageResults = 50;
        stats.totalConsentRecords = 25;

        expect(stats.totalHospitals, 10);
        expect(stats.activeHospitals, 8);
        expect(stats.averageOccupancyRate, 0.75);

        final statsString = stats.toString();
        expect(statsString.contains('Hospitals: 10 total'), true);
        expect(statsString.contains('avg occupancy: 75.0%'), true);
      });
    });

    group('Validation Results', () {
      test('should create validation results correctly', () {
        final result = ValidationResult();
        result.hospitalCount = 10;
        result.hospitalsValid = 9;
        result.capacityCount = 10;
        result.capacitiesValid = 8;
        result.hospitalValidationScore = 0.9;
        result.capacityValidationScore = 0.8;
        result.overallScore = 0.85;

        expect(result.isValid, false); // 0.85 < 0.9 threshold
        expect(result.hospitalValidationScore, 0.9);
        expect(result.capacityValidationScore, 0.8);

        // Test error result
        final errorResult = ValidationResult.error('Test error');
        expect(errorResult.error, 'Test error');
        expect(errorResult.isValid, false);
      });

      test('should detect warnings correctly', () {
        final result = ValidationResult();
        result.orphanedCapacities = 2;
        result.staleCapacities = 3;

        expect(result.hasWarnings, true);

        final resultNoWarnings = ValidationResult();
        expect(resultNoWarnings.hasWarnings, false);
      });
    });

    group('Service Initialization', () {
      test('should initialize service correctly', () {
        expect(dataMigrationService, isNotNull);
        expect(dataMigrationService, isA<DataMigrationService>());
      });
    });

    group('Enum Tests', () {
      test('should handle UrgencyLevel enum correctly', () {
        expect(UrgencyLevel.critical.toString(), 'CRITICAL');
        expect(UrgencyLevel.urgent.toString(), 'URGENT');
        expect(UrgencyLevel.standard.toString(), 'STANDARD');
        expect(UrgencyLevel.nonUrgent.toString(), 'NON_URGENT');

        expect(UrgencyLevel.fromString('CRITICAL'), UrgencyLevel.critical);
        expect(UrgencyLevel.fromString('invalid'), UrgencyLevel.standard);
      });

      test('should handle DataSource enum correctly', () {
        expect(DataSource.firestore.toString(), 'firestore');
        expect(DataSource.customApi.toString(), 'custom_api');

        expect(DataSource.fromString('firestore'), DataSource.firestore);
        expect(DataSource.fromString('custom_api'), DataSource.customApi);
        expect(DataSource.fromString('invalid'), DataSource.firestore);
      });

      test('should handle ConsentType enum correctly', () {
        expect(ConsentType.treatment.toString(), 'treatment');
        expect(ConsentType.dataSharing.toString(), 'data_sharing');
        expect(ConsentType.emergency.toString(), 'emergency');

        expect(ConsentType.fromString('treatment'), ConsentType.treatment);
        expect(ConsentType.fromString('invalid'), ConsentType.treatment);
      });

      test('should handle VitalsSource enum correctly', () {
        expect(VitalsSource.appleHealth.toString(), 'apple_health');
        expect(VitalsSource.googleFit.toString(), 'google_fit');
        expect(VitalsSource.manual.toString(), 'manual');
        expect(VitalsSource.device.toString(), 'device');

        expect(
          VitalsSource.fromString('apple_health'),
          VitalsSource.appleHealth,
        );
        expect(VitalsSource.fromString('invalid'), VitalsSource.manual);
      });
    });
  });
}
