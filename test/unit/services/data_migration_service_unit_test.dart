import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:triage_bios_ai/shared/services/data_migration_service.dart';
import 'package:triage_bios_ai/shared/services/firestore_data_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_consent_firestore.dart';

// Generate mocks
@GenerateMocks([FirestoreDataService])
import 'data_migration_service_unit_test.mocks.dart';

void main() {
  group('DataMigrationService Unit Tests', () {
    late DataMigrationService service;
    late MockFirestoreDataService mockFirestoreService;

    setUp(() {
      mockFirestoreService = MockFirestoreDataService();
      service = DataMigrationService();
    });

    group('Hospital Data Seeding', () {
      test('seedHospitalData should create hospitals and capacities', () async {
        // Arrange
        when(
          mockFirestoreService.createHospital(any),
        ).thenAnswer((_) async => 'hospital_id_123');
        when(
          mockFirestoreService.updateHospitalCapacity(any),
        ).thenAnswer((_) async => {});

        // Act
        await service.seedHospitalData();

        // Assert
        verify(mockFirestoreService.createHospital(any)).called(greaterThan(0));
        verify(
          mockFirestoreService.updateHospitalCapacity(any),
        ).called(greaterThan(0));
      });

      test('should generate realistic hospital data for major cities', () {
        // Act
        final hospitals = service.generateRealisticHospitals();

        // Assert
        expect(hospitals, isA<List<HospitalFirestore>>());
        expect(hospitals.length, greaterThan(10));

        // Check that hospitals have required fields
        for (final hospital in hospitals) {
          expect(hospital.name.isNotEmpty, true);
          expect(hospital.address.city.isNotEmpty, true);
          expect(hospital.contact.phone.isNotEmpty, true);
          expect(hospital.traumaLevel >= 1 && hospital.traumaLevel <= 4, true);
          expect(hospital.specializations.isNotEmpty, true);
          expect(
            hospital.location.latitude >= -90 &&
                hospital.location.latitude <= 90,
            true,
          );
          expect(
            hospital.location.longitude >= -180 &&
                hospital.location.longitude <= 180,
            true,
          );
        }
      });

      test('should generate varied hospital specializations', () {
        // Act
        final hospitals = service.generateRealisticHospitals();

        // Assert
        final allSpecializations = <String>{};
        for (final hospital in hospitals) {
          allSpecializations.addAll(hospital.specializations);
        }

        expect(allSpecializations.contains('emergency'), true);
        expect(allSpecializations.contains('cardiology'), true);
        expect(allSpecializations.contains('neurology'), true);
        expect(allSpecializations.contains('trauma'), true);
        expect(allSpecializations.length, greaterThan(5));
      });

      test('should generate hospitals with different trauma levels', () {
        // Act
        final hospitals = service.generateRealisticHospitals();

        // Assert
        final traumaLevels = hospitals.map((h) => h.traumaLevel).toSet();
        expect(traumaLevels.length, greaterThan(1));
        expect(traumaLevels.every((level) => level >= 1 && level <= 4), true);
      });
    });

    group('Hospital Capacity Generation', () {
      test(
        'generateHospitalCapacity should create realistic capacity data',
        () {
          // Arrange
          final hospital = HospitalFirestore(
            id: 'test_hospital',
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

          // Act
          final capacity = service.generateHospitalCapacity(
            'hospital_id',
            hospital,
          );

          // Assert
          expect(capacity, isA<HospitalCapacityFirestore>());
          expect(capacity.hospitalId, 'hospital_id');
          expect(capacity.totalBeds, greaterThan(0));
          expect(capacity.availableBeds, greaterThanOrEqualTo(0));
          expect(capacity.availableBeds, lessThanOrEqualTo(capacity.totalBeds));
          expect(capacity.icuBeds, greaterThanOrEqualTo(0));
          expect(capacity.emergencyBeds, greaterThanOrEqualTo(0));
          expect(capacity.staffOnDuty, greaterThan(0));
          expect(capacity.averageWaitTime, greaterThanOrEqualTo(0));
          expect(capacity.occupancyRate, greaterThanOrEqualTo(0.0));
          expect(capacity.occupancyRate, lessThanOrEqualTo(1.0));
        },
      );

      test('should generate capacity based on hospital trauma level', () {
        // Arrange
        final level1Hospital = HospitalFirestore(
          id: 'level1_hospital',
          name: 'Level 1 Trauma Center',
          address: const HospitalAddress(
            street: '123 Trauma St',
            city: 'Trauma City',
            state: 'TC',
            zipCode: '12345',
            country: 'USA',
          ),
          location: const HospitalLocation(
            latitude: 40.7589,
            longitude: -73.9851,
          ),
          contact: const HospitalContact(
            phone: '(555) 123-4567',
            email: 'trauma@hospital.com',
          ),
          traumaLevel: 1,
          specializations: const ['emergency', 'trauma', 'neurosurgery'],
          certifications: const ['Joint Commission'],
          operatingHours: const HospitalOperatingHours(
            emergency: '24/7',
            general: 'Mon-Sun 6:00 AM - 10:00 PM',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        final level4Hospital = HospitalFirestore(
          id: 'level4_hospital',
          name: 'Level 4 Community Hospital',
          address: const HospitalAddress(
            street: '456 Community St',
            city: 'Community City',
            state: 'CC',
            zipCode: '67890',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 41.0, longitude: -74.0),
          contact: const HospitalContact(
            phone: '(555) 987-6543',
            email: 'community@hospital.com',
          ),
          traumaLevel: 4,
          specializations: const ['emergency'],
          certifications: const ['Joint Commission'],
          operatingHours: const HospitalOperatingHours(
            emergency: '24/7',
            general: 'Mon-Sun 6:00 AM - 10:00 PM',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Act
        final level1Capacity = service.generateHospitalCapacity(
          'level1_id',
          level1Hospital,
        );
        final level4Capacity = service.generateHospitalCapacity(
          'level4_id',
          level4Hospital,
        );

        // Assert
        expect(level1Capacity.totalBeds, greaterThan(level4Capacity.totalBeds));
        expect(level1Capacity.icuBeds, greaterThan(level4Capacity.icuBeds));
        expect(
          level1Capacity.staffOnDuty,
          greaterThan(level4Capacity.staffOnDuty),
        );
      });
    });

    group('Sample Data Generation', () {
      test('generateSamplePatientVitals should create realistic vitals', () {
        // Act
        final vitals = service.generateSamplePatientVitals('patient123', 10);

        // Assert
        expect(vitals, isA<List<PatientVitalsFirestore>>());
        expect(vitals.length, 10);

        for (final vital in vitals) {
          expect(vital.patientId, 'patient123');
          expect(vital.heartRate, greaterThan(40));
          expect(vital.heartRate, lessThan(200));
          expect(vital.bloodPressureSystolic, greaterThan(80));
          expect(vital.bloodPressureSystolic, lessThan(200));
          expect(vital.bloodPressureDiastolic, greaterThan(40));
          expect(vital.bloodPressureDiastolic, lessThan(120));
          expect(vital.oxygenSaturation, greaterThan(85));
          expect(vital.oxygenSaturation, lessThanOrEqualTo(100));
          expect(vital.temperature, greaterThan(95));
          expect(vital.temperature, lessThan(110));
          expect(vital.accuracy, greaterThan(0.0));
          expect(vital.accuracy, lessThanOrEqualTo(1.0));
        }
      });

      test('generateSampleTriageResults should create varied results', () {
        // Act
        final results = service.generateSampleTriageResults('patient123', 5);

        // Assert
        expect(results, isA<List<TriageResultFirestore>>());
        expect(results.length, 5);

        final urgencyLevels = <UrgencyLevel>{};
        for (final result in results) {
          expect(result.patientId, 'patient123');
          expect(result.severityScore, greaterThanOrEqualTo(0.0));
          expect(result.severityScore, lessThanOrEqualTo(10.0));
          expect(result.confidence, greaterThan(0.0));
          expect(result.confidence, lessThanOrEqualTo(1.0));
          expect(result.symptoms.isNotEmpty, true);
          expect(result.aiReasoning.isNotEmpty, true);
          expect(result.recommendedActions.isNotEmpty, true);
          urgencyLevels.add(result.urgencyLevel);
        }

        expect(
          urgencyLevels.length,
          greaterThan(1),
        ); // Should have varied urgency levels
      });

      test('generateSamplePatientConsents should create valid consents', () {
        // Act
        final consents = service.generateSamplePatientConsents(
          'patient123',
          'provider456',
          3,
        );

        // Assert
        expect(consents, isA<List<PatientConsentFirestore>>());
        expect(consents.length, 3);

        for (final consent in consents) {
          expect(consent.patientId, 'patient123');
          expect(consent.providerId, 'provider456');
          expect(consent.dataScopes.isNotEmpty, true);
          expect(consent.blockchainTxId.isNotEmpty, true);
          expect(consent.ipAddress.isNotEmpty, true);
          expect(consent.grantedAt.isBefore(DateTime.now()), true);
          expect(consent.isActive, true);
        }
      });
    });

    group('Data Validation', () {
      test('validateHospitalData should detect invalid hospitals', () {
        // Arrange
        final validHospital = HospitalFirestore(
          id: 'valid_hospital',
          name: 'Valid Hospital',
          address: const HospitalAddress(
            street: '123 Valid St',
            city: 'Valid City',
            state: 'VC',
            zipCode: '12345',
            country: 'USA',
          ),
          location: const HospitalLocation(
            latitude: 40.7589,
            longitude: -73.9851,
          ),
          contact: const HospitalContact(
            phone: '(555) 123-4567',
            email: 'valid@hospital.com',
          ),
          traumaLevel: 1,
          specializations: const ['emergency'],
          certifications: const ['Joint Commission'],
          operatingHours: const HospitalOperatingHours(
            emergency: '24/7',
            general: 'Mon-Sun 6:00 AM - 10:00 PM',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        final invalidHospital = HospitalFirestore(
          id: 'invalid_hospital',
          name: '', // Invalid: empty name
          address: const HospitalAddress(
            street: '',
            city: '',
            state: '',
            zipCode: '',
            country: '',
          ),
          location: const HospitalLocation(
            latitude: 200.0, // Invalid: out of range
            longitude: -200.0, // Invalid: out of range
          ),
          contact: const HospitalContact(phone: '', email: 'invalid-email'),
          traumaLevel: 5, // Invalid: out of range
          specializations: const [], // Invalid: empty
          certifications: const [],
          operatingHours: const HospitalOperatingHours(
            emergency: '',
            general: '',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Act
        final validResult = service.validateHospitalData(validHospital);
        final invalidResult = service.validateHospitalData(invalidHospital);

        // Assert
        expect(validResult.isValid, true);
        expect(validResult.errors.isEmpty, true);

        expect(invalidResult.isValid, false);
        expect(invalidResult.errors.isNotEmpty, true);
        expect(invalidResult.errors.any((e) => e.contains('name')), true);
        expect(invalidResult.errors.any((e) => e.contains('latitude')), true);
        expect(invalidResult.errors.any((e) => e.contains('longitude')), true);
        expect(
          invalidResult.errors.any((e) => e.contains('traumaLevel')),
          true,
        );
      });

      test('validateCapacityData should detect invalid capacity', () {
        // Arrange
        final validCapacity = HospitalCapacityFirestore(
          id: 'valid_capacity',
          hospitalId: 'hospital123',
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

        final invalidCapacity = HospitalCapacityFirestore(
          id: 'invalid_capacity',
          hospitalId: '', // Invalid: empty
          totalBeds: -10, // Invalid: negative
          availableBeds: 150, // Invalid: more than total
          icuBeds: -5, // Invalid: negative
          icuAvailable: 20, // Invalid: more than ICU beds
          emergencyBeds: -3, // Invalid: negative
          emergencyAvailable: 25, // Invalid: more than emergency beds
          staffOnDuty: -10, // Invalid: negative
          patientsInQueue: -5, // Invalid: negative
          averageWaitTime: -15.0, // Invalid: negative
          lastUpdated: DateTime.now(),
          dataSource: DataSource.firestore,
          isRealTime: false,
        );

        // Act
        final validResult = service.validateCapacityData(validCapacity);
        final invalidResult = service.validateCapacityData(invalidCapacity);

        // Assert
        expect(validResult.isValid, true);
        expect(validResult.errors.isEmpty, true);

        expect(invalidResult.isValid, false);
        expect(invalidResult.errors.isNotEmpty, true);
        expect(invalidResult.errors.any((e) => e.contains('hospitalId')), true);
        expect(invalidResult.errors.any((e) => e.contains('totalBeds')), true);
        expect(
          invalidResult.errors.any((e) => e.contains('availableBeds')),
          true,
        );
      });

      test('validateVitalsData should detect abnormal vitals', () {
        // Arrange
        final normalVitals = PatientVitalsFirestore(
          id: 'normal_vitals',
          patientId: 'patient123',
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

        final abnormalVitals = PatientVitalsFirestore(
          id: 'abnormal_vitals',
          patientId: 'patient123',
          heartRate: 200.0, // Abnormal: too high
          bloodPressureSystolic: 250.0, // Abnormal: too high
          bloodPressureDiastolic: 150.0, // Abnormal: too high
          oxygenSaturation: 75.0, // Abnormal: too low
          temperature: 105.0, // Abnormal: too high
          respiratoryRate: 35.0, // Abnormal: too high
          source: VitalsSource.manual,
          accuracy: 0.95,
          timestamp: DateTime.now(),
          isValidated: true,
        );

        // Act
        final normalResult = service.validateVitalsData(normalVitals);
        final abnormalResult = service.validateVitalsData(abnormalVitals);

        // Assert
        expect(normalResult.isValid, true);
        expect(normalResult.warnings.isEmpty, true);

        expect(
          abnormalResult.isValid,
          true,
        ); // Still valid data, but with warnings
        expect(abnormalResult.warnings.isNotEmpty, true);
        expect(
          abnormalResult.warnings.any((w) => w.contains('heart rate')),
          true,
        );
        expect(
          abnormalResult.warnings.any((w) => w.contains('blood pressure')),
          true,
        );
        expect(
          abnormalResult.warnings.any((w) => w.contains('oxygen saturation')),
          true,
        );
      });
    });

    group('Migration Statistics', () {
      test(
        'calculateMigrationStatistics should provide accurate stats',
        () async {
          // Arrange
          when(mockFirestoreService.getHospitals()).thenAnswer(
            (_) async => [
              // Mock hospital data
            ],
          );
          when(mockFirestoreService.getSystemHealthMetrics()).thenAnswer(
            (_) async => {
              'totalHospitals': 10,
              'totalCapacityRecords': 10,
              'totalVitalsRecords': 100,
              'totalTriageResults': 50,
              'totalConsentRecords': 25,
            },
          );

          // Act
          final stats = await service.calculateMigrationStatistics();

          // Assert
          expect(stats, isA<Map<String, dynamic>>());
          expect(stats.containsKey('totalHospitals'), true);
          expect(stats.containsKey('totalCapacityRecords'), true);
          expect(stats.containsKey('totalVitalsRecords'), true);
          expect(stats.containsKey('totalTriageResults'), true);
          expect(stats.containsKey('totalConsentRecords'), true);
        },
      );

      test('should track migration progress', () {
        // Arrange
        final progress = service.createMigrationProgress();

        // Act
        progress.updateProgress('hospitals', 5, 10);
        progress.updateProgress('capacities', 8, 10);

        // Assert
        expect(
          progress.getOverallProgress(),
          closeTo(0.65, 0.01),
        ); // (5+8)/(10+10)
        expect(progress.isComplete(), false);

        progress.updateProgress('hospitals', 10, 10);
        progress.updateProgress('capacities', 10, 10);

        expect(progress.getOverallProgress(), 1.0);
        expect(progress.isComplete(), true);
      });
    });

    group('Error Handling', () {
      test('should handle Firestore write failures gracefully', () async {
        // Arrange
        when(
          mockFirestoreService.createHospital(any),
        ).thenThrow(Exception('Firestore write failed'));

        // Act & Assert
        expect(() => service.seedHospitalData(), throwsException);
      });

      test('should validate data before migration', () async {
        // Arrange
        final invalidHospital = HospitalFirestore(
          id: 'invalid',
          name: '', // Invalid
          address: const HospitalAddress(
            street: '',
            city: '',
            state: '',
            zipCode: '',
            country: '',
          ),
          location: const HospitalLocation(
            latitude: 200.0, // Invalid
            longitude: -200.0, // Invalid
          ),
          contact: const HospitalContact(phone: '', email: ''),
          traumaLevel: 5, // Invalid
          specializations: const [],
          certifications: const [],
          operatingHours: const HospitalOperatingHours(
            emergency: '',
            general: '',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Act
        final result = service.validateBeforeMigration(
          [invalidHospital],
          [],
          [],
          [],
          [],
        );

        // Assert
        expect(result.isValid, false);
        expect(result.errors.isNotEmpty, true);
      });
    });

    group('Development Utilities', () {
      test('resetDevelopmentData should clear collections', () async {
        // Arrange
        when(
          mockFirestoreService.deleteCollection(any),
        ).thenAnswer((_) async => {});

        // Act
        await service.resetDevelopmentData();

        // Assert
        verify(mockFirestoreService.deleteCollection('hospitals')).called(1);
        verify(
          mockFirestoreService.deleteCollection('hospital_capacity'),
        ).called(1);
        verify(
          mockFirestoreService.deleteCollection('patient_vitals'),
        ).called(1);
        verify(
          mockFirestoreService.deleteCollection('triage_results'),
        ).called(1);
        verify(
          mockFirestoreService.deleteCollection('patient_consents'),
        ).called(1);
      });

      test('should provide data seeding options', () {
        // Act
        final options = service.getDataSeedingOptions();

        // Assert
        expect(options, isA<Map<String, dynamic>>());
        expect(options.containsKey('hospitalCount'), true);
        expect(options.containsKey('vitalsPerPatient'), true);
        expect(options.containsKey('triageResultsPerPatient'), true);
        expect(options.containsKey('consentRecordsPerPatient'), true);
        expect(options.containsKey('cities'), true);
      });
    });
  });
}
