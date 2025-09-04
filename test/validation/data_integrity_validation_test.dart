import 'package:flutter_test/flutter_test.dart';
import 'package:triage_bios_ai/shared/services/data_migration_service.dart';
import 'package:triage_bios_ai/shared/services/firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/enhanced_firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/data_source_manager.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_consent_firestore.dart';
import 'dart:math' as math;

void main() {
  group('Data Integrity Validation Tests', () {
    late DataMigrationService migrationService;
    late FirestoreDataService firestoreService;
    late EnhancedFirestoreDataService enhancedService;
    late DataSourceManager dataSourceManager;

    // Test data cleanup
    final testHospitalIds = <String>[];
    final testPatientIds = <String>[];

    setUpAll(() async {
      migrationService = DataMigrationService();
      firestoreService = FirestoreDataService();
      enhancedService = EnhancedFirestoreDataService();
      dataSourceManager = DataSourceManager();
    });

    tearDownAll(() async {
      // Cleanup test data
      for (final hospitalId in testHospitalIds) {
        try {
          await firestoreService.deleteHospital(hospitalId);
          await firestoreService.deleteHospitalCapacity(hospitalId);
        } catch (e) {
          // Ignore cleanup errors
        }
      }

      for (final patientId in testPatientIds) {
        try {
          await firestoreService.deletePatientData(patientId);
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    });

    group('Hospital Data Integrity Tests', () {
      test('should validate hospital data structure integrity', () async {
        // Arrange - Create test hospital with all required fields
        final validHospital = HospitalFirestore(
          id: '',
          name: 'Integrity Test Hospital',
          address: const HospitalAddress(
            street: '123 Integrity St',
            city: 'Integrity City',
            state: 'IC',
            zipCode: '12345',
            country: 'USA',
          ),
          location: const HospitalLocation(
            latitude: 40.7589,
            longitude: -73.9851,
          ),
          contact: const HospitalContact(
            phone: '(555) 123-4567',
            email: 'integrity@test.com',
            website: 'https://integrity.hospital.com',
          ),
          traumaLevel: 1,
          specializations: const ['emergency', 'cardiology', 'neurology'],
          certifications: const ['Joint Commission', 'Magnet Recognition'],
          operatingHours: const HospitalOperatingHours(
            emergency: '24/7',
            general: 'Mon-Sun 6:00 AM - 10:00 PM',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Act - Create and validate hospital
        final hospitalId = await firestoreService.createHospital(validHospital);
        testHospitalIds.add(hospitalId);

        final retrievedHospital = await firestoreService.getHospitalById(
          hospitalId,
        );

        // Assert - All fields preserved correctly
        expect(retrievedHospital, isNotNull);
        expect(retrievedHospital!.name, validHospital.name);
        expect(retrievedHospital.address.street, validHospital.address.street);
        expect(retrievedHospital.address.city, validHospital.address.city);
        expect(
          retrievedHospital.location.latitude,
          validHospital.location.latitude,
        );
        expect(
          retrievedHospital.location.longitude,
          validHospital.location.longitude,
        );
        expect(retrievedHospital.contact.phone, validHospital.contact.phone);
        expect(retrievedHospital.contact.email, validHospital.contact.email);
        expect(retrievedHospital.traumaLevel, validHospital.traumaLevel);
        expect(
          retrievedHospital.specializations,
          validHospital.specializations,
        );
        expect(retrievedHospital.certifications, validHospital.certifications);
        expect(retrievedHospital.isActive, validHospital.isActive);

        // Validate data types and constraints
        expect(
          retrievedHospital.traumaLevel >= 1 &&
              retrievedHospital.traumaLevel <= 4,
          true,
        );
        expect(
          retrievedHospital.location.latitude >= -90 &&
              retrievedHospital.location.latitude <= 90,
          true,
        );
        expect(
          retrievedHospital.location.longitude >= -180 &&
              retrievedHospital.location.longitude <= 180,
          true,
        );
        expect(retrievedHospital.specializations.isNotEmpty, true);
        expect(retrievedHospital.contact.email.contains('@'), true);
      });

      test('should detect and report hospital data inconsistencies', () {
        // Arrange - Create hospitals with various data issues
        final hospitalsWithIssues = [
          // Hospital with invalid trauma level
          HospitalFirestore(
            id: 'invalid_trauma',
            name: 'Invalid Trauma Hospital',
            address: const HospitalAddress(
              street: '123 Invalid St',
              city: 'Invalid City',
              state: 'IC',
              zipCode: '12345',
              country: 'USA',
            ),
            location: const HospitalLocation(latitude: 40.0, longitude: -74.0),
            contact: const HospitalContact(
              phone: '(555) 123-4567',
              email: 'invalid@test.com',
            ),
            traumaLevel: 5, // Invalid: should be 1-4
            specializations: const ['emergency'],
            certifications: const ['Joint Commission'],
            operatingHours: const HospitalOperatingHours(
              emergency: '24/7',
              general: 'Mon-Sun 6:00 AM - 10:00 PM',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ),
          // Hospital with invalid coordinates
          HospitalFirestore(
            id: 'invalid_coords',
            name: 'Invalid Coordinates Hospital',
            address: const HospitalAddress(
              street: '456 Invalid St',
              city: 'Invalid City',
              state: 'IC',
              zipCode: '67890',
              country: 'USA',
            ),
            location: const HospitalLocation(
              latitude: 200.0, // Invalid: out of range
              longitude: -200.0, // Invalid: out of range
            ),
            contact: const HospitalContact(
              phone: '(555) 987-6543',
              email: 'coords@test.com',
            ),
            traumaLevel: 2,
            specializations: const ['emergency'],
            certifications: const ['Joint Commission'],
            operatingHours: const HospitalOperatingHours(
              emergency: '24/7',
              general: 'Mon-Sun 6:00 AM - 10:00 PM',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ),
          // Hospital with missing required fields
          HospitalFirestore(
            id: 'missing_fields',
            name: '', // Invalid: empty name
            address: const HospitalAddress(
              street: '',
              city: '',
              state: '',
              zipCode: '',
              country: '',
            ),
            location: const HospitalLocation(latitude: 41.0, longitude: -75.0),
            contact: const HospitalContact(
              phone: '',
              email: 'invalid-email', // Invalid format
            ),
            traumaLevel: 1,
            specializations: const [], // Invalid: empty
            certifications: const [],
            operatingHours: const HospitalOperatingHours(
              emergency: '',
              general: '',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ),
        ];

        // Act - Validate each hospital
        final validationResults = <ValidationResult>[];
        for (final hospital in hospitalsWithIssues) {
          final result = migrationService.validateHospitalData(hospital);
          validationResults.add(result);
        }

        // Assert - All hospitals should have validation errors
        expect(validationResults.every((r) => !r.isValid), true);

        // Check specific error types
        expect(
          validationResults[0].errors.any((e) => e.contains('traumaLevel')),
          true,
        );
        expect(
          validationResults[1].errors.any(
            (e) => e.contains('latitude') || e.contains('longitude'),
          ),
          true,
        );
        expect(
          validationResults[2].errors.any((e) => e.contains('name')),
          true,
        );
        expect(
          validationResults[2].errors.any((e) => e.contains('specializations')),
          true,
        );
      });

      test(
        'should validate hospital-capacity relationship integrity',
        () async {
          // Arrange - Create hospital and capacity
          final testHospital = HospitalFirestore(
            id: '',
            name: 'Capacity Integrity Hospital',
            address: const HospitalAddress(
              street: '789 Capacity St',
              city: 'Capacity City',
              state: 'CC',
              zipCode: '78901',
              country: 'USA',
            ),
            location: const HospitalLocation(latitude: 42.0, longitude: -76.0),
            contact: const HospitalContact(
              phone: '(555) 789-0123',
              email: 'capacity@test.com',
            ),
            traumaLevel: 2,
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

          final hospitalId = await firestoreService.createHospital(
            testHospital,
          );
          testHospitalIds.add(hospitalId);

          final validCapacity = HospitalCapacityFirestore(
            id: hospitalId,
            hospitalId: hospitalId,
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

          // Act - Store capacity and validate relationship
          await firestoreService.updateHospitalCapacity(validCapacity);
          final retrievedCapacity = await firestoreService.getHospitalCapacity(
            hospitalId,
          );

          // Assert - Capacity-hospital relationship is valid
          expect(retrievedCapacity, isNotNull);
          expect(retrievedCapacity!.hospitalId, hospitalId);
          expect(retrievedCapacity.totalBeds, validCapacity.totalBeds);
          expect(
            retrievedCapacity.availableBeds <= retrievedCapacity.totalBeds,
            true,
          );
          expect(
            retrievedCapacity.icuAvailable <= retrievedCapacity.icuBeds,
            true,
          );
          expect(
            retrievedCapacity.emergencyAvailable <=
                retrievedCapacity.emergencyBeds,
            true,
          );
          expect(
            retrievedCapacity.occupancyRate >= 0.0 &&
                retrievedCapacity.occupancyRate <= 1.0,
            true,
          );

          // Test invalid capacity data
          final invalidCapacity = HospitalCapacityFirestore(
            id: hospitalId,
            hospitalId: hospitalId,
            totalBeds: 100,
            availableBeds: 150, // Invalid: more than total
            icuBeds: 10,
            icuAvailable: 15, // Invalid: more than ICU beds
            emergencyBeds: 15,
            emergencyAvailable: 20, // Invalid: more than emergency beds
            staffOnDuty: -5, // Invalid: negative
            patientsInQueue: -3, // Invalid: negative
            averageWaitTime: -10.0, // Invalid: negative
            lastUpdated: DateTime.now(),
            dataSource: DataSource.firestore,
            isRealTime: false,
          );

          final capacityValidation = migrationService.validateCapacityData(
            invalidCapacity,
          );
          expect(capacityValidation.isValid, false);
          expect(capacityValidation.errors.isNotEmpty, true);
        },
      );
    });

    group('Patient Data Integrity Tests', () {
      test('should validate patient vitals data integrity', () async {
        // Arrange
        const testPatientId = 'vitals_integrity_patient';
        testPatientIds.add(testPatientId);

        final validVitals = PatientVitalsFirestore(
          id: '',
          patientId: testPatientId,
          heartRate: 75.0,
          bloodPressureSystolic: 120.0,
          bloodPressureDiastolic: 80.0,
          oxygenSaturation: 98.0,
          temperature: 98.6,
          respiratoryRate: 16.0,
          source: VitalsSource.device,
          accuracy: 0.95,
          timestamp: DateTime.now(),
          isValidated: true,
        );

        // Act - Store and retrieve vitals
        await firestoreService.storePatientVitals(validVitals);
        final retrievedVitals = await firestoreService.getPatientVitals(
          testPatientId,
        );

        // Assert - Vitals data integrity maintained
        expect(retrievedVitals.isNotEmpty, true);
        final vitals = retrievedVitals.first;
        expect(vitals.patientId, testPatientId);
        expect(vitals.heartRate, validVitals.heartRate);
        expect(vitals.bloodPressureSystolic, validVitals.bloodPressureSystolic);
        expect(
          vitals.bloodPressureDiastolic,
          validVitals.bloodPressureDiastolic,
        );
        expect(vitals.oxygenSaturation, validVitals.oxygenSaturation);
        expect(vitals.temperature, validVitals.temperature);
        expect(vitals.respiratoryRate, validVitals.respiratoryRate);
        expect(vitals.source, validVitals.source);
        expect(vitals.accuracy, validVitals.accuracy);
        expect(vitals.isValidated, validVitals.isValidated);

        // Validate calculated fields
        expect(vitals.hasAbnormalVitals, false); // Normal vitals
        expect(vitals.vitalsSeverityScore >= 0.0, true);

        // Test abnormal vitals detection
        final abnormalVitals = PatientVitalsFirestore(
          id: '',
          patientId: testPatientId,
          heartRate: 200.0, // Abnormal
          bloodPressureSystolic: 250.0, // Abnormal
          bloodPressureDiastolic: 150.0, // Abnormal
          oxygenSaturation: 75.0, // Abnormal
          temperature: 105.0, // Abnormal
          respiratoryRate: 35.0, // Abnormal
          source: VitalsSource.device,
          accuracy: 0.95,
          timestamp: DateTime.now(),
          isValidated: true,
        );

        await firestoreService.storePatientVitals(abnormalVitals);
        final abnormalRetrieved = await firestoreService.getPatientVitals(
          testPatientId,
          limit: 1,
        );

        expect(abnormalRetrieved.first.hasAbnormalVitals, true);
        expect(abnormalRetrieved.first.vitalsSeverityScore > 0.0, true);
      });

      test('should validate triage result data integrity', () async {
        // Arrange
        const testPatientId = 'triage_integrity_patient';
        const testSessionId = 'triage_integrity_session';
        testPatientIds.add(testPatientId);

        final validTriageResult = TriageResultFirestore(
          id: '',
          patientId: testPatientId,
          sessionId: testSessionId,
          symptoms: 'Chest pain, shortness of breath, dizziness',
          severityScore: 7.5,
          urgencyLevel: UrgencyLevel.urgent,
          aiReasoning:
              'High severity symptoms indicating potential cardiac event requiring immediate attention',
          recommendedActions: const [
            'Immediate medical evaluation',
            'ECG monitoring',
            'Cardiac enzyme tests',
            'Prepare for potential cardiac intervention',
          ],
          vitalsContribution: 2.5,
          confidence: 0.92,
          recommendedHospitalId: 'recommended_hospital_123',
          estimatedWaitTime: 15,
          createdAt: DateTime.now(),
          geminiModelVersion: 'gemini-1.5-flash',
        );

        // Act - Store and retrieve triage result
        await firestoreService.storeTriageResult(validTriageResult);
        final retrievedResults = await firestoreService.getPatientHistory(
          testPatientId,
        );

        // Assert - Triage result data integrity maintained
        expect(retrievedResults.isNotEmpty, true);
        final result = retrievedResults.first;
        expect(result.patientId, testPatientId);
        expect(result.sessionId, testSessionId);
        expect(result.symptoms, validTriageResult.symptoms);
        expect(result.severityScore, validTriageResult.severityScore);
        expect(result.urgencyLevel, validTriageResult.urgencyLevel);
        expect(result.aiReasoning, validTriageResult.aiReasoning);
        expect(result.recommendedActions, validTriageResult.recommendedActions);
        expect(result.vitalsContribution, validTriageResult.vitalsContribution);
        expect(result.confidence, validTriageResult.confidence);
        expect(
          result.recommendedHospitalId,
          validTriageResult.recommendedHospitalId,
        );
        expect(result.estimatedWaitTime, validTriageResult.estimatedWaitTime);
        expect(result.geminiModelVersion, validTriageResult.geminiModelVersion);

        // Validate calculated fields and constraints
        expect(
          result.severityScore >= 0.0 && result.severityScore <= 10.0,
          true,
        );
        expect(result.confidence >= 0.0 && result.confidence <= 1.0, true);
        expect(result.vitalsContribution >= 0.0, true);
        expect(result.isUrgent, true); // UrgencyLevel.urgent
        expect(result.isCritical, false); // Not critical level
        expect(result.urgencyColor.isNotEmpty, true);
      });

      test('should validate patient consent data integrity', () async {
        // Arrange
        const testPatientId = 'consent_integrity_patient';
        const testProviderId = 'consent_integrity_provider';
        testPatientIds.add(testPatientId);

        final validConsent = PatientConsentFirestore(
          id: '',
          patientId: testPatientId,
          providerId: testProviderId,
          consentType: ConsentType.treatment,
          dataScopes: const [
            'vitals',
            'triage_results',
            'medical_history',
            'emergency_contacts',
          ],
          grantedAt: DateTime.now().subtract(const Duration(hours: 1)),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          isActive: true,
          blockchainTxId: 'integrity_test_tx_${math.Random().nextInt(100000)}',
          ipAddress: '192.168.1.100',
          consentDetails: const {
            'reason': 'Emergency treatment consent',
            'grantedBy': 'patient',
            'witnessId': 'nurse_456',
            'location': 'Emergency Department',
            'deviceId': 'tablet_789',
          },
        );

        // Act - Store and retrieve consent
        await firestoreService.storePatientConsent(validConsent);
        final retrievedConsents = await firestoreService.getActiveConsents(
          testPatientId,
        );

        // Assert - Consent data integrity maintained
        expect(retrievedConsents.isNotEmpty, true);
        final consent = retrievedConsents.first;
        expect(consent.patientId, testPatientId);
        expect(consent.providerId, testProviderId);
        expect(consent.consentType, validConsent.consentType);
        expect(consent.dataScopes, validConsent.dataScopes);
        expect(consent.isActive, validConsent.isActive);
        expect(consent.blockchainTxId, validConsent.blockchainTxId);
        expect(consent.ipAddress, validConsent.ipAddress);
        expect(consent.consentDetails, validConsent.consentDetails);

        // Validate calculated fields
        expect(consent.isValid, true);
        expect(consent.isExpired, false);
        expect(consent.isRevoked, false);
        expect(consent.status, ConsentStatus.active);

        // Test consent expiration
        final expiredConsent = validConsent.copyWith(
          id: '',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        await firestoreService.storePatientConsent(expiredConsent);
        final allConsents = await firestoreService.getPatientConsents(
          testPatientId,
        );
        final expiredConsentRetrieved = allConsents.firstWhere(
          (c) => c.expiresAt!.isBefore(DateTime.now()),
        );

        expect(expiredConsentRetrieved.isExpired, true);
        expect(expiredConsentRetrieved.isValid, false);
        expect(expiredConsentRetrieved.status, ConsentStatus.expired);
      });
    });

    group('Data Migration Integrity Tests', () {
      test(
        'should maintain data integrity during hospital migration',
        () async {
          // Arrange - Create source data
          final sourceHospitals = [
            HospitalFirestore(
              id: '',
              name: 'Migration Source Hospital 1',
              address: const HospitalAddress(
                street: '100 Migration St',
                city: 'Migration City',
                state: 'MC',
                zipCode: '10001',
                country: 'USA',
              ),
              location: const HospitalLocation(
                latitude: 40.0,
                longitude: -74.0,
              ),
              contact: const HospitalContact(
                phone: '(555) 100-0001',
                email: 'migration1@test.com',
              ),
              traumaLevel: 1,
              specializations: const ['emergency', 'trauma', 'cardiology'],
              certifications: const ['Joint Commission', 'Trauma Center'],
              operatingHours: const HospitalOperatingHours(
                emergency: '24/7',
                general: 'Mon-Sun 6:00 AM - 10:00 PM',
              ),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isActive: true,
            ),
            HospitalFirestore(
              id: '',
              name: 'Migration Source Hospital 2',
              address: const HospitalAddress(
                street: '200 Migration St',
                city: 'Migration City',
                state: 'MC',
                zipCode: '20002',
                country: 'USA',
              ),
              location: const HospitalLocation(
                latitude: 41.0,
                longitude: -75.0,
              ),
              contact: const HospitalContact(
                phone: '(555) 200-0002',
                email: 'migration2@test.com',
              ),
              traumaLevel: 3,
              specializations: const ['emergency', 'general'],
              certifications: const ['Joint Commission'],
              operatingHours: const HospitalOperatingHours(
                emergency: '24/7',
                general: 'Mon-Sun 7:00 AM - 9:00 PM',
              ),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isActive: true,
            ),
          ];

          // Act - Migrate hospitals
          final migratedIds = <String>[];
          for (final hospital in sourceHospitals) {
            final hospitalId = await firestoreService.createHospital(hospital);
            migratedIds.add(hospitalId);
            testHospitalIds.add(hospitalId);
          }

          // Assert - Verify migration integrity
          for (int i = 0; i < sourceHospitals.length; i++) {
            final source = sourceHospitals[i];
            final migrated = await firestoreService.getHospitalById(
              migratedIds[i],
            );

            expect(migrated, isNotNull);
            expect(migrated!.name, source.name);
            expect(migrated.address.street, source.address.street);
            expect(migrated.address.city, source.address.city);
            expect(migrated.location.latitude, source.location.latitude);
            expect(migrated.location.longitude, source.location.longitude);
            expect(migrated.contact.phone, source.contact.phone);
            expect(migrated.contact.email, source.contact.email);
            expect(migrated.traumaLevel, source.traumaLevel);
            expect(migrated.specializations, source.specializations);
            expect(migrated.certifications, source.certifications);
            expect(migrated.isActive, source.isActive);
          }

          // Validate no data corruption occurred
          final validationResult = await enhancedService
              .validateDataIntegrity();
          expect(validationResult['isValid'], true);
          expect(validationResult['errors'], isEmpty);
        },
      );

      test('should detect orphaned capacity records', () async {
        // Arrange - Create hospital and then delete it, leaving orphaned capacity
        final testHospital = HospitalFirestore(
          id: '',
          name: 'Orphan Test Hospital',
          address: const HospitalAddress(
            street: '999 Orphan St',
            city: 'Orphan City',
            state: 'OC',
            zipCode: '99999',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 43.0, longitude: -77.0),
          contact: const HospitalContact(
            phone: '(555) 999-9999',
            email: 'orphan@test.com',
          ),
          traumaLevel: 2,
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

        final hospitalId = await firestoreService.createHospital(testHospital);

        final testCapacity = HospitalCapacityFirestore(
          id: hospitalId,
          hospitalId: hospitalId,
          totalBeds: 50,
          availableBeds: 15,
          icuBeds: 5,
          icuAvailable: 2,
          emergencyBeds: 8,
          emergencyAvailable: 3,
          staffOnDuty: 40,
          patientsInQueue: 2,
          averageWaitTime: 20.0,
          lastUpdated: DateTime.now(),
          dataSource: DataSource.firestore,
          isRealTime: false,
        );

        await firestoreService.updateHospitalCapacity(testCapacity);

        // Act - Delete hospital but leave capacity (simulating orphaned data)
        await firestoreService.deleteHospital(hospitalId);

        // Assert - Validation should detect orphaned capacity
        final validationResult = await enhancedService.validateDataIntegrity();
        expect(validationResult['orphanedCapacities'], greaterThan(0));
        expect(validationResult['warnings'], isNotEmpty);

        // Cleanup orphaned capacity
        await firestoreService.deleteHospitalCapacity(hospitalId);
      });

      test('should validate data consistency across collections', () async {
        // Arrange - Create related data across collections
        const testPatientId = 'consistency_test_patient';
        testPatientIds.add(testPatientId);

        final testHospital = HospitalFirestore(
          id: '',
          name: 'Consistency Test Hospital',
          address: const HospitalAddress(
            street: '888 Consistency St',
            city: 'Consistency City',
            state: 'CC',
            zipCode: '88888',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 44.0, longitude: -78.0),
          contact: const HospitalContact(
            phone: '(555) 888-8888',
            email: 'consistency@test.com',
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

        final hospitalId = await firestoreService.createHospital(testHospital);
        testHospitalIds.add(hospitalId);

        // Create related data
        final testVitals = PatientVitalsFirestore(
          id: '',
          patientId: testPatientId,
          heartRate: 85.0,
          bloodPressureSystolic: 140.0,
          bloodPressureDiastolic: 90.0,
          oxygenSaturation: 96.0,
          temperature: 99.5,
          respiratoryRate: 20.0,
          source: VitalsSource.device,
          accuracy: 0.95,
          timestamp: DateTime.now(),
          isValidated: true,
        );

        final testTriageResult = TriageResultFirestore(
          id: '',
          patientId: testPatientId,
          sessionId: 'consistency_session',
          symptoms: 'Elevated blood pressure, mild fever',
          severityScore: 5.5,
          urgencyLevel: UrgencyLevel.standard,
          aiReasoning: 'Moderate symptoms requiring standard care',
          recommendedActions: const [
            'Monitor vitals',
            'Blood pressure medication',
          ],
          vitalsContribution: 1.8,
          confidence: 0.87,
          recommendedHospitalId: hospitalId,
          estimatedWaitTime: 25,
          createdAt: DateTime.now(),
          geminiModelVersion: 'gemini-1.5-flash',
        );

        // Act - Store related data
        await firestoreService.storePatientVitals(testVitals);
        await firestoreService.storeTriageResult(testTriageResult);

        // Assert - Verify data consistency
        final retrievedVitals = await firestoreService.getPatientVitals(
          testPatientId,
        );
        final retrievedTriage = await firestoreService.getPatientHistory(
          testPatientId,
        );
        final retrievedHospital = await firestoreService.getHospitalById(
          hospitalId,
        );

        expect(retrievedVitals.isNotEmpty, true);
        expect(retrievedTriage.isNotEmpty, true);
        expect(retrievedHospital, isNotNull);

        // Verify cross-references are valid
        expect(retrievedTriage.first.recommendedHospitalId, hospitalId);
        expect(retrievedTriage.first.patientId, testPatientId);
        expect(retrievedVitals.first.patientId, testPatientId);

        // Verify timestamps are consistent
        final vitalsTime = retrievedVitals.first.timestamp;
        final triageTime = retrievedTriage.first.createdAt;
        expect(
          triageTime.isAfter(vitalsTime) ||
              triageTime.isAtSameMomentAs(vitalsTime),
          true,
        );
      });
    });

    group('Data Synchronization Integrity Tests', () {
      test(
        'should maintain integrity during real-time synchronization',
        () async {
          // Arrange - Setup real-time listener
          final testHospital = HospitalFirestore(
            id: '',
            name: 'Sync Test Hospital',
            address: const HospitalAddress(
              street: '777 Sync St',
              city: 'Sync City',
              state: 'SC',
              zipCode: '77777',
              country: 'USA',
            ),
            location: const HospitalLocation(latitude: 45.0, longitude: -79.0),
            contact: const HospitalContact(
              phone: '(555) 777-7777',
              email: 'sync@test.com',
            ),
            traumaLevel: 2,
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

          final hospitalId = await firestoreService.createHospital(
            testHospital,
          );
          testHospitalIds.add(hospitalId);

          final initialCapacity = HospitalCapacityFirestore(
            id: hospitalId,
            hospitalId: hospitalId,
            totalBeds: 80,
            availableBeds: 20,
            icuBeds: 8,
            icuAvailable: 2,
            emergencyBeds: 12,
            emergencyAvailable: 4,
            staffOnDuty: 60,
            patientsInQueue: 3,
            averageWaitTime: 25.0,
            lastUpdated: DateTime.now(),
            dataSource: DataSource.firestore,
            isRealTime: true,
          );

          await firestoreService.updateHospitalCapacity(initialCapacity);

          // Act - Listen to capacity updates and perform multiple updates
          final capacityStream = enhancedService
              .listenToHospitalCapacityUpdates(hospitalId);
          final receivedUpdates = <List<HospitalCapacityFirestore>>[];

          final subscription = capacityStream.listen((updates) {
            receivedUpdates.add(updates);
          });

          // Wait for initial data
          await Future.delayed(const Duration(seconds: 1));

          // Perform sequential updates
          final updates = [
            initialCapacity.copyWith(availableBeds: 18, patientsInQueue: 5),
            initialCapacity.copyWith(availableBeds: 15, patientsInQueue: 8),
            initialCapacity.copyWith(availableBeds: 12, patientsInQueue: 11),
          ];

          for (final update in updates) {
            await firestoreService.updateHospitalCapacity(update);
            await Future.delayed(const Duration(milliseconds: 500));
          }

          // Wait for all updates
          await Future.delayed(const Duration(seconds: 2));

          // Assert - All updates received and data integrity maintained
          expect(receivedUpdates.isNotEmpty, true);

          // Verify final state
          final finalCapacity = await firestoreService.getHospitalCapacity(
            hospitalId,
          );
          expect(finalCapacity, isNotNull);
          expect(finalCapacity!.availableBeds, 12);
          expect(finalCapacity.patientsInQueue, 11);
          expect(finalCapacity.availableBeds <= finalCapacity.totalBeds, true);

          await subscription.cancel();
        },
      );

      test(
        'should handle concurrent updates without data corruption',
        () async {
          // Arrange
          const testPatientId = 'concurrent_test_patient';
          testPatientIds.add(testPatientId);

          // Act - Perform concurrent vitals updates
          final futures = <Future>[];
          for (int i = 0; i < 10; i++) {
            final vitals = PatientVitalsFirestore(
              id: '',
              patientId: testPatientId,
              heartRate: 70.0 + i,
              bloodPressureSystolic: 120.0 + i,
              bloodPressureDiastolic: 80.0,
              oxygenSaturation: 98.0,
              temperature: 98.6,
              respiratoryRate: 16.0,
              source: VitalsSource.device,
              accuracy: 0.95,
              timestamp: DateTime.now().add(Duration(milliseconds: i * 100)),
              isValidated: true,
            );

            futures.add(firestoreService.storePatientVitals(vitals));
          }

          await Future.wait(futures);

          // Assert - All vitals stored without corruption
          final allVitals = await firestoreService.getPatientVitals(
            testPatientId,
            limit: 20,
          );
          expect(allVitals.length, 10);

          // Verify data integrity - should be ordered by timestamp
          for (int i = 0; i < allVitals.length - 1; i++) {
            expect(
              allVitals[i].timestamp.isAfter(allVitals[i + 1].timestamp) ||
                  allVitals[i].timestamp.isAtSameMomentAs(
                    allVitals[i + 1].timestamp,
                  ),
              true,
            );
          }

          // Verify no duplicate or corrupted data
          final heartRates = allVitals.map((v) => v.heartRate).toSet();
          expect(heartRates.length, 10); // All unique values
        },
      );

      test('should validate data after bulk operations', () async {
        // Arrange - Prepare bulk data
        const batchSize = 20;
        final bulkHospitals = List.generate(
          batchSize,
          (index) => HospitalFirestore(
            id: '',
            name: 'Bulk Hospital $index',
            address: HospitalAddress(
              street: '$index Bulk St',
              city: 'Bulk City',
              state: 'BC',
              zipCode: '${30000 + index}',
              country: 'USA',
            ),
            location: HospitalLocation(
              latitude: 46.0 + (index * 0.01),
              longitude: -80.0 + (index * 0.01),
            ),
            contact: HospitalContact(
              phone: '(555) ${300 + index}-${4000 + index}',
              email: 'bulk$index@test.com',
            ),
            traumaLevel: (index % 4) + 1,
            specializations: const ['emergency'],
            certifications: const ['Joint Commission'],
            operatingHours: const HospitalOperatingHours(
              emergency: '24/7',
              general: 'Mon-Sun 6:00 AM - 10:00 PM',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ),
        );

        // Act - Perform bulk operation
        await enhancedService.batchCreateHospitals(bulkHospitals);

        // Assert - Validate all data was created correctly
        final allHospitals = await firestoreService.getHospitals(limit: 100);
        final bulkHospitalNames = bulkHospitals.map((h) => h.name).toSet();
        final createdNames = allHospitals.map((h) => h.name).toSet();

        final intersection = bulkHospitalNames.intersection(createdNames);
        expect(intersection.length, batchSize);

        // Validate data integrity after bulk operation
        final validationResult = await enhancedService.validateDataIntegrity();
        expect(validationResult['isValid'], true);
        expect(validationResult['errors'], isEmpty);

        // Add created hospitals to cleanup list
        for (final hospital in allHospitals) {
          if (hospital.name.startsWith('Bulk Hospital')) {
            testHospitalIds.add(hospital.id);
          }
        }
      });
    });

    group('Cross-Platform Data Integrity Tests', () {
      test(
        'should maintain data integrity across different data sources',
        () async {
          // Arrange - Test data source switching
          final testHospital = HospitalFirestore(
            id: '',
            name: 'Cross Platform Hospital',
            address: const HospitalAddress(
              street: '666 Platform St',
              city: 'Platform City',
              state: 'PC',
              zipCode: '66666',
              country: 'USA',
            ),
            location: const HospitalLocation(latitude: 47.0, longitude: -81.0),
            contact: const HospitalContact(
              phone: '(555) 666-6666',
              email: 'platform@test.com',
            ),
            traumaLevel: 1,
            specializations: const ['emergency', 'trauma'],
            certifications: const ['Joint Commission'],
            operatingHours: const HospitalOperatingHours(
              emergency: '24/7',
              general: 'Mon-Sun 6:00 AM - 10:00 PM',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          );

          // Act - Store via Firestore
          final hospitalId = await firestoreService.createHospital(
            testHospital,
          );
          testHospitalIds.add(hospitalId);

          // Retrieve via different service
          final retrievedViaEnhanced = await enhancedService.getHospitalById(
            hospitalId,
          );
          final retrievedViaBasic = await firestoreService.getHospitalById(
            hospitalId,
          );

          // Assert - Data consistency across services
          expect(retrievedViaEnhanced, isNotNull);
          expect(retrievedViaBasic, isNotNull);
          expect(retrievedViaEnhanced!.name, retrievedViaBasic!.name);
          expect(
            retrievedViaEnhanced.traumaLevel,
            retrievedViaBasic.traumaLevel,
          );
          expect(
            retrievedViaEnhanced.specializations,
            retrievedViaBasic.specializations,
          );
          expect(
            retrievedViaEnhanced.location.latitude,
            retrievedViaBasic.location.latitude,
          );
          expect(
            retrievedViaEnhanced.location.longitude,
            retrievedViaBasic.location.longitude,
          );
        },
      );

      test('should handle data format consistency across platforms', () async {
        // Test enum serialization/deserialization consistency
        final testData = [
          UrgencyLevel.critical,
          UrgencyLevel.urgent,
          UrgencyLevel.standard,
          UrgencyLevel.nonUrgent,
        ];

        for (final urgency in testData) {
          final serialized = urgency.toString();
          final deserialized = UrgencyLevel.fromString(serialized);
          expect(deserialized, urgency);
        }

        // Test data source enum consistency
        final dataSources = [DataSource.firestore, DataSource.customApi];

        for (final source in dataSources) {
          final serialized = source.toString();
          final deserialized = DataSource.fromString(serialized);
          expect(deserialized, source);
        }

        // Test vitals source enum consistency
        final vitalsSources = [
          VitalsSource.appleHealth,
          VitalsSource.googleFit,
          VitalsSource.manual,
          VitalsSource.device,
        ];

        for (final source in vitalsSources) {
          final serialized = source.toString();
          final deserialized = VitalsSource.fromString(serialized);
          expect(deserialized, source);
        }
      });
    });
  });
}
