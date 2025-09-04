import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:triage_bios_ai/shared/services/firestore_data_service.dart';
import 'package:triage_bios_ai/shared/services/firebase_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/triage_result_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_consent_firestore.dart';

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
])
import 'firestore_data_service_unit_test.mocks.dart';

void main() {
  group('FirestoreDataService Unit Tests', () {
    late FirestoreDataService service;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseService mockFirebaseService;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocument;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocumentSnapshot;
    late MockWriteBatch mockBatch;
    late MockTransaction mockTransaction;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockFirebaseService = MockFirebaseService();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocument = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockDocumentSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      mockTransaction = MockTransaction();

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

      service = FirestoreDataService();
    });

    group('Hospital Management', () {
      test('getHospitals should return list of hospitals', () async {
        // Arrange
        final hospitalData = {
          'id': 'hospital1',
          'name': 'Test Hospital',
          'address': {
            'street': '123 Test St',
            'city': 'Test City',
            'state': 'TS',
            'zipCode': '12345',
            'country': 'USA',
          },
          'location': {'latitude': 40.7589, 'longitude': -73.9851},
          'contact': {'phone': '(555) 123-4567', 'email': 'test@hospital.com'},
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

        // Act
        final result = await service.getHospitals();

        // Assert
        expect(result, isA<List<HospitalFirestore>>());
        expect(result.length, 1);
        expect(result.first.name, 'Test Hospital');
        verify(mockFirestore.collection('hospitals')).called(1);
      });

      test('getHospitalById should return hospital when found', () async {
        // Arrange
        final hospitalData = {
          'id': 'hospital1',
          'name': 'Test Hospital',
          'address': {
            'street': '123 Test St',
            'city': 'Test City',
            'state': 'TS',
            'zipCode': '12345',
            'country': 'USA',
          },
          'location': {'latitude': 40.7589, 'longitude': -73.9851},
          'contact': {'phone': '(555) 123-4567', 'email': 'test@hospital.com'},
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

        when(mockDocumentSnapshot.exists).thenReturn(true);
        when(mockDocumentSnapshot.data()).thenReturn(hospitalData);
        when(mockDocumentSnapshot.id).thenReturn('hospital1');

        // Act
        final result = await service.getHospitalById('hospital1');

        // Assert
        expect(result, isA<HospitalFirestore>());
        expect(result?.name, 'Test Hospital');
        verify(mockDocument.get()).called(1);
      });

      test('getHospitalById should return null when not found', () async {
        // Arrange
        when(mockDocumentSnapshot.exists).thenReturn(false);

        // Act
        final result = await service.getHospitalById('nonexistent');

        // Assert
        expect(result, isNull);
        verify(mockDocument.get()).called(1);
      });

      test('createHospital should return document ID', () async {
        // Arrange
        final hospital = HospitalFirestore(
          id: '',
          name: 'New Hospital',
          address: const HospitalAddress(
            street: '456 New St',
            city: 'New City',
            state: 'NS',
            zipCode: '67890',
            country: 'USA',
          ),
          location: const HospitalLocation(latitude: 41.0, longitude: -74.0),
          contact: const HospitalContact(
            phone: '(555) 987-6543',
            email: 'new@hospital.com',
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

        when(mockDocument.id).thenReturn('new_hospital_id');
        when(mockDocument.set(any)).thenAnswer((_) async => {});

        // Act
        final result = await service.createHospital(hospital);

        // Assert
        expect(result, 'new_hospital_id');
        verify(mockDocument.set(any)).called(1);
      });
    });

    group('Hospital Capacity Management', () {
      test('getHospitalCapacity should return capacity data', () async {
        // Arrange
        final capacityData = {
          'id': 'capacity1',
          'hospitalId': 'hospital1',
          'totalBeds': 100,
          'availableBeds': 25,
          'icuBeds': 10,
          'icuAvailable': 3,
          'emergencyBeds': 15,
          'emergencyAvailable': 5,
          'staffOnDuty': 80,
          'patientsInQueue': 5,
          'averageWaitTime': 30.0,
          'lastUpdated': Timestamp.now(),
          'dataSource': 'firestore',
          'isRealTime': false,
        };

        when(mockDocumentSnapshot.exists).thenReturn(true);
        when(mockDocumentSnapshot.data()).thenReturn(capacityData);
        when(mockDocumentSnapshot.id).thenReturn('capacity1');

        // Act
        final result = await service.getHospitalCapacity('hospital1');

        // Assert
        expect(result, isA<HospitalCapacityFirestore>());
        expect(result?.hospitalId, 'hospital1');
        expect(result?.totalBeds, 100);
      });

      test('updateHospitalCapacity should update capacity data', () async {
        // Arrange
        final capacity = HospitalCapacityFirestore(
          id: 'capacity1',
          hospitalId: 'hospital1',
          totalBeds: 100,
          availableBeds: 20,
          icuBeds: 10,
          icuAvailable: 2,
          emergencyBeds: 15,
          emergencyAvailable: 4,
          staffOnDuty: 75,
          patientsInQueue: 8,
          averageWaitTime: 35.0,
          lastUpdated: DateTime.now(),
          dataSource: DataSource.firestore,
          isRealTime: false,
        );

        when(mockDocument.set(any, any)).thenAnswer((_) async => {});

        // Act
        await service.updateHospitalCapacity(capacity);

        // Assert
        verify(mockDocument.set(any, SetOptions(merge: true))).called(1);
      });
    });

    group('Patient Vitals Management', () {
      test('storePatientVitals should store vitals data', () async {
        // Arrange
        final vitals = PatientVitalsFirestore(
          id: 'vitals1',
          patientId: 'patient1',
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

        when(mockDocument.set(any)).thenAnswer((_) async => {});

        // Act
        await service.storePatientVitals(vitals);

        // Assert
        verify(mockDocument.set(any)).called(1);
      });

      test('getPatientVitals should return vitals list', () async {
        // Arrange
        final vitalsData = {
          'id': 'vitals1',
          'patientId': 'patient1',
          'heartRate': 75.0,
          'bloodPressureSystolic': 120.0,
          'bloodPressureDiastolic': 80.0,
          'oxygenSaturation': 98.0,
          'temperature': 98.6,
          'respiratoryRate': 16.0,
          'source': 'manual',
          'accuracy': 0.95,
          'timestamp': Timestamp.now(),
          'isValidated': true,
        };

        final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDocSnapshot.data()).thenReturn(vitalsData);
        when(mockDocSnapshot.id).thenReturn('vitals1');
        when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

        // Act
        final result = await service.getPatientVitals('patient1');

        // Assert
        expect(result, isA<List<PatientVitalsFirestore>>());
        expect(result.length, 1);
        expect(result.first.patientId, 'patient1');
      });
    });

    group('Triage Results Management', () {
      test('storeTriageResult should store triage data', () async {
        // Arrange
        final triageResult = TriageResultFirestore(
          id: 'triage1',
          patientId: 'patient1',
          sessionId: 'session1',
          symptoms: 'Test symptoms',
          severityScore: 5.0,
          urgencyLevel: UrgencyLevel.standard,
          aiReasoning: 'Test AI reasoning',
          recommendedActions: const ['Action 1', 'Action 2'],
          vitalsContribution: 1.5,
          confidence: 0.85,
          createdAt: DateTime.now(),
          geminiModelVersion: 'gemini-1.5-flash',
        );

        when(mockDocument.set(any)).thenAnswer((_) async => {});

        // Act
        await service.storeTriageResult(triageResult);

        // Assert
        verify(mockDocument.set(any)).called(1);
      });

      test('getPatientHistory should return triage results', () async {
        // Arrange
        final triageData = {
          'id': 'triage1',
          'patientId': 'patient1',
          'sessionId': 'session1',
          'symptoms': 'Test symptoms',
          'severityScore': 5.0,
          'urgencyLevel': 'STANDARD',
          'aiReasoning': 'Test AI reasoning',
          'recommendedActions': ['Action 1', 'Action 2'],
          'vitalsContribution': 1.5,
          'confidence': 0.85,
          'createdAt': Timestamp.now(),
          'geminiModelVersion': 'gemini-1.5-flash',
        };

        final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDocSnapshot.data()).thenReturn(triageData);
        when(mockDocSnapshot.id).thenReturn('triage1');
        when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

        // Act
        final result = await service.getPatientHistory('patient1');

        // Assert
        expect(result, isA<List<TriageResultFirestore>>());
        expect(result.length, 1);
        expect(result.first.patientId, 'patient1');
      });
    });

    group('Patient Consent Management', () {
      test('storePatientConsent should store consent data', () async {
        // Arrange
        final consent = PatientConsentFirestore(
          id: 'consent1',
          patientId: 'patient1',
          providerId: 'provider1',
          consentType: ConsentType.treatment,
          dataScopes: const ['vitals', 'triage_results'],
          grantedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 365)),
          isActive: true,
          blockchainTxId: 'tx123',
          ipAddress: '192.168.1.100',
          consentDetails: const {'reason': 'Emergency treatment'},
        );

        when(mockDocument.set(any)).thenAnswer((_) async => {});

        // Act
        await service.storePatientConsent(consent);

        // Assert
        verify(mockDocument.set(any)).called(1);
      });

      test('getActiveConsents should return active consents', () async {
        // Arrange
        final consentData = {
          'id': 'consent1',
          'patientId': 'patient1',
          'providerId': 'provider1',
          'consentType': 'treatment',
          'dataScopes': ['vitals', 'triage_results'],
          'grantedAt': Timestamp.now(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365)),
          ),
          'isActive': true,
          'blockchainTxId': 'tx123',
          'ipAddress': '192.168.1.100',
          'consentDetails': {'reason': 'Emergency treatment'},
        };

        final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDocSnapshot.data()).thenReturn(consentData);
        when(mockDocSnapshot.id).thenReturn('consent1');
        when(mockQuerySnapshot.docs).thenReturn([mockDocSnapshot]);

        // Act
        final result = await service.getActiveConsents('patient1');

        // Assert
        expect(result, isA<List<PatientConsentFirestore>>());
        expect(result.length, 1);
        expect(result.first.patientId, 'patient1');
      });
    });

    group('Error Handling', () {
      test('should handle Firestore exceptions gracefully', () async {
        // Arrange
        when(mockDocument.get()).thenThrow(Exception('Firestore error'));

        // Act & Assert
        expect(() => service.getHospitalById('hospital1'), throwsException);
      });

      test('should handle network timeouts', () async {
        // Arrange
        when(mockQuery.get()).thenThrow(Exception('Network timeout'));

        // Act & Assert
        expect(() => service.getHospitals(), throwsException);
      });
    });

    group('Batch Operations', () {
      test('should create and execute batch operations', () async {
        // Arrange
        when(mockBatch.commit()).thenAnswer((_) async => []);

        // Act
        final batch = service.createBatch();
        await service.executeBatch(batch);

        // Assert
        verify(mockFirestore.batch()).called(1);
        verify(mockBatch.commit()).called(1);
      });
    });
  });
}
