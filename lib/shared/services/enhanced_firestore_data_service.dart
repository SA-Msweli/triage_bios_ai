import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'firebase_service.dart';
import 'offline_support_service.dart';
import 'firestore_performance_service.dart';
import 'optimized_query_service.dart';
import 'connection_pool_manager.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/triage_result_firestore.dart';
import '../models/firestore/patient_consent_firestore.dart';
import '../models/performance/query_filter.dart';
import '../models/performance/query_order.dart';
import '../models/performance/paginated_result.dart';

/// Enhanced Firestore data service with offline support and intelligent caching
class EnhancedFirestoreDataService {
  static final EnhancedFirestoreDataService _instance =
      EnhancedFirestoreDataService._internal();
  factory EnhancedFirestoreDataService() => _instance;
  EnhancedFirestoreDataService._internal();

  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  final OfflineSupportService _offlineService = OfflineSupportService();
  final FirestorePerformanceService _performanceService =
      FirestorePerformanceService();
  final OptimizedQueryService _optimizedQueryService = OptimizedQueryService();
  final ConnectionPoolManager _connectionPoolManager = ConnectionPoolManager();
  final Uuid _uuid = const Uuid();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // Collection names
  static const String _hospitalsCollection = 'hospitals';
  static const String _hospitalCapacityCollection = 'hospital_capacity';
  static const String _vitalsCollection = 'patient_vitals';
  static const String _triageResultsCollection = 'triage_results';
  static const String _patientConsentsCollection = 'patient_consents';

  // ============================================================================
  // HOSPITAL MANAGEMENT WITH OFFLINE SUPPORT
  // ============================================================================

  /// Get hospitals with offline support and intelligent caching
  Future<List<HospitalFirestore>> getHospitals({
    List<String>? specializations,
    int? minTraumaLevel,
    bool? isActive,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'hospitals_${specializations?.join(',') ?? 'all'}_${minTraumaLevel ?? 'any'}_${isActive ?? 'any'}_$limit';

    try {
      // Try cache first unless force refresh is requested
      if (!forceRefresh) {
        final cachedData = await _offlineService.getCachedData<List<dynamic>>(
          cacheKey,
        );
        if (cachedData != null) {
          _logger.d('Returning cached hospitals data');
          return cachedData
              .map((data) => HospitalFirestore.fromJson(data))
              .toList();
        }
      }

      // Fetch from Firestore
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
      final hospitals = querySnapshot.docs
          .map(
            (doc) => HospitalFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();

      // Cache the results with critical priority for active hospitals
      await _offlineService.cacheData(
        key: cacheKey,
        data: hospitals.map((h) => h.toJson()).toList(),
        priority: (isActive == true)
            ? DataPriority.critical
            : DataPriority.high,
      );

      return hospitals;
    } catch (e) {
      _logger.e('Failed to get hospitals: $e');

      // Try to return cached data as fallback
      final cachedData = await _offlineService.getCachedData<List<dynamic>>(
        cacheKey,
      );
      if (cachedData != null) {
        _logger.i('Returning cached hospitals data as fallback');
        return cachedData
            .map((data) => HospitalFirestore.fromJson(data))
            .toList();
      }

      return [];
    }
  }

  /// Get hospital by ID with offline support
  Future<HospitalFirestore?> getHospitalById(
    String hospitalId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'hospital_$hospitalId';

    try {
      // Try cache first unless force refresh is requested
      if (!forceRefresh) {
        final cachedData = await _offlineService
            .getCachedData<Map<String, dynamic>>(cacheKey);
        if (cachedData != null) {
          _logger.d('Returning cached hospital data for $hospitalId');
          return HospitalFirestore.fromJson(cachedData);
        }
      }

      final doc = await _firestore
          .collection(_hospitalsCollection)
          .doc(hospitalId)
          .get();

      if (doc.exists) {
        final hospital = HospitalFirestore.fromFirestore(doc);

        // Cache with critical priority
        await _offlineService.cacheData(
          key: cacheKey,
          data: hospital.toJson(),
          priority: DataPriority.critical,
        );

        return hospital;
      }

      return null;
    } catch (e) {
      _logger.e('Failed to get hospital by ID: $e');

      // Try cached data as fallback
      final cachedData = await _offlineService
          .getCachedData<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        _logger.i('Returning cached hospital data as fallback for $hospitalId');
        return HospitalFirestore.fromJson(cachedData);
      }

      return null;
    }
  }

  /// Create hospital with offline support
  Future<String> createHospital(HospitalFirestore hospital) async {
    try {
      if (_offlineService.isOnline) {
        // Online: Create directly
        final docRef = await _firestore
            .collection(_hospitalsCollection)
            .add(hospital.toFirestore());

        // Cache the created hospital
        await _offlineService.cacheData(
          key: 'hospital_${docRef.id}',
          data: hospital.toJson(),
          priority: DataPriority.critical,
        );

        _logger.i('Hospital created online: ${hospital.name}');
        return docRef.id;
      } else {
        // Offline: Queue operation
        final tempId = _uuid.v4();

        await _offlineService.addOfflineOperation(
          OfflineOperation(
            id: _uuid.v4(),
            collection: _hospitalsCollection,
            documentId: tempId,
            operation: 'create',
            data: hospital.toFirestore(),
            timestamp: DateTime.now(),
            priority: DataPriority.critical,
          ),
        );

        // Cache locally with temporary ID
        await _offlineService.cacheData(
          key: 'hospital_$tempId',
          data: hospital.toJson(),
          priority: DataPriority.critical,
        );

        _logger.i('Hospital queued for creation: ${hospital.name}');
        return tempId;
      }
    } catch (e) {
      _logger.e('Failed to create hospital: $e');
      rethrow;
    }
  }

  /// Update hospital with offline support
  Future<void> updateHospital(
    String hospitalId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (_offlineService.isOnline) {
        // Online: Update directly
        await _firestore
            .collection(_hospitalsCollection)
            .doc(hospitalId)
            .update(updates);

        // Update cache
        final cachedData = await _offlineService
            .getCachedData<Map<String, dynamic>>('hospital_$hospitalId');
        if (cachedData != null) {
          cachedData.addAll(updates);
          await _offlineService.cacheData(
            key: 'hospital_$hospitalId',
            data: cachedData,
            priority: DataPriority.critical,
          );
        }

        _logger.i('Hospital updated online: $hospitalId');
      } else {
        // Offline: Queue operation
        await _offlineService.addOfflineOperation(
          OfflineOperation(
            id: _uuid.v4(),
            collection: _hospitalsCollection,
            documentId: hospitalId,
            operation: 'update',
            data: updates,
            timestamp: DateTime.now(),
            priority: DataPriority.critical,
          ),
        );

        // Update local cache
        final cachedData = await _offlineService
            .getCachedData<Map<String, dynamic>>('hospital_$hospitalId');
        if (cachedData != null) {
          cachedData.addAll(updates);
          await _offlineService.cacheData(
            key: 'hospital_$hospitalId',
            data: cachedData,
            priority: DataPriority.critical,
          );
        }

        _logger.i('Hospital update queued: $hospitalId');
      }
    } catch (e) {
      _logger.e('Failed to update hospital: $e');
      rethrow;
    }
  }

  // ============================================================================
  // HOSPITAL CAPACITY WITH REAL-TIME CACHING
  // ============================================================================

  /// Get hospital capacity with offline support
  Future<HospitalCapacityFirestore?> getHospitalCapacity(
    String hospitalId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'capacity_$hospitalId';

    try {
      // Try cache first unless force refresh is requested
      if (!forceRefresh) {
        final cachedData = await _offlineService
            .getCachedData<Map<String, dynamic>>(cacheKey);
        if (cachedData != null) {
          _logger.d('Returning cached capacity data for $hospitalId');
          return HospitalCapacityFirestore.fromJson(cachedData);
        }
      }

      final querySnapshot = await _firestore
          .collection(_hospitalCapacityCollection)
          .where('hospitalId', isEqualTo: hospitalId)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final capacity = HospitalCapacityFirestore.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );

        // Cache with high priority and short TTL for real-time data
        await _offlineService.cacheData(
          key: cacheKey,
          data: capacity.toJson(),
          priority: DataPriority.high,
          customTTL: const Duration(minutes: 5), // Short TTL for capacity data
        );

        return capacity;
      }

      return null;
    } catch (e) {
      _logger.e('Failed to get hospital capacity: $e');

      // Try cached data as fallback
      final cachedData = await _offlineService
          .getCachedData<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        _logger.i('Returning cached capacity data as fallback for $hospitalId');
        return HospitalCapacityFirestore.fromJson(cachedData);
      }

      return null;
    }
  }

  /// Update hospital capacity with offline support
  Future<void> updateHospitalCapacity(
    HospitalCapacityFirestore capacity,
  ) async {
    try {
      if (_offlineService.isOnline) {
        // Online: Update directly
        await _firestore
            .collection(_hospitalCapacityCollection)
            .add(capacity.toFirestore());

        // Cache the updated capacity
        await _offlineService.cacheData(
          key: 'capacity_${capacity.hospitalId}',
          data: capacity.toJson(),
          priority: DataPriority.high,
          customTTL: const Duration(minutes: 5),
        );

        _logger.i('Hospital capacity updated online: ${capacity.hospitalId}');
      } else {
        // Offline: Queue operation
        await _offlineService.addOfflineOperation(
          OfflineOperation(
            id: _uuid.v4(),
            collection: _hospitalCapacityCollection,
            documentId: _uuid
                .v4(), // Generate new document for capacity updates
            operation: 'create',
            data: capacity.toFirestore(),
            timestamp: DateTime.now(),
            priority: DataPriority.high,
          ),
        );

        // Update local cache
        await _offlineService.cacheData(
          key: 'capacity_${capacity.hospitalId}',
          data: capacity.toJson(),
          priority: DataPriority.high,
          customTTL: const Duration(minutes: 5),
        );

        _logger.i('Hospital capacity update queued: ${capacity.hospitalId}');
      }
    } catch (e) {
      _logger.e('Failed to update hospital capacity: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PATIENT DATA WITH OFFLINE SUPPORT
  // ============================================================================

  /// Store patient vitals with offline support
  Future<void> storePatientVitals(PatientVitalsFirestore vitals) async {
    try {
      if (_offlineService.isOnline) {
        // Online: Store directly
        await _firestore
            .collection(_vitalsCollection)
            .add(vitals.toFirestore());

        // Cache recent vitals
        await _offlineService.cacheData(
          key: 'vitals_${vitals.patientId}_latest',
          data: vitals.toJson(),
          priority: DataPriority.high,
        );

        _logger.i('Patient vitals stored online: ${vitals.patientId}');
      } else {
        // Offline: Queue operation
        await _offlineService.addOfflineOperation(
          OfflineOperation(
            id: _uuid.v4(),
            collection: _vitalsCollection,
            documentId: _uuid.v4(),
            operation: 'create',
            data: vitals.toFirestore(),
            timestamp: DateTime.now(),
            priority: DataPriority.high,
          ),
        );

        // Cache locally
        await _offlineService.cacheData(
          key: 'vitals_${vitals.patientId}_latest',
          data: vitals.toJson(),
          priority: DataPriority.high,
        );

        _logger.i('Patient vitals queued for storage: ${vitals.patientId}');
      }
    } catch (e) {
      _logger.e('Failed to store patient vitals: $e');
      rethrow;
    }
  }

  /// Store triage result with offline support
  Future<void> storeTriageResult(TriageResultFirestore result) async {
    try {
      if (_offlineService.isOnline) {
        // Online: Store directly
        await _firestore
            .collection(_triageResultsCollection)
            .add(result.toFirestore());

        // Cache recent triage result
        await _offlineService.cacheData(
          key: 'triage_${result.patientId}_latest',
          data: result.toJson(),
          priority: DataPriority.medium,
        );

        _logger.i('Triage result stored online: ${result.patientId}');
      } else {
        // Offline: Queue operation
        await _offlineService.addOfflineOperation(
          OfflineOperation(
            id: _uuid.v4(),
            collection: _triageResultsCollection,
            documentId: _uuid.v4(),
            operation: 'create',
            data: result.toFirestore(),
            timestamp: DateTime.now(),
            priority: DataPriority.medium,
          ),
        );

        // Cache locally
        await _offlineService.cacheData(
          key: 'triage_${result.patientId}_latest',
          data: result.toJson(),
          priority: DataPriority.medium,
        );

        _logger.i('Triage result queued for storage: ${result.patientId}');
      }
    } catch (e) {
      _logger.e('Failed to store triage result: $e');
      rethrow;
    }
  }

  /// Get patient history with offline support
  Future<List<TriageResultFirestore>> getPatientHistory(
    String patientId, {
    int limit = 10,
  }) async {
    final cacheKey = 'history_${patientId}_$limit';

    try {
      // Try cache first
      final cachedData = await _offlineService.getCachedData<List<dynamic>>(
        cacheKey,
      );
      if (cachedData != null) {
        _logger.d('Returning cached patient history for $patientId');
        return cachedData
            .map((data) => TriageResultFirestore.fromJson(data))
            .toList();
      }

      final querySnapshot = await _firestore
          .collection(_triageResultsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final results = querySnapshot.docs
          .map(
            (doc) => TriageResultFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();

      // Cache the results
      await _offlineService.cacheData(
        key: cacheKey,
        data: results.map((r) => r.toJson()).toList(),
        priority: DataPriority.medium,
      );

      return results;
    } catch (e) {
      _logger.e('Failed to get patient history: $e');

      // Try cached data as fallback
      final cachedData = await _offlineService.getCachedData<List<dynamic>>(
        cacheKey,
      );
      if (cachedData != null) {
        _logger.i(
          'Returning cached patient history as fallback for $patientId',
        );
        return cachedData
            .map((data) => TriageResultFirestore.fromJson(data))
            .toList();
      }

      return [];
    }
  }

  // ============================================================================
  // REAL-TIME LISTENERS WITH OFFLINE FALLBACK
  // ============================================================================

  /// Listen to hospital capacity updates with offline fallback
  Stream<List<HospitalCapacityFirestore>> listenToHospitalCapacities(
    List<String> hospitalIds,
  ) {
    if (hospitalIds.isEmpty) {
      return Stream.value([]);
    }

    try {
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

              // Cache each capacity update
              _offlineService.cacheData(
                key: 'capacity_${capacity.hospitalId}',
                data: capacity.toJson(),
                priority: DataPriority.high,
                customTTL: const Duration(minutes: 5),
              );

              final existing = capacityMap[capacity.hospitalId];
              if (existing == null ||
                  capacity.lastUpdated.isAfter(existing.lastUpdated)) {
                capacityMap[capacity.hospitalId] = capacity;
              }
            }
            return capacityMap.values.toList();
          })
          .handleError((error) {
            _logger.e('Real-time capacity listener error: $error');
            // Could implement fallback to cached data here
          });
    } catch (e) {
      _logger.e('Failed to setup capacity listener: $e');
      return Stream.value([]);
    }
  }

  /// Listen to patient vitals with offline fallback
  Stream<List<PatientVitalsFirestore>> listenToPatientVitals(
    String patientId, {
    int limit = 10,
  }) {
    try {
      return _firestore
          .collection(_vitalsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final vitals = snapshot.docs
                .map(
                  (doc) => PatientVitalsFirestore.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList();

            // Cache the latest vitals
            if (vitals.isNotEmpty) {
              _offlineService.cacheData(
                key: 'vitals_${patientId}_latest',
                data: vitals.first.toJson(),
                priority: DataPriority.high,
              );
            }

            return vitals;
          })
          .handleError((error) {
            _logger.e('Real-time vitals listener error: $error');
          });
    } catch (e) {
      _logger.e('Failed to setup vitals listener: $e');
      return Stream.value([]);
    }
  }

  // ============================================================================
  // BATCH OPERATIONS WITH OFFLINE SUPPORT
  // ============================================================================

  /// Batch create hospitals with offline support
  Future<void> batchCreateHospitals(List<HospitalFirestore> hospitals) async {
    if (hospitals.isEmpty) return;

    try {
      if (_offlineService.isOnline) {
        // Online: Execute batch directly
        final batch = _firestore.batch();

        for (final hospital in hospitals) {
          final docRef = _firestore.collection(_hospitalsCollection).doc();
          batch.set(docRef, hospital.toFirestore());

          // Cache each hospital
          _offlineService.cacheData(
            key: 'hospital_${docRef.id}',
            data: hospital.toJson(),
            priority: DataPriority.critical,
          );
        }

        await batch.commit();
        _logger.i('Batch created ${hospitals.length} hospitals online');
      } else {
        // Offline: Queue each operation
        for (final hospital in hospitals) {
          final tempId = _uuid.v4();

          await _offlineService.addOfflineOperation(
            OfflineOperation(
              id: _uuid.v4(),
              collection: _hospitalsCollection,
              documentId: tempId,
              operation: 'create',
              data: hospital.toFirestore(),
              timestamp: DateTime.now(),
              priority: DataPriority.critical,
            ),
          );

          // Cache locally
          await _offlineService.cacheData(
            key: 'hospital_$tempId',
            data: hospital.toJson(),
            priority: DataPriority.critical,
          );
        }

        _logger.i('Batch queued ${hospitals.length} hospitals for creation');
      }
    } catch (e) {
      _logger.e('Failed to batch create hospitals: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Force refresh critical data from server
  Future<void> refreshCriticalData() async {
    try {
      if (!_offlineService.isOnline) {
        _logger.w('Cannot refresh critical data while offline');
        return;
      }

      // Refresh active hospitals
      await getHospitals(isActive: true, forceRefresh: true);

      // Refresh recent capacity data
      final hospitalsSnapshot = await _firestore
          .collection(_hospitalsCollection)
          .where('isActive', isEqualTo: true)
          .limit(50)
          .get();

      for (final doc in hospitalsSnapshot.docs) {
        await getHospitalCapacity(doc.id, forceRefresh: true);
      }

      _logger.i('Critical data refreshed successfully');
    } catch (e) {
      _logger.e('Failed to refresh critical data: $e');
    }
  }

  // ============================================================================
  // PERFORMANCE OPTIMIZED METHODS
  // ============================================================================

  /// Get hospitals with pagination and performance optimization
  Future<PaginatedResult<HospitalFirestore>> getHospitalsPaginated({
    List<String>? specializations,
    int? minTraumaLevel,
    bool? isActive,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int pageSize = 20,
    String? pageToken,
  }) async {
    return await _optimizedQueryService.getHospitalsPaginated(
      specializations: specializations,
      minTraumaLevel: minTraumaLevel,
      isActive: isActive,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      pageSize: pageSize,
      pageToken: pageToken,
    );
  }

  /// Get patient vitals with pagination and performance optimization
  Future<PaginatedResult<PatientVitalsFirestore>> getPatientVitalsPaginated({
    required String patientId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? sources,
    bool? hasAbnormalVitals,
    int pageSize = 20,
    String? pageToken,
  }) async {
    return await _optimizedQueryService.getPatientVitalsPaginated(
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
      sources: sources,
      hasAbnormalVitals: hasAbnormalVitals,
      pageSize: pageSize,
      pageToken: pageToken,
    );
  }

  /// Get triage results with pagination and performance optimization
  Future<PaginatedResult<TriageResultFirestore>> getTriageResultsPaginated({
    String? patientId,
    String? hospitalId,
    UrgencyLevel? urgencyLevel,
    bool? isCritical,
    DateTime? startDate,
    DateTime? endDate,
    int pageSize = 20,
    String? pageToken,
  }) async {
    return await _optimizedQueryService.getTriageResultsPaginated(
      patientId: patientId,
      hospitalId: hospitalId,
      urgencyLevel: urgencyLevel,
      isCritical: isCritical,
      startDate: startDate,
      endDate: endDate,
      pageSize: pageSize,
      pageToken: pageToken,
    );
  }

  /// Create optimized real-time listener for hospital capacities
  StreamSubscription<List<HospitalCapacityFirestore>>
  listenToOptimizedCapacityUpdates({
    required String listenerId,
    List<String>? hospitalIds,
    required void Function(List<HospitalCapacityFirestore>) onUpdate,
    required void Function(Object) onError,
  }) {
    return _optimizedQueryService.listenToCapacityUpdates(
      listenerId: listenerId,
      hospitalIds: hospitalIds,
      onUpdate: onUpdate,
      onError: onError,
    );
  }

  /// Create optimized real-time listener for patient vitals
  StreamSubscription<List<PatientVitalsFirestore>>
  listenToOptimizedPatientVitals({
    required String listenerId,
    required String patientId,
    int limit = 10,
    required void Function(List<PatientVitalsFirestore>) onUpdate,
    required void Function(Object) onError,
  }) {
    return _optimizedQueryService.listenToPatientVitals(
      listenerId: listenerId,
      patientId: patientId,
      limit: limit,
      onUpdate: onUpdate,
      onError: onError,
    );
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'queryMetrics': _performanceService.getQueryMetrics(),
      'performanceSummary': _performanceService.getPerformanceSummary(),
      'connectionMetrics': _connectionPoolManager.getConnectionMetrics(),
      'poolStatistics': _connectionPoolManager.getPoolStatistics(),
    };
  }

  /// Start performance monitoring
  Future<void> startPerformanceMonitoring() async {
    _connectionPoolManager.startCleanup();
    _logger.i('Started performance monitoring for enhanced Firestore service');
  }

  /// Stop performance monitoring
  Future<void> stopPerformanceMonitoring() async {
    _connectionPoolManager.stopCleanup();
    _logger.i('Stopped performance monitoring for enhanced Firestore service');
  }

  /// Get offline support service instance
  OfflineSupportService get offlineService => _offlineService;

  /// Get performance service instance
  FirestorePerformanceService get performanceService => _performanceService;

  /// Get optimized query service instance
  OptimizedQueryService get optimizedQueryService => _optimizedQueryService;

  /// Dispose all resources
  void dispose() {
    _performanceService.dispose();
    _optimizedQueryService.dispose();
    _connectionPoolManager.dispose();
  }
}
