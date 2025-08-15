import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/triage_result_firestore.dart';
import '../models/firestore/patient_consent_firestore.dart';
import 'dart:math' as math;

class FirestoreDataService {
  static final FirestoreDataService _instance =
      FirestoreDataService._internal();
  factory FirestoreDataService() => _instance;
  FirestoreDataService._internal();

  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // ============================================================================
  // HOSPITAL MANAGEMENT
  // ============================================================================

  /// Get all hospitals with optional filtering
  Future<List<HospitalFirestore>> getHospitals({
    List<String>? specializations,
    int? minTraumaLevel,
    bool? isActive,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection(_hospitalsCollection);

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      if (minTraumaLevel != null) {
        query = query.where(
          'traumaLevel',
          isGreaterThanOrEqualTo: minTraumaLevel,
        );
      }

      if (specializations != null && specializations.isNotEmpty) {
        query = query.where(
          'specializations',
          arrayContainsAny: specializations,
        );
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => HospitalFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get hospitals from Firestore: $e');
      return [];
    }
  }

  /// Get hospitals within a radius of a location
  Future<List<HospitalFirestore>> getHospitalsInRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
    List<String>? specializations,
    int? minTraumaLevel,
    int limit = 20,
  }) async {
    try {
      // Calculate bounding box for initial filtering
      final latRange = radiusKm / 111.0; // Rough conversion: 1 degree ≈ 111 km
      final lngRange = radiusKm / (111.0 * math.cos(latitude * math.pi / 180));

      Query query = _firestore
          .collection(_hospitalsCollection)
          .where('isActive', isEqualTo: true)
          .where('location.latitude', isGreaterThan: latitude - latRange)
          .where('location.latitude', isLessThan: latitude + latRange);

      if (minTraumaLevel != null) {
        query = query.where(
          'traumaLevel',
          isGreaterThanOrEqualTo: minTraumaLevel,
        );
      }

      if (specializations != null && specializations.isNotEmpty) {
        query = query.where(
          'specializations',
          arrayContainsAny: specializations,
        );
      }

      final querySnapshot = await query.get();
      final hospitals = querySnapshot.docs
          .map((doc) => HospitalFirestore.fromFirestore(doc))
          .toList();

      // Filter by actual distance and sort by proximity
      final hospitalsInRadius = <HospitalFirestore>[];
      for (final hospital in hospitals) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          hospital.location.latitude,
          hospital.location.longitude,
        );
        if (distance <= radiusKm) {
          hospitalsInRadius.add(hospital);
        }
      }

      // Sort by distance
      hospitalsInRadius.sort((a, b) {
        final distanceA = _calculateDistance(
          latitude,
          longitude,
          a.location.latitude,
          a.location.longitude,
        );
        final distanceB = _calculateDistance(
          latitude,
          longitude,
          b.location.latitude,
          b.location.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      return hospitalsInRadius.take(limit).toList();
    } catch (e) {
      _logger.e('Failed to get hospitals in radius from Firestore: $e');
      return [];
    }
  }

  /// Get hospital by ID
  Future<HospitalFirestore?> getHospitalById(String hospitalId) async {
    try {
      final doc = await _firestore
          .collection(_hospitalsCollection)
          .doc(hospitalId)
          .get();

      return doc.exists ? HospitalFirestore.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get hospital by ID from Firestore: $e');
      return null;
    }
  }

  /// Create a new hospital
  Future<String> createHospital(HospitalFirestore hospital) async {
    try {
      final docRef = await _firestore
          .collection(_hospitalsCollection)
          .add(hospital.toFirestore());

      _logger.i('Hospital created in Firestore: ${hospital.name}');
      return docRef.id;
    } catch (e) {
      _logger.e('Failed to create hospital in Firestore: $e');
      rethrow;
    }
  }

  /// Update hospital information
  Future<void> updateHospital(
    String hospitalId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_hospitalsCollection)
          .doc(hospitalId)
          .update(updates);

      _logger.i('Hospital updated in Firestore: $hospitalId');
    } catch (e) {
      _logger.e('Failed to update hospital in Firestore: $e');
      rethrow;
    }
  }

  // ============================================================================
  // HOSPITAL CAPACITY MANAGEMENT
  // ============================================================================

  /// Get hospital capacity by hospital ID
  Future<HospitalCapacityFirestore?> getHospitalCapacity(
    String hospitalId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_hospitalCapacityCollection)
          .where('hospitalId', isEqualTo: hospitalId)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return HospitalCapacityFirestore.fromFirestore(
          querySnapshot.docs.first,
        );
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get hospital capacity from Firestore: $e');
      return null;
    }
  }

  /// Get capacities for multiple hospitals
  Future<List<HospitalCapacityFirestore>> getHospitalCapacities(
    List<String> hospitalIds,
  ) async {
    try {
      if (hospitalIds.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection(_hospitalCapacityCollection)
          .where('hospitalId', whereIn: hospitalIds)
          .get();

      // Group by hospitalId and get the most recent for each
      final capacityMap = <String, HospitalCapacityFirestore>{};
      for (final doc in querySnapshot.docs) {
        final capacity = HospitalCapacityFirestore.fromFirestore(doc);
        final existing = capacityMap[capacity.hospitalId];
        if (existing == null ||
            capacity.lastUpdated.isAfter(existing.lastUpdated)) {
          capacityMap[capacity.hospitalId] = capacity;
        }
      }

      return capacityMap.values.toList();
    } catch (e) {
      _logger.e('Failed to get hospital capacities from Firestore: $e');
      return [];
    }
  }

  /// Update hospital capacity
  Future<void> updateHospitalCapacity(
    HospitalCapacityFirestore capacity,
  ) async {
    try {
      await _firestore
          .collection(_hospitalCapacityCollection)
          .add(capacity.toFirestore());

      _logger.i(
        'Hospital capacity updated in Firestore: ${capacity.hospitalId}',
      );
    } catch (e) {
      _logger.e('Failed to update hospital capacity in Firestore: $e');
      rethrow;
    }
  }

  /// Get hospitals with available capacity
  Future<List<HospitalCapacityFirestore>> getAvailableCapacities({
    int minAvailableBeds = 1,
    int minEmergencyBeds = 0,
    int minIcuBeds = 0,
    double maxOccupancyRate = 0.95,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection(_hospitalCapacityCollection)
          .where('availableBeds', isGreaterThanOrEqualTo: minAvailableBeds)
          .where('occupancyRate', isLessThan: maxOccupancyRate);

      if (minEmergencyBeds > 0) {
        query = query.where(
          'emergencyAvailable',
          isGreaterThanOrEqualTo: minEmergencyBeds,
        );
      }

      query = query.orderBy('occupancyRate', descending: false).limit(limit);

      final querySnapshot = await query.get();
      final capacities = querySnapshot.docs
          .map((doc) => HospitalCapacityFirestore.fromFirestore(doc))
          .toList();

      // Filter by ICU beds if specified (can't use in compound query)
      if (minIcuBeds > 0) {
        return capacities.where((c) => c.icuAvailable >= minIcuBeds).toList();
      }

      return capacities;
    } catch (e) {
      _logger.e('Failed to get available capacities from Firestore: $e');
      return [];
    }
  }

  // ============================================================================
  // REAL-TIME LISTENERS
  // ============================================================================

  /// Listen to hospital capacity updates
  Stream<List<HospitalCapacityFirestore>> listenToHospitalCapacities(
    List<String> hospitalIds,
  ) {
    if (hospitalIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_hospitalCapacityCollection)
        .where('hospitalId', whereIn: hospitalIds)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
          // Group by hospitalId and get the most recent for each
          final capacityMap = <String, HospitalCapacityFirestore>{};
          for (final doc in snapshot.docs) {
            final capacity = HospitalCapacityFirestore.fromFirestore(doc);
            final existing = capacityMap[capacity.hospitalId];
            if (existing == null ||
                capacity.lastUpdated.isAfter(existing.lastUpdated)) {
              capacityMap[capacity.hospitalId] = capacity;
            }
          }
          return capacityMap.values.toList();
        });
  }

  /// Listen to all hospital capacity updates
  Stream<List<HospitalCapacityFirestore>> listenToAllCapacityUpdates() {
    return _firestore
        .collection(_hospitalCapacityCollection)
        .orderBy('lastUpdated', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HospitalCapacityFirestore.fromFirestore(doc))
              .toList(),
        );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Collection names
  static const String _hospitalsCollection = 'hospitals';
  static const String _hospitalCapacityCollection = 'hospital_capacity';
  static const String _vitalsCollection = 'patient_vitals';
  static const String _triageResultsCollection = 'triage_results';
  static const String _consentsCollection = 'patient_consents';
  static const String _deviceDataCollection = 'device_data';
  static const String _auditLogsCollection = 'audit_logs';

  // ============================================================================
  // PATIENT VITALS MANAGEMENT
  // ============================================================================

  /// Store patient vitals in Firestore
  Future<String> storePatientVitals(PatientVitalsFirestore vitals) async {
    try {
      final docRef = await _firestore
          .collection(_vitalsCollection)
          .add(vitals.toFirestore());

      _logger.i(
        'Patient vitals stored in Firestore for patient: ${vitals.patientId}',
      );
      return docRef.id;
    } catch (e) {
      _logger.e('Failed to store patient vitals in Firestore: $e');
      rethrow;
    }
  }

  /// Store patient vitals from legacy PatientVitals entity
  Future<void> storePatientVitalsLegacy(
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
            'isValidated': false,
            'hasAbnormalVitals': false,
            'vitalsSeverityScore': 0.0,
          });

      _logger.i('Patient vitals stored in Firestore for patient: $patientId');
    } catch (e) {
      _logger.e('Failed to store patient vitals in Firestore: $e');
      rethrow;
    }
  }

  /// Get patient vitals from Firestore
  Future<List<PatientVitalsFirestore>> getPatientVitals(
    String patientId, {
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasAbnormalVitals,
  }) async {
    try {
      Query query = _firestore
          .collection(_vitalsCollection)
          .where('patientId', isEqualTo: patientId);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      if (hasAbnormalVitals != null) {
        query = query.where('hasAbnormalVitals', isEqualTo: hasAbnormalVitals);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get patient vitals from Firestore: $e');
      return [];
    }
  }

  /// Get patient vitals from Firestore (legacy format)
  Future<List<PatientVitals>> getPatientVitalsLegacy(
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

  /// Get latest vitals for a patient
  Future<PatientVitalsFirestore?> getLatestPatientVitals(
    String patientId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_vitalsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return PatientVitalsFirestore.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get latest patient vitals from Firestore: $e');
      return null;
    }
  }

  /// Get patients with abnormal vitals
  Future<List<PatientVitalsFirestore>> getPatientsWithAbnormalVitals({
    int limit = 50,
    double minSeverityScore = 1.0,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_vitalsCollection)
          .where('hasAbnormalVitals', isEqualTo: true)
          .where(
            'vitalsSeverityScore',
            isGreaterThanOrEqualTo: minSeverityScore,
          )
          .orderBy('vitalsSeverityScore', descending: true)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e(
        'Failed to get patients with abnormal vitals from Firestore: $e',
      );
      return [];
    }
  }

  // ============================================================================
  // TRIAGE RESULTS MANAGEMENT
  // ============================================================================

  /// Store triage result in Firestore
  Future<String> storeTriageResult(TriageResultFirestore result) async {
    try {
      final docRef = await _firestore
          .collection(_triageResultsCollection)
          .add(result.toFirestore());

      _logger.i(
        'Triage result stored in Firestore for patient: ${result.patientId}',
      );
      return docRef.id;
    } catch (e) {
      _logger.e('Failed to store triage result in Firestore: $e');
      rethrow;
    }
  }

  /// Store triage result in Firestore (legacy format)
  Future<void> storeTriageResultLegacy(
    String patientId,
    Map<String, dynamic> triageResult,
  ) async {
    try {
      await _firestore
          .collection(_triageResultsCollection)
          .doc('${patientId}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
            'patientId': patientId,
            'sessionId': triageResult['sessionId'] ?? 'legacy_session',
            'timestamp': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'severityScore': triageResult['severityScore'],
            'urgencyLevel': triageResult['urgencyLevel'],
            'symptoms': triageResult['symptoms'],
            'aiReasoning': triageResult['aiReasoning'],
            'recommendedActions': triageResult['recommendedActions'] ?? [],
            'vitalsContribution': triageResult['vitalsContribution'],
            'confidence': triageResult['confidence'],
            'watsonxModelVersion':
                triageResult['watsonxModelVersion'] ?? 'legacy',
            'isCritical': (triageResult['urgencyLevel'] == 'CRITICAL'),
            'isUrgent': [
              'URGENT',
              'CRITICAL',
            ].contains(triageResult['urgencyLevel']),
          });

      _logger.i('Triage result stored in Firestore for patient: $patientId');
    } catch (e) {
      _logger.e('Failed to store triage result in Firestore: $e');
      rethrow;
    }
  }

  /// Get triage results from Firestore
  Future<List<TriageResultFirestore>> getTriageResults(
    String patientId, {
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
    UrgencyLevel? urgencyLevel,
  }) async {
    try {
      Query query = _firestore
          .collection(_triageResultsCollection)
          .where('patientId', isEqualTo: patientId);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      if (urgencyLevel != null) {
        query = query.where('urgencyLevel', isEqualTo: urgencyLevel.toString());
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => TriageResultFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get triage results from Firestore: $e');
      return [];
    }
  }

  /// Get triage results from Firestore (legacy format)
  Future<List<Map<String, dynamic>>> getTriageResultsLegacy(
    String patientId, {
    int limit = 5,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_triageResultsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('Failed to get triage results from Firestore: $e');
      return [];
    }
  }

  /// Get critical triage cases
  Future<List<TriageResultFirestore>> getCriticalTriageCases({
    int limit = 20,
    DateTime? since,
  }) async {
    try {
      Query query = _firestore
          .collection(_triageResultsCollection)
          .where('isCritical', isEqualTo: true);

      if (since != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: since);
      }

      query = query
          .orderBy('severityScore', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => TriageResultFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get critical triage cases from Firestore: $e');
      return [];
    }
  }

  /// Get triage results by hospital
  Future<List<TriageResultFirestore>> getTriageResultsByHospital(
    String hospitalId, {
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_triageResultsCollection)
          .where('recommendedHospitalId', isEqualTo: hospitalId);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => TriageResultFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get triage results by hospital from Firestore: $e');
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

  // ============================================================================
  // PATIENT CONSENT MANAGEMENT
  // ============================================================================

  /// Store patient consent
  Future<String> storePatientConsent(PatientConsentFirestore consent) async {
    try {
      final docRef = await _firestore
          .collection(_consentsCollection)
          .add(consent.toFirestore());

      _logger.i('Patient consent stored in Firestore: ${consent.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Failed to store patient consent in Firestore: $e');
      rethrow;
    }
  }

  /// Get active consents for a patient
  Future<List<PatientConsentFirestore>> getActivePatientConsents(
    String patientId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_consentsCollection)
          .where('patientId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .where('isValid', isEqualTo: true)
          .orderBy('grantedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PatientConsentFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get active patient consents from Firestore: $e');
      return [];
    }
  }

  /// Get consents by provider
  Future<List<PatientConsentFirestore>> getConsentsByProvider(
    String providerId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_consentsCollection)
          .where('providerId', isEqualTo: providerId)
          .where('isValid', isEqualTo: true)
          .orderBy('grantedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PatientConsentFirestore.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get consents by provider from Firestore: $e');
      return [];
    }
  }

  /// Revoke patient consent
  Future<void> revokePatientConsent(String consentId) async {
    try {
      await _firestore.collection(_consentsCollection).doc(consentId).update({
        'isActive': false,
        'revokedAt': FieldValue.serverTimestamp(),
        'isValid': false,
        'status': 'revoked',
      });

      _logger.i('Patient consent revoked in Firestore: $consentId');
    } catch (e) {
      _logger.e('Failed to revoke patient consent in Firestore: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ENHANCED REAL-TIME LISTENERS
  // ============================================================================

  /// Listen to real-time patient vitals
  Stream<List<PatientVitalsFirestore>> listenToPatientVitals(String patientId) {
    return _firestore
        .collection(_vitalsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
              .toList(),
        );
  }

  /// Listen to real-time patient vitals (legacy format)
  Stream<List<PatientVitals>> listenToPatientVitalsLegacy(String patientId) {
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

  /// Listen to critical triage cases
  Stream<List<TriageResultFirestore>> listenToCriticalCases() {
    return _firestore
        .collection(_triageResultsCollection)
        .where('isCritical', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TriageResultFirestore.fromFirestore(doc))
              .toList(),
        );
  }

  /// Listen to patients with abnormal vitals
  Stream<List<PatientVitalsFirestore>> listenToAbnormalVitals() {
    return _firestore
        .collection(_vitalsCollection)
        .where('hasAbnormalVitals', isEqualTo: true)
        .orderBy('vitalsSeverityScore', descending: true)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
              .toList(),
        );
  }
}

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Batch write multiple operations
  Future<void> batchWrite(List<BatchOperation> operations) async {
    try {
      final batch = _firestore.batch();

      for (final operation in operations) {
        switch (operation.type) {
          case BatchOperationType.create:
            final docRef = _firestore.collection(operation.collection).doc();
            batch.set(docRef, operation.data!);
            break;
          case BatchOperationType.update:
            final docRef = _firestore.collection(operation.collection).doc(operation.documentId);
            batch.update(docRef, operation.data!);
            break;
          case BatchOperationType.delete:
            final docRef = _firestore.collection(operation.collection).doc(operation.documentId);
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();
      _logger.i('Batch operation completed with ${operations.length} operations');
    } catch (e) {
      _logger.e('Failed to execute batch operation: $e');
      rethrow;
    }
  }

  /// Batch update hospital capacities
  Future<void> batchUpdateCapacities(List<HospitalCapacityFirestore> capacities) async {
    try {
      final batch = _firestore.batch();

      for (final capacity in capacities) {
        final docRef = _firestore.collection(_hospitalCapacityCollection).doc();
        batch.set(docRef, capacity.toFirestore());
      }

      await batch.commit();
      _logger.i('Batch updated ${capacities.length} hospital capacities');
    } catch (e) {
      _logger.e('Failed to batch update capacities: $e');
      rethrow;
    }
  }

  // ============================================================================
  // QUERY BUILDERS
  // ============================================================================

  /// Build complex hospital query
  Query buildHospitalQuery({
    List<String>? specializations,
    int? minTraumaLevel,
    int? maxTraumaLevel,
    bool? isActive,
    String? city,
    String? state,
    int? limit,
  }) {
    Query query = _firestore.collection(_hospitalsCollection);

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    if (minTraumaLevel != null) {
      query = query.where('traumaLevel', isGreaterThanOrEqualTo: minTraumaLevel);
    }

    if (maxTraumaLevel != null) {
      query = query.where('traumaLevel', isLessThanOrEqualTo: maxTraumaLevel);
    }

    if (specializations != null && specializations.isNotEmpty) {
      query = query.where('specializations', arrayContainsAny: specializations);
    }

    if (city != null) {
      query = query.where('address.city', isEqualTo: city);
    }

    if (state != null) {
      query = query.where('address.state', isEqualTo: state);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query;
  }

  /// Build capacity query with filters
  Query buildCapacityQuery({
    List<String>? hospitalIds,
    int? minAvailableBeds,
    double? maxOccupancyRate,
    bool? isRealTime,
    DateTime? since,
    int? limit,
  }) {
    Query query = _firestore.collection(_hospitalCapacityCollection);

    if (hospitalIds != null && hospitalIds.isNotEmpty) {
      query = query.where('hospitalId', whereIn: hospitalIds);
    }

    if (minAvailableBeds != null) {
      query = query.where('availableBeds', isGreaterThanOrEqualTo: minAvailableBeds);
    }

    if (maxOccupancyRate != null) {
      query = query.where('occupancyRate', isLessThan: maxOccupancyRate);
    }

    if (isRealTime != null) {
      query = query.where('isRealTime', isEqualTo: isRealTime);
    }

    if (since != null) {
      query = query.where('lastUpdated', isGreaterThanOrEqualTo: since);
    }

    query = query.orderBy('lastUpdated', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query;
  }

  // ============================================================================
  // ANALYTICS AND REPORTING
  // ============================================================================

  /// Get hospital capacity analytics
  Future<CapacityAnalytics> getCapacityAnalytics({
    List<String>? hospitalIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection(_hospitalCapacityCollection);

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        query = query.where('hospitalId', whereIn: hospitalIds);
      }

      if (startDate != null) {
        query = query.where('lastUpdated', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('lastUpdated', isLessThanOrEqualTo: endDate);
      }

      final querySnapshot = await query.get();
      final capacities = querySnapshot.docs
          .map((doc) => HospitalCapacityFirestore.fromFirestore(doc))
          .toList();

      return CapacityAnalytics.fromCapacities(capacities);
    } catch (e) {
      _logger.e('Failed to get capacity analytics: $e');
      return CapacityAnalytics.empty();
    }
  }

  /// Get triage analytics
  Future<TriageAnalytics> getTriageAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? hospitalId,
  }) async {
    try {
      Query query = _firestore.collection(_triageResultsCollection);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      if (hospitalId != null) {
        query = query.where('recommendedHospitalId', isEqualTo: hospitalId);
      }

      final querySnapshot = await query.get();
      final results = querySnapshot.docs
          .map((doc) => TriageResultFirestore.fromFirestore(doc))
          .toList();

      return TriageAnalytics.fromResults(results);
    } catch (e) {
      _logger.e('Failed to get triage analytics: $e');
      return TriageAnalytics.empty();
    }
  }
}

// ============================================================================
// SUPPORTING CLASSES
// ============================================================================

class BatchOperation {
  final BatchOperationType type;
  final String collection;
  final String? documentId;
  final Map<String, dynamic>? data;

  BatchOperation({
    required this.type,
    required this.collection,
    this.documentId,
    this.data,
  });

  factory BatchOperation.create(String collection, Map<String, dynamic> data) {
    return BatchOperation(
      type: BatchOperationType.create,
      collection: collection,
      data: data,
    );
  }

  factory BatchOperation.update(String collection, String documentId, Map<String, dynamic> data) {
    return BatchOperation(
      type: BatchOperationType.update,
      collection: collection,
      documentId: documentId,
      data: data,
    );
  }

  factory BatchOperation.delete(String collection, String documentId) {
    return BatchOperation(
      type: BatchOperationType.delete,
      collection: collection,
      documentId: documentId,
    );
  }
}

enum BatchOperationType { create, update, delete }

class CapacityAnalytics {
  final int totalHospitals;
  final int totalBeds;
  final int totalAvailableBeds;
  final double averageOccupancyRate;
  final int hospitalsNearCapacity;
  final int hospitalsAtCapacity;
  final double averageWaitTime;

  CapacityAnalytics({
    required this.totalHospitals,
    required this.totalBeds,
    required this.totalAvailableBeds,
    required this.averageOccupancyRate,
    required this.hospitalsNearCapacity,
    required this.hospitalsAtCapacity,
    required this.averageWaitTime,
  });

  factory CapacityAnalytics.fromCapacities(List<HospitalCapacityFirestore> capacities) {
    if (capacities.isEmpty) return CapacityAnalytics.empty();

    final totalBeds = capacities.fold<int>(0, (sum, c) => sum + c.totalBeds);
    final totalAvailable = capacities.fold<int>(0, (sum, c) => sum + c.availableBeds);
    final avgOccupancy = capacities.fold<double>(0, (sum, c) => sum + c.occupancyRate) / capacities.length;
    final nearCapacity = capacities.where((c) => c.isNearCapacity).length;
    final atCapacity = capacities.where((c) => c.isAtCapacity).length;
    final avgWait = capacities.fold<double>(0, (sum, c) => sum + c.averageWaitTime) / capacities.length;

    return CapacityAnalytics(
      totalHospitals: capacities.length,
      totalBeds: totalBeds,
      totalAvailableBeds: totalAvailable,
      averageOccupancyRate: avgOccupancy,
      hospitalsNearCapacity: nearCapacity,
      hospitalsAtCapacity: atCapacity,
      averageWaitTime: avgWait,
    );
  }

  factory CapacityAnalytics.empty() {
    return CapacityAnalytics(
      totalHospitals: 0,
      totalBeds: 0,
      totalAvailableBeds: 0,
      averageOccupancyRate: 0.0,
      hospitalsNearCapacity: 0,
      hospitalsAtCapacity: 0,
      averageWaitTime: 0.0,
    );
  }
}

class TriageAnalytics {
  final int totalCases;
  final int criticalCases;
  final int urgentCases;
  final int standardCases;
  final int nonUrgentCases;
  final double averageSeverityScore;
  final double averageConfidence;

  TriageAnalytics({
    required this.totalCases,
    required this.criticalCases,
    required this.urgentCases,
    required this.standardCases,
    required this.nonUrgentCases,
    required this.averageSeverityScore,
    required this.averageConfidence,
  });

  factory TriageAnalytics.fromResults(List<TriageResultFirestore> results) {
    if (results.isEmpty) return TriageAnalytics.empty();

    final critical = results.where((r) => r.urgencyLevel == UrgencyLevel.critical).length;
    final urgent = results.where((r) => r.urgencyLevel == UrgencyLevel.urgent).length;
    final standard = results.where((r) => r.urgencyLevel == UrgencyLevel.standard).length;
    final nonUrgent = results.where((r) => r.urgencyLevel == UrgencyLevel.nonUrgent).length;
    final avgSeverity = results.fold<double>(0, (sum, r) => sum + r.severityScore) / results.length;
    final avgConfidence = results.fold<double>(0, (sum, r) => sum + r.confidence) / results.length;

    return TriageAnalytics(
      totalCases: results.length,
      criticalCases: critical,
      urgentCases: urgent,
      standardCases: standard,
      nonUrgentCases: nonUrgent,
      averageSeverityScore: avgSeverity,
      averageConfidence: avgConfidence,
    );
  }

  factory TriageAnalytics.empty() {
    return TriageAnalytics(
      totalCases: 0,
      criticalCases: 0,
      urgentCases: 0,
      standardCases: 0,
      nonUrgentCases: 0,
      averageSeverityScore: 0.0,
      averageConfidence: 0.0,
    );
  }
}