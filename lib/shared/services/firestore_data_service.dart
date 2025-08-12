import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';

class FirestoreDataService {
  static final FirestoreDataService _instance =
      FirestoreDataService._internal();
  factory FirestoreDataService() => _instance;
  FirestoreDataService._internal();

  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // Collection names
  static const String _vitalsCollection = 'patient_vitals';
  static const String _triageResultsCollection = 'triage_results';
  static const String _hospitalCapacityCollection = 'hospital_capacity';
  static const String _deviceDataCollection = 'device_data';

  /// Store patient vitals in Firestore
  Future<void> storePatientVitals(
    String patientId,
    PatientVitals vitals,
  ) async {
    try {
      await _firestore
          .collection(_vitalsCollection)
          .doc('${patientId}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
            'patientId': patientId,
            'timestamp': FieldValue.serverTimestamp(),
            'heartRate': vitals.heartRate,
            'bloodPressureSystolic': vitals.bloodPressureSystolic,
            'bloodPressureDiastolic': vitals.bloodPressureDiastolic,
            'oxygenSaturation': vitals.oxygenSaturation,
            'temperature': vitals.temperature,
            'respiratoryRate': vitals.respiratoryRate,
            'deviceId': vitals.deviceId,
            'source': vitals.source,
            'accuracy': vitals.accuracy,
          });

      _logger.i('Patient vitals stored in Firestore for patient: $patientId');
    } catch (e) {
      _logger.e('Failed to store patient vitals in Firestore: $e');
      rethrow;
    }
  }

  /// Get patient vitals from Firestore
  Future<List<PatientVitals>> getPatientVitals(
    String patientId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_vitalsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PatientVitals(
          heartRate: data['heartRate']?.toDouble(),
          bloodPressureSystolic: data['bloodPressureSystolic']?.toDouble(),
          bloodPressureDiastolic: data['bloodPressureDiastolic']?.toDouble(),
          oxygenSaturation: data['oxygenSaturation']?.toDouble(),
          temperature: data['temperature']?.toDouble(),
          respiratoryRate: data['respiratoryRate']?.toDouble(),
          deviceId: data['deviceId'],
          source: data['source'] ?? 'unknown',
          accuracy: data['accuracy']?.toDouble() ?? 0.95,
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.e('Failed to get patient vitals from Firestore: $e');
      return [];
    }
  }

  /// Store triage result in Firestore
  Future<void> storeTriageResult(
    String patientId,
    Map<String, dynamic> triageResult,
  ) async {
    try {
      await _firestore
          .collection(_triageResultsCollection)
          .doc('${patientId}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
            'patientId': patientId,
            'timestamp': FieldValue.serverTimestamp(),
            'severityScore': triageResult['severityScore'],
            'urgencyLevel': triageResult['urgencyLevel'],
            'symptoms': triageResult['symptoms'],
            'aiReasoning': triageResult['aiReasoning'],
            'recommendedActions': triageResult['recommendedActions'],
            'vitalsContribution': triageResult['vitalsContribution'],
            'confidence': triageResult['confidence'],
          });

      _logger.i('Triage result stored in Firestore for patient: $patientId');
    } catch (e) {
      _logger.e('Failed to store triage result in Firestore: $e');
      rethrow;
    }
  }

  /// Get triage results from Firestore
  Future<List<Map<String, dynamic>>> getTriageResults(
    String patientId, {
    int limit = 5,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_triageResultsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('Failed to get triage results from Firestore: $e');
      return [];
    }
  }

  /// Store hospital capacity data
  Future<void> storeHospitalCapacity(
    String hospitalId,
    Map<String, dynamic> capacityData,
  ) async {
    try {
      await _firestore
          .collection(_hospitalCapacityCollection)
          .doc(hospitalId)
          .set({
            'hospitalId': hospitalId,
            'lastUpdated': FieldValue.serverTimestamp(),
            'totalBeds': capacityData['totalBeds'],
            'availableBeds': capacityData['availableBeds'],
            'icuBeds': capacityData['icuBeds'],
            'emergencyBeds': capacityData['emergencyBeds'],
            'staffCount': capacityData['staffCount'],
            'currentLoad': capacityData['currentLoad'],
            'estimatedWaitTime': capacityData['estimatedWaitTime'],
          }, SetOptions(merge: true));

      _logger.i(
        'Hospital capacity updated in Firestore for hospital: $hospitalId',
      );
    } catch (e) {
      _logger.e('Failed to store hospital capacity in Firestore: $e');
      rethrow;
    }
  }

  /// Get hospital capacity data
  Future<Map<String, dynamic>?> getHospitalCapacity(String hospitalId) async {
    try {
      final doc = await _firestore
          .collection(_hospitalCapacityCollection)
          .doc(hospitalId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      _logger.e('Failed to get hospital capacity from Firestore: $e');
      return null;
    }
  }

  /// Get all hospitals capacity data
  Future<List<Map<String, dynamic>>> getAllHospitalCapacities() async {
    try {
      final querySnapshot = await _firestore
          .collection(_hospitalCapacityCollection)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('Failed to get all hospital capacities from Firestore: $e');
      return [];
    }
  }

  /// Store device data
  Future<void> storeDeviceData(
    String deviceId,
    Map<String, dynamic> deviceData,
  ) async {
    try {
      await _firestore
          .collection(_deviceDataCollection)
          .doc('${deviceId}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
            'deviceId': deviceId,
            'timestamp': FieldValue.serverTimestamp(),
            'deviceType': deviceData['deviceType'],
            'batteryLevel': deviceData['batteryLevel'],
            'connectionStatus': deviceData['connectionStatus'],
            'lastSync': deviceData['lastSync'],
            'dataQuality': deviceData['dataQuality'],
            'userId': deviceData['userId'],
          });

      _logger.i('Device data stored in Firestore for device: $deviceId');
    } catch (e) {
      _logger.e('Failed to store device data in Firestore: $e');
      rethrow;
    }
  }

  /// Get device data
  Future<List<Map<String, dynamic>>> getDeviceData(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_deviceDataCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('Failed to get device data from Firestore: $e');
      return [];
    }
  }

  /// Listen to real-time hospital capacity updates
  Stream<List<Map<String, dynamic>>> listenToHospitalCapacities() {
    return _firestore
        .collection(_hospitalCapacityCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Listen to real-time patient vitals
  Stream<List<PatientVitals>> listenToPatientVitals(String patientId) {
    return _firestore
        .collection(_vitalsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return PatientVitals(
              heartRate: data['heartRate']?.toDouble(),
              bloodPressureSystolic: data['bloodPressureSystolic']?.toDouble(),
              bloodPressureDiastolic: data['bloodPressureDiastolic']
                  ?.toDouble(),
              oxygenSaturation: data['oxygenSaturation']?.toDouble(),
              temperature: data['temperature']?.toDouble(),
              respiratoryRate: data['respiratoryRate']?.toDouble(),
              deviceId: data['deviceId'],
              source: data['source'] ?? 'unknown',
              accuracy: data['accuracy']?.toDouble() ?? 0.95,
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList(),
        );
  }
}
