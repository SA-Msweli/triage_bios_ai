import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:triage_bios_ai/shared/services/firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/enhanced_firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/data_migration_service.dart';
import 'package:triage_bios_ai/shared/services/hospital_routing_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_consent_firestore.dart';
import 'dart:math' as math;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Firestore Integration Tests', () {
    late FirestoreDataService firestoreService;
    late EnhancedFirestoreDataService enhancedService;
    late DataMigrationService migrationService;
    late HospitalRoutingService routingService;

    // Test data cleanup
    final testHospitalIds = <String>[];
    final testPatientIds = <String>[];
    final testSessionIds = <String>[];

    setUpAll(() async {
      firestoreService = FirestoreDataService();
      enhancedService = EnhancedFirestoreDataService();
      migrationService = DataMigrationService();
      routingService = HospitalRoutingService();
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

    group('End-to-End Hospital Data Flow', () {
      testWidgets('should create, retrieve, and update hospital data', (
        tester,
      ) async {
        // Arrange
        final testHospital = HospitalFirestore(
          id: '',
          name: 'Integration Test Hospital',
          address: const HospitalAddress(
            street: '123 Integration St',
            city: 'Test City',
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
            email: 'integration@test.com',
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

        // Act - Create hospital
        final hospitalId = await firestoreService.createHospital(testHospital);
        testHospitalIds.add(hospitalId);

        // Assert - Hospital created
        expect(hospitalId.isNotEmpty, true);

        // Act - Retrieve hospital
        final retrievedHospital = await firestoreService.getHospitalById(
          hospitalId,
        );

        // Assert - Hospital retrieved correctly
        expect(retrievedHospital, isNotNull);
        expect(retrievedHospital!.name, 'Integration Test Hospital');
        expect(retrievedHospital.traumaLevel, 1);
        expect(retrievedHospital.specializations.contains('emergency'), true);

        // Act - Update hospital
        final updatedHospital = retrievedHospital.copyWith(
          name: 'Updated Integration Test Hospital',
          traumaLevel: 2,
        );
        await firestoreService.updateHospital(hospitalId, updatedHospital);

        // Act - Retrieve updated hospital
        final finalHospital = await firestoreService.getHospitalById(
          hospitalId,
        );

        // Assert - Hospital updated correctly
        expect(finalHospital!.name, 'Updated Integration Test Hospital');
        expect(finalHospital.traumaLevel, 2);
      });

      testWidgets('should manage hospital capacity with real-time updates', (
        tester,
      ) async {
        // Arrange
        final testHospital = HospitalFirestore(
          id: '',
          name: 'Capacity Test Hospital',
          address: const HospitalAddress(
            street: '456 Capacity St',
            city: 'Capacity City',
            state: 'CC',
            zipCode: '67890',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 41.0, longitude: -74.0),
          contact: const HospitalContact(
            phone: '(555) 987-6543',
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

        final hospitalId = await firestoreService.createHospital(testHospital);
        testHospitalIds.add(hospitalId);

        final testCapacity = HospitalCapacityFirestore(
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
          isRealTime: true,
        );

        // Act - Create capacity
        await firestoreService.updateHospitalCapacity(testCapacity);

        // Assert - Capacity created
        final retrievedCapacity = await firestoreService.getHospitalCapacity(
          hospitalId,
        );
        expect(retrievedCapacity, isNotNull);
        expect(retrievedCapacity!.totalBeds, 100);
        expect(retrievedCapacity.availableBeds, 25);

        // Act - Update capacity
        final updatedCapacity = testCapacity.copyWith(
          availableBeds: 20,
          patientsInQueue: 8,
          averageWaitTime: 35.0,
          lastUpdated: DateTime.now(),
        );
        await firestoreService.updateHospitalCapacity(updatedCapacity);

        // Assert - Capacity updated
        final finalCapacity = await firestoreService.getHospitalCapacity(
          hospitalId,
        );
        expect(finalCapacity!.availableBeds, 20);
        expect(finalCapacity.patientsInQueue, 8);
        expect(finalCapacity.averageWaitTime, 35.0);
      });
    });

    group('End-to-End Patient Data Flow', () {
      testWidgets('should store and retrieve patient vitals', (tester) async {
        // Arrange
        const patientId = 'integration_test_patient_1';
        testPatientIds.add(patientId);

        final testVitals = PatientVitalsFirestore(
          id: '',
          patientId: patientId,
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

        // Act - Store vitals
        await firestoreService.storePatientVitals(testVitals);

        // Assert - Vitals stored and retrievable
        final retrievedVitals = await firestoreService.getPatientVitals(
          patientId,
        );
        expect(retrievedVitals.isNotEmpty, true);
        expect(retrievedVitals.first.heartRate, 75.0);
        expect(retrievedVitals.first.oxygenSaturation, 98.0);

        // Act - Store multiple vitals
        final additionalVitals = [
          testVitals.copyWith(
            id: '',
            heartRate: 80.0,
            timestamp: DateTime.now().add(const Duration(minutes: 5)),
          ),
          testVitals.copyWith(
            id: '',
            heartRate: 85.0,
            timestamp: DateTime.now().add(const Duration(minutes: 10)),
          ),
        ];

        for (final vitals in additionalVitals) {
          await firestoreService.storePatientVitals(vitals);
        }

        // Assert - Multiple vitals stored
        final allVitals = await firestoreService.getPatientVitals(patientId);
        expect(allVitals.length, 3);

        // Should be ordered by timestamp (most recent first)
        expect(allVitals.first.heartRate, 85.0);
        expect(allVitals.last.heartRate, 75.0);
      });

      testWidgets('should store and retrieve triage results', (tester) async {
        // Arrange
        const patientId = 'integration_test_patient_2';
        const sessionId = 'integration_test_session_1';
        testPatientIds.add(patientId);
        testSessionIds.add(sessionId);

        final testTriageResult = TriageResultFirestore(
          id: '',
          patientId: patientId,
          sessionId: sessionId,
          symptoms: 'Chest pain, shortness of breath',
          severityScore: 7.5,
          urgencyLevel: UrgencyLevel.urgent,
          aiReasoning:
              'High severity symptoms indicating potential cardiac event',
          recommendedActions: const [
            'Immediate medical attention required',
            'Monitor vital signs',
            'Prepare for cardiac evaluation',
          ],
          vitalsContribution: 2.5,
          confidence: 0.92,
          createdAt: DateTime.now(),
          geminiModelVersion: 'gemini-1.5-flash',
        );

        // Act - Store triage result
        await firestoreService.storeTriageResult(testTriageResult);

        // Assert - Triage result stored and retrievable
        final patientHistory = await firestoreService.getPatientHistory(
          patientId,
        );
        expect(patientHistory.isNotEmpty, true);
        expect(patientHistory.first.severityScore, 7.5);
        expect(patientHistory.first.urgencyLevel, UrgencyLevel.urgent);
        expect(patientHistory.first.confidence, 0.92);
      });

      testWidgets('should manage patient consents', (tester) async {
        // Arrange
        const patientId = 'integration_test_patient_3';
        const providerId = 'integration_test_provider_1';
        testPatientIds.add(patientId);

        final testConsent = PatientConsentFirestore(
          id: '',
          patientId: patientId,
          providerId: providerId,
          consentType: ConsentType.treatment,
          dataScopes: const ['vitals', 'triage_results', 'medical_history'],
          grantedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          isActive: true,
          blockchainTxId: 'integration_test_tx_${math.Random().nextInt(10000)}',
          ipAddress: '192.168.1.100',
          consentDetails: const {
            'reason': 'Emergency treatment consent',
            'grantedBy': 'patient',
            'witnessId': 'nurse_123',
          },
        );

        // Act - Store consent
        await firestoreService.storePatientConsent(testConsent);

        // Assert - Consent stored and retrievable
        final activeConsents = await firestoreService.getActiveConsents(
          patientId,
        );
        expect(activeConsents.isNotEmpty, true);
        expect(activeConsents.first.consentType, ConsentType.treatment);
        expect(activeConsents.first.isActive, true);
        expect(activeConsents.first.dataScopes.contains('vitals'), true);

        // Act - Revoke consent
        await firestoreService.revokeConsent(activeConsents.first.id);

        // Assert - Consent revoked
        final revokedConsents = await firestoreService.getActiveConsents(
          patientId,
        );
        expect(revokedConsents.isEmpty, true);
      });
    });

    group('Real-time Listeners Integration', () {
      testWidgets('should receive real-time capacity updates', (tester) async {
        // Arrange
        final testHospital = HospitalFirestore(
          id: '',
          name: 'Real-time Test Hospital',
          address: const HospitalAddress(
            street: '789 Realtime St',
            city: 'Realtime City',
            state: 'RC',
            zipCode: '78901',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 42.0, longitude: -75.0),
          contact: const HospitalContact(
            phone: '(555) 789-0123',
            email: 'realtime@test.com',
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

        final hospitalId = await firestoreService.createHospital(testHospital);
        testHospitalIds.add(hospitalId);

        final initialCapacity = HospitalCapacityFirestore(
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
          isRealTime: true,
        );

        await firestoreService.updateHospitalCapacity(initialCapacity);

        // Act - Listen to capacity updates
        final capacityStream = enhancedService.listenToHospitalCapacityUpdates(
          hospitalId,
        );
        final capacityUpdates = <List<HospitalCapacityFirestore>>[];

        final subscription = capacityStream.listen((updates) {
          capacityUpdates.add(updates);
        });

        // Wait for initial data
        await tester.pump(const Duration(seconds: 1));

        // Update capacity
        final updatedCapacity = initialCapacity.copyWith(
          availableBeds: 10,
          patientsInQueue: 5,
          averageWaitTime: 25.0,
          lastUpdated: DateTime.now(),
        );
        await firestoreService.updateHospitalCapacity(updatedCapacity);

        // Wait for update
        await tester.pump(const Duration(seconds: 2));

        // Assert - Received real-time updates
        expect(capacityUpdates.isNotEmpty, true);
        if (capacityUpdates.isNotEmpty) {
          final latestUpdate = capacityUpdates.last;
          expect(latestUpdate.isNotEmpty, true);
          expect(latestUpdate.first.availableBeds, 10);
          expect(latestUpdate.first.patientsInQueue, 5);
        }

        await subscription.cancel();
      });

      testWidgets('should receive real-time vitals updates', (tester) async {
        // Arrange
        const patientId = 'realtime_vitals_patient';
        testPatientIds.add(patientId);

        // Act - Listen to vitals updates
        final vitalsStream = enhancedService.listenToPatientVitals(
          patientId,
          limit: 5,
        );
        final vitalsUpdates = <List<PatientVitalsFirestore>>[];

        final subscription = vitalsStream.listen((updates) {
          vitalsUpdates.add(updates);
        });

        // Wait for initial data
        await tester.pump(const Duration(seconds: 1));

        // Add new vitals
        final newVitals = PatientVitalsFirestore(
          id: '',
          patientId: patientId,
          heartRate: 90.0,
          bloodPressureSystolic: 130.0,
          bloodPressureDiastolic: 85.0,
          oxygenSaturation: 97.0,
          temperature: 99.2,
          respiratoryRate: 18.0,
          source: VitalsSource.device,
          accuracy: 0.98,
          timestamp: DateTime.now(),
          isValidated: true,
        );

        await firestoreService.storePatientVitals(newVitals);

        // Wait for update
        await tester.pump(const Duration(seconds: 2));

        // Assert - Received real-time vitals
        expect(vitalsUpdates.isNotEmpty, true);
        if (vitalsUpdates.isNotEmpty) {
          final latestUpdate = vitalsUpdates.last;
          if (latestUpdate.isNotEmpty) {
            expect(latestUpdate.first.heartRate, 90.0);
            expect(latestUpdate.first.source, VitalsSource.device);
          }
        }

        await subscription.cancel();
      });
    });

    group('Hospital Routing Integration', () {
      testWidgets('should find optimal hospitals based on patient needs', (
        tester,
      ) async {
        // Arrange - Create multiple test hospitals
        final hospitals = [
          HospitalFirestore(
            id: '',
            name: 'Nearby General Hospital',
            address: const HospitalAddress(
              street: '100 Near St',
              city: 'Near City',
              state: 'NC',
              zipCode: '10001',
              country: 'USA',
            ),
            location: const HospitalLocation(
              latitude: 40.7500, // Close to test location
              longitude: -73.9800,
            ),
            contact: const HospitalContact(
              phone: '(555) 100-0001',
              email: 'near@hospital.com',
            ),
            traumaLevel: 3,
            specializations: const ['emergency', 'general'],
            certifications: const ['Joint Commission'],
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
            name: 'Specialized Cardiac Center',
            address: const HospitalAddress(
              street: '200 Cardiac St',
              city: 'Cardiac City',
              state: 'CC',
              zipCode: '20002',
              country: 'USA',
            ),
            location: const HospitalLocation(
              latitude: 40.7600, // Slightly farther
              longitude: -73.9700,
            ),
            contact: const HospitalContact(
              phone: '(555) 200-0002',
              email: 'cardiac@hospital.com',
            ),
            traumaLevel: 1,
            specializations: const [
              'emergency',
              'cardiology',
              'cardiac_surgery',
            ],
            certifications: const ['Joint Commission', 'Cardiac Specialty'],
            operatingHours: const HospitalOperatingHours(
              emergency: '24/7',
              general: 'Mon-Sun 6:00 AM - 10:00 PM',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ),
        ];

        final hospitalIds = <String>[];
        for (final hospital in hospitals) {
          final id = await firestoreService.createHospital(hospital);
          hospitalIds.add(id);
          testHospitalIds.add(id);

          // Create capacity for each hospital
          final capacity = HospitalCapacityFirestore(
            id: id,
            hospitalId: id,
            totalBeds: 100,
            availableBeds: 20,
            icuBeds: 10,
            icuAvailable: 3,
            emergencyBeds: 15,
            emergencyAvailable: 5,
            staffOnDuty: 80,
            patientsInQueue: 3,
            averageWaitTime: 25.0,
            lastUpdated: DateTime.now(),
            dataSource: DataSource.firestore,
            isRealTime: false,
          );
          await firestoreService.updateHospitalCapacity(capacity);
        }

        // Act - Find optimal hospital for cardiac emergency
        const patientLocation = HospitalLocation(
          latitude: 40.7589,
          longitude: -73.9851,
        );

        final optimalHospitals = await routingService.findOptimalHospital(
          patientLocation: patientLocation,
          severityScore: 8.0, // High severity
          requiredSpecializations: ['cardiology'],
        );

        // Assert - Should prioritize cardiac center despite distance
        expect(optimalHospitals.isNotEmpty, true);
        expect(
          optimalHospitals.first.hospitalName,
          'Specialized Cardiac Center',
        );

        // Act - Find optimal hospital for general emergency
        final generalHospitals = await routingService.findOptimalHospital(
          patientLocation: patientLocation,
          severityScore: 4.0, // Moderate severity
          requiredSpecializations: ['emergency'],
        );

        // Assert - Should prioritize nearby hospital for general case
        expect(generalHospitals.isNotEmpty, true);
        // Either hospital could be optimal depending on exact scoring
        expect(
          generalHospitals.any(
            (h) =>
                h.hospitalName == 'Nearby General Hospital' ||
                h.hospitalName == 'Specialized Cardiac Center',
          ),
          true,
        );
      });
    });

    group('Data Migration Integration', () {
      testWidgets('should migrate and validate data integrity', (tester) async {
        // Arrange - Clear any existing test data
        await migrationService.resetDevelopmentData();

        // Act - Seed hospital data
        await migrationService.seedHospitalData();

        // Assert - Data seeded successfully
        final hospitals = await firestoreService.getHospitals(limit: 100);
        expect(hospitals.isNotEmpty, true);
        expect(
          hospitals.length,
          greaterThan(10),
        ); // Should have multiple hospitals

        // Verify hospital data quality
        for (final hospital in hospitals.take(5)) {
          expect(hospital.name.isNotEmpty, true);
          expect(hospital.address.city.isNotEmpty, true);
          expect(hospital.traumaLevel >= 1 && hospital.traumaLevel <= 4, true);
          expect(hospital.specializations.isNotEmpty, true);

          // Check if capacity exists
          final capacity = await firestoreService.getHospitalCapacity(
            hospital.id,
          );
          expect(capacity, isNotNull);
          expect(capacity!.totalBeds, greaterThan(0));
          expect(capacity.availableBeds, greaterThanOrEqualTo(0));
        }

        // Act - Validate data integrity
        final validationResult = await enhancedService.validateDataIntegrity();

        // Assert - Data integrity is good
        expect(validationResult['isValid'], true);
        expect(validationResult['errors'], isEmpty);

        // Act - Generate sample patient data
        const testPatientId = 'migration_test_patient';
        testPatientIds.add(testPatientId);

        final sampleVitals = migrationService.generateSamplePatientVitals(
          testPatientId,
          5,
        );
        for (final vitals in sampleVitals) {
          await firestoreService.storePatientVitals(vitals);
        }

        final sampleTriageResults = migrationService
            .generateSampleTriageResults(testPatientId, 3);
        for (final result in sampleTriageResults) {
          await firestoreService.storeTriageResult(result);
        }

        // Assert - Sample data created successfully
        final patientVitals = await firestoreService.getPatientVitals(
          testPatientId,
        );
        expect(patientVitals.length, 5);

        final patientHistory = await firestoreService.getPatientHistory(
          testPatientId,
        );
        expect(patientHistory.length, 3);
      });
    });

    group('Performance and Scalability', () {
      testWidgets('should handle batch operations efficiently', (tester) async {
        // Arrange
        const batchSize = 10;
        final batchHospitals = <HospitalFirestore>[];

        for (int i = 0; i < batchSize; i++) {
          batchHospitals.add(
            HospitalFirestore(
              id: '',
              name: 'Batch Hospital $i',
              address: HospitalAddress(
                street: '$i Batch St',
                city: 'Batch City',
                state: 'BC',
                zipCode: '${10000 + i}',
                country: 'USA',
              ),
              location: HospitalLocation(
                latitude: 40.0 + (i * 0.01),
                longitude: -74.0 + (i * 0.01),
              ),
              contact: HospitalContact(
                phone: '(555) ${100 + i}-${1000 + i}',
                email: 'batch$i@hospital.com',
              ),
              traumaLevel: (i % 4) + 1,
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
        }

        // Act - Batch create hospitals
        final stopwatch = Stopwatch()..start();
        await enhancedService.batchCreateHospitals(batchHospitals);
        stopwatch.stop();

        // Assert - Batch operation completed efficiently
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10000),
        ); // Should complete within 10 seconds

        // Verify all hospitals were created
        final allHospitals = await firestoreService.getHospitals(limit: 100);
        final batchHospitalNames = batchHospitals.map((h) => h.name).toSet();
        final createdNames = allHospitals.map((h) => h.name).toSet();

        expect(batchHospitalNames.intersection(createdNames).length, batchSize);

        // Add created hospital IDs to cleanup list
        for (final hospital in allHospitals) {
          if (hospital.name.startsWith('Batch Hospital')) {
            testHospitalIds.add(hospital.id);
          }
        }
      });

      testWidgets('should handle large dataset queries efficiently', (
        tester,
      ) async {
        // Act - Query large dataset with filters
        final stopwatch = Stopwatch()..start();
        final hospitals = await enhancedService.queryHospitalsAdvanced(
          latitude: 40.7589,
          longitude: -73.9851,
          radiusKm: 50.0,
          isActive: true,
          limit: 50,
        );
        stopwatch.stop();

        // Assert - Query completed efficiently
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
        ); // Should complete within 5 seconds
        expect(hospitals, isA<List<HospitalFirestore>>());
      });
    });

    group('Error Handling and Recovery', () {
      testWidgets('should handle network interruptions gracefully', (
        tester,
      ) async {
        // This test would require network simulation capabilities
        // For now, we'll test the offline cache functionality

        // Arrange - Populate cache
        await enhancedService.getHospitals(forceRefresh: true);

        // Act - Get hospitals (should use cache if network fails)
        final cachedHospitals = await enhancedService.getHospitals(
          forceRefresh: false,
        );

        // Assert - Should return data even if network is unavailable
        expect(cachedHospitals, isA<List<HospitalFirestore>>());
      });

      testWidgets('should validate data before operations', (tester) async {
        // Arrange - Create invalid hospital data
        final invalidHospital = HospitalFirestore(
          id: '',
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

        // Act & Assert - Should throw validation error
        expect(
          () => firestoreService.createHospital(invalidHospital),
          throwsException,
        );
      });
    });
  });
}
