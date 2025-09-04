import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:triage_bios_ai/shared/services/enhanced_firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/firebase_service.dart';
import 'package:triage_bios_ai/shared/services/offline_support_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';

// Generate mocks
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
  WriteBatch,
  Transaction,
  FirebaseService,
  OfflineSupportService,
])
import 'enhanced_firestore_data_service_unit_test.mocks.dart';

void main() {
  group('EnhancedFirestoreDataService Unit Tests', () {
    late EnhancedFirestoreDataService service;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseService mockFirebaseService;
    late MockOfflineSupportService mockOfflineService;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocument;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocumentSnapshot;
    late MockWriteBatch mockBatch;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockFirebaseService = MockFirebaseService();
      mockOfflineService = MockOfflineSupportService();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocument = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockDocumentSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();

      // Setup basic mocks
      when(mockFirebaseService.firestore).thenReturn(mockFirestore);
      when(mockFirestore.collection(any)).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDocument);
      when(
        mockCollection.where(any, isEqualTo: anyNamed('isEqualTo')),
      ).thenReturn(mockQuery);
      when(
        mockQuery.where(any, isEqualTo: anyNamed('isEqualTo')),
      ).thenReturn(mockQuery);
      when(mockQuery.limit(any)).thenReturn(mockQuery);
      when(mockQuery.orderBy(any)).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockDocument.get()).thenAnswer((_) async => mockDocumentSnapshot);
      when(mockFirestore.batch()).thenReturn(mockBatch);

      service = EnhancedFirestoreDataService();
    });

    group('Enhanced Hospital Management with Offline Support', () {
      test(
        'getHospitals should check cache first when not forcing refresh',
        () async {
          // Arrange
          final cachedHospitals = [
            HospitalFirestore(
              id: 'cached_hospital',
              name: 'Cached Hospital',
              address: const HospitalAddress(
                street: '123 Cache St',
                city: 'Cache City',
                state: 'CC',
                zipCode: '12345',
                country: 'USA',
              ),
              location: const HospitalLocation(
                latitude: 40.7589,
                longitude: -73.9851,
              ),
              contact: const HospitalContact(
                phone: '(555) 123-4567',
                email: 'cache@hospital.com',
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
            ),
          ];

          when(
            mockOfflineService.getCachedData<List<HospitalFirestore>>(any),
          ).thenReturn(cachedHospitals);

          // Act
          final result = await service.getHospitals(forceRefresh: false);

          // Assert
          expect(result, isA<List<HospitalFirestore>>());
          expect(result.length, 1);
          expect(result.first.name, 'Cached Hospital');
          verify(
            mockOfflineService.getCachedData<List<HospitalFirestore>>(any),
          ).called(1);
        },
      );

      test(
        'getHospitals should fetch from Firestore when cache miss',
        () async {
          // Arrange
          when(
            mockOfflineService.getCachedData<List<HospitalFirestore>>(any),
          ).thenReturn(null);

          final hospitalData = {
            'id': 'hospital1',
            'name': 'Fresh Hospital',
            'address': {
              'street': '456 Fresh St',
              'city': 'Fresh City',
              'state': 'FC',
              'zipCode': '67890',
              'country': 'USA',
            },
            'location': {'latitude': 41.0, 'longitude': -74.0},
            'contact': {
              'phone': '(555) 987-6543',
              'email': 'fresh@hospital.com',
            },
            'traumaLevel': 2,
            'specializations': ['emergency', 'cardiology'],
            'certifications': ['Joint Commission'],
            'operatingHours': {
              'emergency': '24/7',
              'general': 'Mon-Sun 6:00 AM - 10:00 PM',
            },
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'isActive': true,
          };

          final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
          when(mockDocSnapshot.data()).thenReturn(hospitalData);
          when(mockDocSnapshot.id).thenReturn('hospital1');
          when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

          when(
            mockOfflineService.cacheData(any, any, any),
          ).thenAnswer((_) async => {});

          // Act
          final result = await service.getHospitals(forceRefresh: false);

          // Assert
          expect(result, isA<List<HospitalFirestore>>());
          expect(result.length, 1);
          expect(result.first.name, 'Fresh Hospital');
          verify(mockOfflineService.cacheData(any, any, any)).called(1);
        },
      );

      test('getHospitals should force refresh when requested', () async {
        // Arrange
        final hospitalData = {
          'id': 'hospital1',
          'name': 'Force Refresh Hospital',
          'address': {
            'street': '789 Refresh St',
            'city': 'Refresh City',
            'state': 'RC',
            'zipCode': '11111',
            'country': 'USA',
          },
          'location': {'latitude': 42.0, 'longitude': -75.0},
          'contact': {
            'phone': '(555) 111-2222',
            'email': 'refresh@hospital.com',
          },
          'traumaLevel': 3,
          'specializations': ['trauma'],
          'certifications': ['Joint Commission'],
          'operatingHours': {
            'emergency': '24/7',
            'general': 'Mon-Sun 6:00 AM - 10:00 PM',
          },
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'isActive': true,
        };

        final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDocSnapshot.data()).thenReturn(hospitalData);
        when(mockDocSnapshot.id).thenReturn('hospital1');
        when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

        when(
          mockOfflineService.cacheData(any, any, any),
        ).thenAnswer((_) async => {});

        // Act
        final result = await service.getHospitals(forceRefresh: true);

        // Assert
        expect(result, isA<List<HospitalFirestore>>());
        expect(result.length, 1);
        expect(result.first.name, 'Force Refresh Hospital');
        verifyNever(
          mockOfflineService.getCachedData<List<HospitalFirestore>>(any),
        );
        verify(mockOfflineService.cacheData(any, any, any)).called(1);
      });
    });

    group('Real-time Listeners', () {
      test('listenToHospitalCapacityUpdates should return stream', () {
        // Arrange
        final mockStream = Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
        when(mockQuery.snapshots()).thenAnswer((_) => mockStream);

        // Act
        final result = service.listenToHospitalCapacityUpdates('hospital1');

        // Assert
        expect(result, isA<Stream<List<HospitalCapacityFirestore>>>());
      });

      test('listenToPatientVitals should return stream with limit', () {
        // Arrange
        final mockStream = Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
        when(mockQuery.snapshots()).thenAnswer((_) => mockStream);

        // Act
        final result = service.listenToPatientVitals('patient1', limit: 10);

        // Assert
        expect(result, isA<Stream<List<PatientVitalsFirestore>>>());
        verify(mockQuery.limit(10)).called(1);
      });

      test('listenToCriticalVitals should filter by severity score', () {
        // Arrange
        final mockStream = Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
        when(mockQuery.snapshots()).thenAnswer((_) => mockStream);
        when(
          mockQuery.where(
            any,
            isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo'),
          ),
        ).thenReturn(mockQuery);

        // Act
        final result = service.listenToCriticalVitals(minSeverityScore: 7.0);

        // Assert
        expect(result, isA<Stream<List<PatientVitalsFirestore>>>());
        verify(
          mockQuery.where('vitalsSeverityScore', isGreaterThanOrEqualTo: 7.0),
        ).called(1);
      });
    });

    group('Batch Operations', () {
      test('batchCreateHospitals should create multiple hospitals', () async {
        // Arrange
        final hospitals = [
          HospitalFirestore(
            id: '',
            name: 'Batch Hospital 1',
            address: const HospitalAddress(
              street: '111 Batch St',
              city: 'Batch City',
              state: 'BC',
              zipCode: '11111',
              country: 'USA',
            ),
            location: const HospitalLocation(latitude: 40.0, longitude: -73.0),
            contact: const HospitalContact(
              phone: '(555) 111-1111',
              email: 'batch1@hospital.com',
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
          ),
          HospitalFirestore(
            id: '',
            name: 'Batch Hospital 2',
            address: const HospitalAddress(
              street: '222 Batch St',
              city: 'Batch City',
              state: 'BC',
              zipCode: '22222',
              country: 'USA',
            ),
            location: const HospitalLocation(latitude: 41.0, longitude: -74.0),
            contact: const HospitalContact(
              phone: '(555) 222-2222',
              email: 'batch2@hospital.com',
            ),
            traumaLevel: 2,
            specializations: const ['emergency', 'cardiology'],
            certifications: const ['Joint Commission'],
            operatingHours: const HospitalOperatingHours(
              emergency: '24/7',
              general: 'Mon-Sun 6:00 AM - 10:00 PM',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ),
        ];

        when(mockBatch.set(any, any)).thenReturn(mockBatch);
        when(mockBatch.commit()).thenAnswer((_) async => []);

        // Act
        await service.batchCreateHospitals(hospitals);

        // Assert
        verify(mockBatch.set(any, any)).called(2);
        verify(mockBatch.commit()).called(1);
      });

      test('batchUpdateCapacities should update multiple capacities', () async {
        // Arrange
        final capacities = [
          HospitalCapacityFirestore(
            id: 'capacity1',
            hospitalId: 'hospital1',
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
          ),
          HospitalCapacityFirestore(
            id: 'capacity2',
            hospitalId: 'hospital2',
            totalBeds: 150,
            availableBeds: 40,
            icuBeds: 15,
            icuAvailable: 5,
            emergencyBeds: 20,
            emergencyAvailable: 8,
            staffOnDuty: 120,
            patientsInQueue: 3,
            averageWaitTime: 25.0,
            lastUpdated: DateTime.now(),
            dataSource: DataSource.firestore,
            isRealTime: false,
          ),
        ];

        when(mockBatch.set(any, any, any)).thenReturn(mockBatch);
        when(mockBatch.commit()).thenAnswer((_) async => []);

        // Act
        await service.batchUpdateCapacities(capacities);

        // Assert
        verify(mockBatch.set(any, any, any)).called(2);
        verify(mockBatch.commit()).called(1);
      });
    });

    group('Advanced Queries', () {
      test('queryHospitalsAdvanced should handle complex filtering', () async {
        // Arrange
        final hospitalData = {
          'id': 'hospital1',
          'name': 'Advanced Query Hospital',
          'address': {
            'street': '999 Advanced St',
            'city': 'Advanced City',
            'state': 'AC',
            'zipCode': '99999',
            'country': 'USA',
          },
          'location': {'latitude': 40.7589, 'longitude': -73.9851},
          'contact': {
            'phone': '(555) 999-9999',
            'email': 'advanced@hospital.com',
          },
          'traumaLevel': 1,
          'specializations': ['emergency', 'cardiology'],
          'certifications': ['Joint Commission'],
          'operatingHours': {
            'emergency': '24/7',
            'general': 'Mon-Sun 6:00 AM - 10:00 PM',
          },
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'isActive': true,
        };

        final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDocSnapshot.data()).thenReturn(hospitalData);
        when(mockDocSnapshot.id).thenReturn('hospital1');
        when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

        when(
          mockQuery.where(any, arrayContainsAny: anyNamed('arrayContainsAny')),
        ).thenReturn(mockQuery);
        when(
          mockQuery.where(
            any,
            isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo'),
          ),
        ).thenReturn(mockQuery);
        when(
          mockQuery.where(
            any,
            isLessThanOrEqualTo: anyNamed('isLessThanOrEqualTo'),
          ),
        ).thenReturn(mockQuery);

        // Act
        final result = await service.queryHospitalsAdvanced(
          latitude: 40.7589,
          longitude: -73.9851,
          radiusKm: 10.0,
          requiredSpecializations: ['emergency', 'cardiology'],
          minTraumaLevel: 1,
          maxTraumaLevel: 3,
          isActive: true,
          limit: 10,
        );

        // Assert
        expect(result, isA<List<HospitalFirestore>>());
        expect(result.length, 1);
        expect(result.first.name, 'Advanced Query Hospital');
      });

      test(
        'queryHospitalsByAvailability should filter by urgency level',
        () async {
          // Arrange
          final hospitalData = {
            'id': 'hospital1',
            'name': 'Available Hospital',
            'address': {
              'street': '888 Available St',
              'city': 'Available City',
              'state': 'AV',
              'zipCode': '88888',
              'country': 'USA',
            },
            'location': {'latitude': 40.7589, 'longitude': -73.9851},
            'contact': {
              'phone': '(555) 888-8888',
              'email': 'available@hospital.com',
            },
            'traumaLevel': 1,
            'specializations': ['emergency'],
            'certifications': ['Joint Commission'],
            'operatingHours': {
              'emergency': '24/7',
              'general': 'Mon-Sun 6:00 AM - 10:00 PM',
            },
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'isActive': true,
          };

          final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
          when(mockDocSnapshot.data()).thenReturn(hospitalData);
          when(mockDocSnapshot.id).thenReturn('hospital1');
          when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

          // Act
          final result = await service.queryHospitalsByAvailability(
            urgencyLevel: UrgencyLevel.critical,
            latitude: 40.7589,
            longitude: -73.9851,
            radiusKm: 5.0,
            limit: 5,
          );

          // Assert
          expect(result, isA<List<HospitalFirestore>>());
          expect(result.length, 1);
          expect(result.first.name, 'Available Hospital');
        },
      );
    });

    group('System Health and Analytics', () {
      test('getSystemHealthMetrics should return health data', () async {
        // Arrange
        when(mockQuerySnapshot.size).thenReturn(10);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await service.getSystemHealthMetrics();

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('totalHospitals'), true);
        expect(result.containsKey('totalCapacityRecords'), true);
        expect(result.containsKey('totalVitalsRecords'), true);
        expect(result.containsKey('totalTriageResults'), true);
      });

      test('validateDataIntegrity should check data consistency', () async {
        // Arrange
        when(mockQuerySnapshot.size).thenReturn(5);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await service.validateDataIntegrity();

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('isValid'), true);
        expect(result.containsKey('errors'), true);
        expect(result.containsKey('warnings'), true);
      });

      test('cleanupOldData should remove expired records', () async {
        // Arrange
        when(mockBatch.delete(any)).thenReturn(mockBatch);
        when(mockBatch.commit()).thenAnswer((_) async => []);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await service.cleanupOldData(
          vitalsRetentionDays: 60,
          triageRetentionDays: 180,
          capacityRetentionDays: 15,
        );

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('deletedVitals'), true);
        expect(result.containsKey('deletedTriageResults'), true);
        expect(result.containsKey('deletedCapacityRecords'), true);
      });
    });

    group('Error Handling and Resilience', () {
      test('should handle offline scenarios gracefully', () async {
        // Arrange
        when(mockQuery.get()).thenThrow(Exception('Network unavailable'));
        when(
          mockOfflineService.getCachedData<List<HospitalFirestore>>(any),
        ).thenReturn([]);

        // Act
        final result = await service.getHospitals();

        // Assert
        expect(result, isA<List<HospitalFirestore>>());
        expect(result.isEmpty, true);
        verify(
          mockOfflineService.getCachedData<List<HospitalFirestore>>(any),
        ).called(1);
      });

      test('should retry failed operations', () async {
        // Arrange
        when(
          mockDocument.set(any),
        ).thenThrow(Exception('Temporary failure')).thenAnswer((_) async => {});

        final hospital = HospitalFirestore(
          id: '',
          name: 'Retry Hospital',
          address: const HospitalAddress(
            street: '777 Retry St',
            city: 'Retry City',
            state: 'RC',
            zipCode: '77777',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 40.0, longitude: -73.0),
          contact: const HospitalContact(
            phone: '(555) 777-7777',
            email: 'retry@hospital.com',
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

        // Act & Assert
        expect(
          () => service.createHospitalWithRetry(hospital, maxRetries: 2),
          returnsNormally,
        );
      });
    });
  });
}
