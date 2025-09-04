import 'package:flutter_test/flutter_test.dart';
import 'package:triage_bios_ai/shared/services/firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/enhanced_firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/data_migration_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  group('Firestore Performance Tests', () {
    late FirestoreDataService firestoreService;
    late EnhancedFirestoreDataService enhancedService;
    late DataMigrationService migrationService;

    // Performance thresholds (in milliseconds)
    const int queryTimeoutMs = 5000;
    const int batchOperationTimeoutMs = 10000;
    const int realTimeListenerSetupMs = 2000;
    const int largeDatasetQueryMs = 8000;

    // Test data cleanup
    final testHospitalIds = <String>[];
    final testPatientIds = <String>[];

    setUpAll(() async {
      firestoreService = FirestoreDataService();
      enhancedService = EnhancedFirestoreDataService();
      migrationService = DataMigrationService();
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

    group('Query Performance Tests', () {
      test(
        'hospital queries should complete within performance threshold',
        () async {
          // Arrange
          final stopwatch = Stopwatch();

          // Act & Assert - Basic hospital query
          stopwatch.start();
          final hospitals = await firestoreService.getHospitals(limit: 50);
          stopwatch.stop();

          expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));
          expect(hospitals, isA<List<HospitalFirestore>>());

          // Act & Assert - Filtered hospital query
          stopwatch.reset();
          stopwatch.start();
          final filteredHospitals = await firestoreService.getHospitals(
            specializations: ['emergency', 'cardiology'],
            minTraumaLevel: 1,
            isActive: true,
            limit: 25,
          );
          stopwatch.stop();

          expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));
          expect(filteredHospitals, isA<List<HospitalFirestore>>());
        },
      );

      test('advanced hospital queries should perform efficiently', () async {
        // Arrange
        final stopwatch = Stopwatch();

        // Act & Assert - Complex query with multiple filters
        stopwatch.start();
        final advancedResults = await enhancedService.queryHospitalsAdvanced(
          latitude: 40.7589,
          longitude: -73.9851,
          radiusKm: 25.0,
          requiredSpecializations: ['emergency'],
          minTraumaLevel: 1,
          maxTraumaLevel: 3,
          isActive: true,
          minAvailableBeds: 5,
          maxOccupancyRate: 0.85,
          maxWaitTime: 60,
          sortByDistance: true,
          limit: 20,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(advancedResults, isA<List<HospitalFirestore>>());

        // Act & Assert - Urgency-based query
        stopwatch.reset();
        stopwatch.start();
        final urgentResults = await enhancedService
            .queryHospitalsByAvailability(
              urgencyLevel: UrgencyLevel.critical,
              latitude: 40.7589,
              longitude: -73.9851,
              radiusKm: 15.0,
              limit: 10,
            );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));
        expect(urgentResults, isA<List<HospitalFirestore>>());
      });

      test('patient data queries should be performant', () async {
        // Arrange
        const testPatientId = 'performance_test_patient';
        testPatientIds.add(testPatientId);
        final stopwatch = Stopwatch();

        // Create test data
        final testVitals = List.generate(
          20,
          (index) => PatientVitalsFirestore(
            id: '',
            patientId: testPatientId,
            heartRate: 70.0 + (index * 2),
            bloodPressureSystolic: 120.0 + index,
            bloodPressureDiastolic: 80.0 + index,
            oxygenSaturation: 98.0 - (index * 0.1),
            temperature: 98.6 + (index * 0.1),
            respiratoryRate: 16.0 + index,
            source: VitalsSource.device,
            accuracy: 0.95,
            timestamp: DateTime.now().subtract(Duration(minutes: index * 5)),
            isValidated: true,
          ),
        );

        // Store test vitals
        for (final vitals in testVitals) {
          await firestoreService.storePatientVitals(vitals);
        }

        // Act & Assert - Patient vitals query
        stopwatch.start();
        final retrievedVitals = await firestoreService.getPatientVitals(
          testPatientId,
          limit: 10,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));
        expect(retrievedVitals.length, lessThanOrEqualTo(10));

        // Act & Assert - Patient history query
        stopwatch.reset();
        stopwatch.start();
        final patientHistory = await firestoreService.getPatientHistory(
          testPatientId,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));
        expect(patientHistory, isA<List<TriageResultFirestore>>());
      });
    });

    group('Batch Operation Performance Tests', () {
      test('batch hospital creation should be efficient', () async {
        // Arrange
        const batchSize = 25;
        final batchHospitals = List.generate(
          batchSize,
          (index) => HospitalFirestore(
            id: '',
            name: 'Performance Test Hospital $index',
            address: HospitalAddress(
              street: '$index Performance St',
              city: 'Performance City',
              state: 'PC',
              zipCode: '${10000 + index}',
              country: 'USA',
            ),
            location: HospitalLocation(
              latitude: 40.0 + (index * 0.01),
              longitude: -74.0 + (index * 0.01),
            ),
            contact: HospitalContact(
              phone: '(555) ${100 + index}-${1000 + index}',
              email: 'perf$index@hospital.com',
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

        final stopwatch = Stopwatch();

        // Act & Assert - Batch creation
        stopwatch.start();
        await enhancedService.batchCreateHospitals(batchHospitals);
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(batchOperationTimeoutMs),
        );

        // Verify hospitals were created
        final createdHospitals = await firestoreService.getHospitals(
          limit: 100,
        );
        final performanceHospitals = createdHospitals
            .where((h) => h.name.startsWith('Performance Test Hospital'))
            .toList();

        expect(performanceHospitals.length, batchSize);

        // Add to cleanup list
        testHospitalIds.addAll(performanceHospitals.map((h) => h.id));
      });

      test('batch capacity updates should be efficient', () async {
        // Arrange
        const batchSize = 20;
        final batchCapacities = List.generate(
          batchSize,
          (index) => HospitalCapacityFirestore(
            id: 'perf_capacity_$index',
            hospitalId: 'perf_hospital_$index',
            totalBeds: 100 + (index * 10),
            availableBeds: 25 + (index * 2),
            icuBeds: 10 + index,
            icuAvailable: 3 + (index ~/ 2),
            emergencyBeds: 15 + index,
            emergencyAvailable: 5 + (index ~/ 3),
            staffOnDuty: 80 + (index * 2),
            patientsInQueue: 5 + (index ~/ 4),
            averageWaitTime: 30.0 + (index * 2),
            lastUpdated: DateTime.now(),
            dataSource: DataSource.firestore,
            isRealTime: false,
          ),
        );

        final stopwatch = Stopwatch();

        // Act & Assert - Batch capacity update
        stopwatch.start();
        await enhancedService.batchUpdateCapacities(batchCapacities);
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(batchOperationTimeoutMs),
        );
      });

      test('batch vitals storage should be performant', () async {
        // Arrange
        const testPatientId = 'batch_vitals_patient';
        const batchSize = 50;
        testPatientIds.add(testPatientId);

        final batchVitals = List.generate(
          batchSize,
          (index) => PatientVitalsFirestore(
            id: '',
            patientId: testPatientId,
            heartRate: 60.0 + (index % 40),
            bloodPressureSystolic: 110.0 + (index % 50),
            bloodPressureDiastolic: 70.0 + (index % 30),
            oxygenSaturation: 95.0 + (index % 5),
            temperature: 98.0 + (index % 3),
            respiratoryRate: 12.0 + (index % 10),
            source: VitalsSource.device,
            accuracy: 0.9 + (index % 10) * 0.01,
            timestamp: DateTime.now().subtract(Duration(minutes: index)),
            isValidated: true,
          ),
        );

        final stopwatch = Stopwatch();

        // Act & Assert - Batch vitals storage
        stopwatch.start();
        await enhancedService.batchStorePatientVitals(batchVitals);
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(batchOperationTimeoutMs),
        );

        // Verify vitals were stored
        final storedVitals = await firestoreService.getPatientVitals(
          testPatientId,
          limit: 100,
        );
        expect(storedVitals.length, batchSize);
      });
    });

    group('Real-time Listener Performance Tests', () {
      test('real-time listeners should setup quickly', () async {
        // Arrange
        const testHospitalId = 'realtime_perf_hospital';
        const testPatientId = 'realtime_perf_patient';
        testPatientIds.add(testPatientId);

        final stopwatch = Stopwatch();

        // Act & Assert - Hospital capacity listener setup
        stopwatch.start();
        final capacityStream = enhancedService.listenToHospitalCapacityUpdates(
          testHospitalId,
        );
        final capacitySubscription = capacityStream.listen((_) {});
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(realTimeListenerSetupMs),
        );

        // Act & Assert - Patient vitals listener setup
        stopwatch.reset();
        stopwatch.start();
        final vitalsStream = enhancedService.listenToPatientVitals(
          testPatientId,
          limit: 10,
        );
        final vitalsSubscription = vitalsStream.listen((_) {});
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(realTimeListenerSetupMs),
        );

        // Act & Assert - Critical vitals listener setup
        stopwatch.reset();
        stopwatch.start();
        final criticalStream = enhancedService.listenToCriticalVitals(
          minSeverityScore: 7.0,
        );
        final criticalSubscription = criticalStream.listen((_) {});
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(realTimeListenerSetupMs),
        );

        // Cleanup
        await capacitySubscription.cancel();
        await vitalsSubscription.cancel();
        await criticalSubscription.cancel();
      });

      test(
        'real-time listeners should handle high-frequency updates',
        () async {
          // Arrange
          const testPatientId = 'high_freq_patient';
          testPatientIds.add(testPatientId);

          final vitalsStream = enhancedService.listenToPatientVitals(
            testPatientId,
            limit: 5,
          );
          final receivedUpdates = <List<PatientVitalsFirestore>>[];
          final completer = Completer<void>();

          final subscription = vitalsStream.listen((updates) {
            receivedUpdates.add(updates);
            if (receivedUpdates.length >= 5) {
              completer.complete();
            }
          });

          final stopwatch = Stopwatch()..start();

          // Act - Generate high-frequency updates
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

            await firestoreService.storePatientVitals(vitals);

            // Small delay to simulate real-time updates
            await Future.delayed(const Duration(milliseconds: 200));
          }

          // Wait for updates or timeout
          await completer.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Real-time updates too slow'),
          );

          stopwatch.stop();

          // Assert - Updates received efficiently
          expect(receivedUpdates.length, greaterThanOrEqualTo(5));
          expect(stopwatch.elapsedMilliseconds, lessThan(15000));

          await subscription.cancel();
        },
      );

      test('multiple concurrent listeners should perform well', () async {
        // Arrange
        const numListeners = 5;
        const testPatientIds = [
          'concurrent_1',
          'concurrent_2',
          'concurrent_3',
          'concurrent_4',
          'concurrent_5',
        ];
        this.testPatientIds.addAll(testPatientIds);

        final subscriptions = <StreamSubscription>[];
        final stopwatch = Stopwatch();

        // Act - Setup multiple concurrent listeners
        stopwatch.start();
        for (final patientId in testPatientIds) {
          final stream = enhancedService.listenToPatientVitals(
            patientId,
            limit: 3,
          );
          final subscription = stream.listen((_) {});
          subscriptions.add(subscription);
        }
        stopwatch.stop();

        // Assert - All listeners setup efficiently
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(realTimeListenerSetupMs * numListeners),
        );
        expect(subscriptions.length, numListeners);

        // Test concurrent updates
        stopwatch.reset();
        stopwatch.start();

        final futures = <Future>[];
        for (int i = 0; i < testPatientIds.length; i++) {
          final patientId = testPatientIds[i];
          final future = firestoreService.storePatientVitals(
            PatientVitalsFirestore(
              id: '',
              patientId: patientId,
              heartRate: 75.0 + i,
              bloodPressureSystolic: 120.0,
              bloodPressureDiastolic: 80.0,
              oxygenSaturation: 98.0,
              temperature: 98.6,
              respiratoryRate: 16.0,
              source: VitalsSource.device,
              accuracy: 0.95,
              timestamp: DateTime.now(),
              isValidated: true,
            ),
          );
          futures.add(future);
        }

        await Future.wait(futures);
        stopwatch.stop();

        // Assert - Concurrent updates completed efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));

        // Cleanup
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });
    });

    group('Large Dataset Performance Tests', () {
      test('should handle large hospital datasets efficiently', () async {
        // This test assumes a large dataset exists or creates one
        final stopwatch = Stopwatch();

        // Act & Assert - Query large dataset with pagination
        stopwatch.start();
        final page1 = await firestoreService.getHospitals(limit: 100);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));

        if (page1.length == 100) {
          // Test pagination performance
          stopwatch.reset();
          stopwatch.start();
          final page2 = await firestoreService.getHospitals(
            limit: 100,
            startAfter: page1.last.id,
          );
          stopwatch.stop();

          expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
          expect(page2, isA<List<HospitalFirestore>>());
        }
      });

      test('should handle complex queries on large datasets', () async {
        // Arrange
        final stopwatch = Stopwatch();

        // Act & Assert - Complex query with multiple filters
        stopwatch.start();
        final results = await enhancedService.queryHospitalsAdvanced(
          latitude: 40.7589,
          longitude: -73.9851,
          radiusKm: 100.0, // Large radius
          requiredSpecializations: ['emergency'],
          isActive: true,
          sortByDistance: true,
          limit: 50,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(results, isA<List<HospitalFirestore>>());

        // Act & Assert - Specialized hospital query
        stopwatch.reset();
        stopwatch.start();
        final specializedResults = await enhancedService
            .querySpecializedHospitals(
              requiredSpecializations: ['cardiology', 'neurology'],
              latitude: 40.7589,
              longitude: -73.9851,
              radiusKm: 50.0,
              minTraumaLevel: 1,
              requireAllSpecializations: false,
              limit: 30,
            );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(specializedResults, isA<List<HospitalFirestore>>());
      });

      test('should handle large patient data queries efficiently', () async {
        // Arrange - Create patient with large history
        const testPatientId = 'large_dataset_patient';
        testPatientIds.add(testPatientId);

        // Create large vitals dataset
        final largeVitalsSet = List.generate(
          100,
          (index) => PatientVitalsFirestore(
            id: '',
            patientId: testPatientId,
            heartRate: 60.0 + (index % 60),
            bloodPressureSystolic: 100.0 + (index % 80),
            bloodPressureDiastolic: 60.0 + (index % 40),
            oxygenSaturation: 90.0 + (index % 10),
            temperature: 97.0 + (index % 5),
            respiratoryRate: 10.0 + (index % 15),
            source: VitalsSource.device,
            accuracy: 0.8 + (index % 20) * 0.01,
            timestamp: DateTime.now().subtract(Duration(hours: index)),
            isValidated: true,
          ),
        );

        // Store in batches for better performance
        const batchSize = 20;
        for (int i = 0; i < largeVitalsSet.length; i += batchSize) {
          final batch = largeVitalsSet.skip(i).take(batchSize).toList();
          await enhancedService.batchStorePatientVitals(batch);
        }

        final stopwatch = Stopwatch();

        // Act & Assert - Query large patient dataset
        stopwatch.start();
        final recentVitals = await firestoreService.getPatientVitals(
          testPatientId,
          limit: 50,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(recentVitals.length, lessThanOrEqualTo(50));

        // Act & Assert - Query with date range
        stopwatch.reset();
        stopwatch.start();
        final dateRangeVitals = await firestoreService.getPatientVitalsInRange(
          testPatientId,
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now(),
          limit: 30,
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(dateRangeVitals, isA<List<PatientVitalsFirestore>>());
      });
    });

    group('Memory and Resource Performance Tests', () {
      test('should manage memory efficiently with large result sets', () async {
        // This test would ideally measure memory usage
        // For now, we'll test that large queries don't cause issues

        final stopwatch = Stopwatch();

        // Act - Multiple large queries in sequence
        stopwatch.start();
        for (int i = 0; i < 5; i++) {
          final hospitals = await firestoreService.getHospitals(limit: 50);
          expect(hospitals, isA<List<HospitalFirestore>>());

          // Small delay to allow garbage collection
          await Future.delayed(const Duration(milliseconds: 100));
        }
        stopwatch.stop();

        // Assert - All queries completed without memory issues
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(largeDatasetQueryMs * 5),
        );
      });

      test('should handle connection pooling efficiently', () async {
        // Test concurrent operations to verify connection management
        final stopwatch = Stopwatch();

        // Act - Concurrent operations
        stopwatch.start();
        final futures = <Future>[];

        for (int i = 0; i < 10; i++) {
          futures.add(firestoreService.getHospitals(limit: 10));
        }

        final results = await Future.wait(futures);
        stopwatch.stop();

        // Assert - All concurrent operations completed efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(results.length, 10);

        for (final result in results) {
          expect(result, isA<List<HospitalFirestore>>());
        }
      });
    });

    group('System Health Performance Tests', () {
      test('system health metrics should be calculated efficiently', () async {
        // Arrange
        final stopwatch = Stopwatch();

        // Act & Assert - System health metrics
        stopwatch.start();
        final healthMetrics = await enhancedService.getSystemHealthMetrics();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(queryTimeoutMs));
        expect(healthMetrics, isA<Map<String, dynamic>>());
        expect(healthMetrics.containsKey('totalHospitals'), true);
        expect(healthMetrics.containsKey('totalCapacityRecords'), true);
      });

      test('data integrity validation should be performant', () async {
        // Arrange
        final stopwatch = Stopwatch();

        // Act & Assert - Data integrity validation
        stopwatch.start();
        final validationResult = await enhancedService.validateDataIntegrity();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(largeDatasetQueryMs));
        expect(validationResult, isA<Map<String, dynamic>>());
        expect(validationResult.containsKey('isValid'), true);
      });

      test('data cleanup should be efficient', () async {
        // Arrange
        final stopwatch = Stopwatch();

        // Act & Assert - Data cleanup
        stopwatch.start();
        final cleanupResult = await enhancedService.cleanupOldData(
          vitalsRetentionDays: 30,
          triageRetentionDays: 90,
          capacityRetentionDays: 7,
        );
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(batchOperationTimeoutMs),
        );
        expect(cleanupResult, isA<Map<String, dynamic>>());
        expect(cleanupResult.containsKey('deletedVitals'), true);
      });
    });
  });
}
