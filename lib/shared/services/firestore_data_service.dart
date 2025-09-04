import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';
import '../../features/triage/domain/entities/triage_result.dart' as legacy;
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

  // Collection names
  static const String _hospitalsCollection = 'hospitals';
  static const String _hospitalCapacityCollection = 'hospital_capacity';
  static const String _vitalsCollection = 'patient_vitals';
  static const String _triageResultsCollection = 'triage_results';
  static const String _patientConsentsCollection = 'patient_consents';
  static const String _deviceDataCollection = 'device_data';

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
          .map(
            (doc) => HospitalFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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
          .map(
            (doc) => HospitalFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
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
        final capacity = HospitalCapacityFirestore.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
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
          .map(
            (doc) => HospitalCapacityFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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
            final capacity = HospitalCapacityFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            );
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
              .map(
                (doc) => HospitalCapacityFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Listen to patient vitals updates for a specific patient
  Stream<List<PatientVitalsFirestore>> listenToPatientVitals(
    String patientId, {
    int limit = 10,
  }) {
    return _firestore
        .collection(_vitalsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PatientVitalsFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Listen to critical patient vitals across all patients
  Stream<List<PatientVitalsFirestore>> listenToCriticalVitals({
    double minSeverityScore = 2.0,
    int limit = 50,
  }) {
    return _firestore
        .collection(_vitalsCollection)
        .where('hasAbnormalVitals', isEqualTo: true)
        .where('vitalsSeverityScore', isGreaterThanOrEqualTo: minSeverityScore)
        .orderBy('vitalsSeverityScore', descending: true)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PatientVitalsFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Listen to triage results for a specific patient
  Stream<List<TriageResultFirestore>> listenToPatientTriageResults(
    String patientId, {
    int limit = 5,
  }) {
    return _firestore
        .collection(_triageResultsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => TriageResultFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Listen to critical triage cases
  Stream<List<TriageResultFirestore>> listenToCriticalTriageCases({
    int limit = 20,
  }) {
    return _firestore
        .collection(_triageResultsCollection)
        .where('isCritical', isEqualTo: true)
        .orderBy('severityScore', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => TriageResultFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Listen to hospital-specific capacity updates with real-time alerts
  Stream<HospitalCapacityFirestore?> listenToHospitalCapacityUpdates(
    String hospitalId,
  ) {
    return _firestore
        .collection(_hospitalCapacityCollection)
        .where('hospitalId', isEqualTo: hospitalId)
        .orderBy('lastUpdated', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return HospitalCapacityFirestore.fromFirestore(
              snapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
            );
          }
          return null;
        });
  }

  // ============================================================================
  // BATCH OPERATIONS AND TRANSACTIONS
  // ============================================================================

  /// Create a new batch for bulk operations
  WriteBatch createBatch() {
    return _firestore.batch();
  }

  /// Execute batch operations with error handling
  Future<void> executeBatch(WriteBatch batch) async {
    try {
      await batch.commit();
      _logger.i('Batch operation completed successfully');
    } catch (e) {
      _logger.e('Failed to execute batch operation: $e');
      rethrow;
    }
  }

  /// Batch create hospitals
  Future<void> batchCreateHospitals(List<HospitalFirestore> hospitals) async {
    if (hospitals.isEmpty) return;

    final batch = createBatch();

    for (final hospital in hospitals) {
      final docRef = _firestore.collection(_hospitalsCollection).doc();
      batch.set(docRef, hospital.toFirestore());
    }

    await executeBatch(batch);
    _logger.i('Batch created ${hospitals.length} hospitals');
  }

  /// Batch update hospital capacities
  Future<void> batchUpdateCapacities(
    List<HospitalCapacityFirestore> capacities,
  ) async {
    if (capacities.isEmpty) return;

    final batch = createBatch();

    for (final capacity in capacities) {
      final docRef = _firestore.collection(_hospitalCapacityCollection).doc();
      batch.set(docRef, capacity.toFirestore());
    }

    await executeBatch(batch);
    _logger.i('Batch updated ${capacities.length} hospital capacities');
  }

  /// Batch store patient vitals
  Future<void> batchStorePatientVitals(
    List<PatientVitalsFirestore> vitalsList,
  ) async {
    if (vitalsList.isEmpty) return;

    final batch = createBatch();

    for (final vitals in vitalsList) {
      final docRef = _firestore.collection(_vitalsCollection).doc();
      batch.set(docRef, vitals.toFirestore());
    }

    await executeBatch(batch);
    _logger.i('Batch stored ${vitalsList.length} patient vitals records');
  }

  /// Batch store triage results
  Future<void> batchStoreTriageResults(
    List<TriageResultFirestore> results,
  ) async {
    if (results.isEmpty) return;

    final batch = createBatch();

    for (final result in results) {
      final docRef = _firestore.collection(_triageResultsCollection).doc();
      batch.set(docRef, result.toFirestore());
    }

    await executeBatch(batch);
    _logger.i('Batch stored ${results.length} triage results');
  }

  /// Transaction: Update hospital capacity and create triage result atomically
  Future<void> updateCapacityAndCreateTriageResult({
    required HospitalCapacityFirestore capacity,
    required TriageResultFirestore triageResult,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Add capacity update
        final capacityRef = _firestore
            .collection(_hospitalCapacityCollection)
            .doc();
        transaction.set(capacityRef, capacity.toFirestore());

        // Add triage result
        final triageRef = _firestore.collection(_triageResultsCollection).doc();
        transaction.set(triageRef, triageResult.toFirestore());

        _logger.i(
          'Transaction completed: Updated capacity for ${capacity.hospitalId} '
          'and created triage result for ${triageResult.patientId}',
        );
      });
    } catch (e) {
      _logger.e('Transaction failed: $e');
      rethrow;
    }
  }

  /// Transaction: Store patient vitals and triage result together
  Future<void> storeVitalsAndTriageResult({
    required PatientVitalsFirestore vitals,
    required TriageResultFirestore triageResult,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Store vitals
        final vitalsRef = _firestore.collection(_vitalsCollection).doc();
        transaction.set(vitalsRef, vitals.toFirestore());

        // Store triage result
        final triageRef = _firestore.collection(_triageResultsCollection).doc();
        transaction.set(triageRef, triageResult.toFirestore());

        _logger.i(
          'Transaction completed: Stored vitals and triage result for patient ${vitals.patientId}',
        );
      });
    } catch (e) {
      _logger.e('Transaction failed: $e');
      rethrow;
    }
  }

  /// Transaction: Update multiple hospital capacities atomically
  Future<void> updateMultipleCapacitiesTransaction(
    List<HospitalCapacityFirestore> capacities,
  ) async {
    if (capacities.isEmpty) return;

    try {
      await _firestore.runTransaction((transaction) async {
        for (final capacity in capacities) {
          final docRef = _firestore
              .collection(_hospitalCapacityCollection)
              .doc();
          transaction.set(docRef, capacity.toFirestore());
        }

        _logger.i(
          'Transaction completed: Updated ${capacities.length} hospital capacities',
        );
      });
    } catch (e) {
      _logger.e('Transaction failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ADVANCED QUERY BUILDERS
  // ============================================================================

  /// Advanced hospital query builder with complex filtering
  Future<List<HospitalFirestore>> queryHospitalsAdvanced({
    double? latitude,
    double? longitude,
    double? radiusKm,
    List<String>? requiredSpecializations,
    List<String>? optionalSpecializations,
    int? minTraumaLevel,
    int? maxTraumaLevel,
    bool? isActive,
    int? minAvailableBeds,
    double? maxOccupancyRate,
    int? maxWaitTime,
    bool sortByDistance = true,
    bool sortByCapacity = false,
    bool sortByWaitTime = false,
    int limit = 20,
  }) async {
    try {
      // Start with base hospital query
      Query hospitalQuery = _firestore.collection(_hospitalsCollection);

      // Apply basic filters
      if (isActive != null) {
        hospitalQuery = hospitalQuery.where('isActive', isEqualTo: isActive);
      }

      if (minTraumaLevel != null) {
        hospitalQuery = hospitalQuery.where(
          'traumaLevel',
          isGreaterThanOrEqualTo: minTraumaLevel,
        );
      }

      if (maxTraumaLevel != null) {
        hospitalQuery = hospitalQuery.where(
          'traumaLevel',
          isLessThanOrEqualTo: maxTraumaLevel,
        );
      }

      if (requiredSpecializations != null &&
          requiredSpecializations.isNotEmpty) {
        hospitalQuery = hospitalQuery.where(
          'specializations',
          arrayContainsAny: requiredSpecializations,
        );
      }

      // Execute hospital query
      final hospitalSnapshot = await hospitalQuery.get();
      List<HospitalFirestore> hospitals = hospitalSnapshot.docs
          .map(
            (doc) => HospitalFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();

      // Apply location filtering if specified
      if (latitude != null && longitude != null && radiusKm != null) {
        hospitals = hospitals.where((hospital) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            hospital.location.latitude,
            hospital.location.longitude,
          );
          return distance <= radiusKm;
        }).toList();
      }

      // Filter by optional specializations (OR logic)
      if (optionalSpecializations != null &&
          optionalSpecializations.isNotEmpty) {
        hospitals = hospitals.where((hospital) {
          return optionalSpecializations.any(
            (spec) => hospital.specializations.contains(spec),
          );
        }).toList();
      }

      // Get hospital IDs for capacity filtering
      final hospitalIds = hospitals.map((h) => h.id).toList();
      if (hospitalIds.isEmpty) return [];

      // Get capacity data for filtering and sorting
      final capacities = await getHospitalCapacities(hospitalIds);
      final capacityMap = <String, HospitalCapacityFirestore>{};
      for (final capacity in capacities) {
        capacityMap[capacity.hospitalId] = capacity;
      }

      // Apply capacity-based filters
      if (minAvailableBeds != null ||
          maxOccupancyRate != null ||
          maxWaitTime != null) {
        hospitals = hospitals.where((hospital) {
          final capacity = capacityMap[hospital.id];
          if (capacity == null) return false;

          if (minAvailableBeds != null &&
              capacity.availableBeds < minAvailableBeds) {
            return false;
          }

          if (maxOccupancyRate != null &&
              capacity.occupancyRate > maxOccupancyRate) {
            return false;
          }

          if (maxWaitTime != null && capacity.averageWaitTime > maxWaitTime) {
            return false;
          }

          return true;
        }).toList();
      }

      // Apply sorting
      if (sortByDistance && latitude != null && longitude != null) {
        hospitals.sort((a, b) {
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
      } else if (sortByCapacity) {
        hospitals.sort((a, b) {
          final capacityA = capacityMap[a.id];
          final capacityB = capacityMap[b.id];
          if (capacityA == null || capacityB == null) return 0;
          return capacityB.availableBeds.compareTo(capacityA.availableBeds);
        });
      } else if (sortByWaitTime) {
        hospitals.sort((a, b) {
          final capacityA = capacityMap[a.id];
          final capacityB = capacityMap[b.id];
          if (capacityA == null || capacityB == null) return 0;
          return capacityA.averageWaitTime.compareTo(capacityB.averageWaitTime);
        });
      }

      return hospitals.take(limit).toList();
    } catch (e) {
      _logger.e('Failed to execute advanced hospital query: $e');
      return [];
    }
  }

  /// Query hospitals by availability and urgency level
  Future<List<HospitalFirestore>> queryHospitalsByAvailability({
    required UrgencyLevel urgencyLevel,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int limit = 10,
  }) async {
    try {
      // Define capacity requirements based on urgency
      int minAvailableBeds;
      double maxOccupancyRate;
      int maxWaitTime;

      switch (urgencyLevel) {
        case UrgencyLevel.critical:
          minAvailableBeds = 1;
          maxOccupancyRate = 1.0; // Accept any hospital for critical cases
          maxWaitTime = 30; // 30 minutes max
        case UrgencyLevel.urgent:
          minAvailableBeds = 2;
          maxOccupancyRate = 0.95;
          maxWaitTime = 60; // 1 hour max
        case UrgencyLevel.standard:
          minAvailableBeds = 3;
          maxOccupancyRate = 0.90;
          maxWaitTime = 120; // 2 hours max
        case UrgencyLevel.nonUrgent:
          minAvailableBeds = 5;
          maxOccupancyRate = 0.85;
          maxWaitTime = 240; // 4 hours max
      }

      return await queryHospitalsAdvanced(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        minAvailableBeds: minAvailableBeds,
        maxOccupancyRate: maxOccupancyRate,
        maxWaitTime: maxWaitTime,
        sortByDistance: latitude != null && longitude != null,
        sortByCapacity: latitude == null || longitude == null,
        limit: limit,
      );
    } catch (e) {
      _logger.e('Failed to query hospitals by availability: $e');
      return [];
    }
  }

  /// Query hospitals with specialized care capabilities
  Future<List<HospitalFirestore>> querySpecializedHospitals({
    required List<String> requiredSpecializations,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int? minTraumaLevel,
    bool requireAllSpecializations = false,
    int limit = 15,
  }) async {
    try {
      if (requireAllSpecializations) {
        // For "require all" logic, we need to filter in memory
        final hospitals = await queryHospitalsAdvanced(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
          minTraumaLevel: minTraumaLevel,
          sortByDistance: latitude != null && longitude != null,
          limit: limit * 2, // Get more to filter
        );

        return hospitals
            .where((hospital) {
              return requiredSpecializations.every(
                (spec) => hospital.specializations.contains(spec),
              );
            })
            .take(limit)
            .toList();
      } else {
        // For "any" logic, use the existing query
        return await queryHospitalsAdvanced(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
          requiredSpecializations: requiredSpecializations,
          minTraumaLevel: minTraumaLevel,
          sortByDistance: latitude != null && longitude != null,
          limit: limit,
        );
      }
    } catch (e) {
      _logger.e('Failed to query specialized hospitals: $e');
      return [];
    }
  }

  /// Query hospitals with real-time capacity monitoring
  Future<List<Map<String, dynamic>>> queryHospitalsWithLiveCapacity({
    double? latitude,
    double? longitude,
    double? radiusKm,
    List<String>? specializations,
    int limit = 20,
  }) async {
    try {
      final hospitals = await queryHospitalsAdvanced(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        requiredSpecializations: specializations,
        sortByDistance: latitude != null && longitude != null,
        limit: limit,
      );

      final hospitalIds = hospitals.map((h) => h.id).toList();
      final capacities = await getHospitalCapacities(hospitalIds);

      final capacityMap = <String, HospitalCapacityFirestore>{};
      for (final capacity in capacities) {
        capacityMap[capacity.hospitalId] = capacity;
      }

      return hospitals.map((hospital) {
        final capacity = capacityMap[hospital.id];
        double? distance;

        if (latitude != null && longitude != null) {
          distance = _calculateDistance(
            latitude,
            longitude,
            hospital.location.latitude,
            hospital.location.longitude,
          );
        }

        return {
          'hospital': hospital,
          'capacity': capacity,
          'distance': distance,
          'isDataFresh': capacity?.isDataFresh ?? false,
          'isNearCapacity': capacity?.isNearCapacity ?? false,
          'isAtCapacity': capacity?.isAtCapacity ?? false,
        };
      }).toList();
    } catch (e) {
      _logger.e('Failed to query hospitals with live capacity: $e');
      return [];
    }
  }

  // ============================================================================
  // PATIENT CONSENT MANAGEMENT
  // ============================================================================

  /// Store patient consent
  Future<String> storePatientConsent(PatientConsentFirestore consent) async {
    try {
      final docRef = await _firestore
          .collection(_patientConsentsCollection)
          .add(consent.toFirestore());

      _logger.i(
        'Patient consent stored in Firestore for patient: ${consent.patientId}',
      );
      return docRef.id;
    } catch (e) {
      _logger.e('Failed to store patient consent in Firestore: $e');
      rethrow;
    }
  }

  /// Get active consents for a patient
  Future<List<PatientConsentFirestore>> getActiveConsents(
    String patientId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_patientConsentsCollection)
          .where('patientId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .orderBy('grantedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => PatientConsentFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .where((consent) => consent.isValid)
          .toList();
    } catch (e) {
      _logger.e('Failed to get active consents from Firestore: $e');
      return [];
    }
  }

  /// Get all consents for a patient
  Future<List<PatientConsentFirestore>> getPatientConsents(
    String patientId, {
    ConsentType? consentType,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(_patientConsentsCollection)
          .where('patientId', isEqualTo: patientId);

      if (consentType != null) {
        query = query.where('consentType', isEqualTo: consentType.toString());
      }

      query = query.orderBy('grantedAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => PatientConsentFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get patient consents from Firestore: $e');
      return [];
    }
  }

  /// Revoke patient consent
  Future<void> revokeConsent(String consentId) async {
    try {
      await _firestore
          .collection(_patientConsentsCollection)
          .doc(consentId)
          .update({
            'revokedAt': FieldValue.serverTimestamp(),
            'isActive': false,
          });

      _logger.i('Patient consent revoked: $consentId');
    } catch (e) {
      _logger.e('Failed to revoke patient consent in Firestore: $e');
      rethrow;
    }
  }

  /// Check if patient has valid consent for specific data scopes
  Future<bool> hasValidConsent(
    String patientId,
    String providerId,
    List<String> requiredScopes,
  ) async {
    try {
      final consents = await getActiveConsents(patientId);

      for (final consent in consents) {
        if (consent.providerId == providerId && consent.isValid) {
          final hasAllScopes = requiredScopes.every(
            (scope) => consent.dataScopes.contains(scope),
          );
          if (hasAllScopes) return true;
        }
      }

      return false;
    } catch (e) {
      _logger.e('Failed to check patient consent: $e');
      return false;
    }
  }

  /// Get consents expiring soon
  Future<List<PatientConsentFirestore>> getExpiringConsents({
    int daysAhead = 30,
    int limit = 100,
  }) async {
    try {
      final futureDate = DateTime.now().add(Duration(days: daysAhead));

      final querySnapshot = await _firestore
          .collection(_consentsCollection)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isLessThanOrEqualTo: futureDate)
          .orderBy('expiresAt', descending: false)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => PatientConsentFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .where((consent) => consent.isValid)
          .toList();
    } catch (e) {
      _logger.e('Failed to get expiring consents from Firestore: $e');
      return [];
    }
  }

  /// Store patient consent with blockchain transaction ID and audit trail
  Future<String> storePatientConsentWithAudit(
    PatientConsentFirestore consent,
    String blockchainTxId,
    String ipAddress,
    Map<String, dynamic> auditDetails,
  ) async {
    try {
      // Create enhanced consent with audit information
      final enhancedConsent = consent.copyWith(
        blockchainTxId: blockchainTxId,
        ipAddress: ipAddress,
        consentDetails: {
          ...consent.consentDetails,
          'auditTrail': auditDetails,
          'createdBy': auditDetails['userId'],
          'userAgent': auditDetails['userAgent'],
          'sessionId': auditDetails['sessionId'],
        },
      );

      final docRef = await _firestore
          .collection(_consentsCollection)
          .add(enhancedConsent.toFirestore());

      // Create audit log entry
      await _createConsentAuditLog(
        consentId: docRef.id,
        action: 'CONSENT_GRANTED',
        patientId: consent.patientId,
        providerId: consent.providerId,
        blockchainTxId: blockchainTxId,
        ipAddress: ipAddress,
        details: auditDetails,
      );

      _logger.i(
        'Patient consent stored with audit trail: ${consent.patientId}',
      );
      return docRef.id;
    } catch (e) {
      _logger.e('Failed to store patient consent with audit: $e');
      rethrow;
    }
  }

  /// Revoke patient consent with audit trail
  Future<void> revokeConsentWithAudit(
    String consentId,
    String revokedBy,
    String reason,
    String ipAddress,
    Map<String, dynamic> auditDetails,
  ) async {
    try {
      // Get the consent to update
      final consentDoc = await _firestore
          .collection(_consentsCollection)
          .doc(consentId)
          .get();

      if (!consentDoc.exists) {
        throw Exception('Consent not found: $consentId');
      }

      final consent = PatientConsentFirestore.fromFirestore(consentDoc);

      // Update consent with revocation details
      await _firestore.collection(_consentsCollection).doc(consentId).update({
        'revokedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'revocationReason': reason,
        'revokedBy': revokedBy,
        'revocationIpAddress': ipAddress,
        'revocationDetails': auditDetails,
      });

      // Create audit log entry
      await _createConsentAuditLog(
        consentId: consentId,
        action: 'CONSENT_REVOKED',
        patientId: consent.patientId,
        providerId: consent.providerId,
        blockchainTxId: consent.blockchainTxId,
        ipAddress: ipAddress,
        details: {...auditDetails, 'reason': reason, 'revokedBy': revokedBy},
      );

      _logger.i('Patient consent revoked with audit trail: $consentId');
    } catch (e) {
      _logger.e('Failed to revoke patient consent with audit: $e');
      rethrow;
    }
  }

  /// Get consent audit trail
  Future<List<ConsentAuditLog>> getConsentAuditTrail(
    String consentId, {
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('consent_audit_logs')
          .where('consentId', isEqualTo: consentId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ConsentAuditLog.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get consent audit trail: $e');
      return [];
    }
  }

  /// Create consent audit log entry
  Future<void> _createConsentAuditLog({
    required String consentId,
    required String action,
    required String patientId,
    required String providerId,
    required String blockchainTxId,
    required String ipAddress,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('consent_audit_logs').add({
        'consentId': consentId,
        'action': action,
        'patientId': patientId,
        'providerId': providerId,
        'blockchainTxId': blockchainTxId,
        'ipAddress': ipAddress,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      _logger.e('Failed to create consent audit log: $e');
      // Don't rethrow as this is a secondary operation
    }
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

  /// Get system health metrics
  Future<Map<String, dynamic>> getSystemHealthMetrics() async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      // Get recent activity counts
      final recentVitals = await _firestore
          .collection(_vitalsCollection)
          .where('timestamp', isGreaterThan: oneHourAgo)
          .count()
          .get();

      final recentTriage = await _firestore
          .collection(_triageResultsCollection)
          .where('createdAt', isGreaterThan: oneHourAgo)
          .count()
          .get();

      final criticalCases = await _firestore
          .collection(_triageResultsCollection)
          .where('isCritical', isEqualTo: true)
          .where('createdAt', isGreaterThan: oneHourAgo)
          .count()
          .get();

      // Get capacity metrics
      final capacities = await getAvailableCapacities(limit: 100);
      final totalBeds = capacities.fold<int>(
        0,
        (accumulator, c) => accumulator + c.totalBeds,
      );
      final availableBeds = capacities.fold<int>(
        0,
        (accumulator, c) => accumulator + c.availableBeds,
      );
      final avgOccupancy = capacities.isNotEmpty
          ? capacities.fold<double>(
                  0,
                  (accumulator, c) => accumulator + c.occupancyRate,
                ) /
                capacities.length
          : 0.0;

      return {
        'timestamp': now.toIso8601String(),
        'activity': {
          'recentVitalsCount': recentVitals.count,
          'recentTriageCount': recentTriage.count,
          'criticalCasesCount': criticalCases.count,
        },
        'capacity': {
          'totalHospitals': capacities.length,
          'totalBeds': totalBeds,
          'availableBeds': availableBeds,
          'averageOccupancy': avgOccupancy,
          'hospitalsNearCapacity': capacities
              .where((c) => c.isNearCapacity)
              .length,
          'hospitalsAtCapacity': capacities.where((c) => c.isAtCapacity).length,
        },
        'dataFreshness': {
          'freshCapacityData': capacities.where((c) => c.isDataFresh).length,
          'staleCapacityData': capacities.where((c) => !c.isDataFresh).length,
        },
      };
    } catch (e) {
      _logger.e('Failed to get system health metrics: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Validate data integrity across collections
  Future<Map<String, dynamic>> validateDataIntegrity() async {
    try {
      final issues = <String>[];

      // Check for orphaned capacity records
      final capacities = await _firestore
          .collection(_hospitalCapacityCollection)
          .get();
      final hospitals = await _firestore.collection(_hospitalsCollection).get();
      final hospitalIds = hospitals.docs.map((doc) => doc.id).toSet();

      for (final capacityDoc in capacities.docs) {
        final capacity = HospitalCapacityFirestore.fromFirestore(
          capacityDoc as DocumentSnapshot<Map<String, dynamic>>,
        );
        if (!hospitalIds.contains(capacity.hospitalId)) {
          issues.add(
            'Orphaned capacity record for hospital: ${capacity.hospitalId}',
          );
        }
      }

      // Check for hospitals without recent capacity data
      final recentCapacities = await _firestore
          .collection(_hospitalCapacityCollection)
          .where(
            'lastUpdated',
            isGreaterThan: DateTime.now().subtract(const Duration(hours: 24)),
          )
          .get();
      final recentCapacityHospitalIds = recentCapacities.docs
          .map((doc) => (doc.data())['hospitalId'] as String)
          .toSet();

      for (final hospitalDoc in hospitals.docs) {
        final hospital = HospitalFirestore.fromFirestore(
          hospitalDoc as DocumentSnapshot<Map<String, dynamic>>,
        );
        if (hospital.isActive &&
            !recentCapacityHospitalIds.contains(hospital.id)) {
          issues.add(
            'Active hospital without recent capacity data: ${hospital.name}',
          );
        }
      }

      return {
        'isValid': issues.isEmpty,
        'issuesFound': issues.length,
        'issues': issues,
        'checkedAt': DateTime.now().toIso8601String(),
        'collections': {
          'hospitals': hospitals.docs.length,
          'capacities': capacities.docs.length,
          'recentCapacities': recentCapacities.docs.length,
        },
      };
    } catch (e) {
      _logger.e('Failed to validate data integrity: $e');
      return {
        'isValid': false,
        'error': e.toString(),
        'checkedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Clean up old data based on retention policies
  Future<Map<String, int>> cleanupOldData({
    int vitalsRetentionDays = 90,
    int triageRetentionDays = 365,
    int capacityRetentionDays = 30,
  }) async {
    try {
      final deletedCounts = <String, int>{};

      // Clean up old vitals
      final vitalsThreshold = DateTime.now().subtract(
        Duration(days: vitalsRetentionDays),
      );
      final oldVitals = await _firestore
          .collection(_vitalsCollection)
          .where('timestamp', isLessThan: vitalsThreshold)
          .get();

      final vitalsBatch = createBatch();
      for (final doc in oldVitals.docs) {
        vitalsBatch.delete(doc.reference);
      }
      if (oldVitals.docs.isNotEmpty) {
        await executeBatch(vitalsBatch);
      }
      deletedCounts['vitals'] = oldVitals.docs.length;

      // Clean up old triage results
      final triageThreshold = DateTime.now().subtract(
        Duration(days: triageRetentionDays),
      );
      final oldTriage = await _firestore
          .collection(_triageResultsCollection)
          .where('createdAt', isLessThan: triageThreshold)
          .get();

      final triageBatch = createBatch();
      for (final doc in oldTriage.docs) {
        triageBatch.delete(doc.reference);
      }
      if (oldTriage.docs.isNotEmpty) {
        await executeBatch(triageBatch);
      }
      deletedCounts['triageResults'] = oldTriage.docs.length;

      // Clean up old capacity records
      final capacityThreshold = DateTime.now().subtract(
        Duration(days: capacityRetentionDays),
      );
      final oldCapacities = await _firestore
          .collection(_hospitalCapacityCollection)
          .where('lastUpdated', isLessThan: capacityThreshold)
          .get();

      final capacityBatch = createBatch();
      for (final doc in oldCapacities.docs) {
        capacityBatch.delete(doc.reference);
      }
      if (oldCapacities.docs.isNotEmpty) {
        await executeBatch(capacityBatch);
      }
      deletedCounts['capacities'] = oldCapacities.docs.length;

      _logger.i('Data cleanup completed: $deletedCounts');
      return deletedCounts;
    } catch (e) {
      _logger.e('Failed to cleanup old data: $e');
      rethrow;
    }
  }

  // Additional collection names for device data
  static const String _consentsCollection = 'patient_consents';

  // ============================================================================
  // DATA MIGRATION HELPERS
  // ============================================================================

  /// Provides a Firestore batch instance for bulk operations.
  WriteBatch getFirestoreBatch() {
    return _firestore.batch();
  }

  /// Retrieves all documents from a specified collection.
  /// Note: Use with caution on very large collections.
  Future<QuerySnapshot<Map<String, dynamic>>> getAllDocumentsFromCollection(
    String collectionPath,
  ) async {
    try {
      final querySnapshot = await _firestore.collection(collectionPath).get();
      // Assuming the calling service (DataMigrationService) will handle
      // the specific type of documents (e.g., via fromFirestore methods).
      return querySnapshot;
    } catch (e) {
      _logger.e('Failed to get all documents from $collectionPath: $e');
      rethrow;
    }
  }

  /// Gets the count of documents in a specified collection.
  Future<AggregateQuerySnapshot> getCountFromCollection(
    String collectionPath,
  ) async {
    try {
      final countQuery = _firestore.collection(collectionPath).count();
      final aggregateSnapshot = await countQuery.get();
      return aggregateSnapshot;
    } catch (e) {
      _logger.e('Failed to get count from $collectionPath: $e');
      rethrow;
    }
  }

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
          .map(
            (doc) => PatientVitalsFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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
        return PatientVitalsFirestore.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
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
          .map(
            (doc) => PatientVitalsFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e(
        'Failed to get patients with abnormal vitals from Firestore: $e',
      );
      return [];
    }
  }

  /// Get comprehensive patient history with filtering by date range, severity, and hospital
  Future<PatientHistoryData> getPatientHistory(
    String patientId, {
    DateTime? startDate,
    DateTime? endDate,
    UrgencyLevel? severityFilter,
    String? hospitalId,
    int vitalsLimit = 50,
    int triageLimit = 20,
    int consentsLimit = 10,
  }) async {
    try {
      // Get patient vitals with date filtering
      Query vitalsQuery = _firestore
          .collection(_vitalsCollection)
          .where('patientId', isEqualTo: patientId);

      if (startDate != null) {
        vitalsQuery = vitalsQuery.where(
          'timestamp',
          isGreaterThanOrEqualTo: startDate,
        );
      }
      if (endDate != null) {
        vitalsQuery = vitalsQuery.where(
          'timestamp',
          isLessThanOrEqualTo: endDate,
        );
      }

      vitalsQuery = vitalsQuery
          .orderBy('timestamp', descending: true)
          .limit(vitalsLimit);

      // Get triage results with filtering
      Query triageQuery = _firestore
          .collection(_triageResultsCollection)
          .where('patientId', isEqualTo: patientId);

      if (startDate != null) {
        triageQuery = triageQuery.where(
          'createdAt',
          isGreaterThanOrEqualTo: startDate,
        );
      }
      if (endDate != null) {
        triageQuery = triageQuery.where(
          'createdAt',
          isLessThanOrEqualTo: endDate,
        );
      }
      if (severityFilter != null) {
        triageQuery = triageQuery.where(
          'urgencyLevel',
          isEqualTo: severityFilter.toString(),
        );
      }
      if (hospitalId != null) {
        triageQuery = triageQuery.where(
          'recommendedHospitalId',
          isEqualTo: hospitalId,
        );
      }

      triageQuery = triageQuery
          .orderBy('createdAt', descending: true)
          .limit(triageLimit);

      // Get patient consents
      Query consentsQuery = _firestore
          .collection(_consentsCollection)
          .where('patientId', isEqualTo: patientId);

      if (startDate != null) {
        consentsQuery = consentsQuery.where(
          'grantedAt',
          isGreaterThanOrEqualTo: startDate,
        );
      }
      if (endDate != null) {
        consentsQuery = consentsQuery.where(
          'grantedAt',
          isLessThanOrEqualTo: endDate,
        );
      }

      consentsQuery = consentsQuery
          .orderBy('grantedAt', descending: true)
          .limit(consentsLimit);

      // Execute all queries concurrently
      final results = await Future.wait([
        vitalsQuery.get(),
        triageQuery.get(),
        consentsQuery.get(),
      ]);

      final vitalsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final triageSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final consentsSnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      // Convert to models
      final vitals = vitalsSnapshot.docs
          .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
          .toList();

      final triageResults = triageSnapshot.docs
          .map((doc) => TriageResultFirestore.fromFirestore(doc))
          .toList();

      final consents = consentsSnapshot.docs
          .map((doc) => PatientConsentFirestore.fromFirestore(doc))
          .toList();

      _logger.i('Retrieved patient history for patient: $patientId');

      return PatientHistoryData(
        patientId: patientId,
        vitals: vitals,
        triageResults: triageResults,
        consents: consents,
        retrievedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Failed to get patient history from Firestore: $e');
      return PatientHistoryData.empty(patientId);
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
            'geminiModelVersion':
                triageResult['geminiModelVersion'] ?? 'gemini-1.5-flash',
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

  /// Get patient triage results from Firestore
  Future<List<TriageResultFirestore>> getPatientTriageResults(
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
          .map(
            (doc) => TriageResultFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get patient triage results from Firestore: $e');
      return [];
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
          .map(
            (doc) => TriageResultFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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
          .map(
            (doc) => TriageResultFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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
          .map(
            (doc) => TriageResultFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
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

  /// Store patient vitals with device integration and data quality tracking
  Future<String> storePatientVitalsWithDevice(
    PatientVitalsFirestore vitals,
    DeviceDataQuality deviceQuality,
  ) async {
    try {
      // Enhanced vitals with device quality metrics
      final enhancedVitals = vitals.copyWith(
        accuracy: deviceQuality.overallAccuracy,
        isValidated: deviceQuality.isValidated,
      );

      // Store vitals
      final vitalsDocRef = await _firestore
          .collection(_vitalsCollection)
          .add(enhancedVitals.toFirestore());

      // Store device quality data
      if (vitals.deviceId != null) {
        await _firestore.collection('device_quality_logs').add({
          'deviceId': vitals.deviceId,
          'patientId': vitals.patientId,
          'vitalsId': vitalsDocRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'batteryLevel': deviceQuality.batteryLevel,
          'signalStrength': deviceQuality.signalStrength,
          'dataQualityScore': deviceQuality.dataQualityScore,
          'calibrationStatus': deviceQuality.calibrationStatus,
          'sensorAccuracy': deviceQuality.sensorAccuracy,
          'connectionStability': deviceQuality.connectionStability,
          'lastCalibration': deviceQuality.lastCalibration != null
              ? Timestamp.fromDate(deviceQuality.lastCalibration!)
              : null,
        });
      }

      _logger.i(
        'Patient vitals stored with device quality tracking: ${vitals.patientId}',
      );
      return vitalsDocRef.id;
    } catch (e) {
      _logger.e('Failed to store patient vitals with device data: $e');
      rethrow;
    }
  }

  /// Validate device data quality and trigger alerts if needed
  Future<bool> validateDeviceDataQuality(
    String deviceId,
    PatientVitalsFirestore vitals,
  ) async {
    try {
      // Get recent device quality data
      final recentQuality = await _firestore
          .collection('device_quality_logs')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (recentQuality.docs.isEmpty) {
        _logger.w('No device quality data found for device: $deviceId');
        return false;
      }

      final qualityLogs = recentQuality.docs
          .map((doc) => DeviceQualityLog.fromFirestore(doc))
          .toList();

      // Check for quality issues
      final avgQuality =
          qualityLogs.fold<double>(
            0,
            (sum, log) => sum + log.dataQualityScore,
          ) /
          qualityLogs.length;

      final hasLowBattery = qualityLogs.any(
        (log) => (log.batteryLevel ?? 100) < 20,
      );
      final hasWeakSignal = qualityLogs.any(
        (log) => (log.signalStrength ?? 1.0) < 0.5,
      );
      final needsCalibration = qualityLogs.any(
        (log) =>
            log.lastCalibration == null ||
            DateTime.now().difference(log.lastCalibration!).inDays > 30,
      );

      // Return true if quality is good
      return !(avgQuality < 0.7 ||
          hasLowBattery ||
          hasWeakSignal ||
          needsCalibration);
    } catch (e) {
      _logger.e('Failed to validate device data quality: $e');
      return false;
    }
  }

  /// Get device quality history for a patient
  Future<List<DeviceQualityLog>> getDeviceQualityHistory(
    String patientId, {
    String? deviceId,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('device_quality_logs')
          .where('patientId', isEqualTo: patientId);

      if (deviceId != null) {
        query = query.where('deviceId', isEqualTo: deviceId);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => DeviceQualityLog.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get device quality history: $e');
      return [];
    }
  }
}

// ============================================================================
// SUPPORTING DATA CLASSES
// ============================================================================

/// Patient history data container
class PatientHistoryData {
  final String patientId;
  final List<PatientVitalsFirestore> vitals;
  final List<TriageResultFirestore> triageResults;
  final List<PatientConsentFirestore> consents;
  final DateTime retrievedAt;

  const PatientHistoryData({
    required this.patientId,
    required this.vitals,
    required this.triageResults,
    required this.consents,
    required this.retrievedAt,
  });

  factory PatientHistoryData.empty(String patientId) {
    return PatientHistoryData(
      patientId: patientId,
      vitals: [],
      triageResults: [],
      consents: [],
      retrievedAt: DateTime.now(),
    );
  }

  bool get isEmpty =>
      vitals.isEmpty && triageResults.isEmpty && consents.isEmpty;
  bool get hasVitals => vitals.isNotEmpty;
  bool get hasTriageResults => triageResults.isNotEmpty;
  bool get hasConsents => consents.isNotEmpty;

  // Additional computed properties
  TriageResultFirestore? get latestTriageResult =>
      triageResults.isNotEmpty ? triageResults.first : null;

  PatientVitalsFirestore? get latestVitals =>
      vitals.isNotEmpty ? vitals.first : null;

  List<PatientConsentFirestore> get activeConsents =>
      consents.where((consent) => consent.isActive).toList();

  bool get hasCriticalCases => triageResults.any((result) => result.isCritical);

  double get averageSeverityScore {
    if (triageResults.isEmpty) return 0.0;
    final total = triageResults.fold<double>(
      0.0,
      (sum, result) => sum + result.severityScore,
    );
    return total / triageResults.length;
  }

  VitalsTrend get vitalsTrend {
    if (vitals.length < 2) return VitalsTrend.stable;

    // Simple trend analysis based on heart rate
    final recent = vitals.take(3).toList();
    final older = vitals.skip(3).take(3).toList();

    if (recent.isEmpty || older.isEmpty) return VitalsTrend.stable;

    final recentAvg =
        recent.fold<double>(0.0, (sum, v) => sum + (v.heartRate ?? 0)) /
        recent.length;

    final olderAvg =
        older.fold<double>(0.0, (sum, v) => sum + (v.heartRate ?? 0)) /
        older.length;

    final diff = recentAvg - olderAvg;
    if (diff > 10) return VitalsTrend.worsening;
    if (diff < -10) return VitalsTrend.improving;
    return VitalsTrend.stable;
  }

  int get length => triageResults.length;
  bool get isNotEmpty => !isEmpty;
  TriageResultFirestore get first => triageResults.first;
}

/// Vitals trend analysis
enum VitalsTrend {
  improving,
  stable,
  worsening;

  String get displayName {
    switch (this) {
      case VitalsTrend.improving:
        return 'Improving';
      case VitalsTrend.stable:
        return 'Stable';
      case VitalsTrend.worsening:
        return 'Worsening';
    }
  }
}

/// Device data quality metrics
class DeviceDataQuality {
  final double overallAccuracy;
  final bool isValidated;
  final double? batteryLevel;
  final double? signalStrength;
  final double dataQualityScore;
  final String calibrationStatus;
  final Map<String, double> sensorAccuracy;
  final double connectionStability;
  final DateTime? lastCalibration;

  const DeviceDataQuality({
    required this.overallAccuracy,
    required this.isValidated,
    this.batteryLevel,
    this.signalStrength,
    required this.dataQualityScore,
    required this.calibrationStatus,
    required this.sensorAccuracy,
    required this.connectionStability,
    this.lastCalibration,
  });
}

/// Device quality log entry
class DeviceQualityLog {
  final String id;
  final String deviceId;
  final String patientId;
  final String vitalsId;
  final DateTime timestamp;
  final double? batteryLevel;
  final double? signalStrength;
  final double dataQualityScore;
  final String calibrationStatus;
  final Map<String, double> sensorAccuracy;
  final double connectionStability;
  final DateTime? lastCalibration;

  const DeviceQualityLog({
    required this.id,
    required this.deviceId,
    required this.patientId,
    required this.vitalsId,
    required this.timestamp,
    this.batteryLevel,
    this.signalStrength,
    required this.dataQualityScore,
    required this.calibrationStatus,
    required this.sensorAccuracy,
    required this.connectionStability,
    this.lastCalibration,
  });

  factory DeviceQualityLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DeviceQualityLog(
      id: doc.id,
      deviceId: data['deviceId'] as String,
      patientId: data['patientId'] as String,
      vitalsId: data['vitalsId'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      batteryLevel: (data['batteryLevel'] as num?)?.toDouble(),
      signalStrength: (data['signalStrength'] as num?)?.toDouble(),
      dataQualityScore: (data['dataQualityScore'] as num).toDouble(),
      calibrationStatus: data['calibrationStatus'] as String,
      sensorAccuracy: Map<String, double>.from(
        (data['sensorAccuracy'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      connectionStability: (data['connectionStability'] as num).toDouble(),
      lastCalibration: (data['lastCalibration'] as Timestamp?)?.toDate(),
    );
  }
}

/// Consent audit log entry
class ConsentAuditLog {
  final String id;
  final String consentId;
  final String action;
  final String patientId;
  final String providerId;
  final String blockchainTxId;
  final String ipAddress;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const ConsentAuditLog({
    required this.id,
    required this.consentId,
    required this.action,
    required this.patientId,
    required this.providerId,
    required this.blockchainTxId,
    required this.ipAddress,
    required this.timestamp,
    required this.details,
  });

  factory ConsentAuditLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ConsentAuditLog(
      id: doc.id,
      consentId: data['consentId'] as String,
      action: data['action'] as String,
      patientId: data['patientId'] as String,
      providerId: data['providerId'] as String,
      blockchainTxId: data['blockchainTxId'] as String,
      ipAddress: data['ipAddress'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      details: Map<String, dynamic>.from(data['details'] as Map),
    );
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

  factory BatchOperation.update(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) {
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

  factory CapacityAnalytics.fromCapacities(
    List<HospitalCapacityFirestore> capacities,
  ) {
    if (capacities.isEmpty) return CapacityAnalytics.empty();

    final totalBeds = capacities.fold<int>(
      0,
      (accumulator, c) => accumulator + c.totalBeds,
    );
    final totalAvailable = capacities.fold<int>(
      0,
      (accumulator, c) => accumulator + c.availableBeds,
    );
    final avgOccupancy =
        capacities.fold<double>(
          0,
          (accumulator, c) => accumulator + c.occupancyRate,
        ) /
        capacities.length;
    final nearCapacity = capacities.where((c) => c.isNearCapacity).length;
    final atCapacity = capacities.where((c) => c.isAtCapacity).length;
    final avgWait =
        capacities.fold<double>(
          0,
          (accumulator, c) => accumulator + c.averageWaitTime,
        ) /
        capacities.length;

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
