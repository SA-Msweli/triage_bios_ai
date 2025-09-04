import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'firestore_performance_service.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/triage_result_firestore.dart';
import '../models/performance/query_filter.dart';
import '../models/performance/query_order.dart';
import '../models/performance/paginated_result.dart';

/// Service providing optimized Firestore queries with performance monitoring
class OptimizedQueryService {
  static final OptimizedQueryService _instance =
      OptimizedQueryService._internal();
  factory OptimizedQueryService() => _instance;
  OptimizedQueryService._internal();

  final Logger _logger = Logger();
  final FirestorePerformanceService _performanceService =
      FirestorePerformanceService();

  // Collection names
  static const String _hospitalsCollection = 'hospitals';
  static const String _hospitalCapacityCollection = 'hospital_capacity';
  static const String _vitalsCollection = 'patient_vitals';
  static const String _triageResultsCollection = 'triage_results';

  // ============================================================================
  // OPTIMIZED HOSPITAL QUERIES
  // ============================================================================

  /// Get hospitals with optimized query and pagination
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
    final filters = <QueryFilter>[];
    final orderBy = <QueryOrder>[];

    // Build filters
    if (isActive != null) {
      filters.add(QueryFilter.isEqualTo('isActive', isActive));
    }

    if (minTraumaLevel != null) {
      filters.add(
        QueryFilter.isGreaterThanOrEqualTo('traumaLevel', minTraumaLevel),
      );
    }

    if (specializations != null && specializations.isNotEmpty) {
      filters.add(
        QueryFilter.arrayContainsAny('specializations', specializations),
      );
    }

    // Add location-based filtering if coordinates provided
    if (latitude != null && longitude != null && radiusKm != null) {
      // Use bounding box for initial filtering
      final latRange = radiusKm / 111.0; // Rough conversion
      filters.add(
        QueryFilter.isGreaterThan('location.latitude', latitude - latRange),
      );
      filters.add(
        QueryFilter.isLessThan('location.latitude', latitude + latRange),
      );
    }

    // Default ordering
    orderBy.add(QueryOrder.desc('updatedAt'));

    return await _performanceService.executePaginatedQuery<HospitalFirestore>(
      collectionPath: _hospitalsCollection,
      queryId: 'hospitals_paginated',
      fromFirestore: (doc) => HospitalFirestore.fromFirestore(doc),
      filters: filters,
      orderBy: orderBy,
      pageSize: pageSize,
      pageToken: pageToken,
    );
  }

  /// Get hospitals by availability with optimized queries
  Future<PaginatedResult<Map<String, dynamic>>> getHospitalsByAvailability({
    required UrgencyLevel urgencyLevel,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int pageSize = 15,
    String? pageToken,
  }) async {
    // First get hospitals
    final hospitalResult = await getHospitalsPaginated(
      isActive: true,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      pageSize: pageSize * 2, // Get more to filter by capacity
      pageToken: pageToken,
    );

    if (hospitalResult.items.isEmpty) {
      return PaginatedResult.empty();
    }

    // Get capacity data for these hospitals
    final hospitalIds = hospitalResult.items.map((h) => h.id).toList();
    final capacities = await getHospitalCapacitiesBatch(hospitalIds);
    final capacityMap = <String, HospitalCapacityFirestore>{};
    for (final capacity in capacities) {
      capacityMap[capacity.hospitalId] = capacity;
    }

    // Filter and combine data based on urgency requirements
    final combinedResults = <Map<String, dynamic>>[];

    for (final hospital in hospitalResult.items) {
      final capacity = capacityMap[hospital.id];
      if (capacity == null) continue;

      // Apply urgency-based filtering
      if (_meetsUrgencyRequirements(capacity, urgencyLevel)) {
        combinedResults.add({
          'hospital': hospital,
          'capacity': capacity,
          'score': _calculateHospitalScore(
            hospital,
            capacity,
            latitude,
            longitude,
          ),
        });
      }
    }

    // Sort by score
    combinedResults.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    // Take only the requested page size
    final pageItems = combinedResults.take(pageSize).toList();

    return PaginatedResult<Map<String, dynamic>>(
      items: pageItems,
      hasMore: combinedResults.length > pageSize || hospitalResult.hasMore,
      nextPageToken: hospitalResult.nextPageToken,
    );
  }

  /// Get hospital capacities in batch with optimization
  Future<List<HospitalCapacityFirestore>> getHospitalCapacitiesBatch(
    List<String> hospitalIds,
  ) async {
    if (hospitalIds.isEmpty) return [];

    // Split into chunks to avoid Firestore 'in' query limits
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (int i = 0; i < hospitalIds.length; i += chunkSize) {
      chunks.add(hospitalIds.skip(i).take(chunkSize).toList());
    }

    final allCapacities = <HospitalCapacityFirestore>[];

    // Execute queries in parallel
    final futures = chunks.map((chunk) async {
      final result = await _performanceService.executeOptimizedQuery(
        collectionPath: _hospitalCapacityCollection,
        queryId: 'hospital_capacities_batch',
        filters: [QueryFilter.whereIn('hospitalId', chunk)],
        orderBy: [QueryOrder.desc('lastUpdated')],
      );

      return result.docs
          .map((doc) => HospitalCapacityFirestore.fromFirestore(doc))
          .toList();
    });

    final results = await Future.wait(futures);
    for (final capacities in results) {
      allCapacities.addAll(capacities);
    }

    // Group by hospital ID and get most recent for each
    final capacityMap = <String, HospitalCapacityFirestore>{};
    for (final capacity in allCapacities) {
      final existing = capacityMap[capacity.hospitalId];
      if (existing == null ||
          capacity.lastUpdated.isAfter(existing.lastUpdated)) {
        capacityMap[capacity.hospitalId] = capacity;
      }
    }

    return capacityMap.values.toList();
  }

  // ============================================================================
  // OPTIMIZED PATIENT DATA QUERIES
  // ============================================================================

  /// Get patient vitals with pagination and optimization
  Future<PaginatedResult<PatientVitalsFirestore>> getPatientVitalsPaginated({
    required String patientId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? sources,
    bool? hasAbnormalVitals,
    int pageSize = 20,
    String? pageToken,
  }) async {
    final filters = <QueryFilter>[
      QueryFilter.isEqualTo('patientId', patientId),
    ];

    if (startDate != null) {
      filters.add(
        QueryFilter.isGreaterThanOrEqualTo(
          'timestamp',
          Timestamp.fromDate(startDate),
        ),
      );
    }

    if (endDate != null) {
      filters.add(
        QueryFilter.isLessThanOrEqualTo(
          'timestamp',
          Timestamp.fromDate(endDate),
        ),
      );
    }

    if (sources != null && sources.isNotEmpty) {
      filters.add(QueryFilter.whereIn('source', sources));
    }

    if (hasAbnormalVitals != null) {
      filters.add(
        QueryFilter.isEqualTo('hasAbnormalVitals', hasAbnormalVitals),
      );
    }

    return await _performanceService
        .executePaginatedQuery<PatientVitalsFirestore>(
          collectionPath: _vitalsCollection,
          queryId: 'patient_vitals_paginated',
          fromFirestore: (doc) => PatientVitalsFirestore.fromFirestore(doc),
          filters: filters,
          orderBy: [QueryOrder.desc('timestamp')],
          pageSize: pageSize,
          pageToken: pageToken,
        );
  }

  /// Get critical vitals across all patients with optimization
  Future<PaginatedResult<PatientVitalsFirestore>> getCriticalVitalsPaginated({
    double minSeverityScore = 2.0,
    DateTime? since,
    int pageSize = 25,
    String? pageToken,
  }) async {
    final filters = <QueryFilter>[
      QueryFilter.isEqualTo('hasAbnormalVitals', true),
      QueryFilter.isGreaterThanOrEqualTo(
        'vitalsSeverityScore',
        minSeverityScore,
      ),
    ];

    if (since != null) {
      filters.add(
        QueryFilter.isGreaterThanOrEqualTo(
          'timestamp',
          Timestamp.fromDate(since),
        ),
      );
    }

    return await _performanceService
        .executePaginatedQuery<PatientVitalsFirestore>(
          collectionPath: _vitalsCollection,
          queryId: 'critical_vitals_paginated',
          fromFirestore: (doc) => PatientVitalsFirestore.fromFirestore(doc),
          filters: filters,
          orderBy: [
            QueryOrder.desc('vitalsSeverityScore'),
            QueryOrder.desc('timestamp'),
          ],
          pageSize: pageSize,
          pageToken: pageToken,
        );
  }

  /// Get triage results with pagination and optimization
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
    final filters = <QueryFilter>[];

    if (patientId != null) {
      filters.add(QueryFilter.isEqualTo('patientId', patientId));
    }

    if (hospitalId != null) {
      filters.add(QueryFilter.isEqualTo('recommendedHospitalId', hospitalId));
    }

    if (urgencyLevel != null) {
      filters.add(
        QueryFilter.isEqualTo('urgencyLevel', urgencyLevel.name.toUpperCase()),
      );
    }

    if (isCritical != null) {
      filters.add(QueryFilter.isEqualTo('isCritical', isCritical));
    }

    if (startDate != null) {
      filters.add(
        QueryFilter.isGreaterThanOrEqualTo(
          'createdAt',
          Timestamp.fromDate(startDate),
        ),
      );
    }

    if (endDate != null) {
      filters.add(
        QueryFilter.isLessThanOrEqualTo(
          'createdAt',
          Timestamp.fromDate(endDate),
        ),
      );
    }

    return await _performanceService
        .executePaginatedQuery<TriageResultFirestore>(
          collectionPath: _triageResultsCollection,
          queryId: 'triage_results_paginated',
          fromFirestore: (doc) => TriageResultFirestore.fromFirestore(doc),
          filters: filters,
          orderBy: [QueryOrder.desc('createdAt')],
          pageSize: pageSize,
          pageToken: pageToken,
        );
  }

  // ============================================================================
  // OPTIMIZED REAL-TIME LISTENERS
  // ============================================================================

  /// Create optimized capacity listener
  StreamSubscription<List<HospitalCapacityFirestore>> listenToCapacityUpdates({
    required String listenerId,
    List<String>? hospitalIds,
    required void Function(List<HospitalCapacityFirestore>) onUpdate,
    required void Function(Object) onError,
  }) {
    final filters = <QueryFilter>[];

    if (hospitalIds != null && hospitalIds.isNotEmpty) {
      // Split into chunks if too many IDs
      if (hospitalIds.length <= 10) {
        filters.add(QueryFilter.whereIn('hospitalId', hospitalIds));
      } else {
        // For more than 10 hospitals, we'll need to create multiple listeners
        // For now, just listen to all and filter in memory
        _logger.w(
          'Listening to all capacity updates due to large hospital ID list',
        );
      }
    }

    return _performanceService.createOptimizedListener(
      listenerId: listenerId,
      collectionPath: _hospitalCapacityCollection,
      filters: filters,
      orderBy: [QueryOrder.desc('lastUpdated')],
      limit: 100,
      onData: (snapshot) {
        final capacities = snapshot.docs
            .map((doc) => HospitalCapacityFirestore.fromFirestore(doc))
            .toList();

        // Group by hospital ID and get most recent
        final capacityMap = <String, HospitalCapacityFirestore>{};
        for (final capacity in capacities) {
          final existing = capacityMap[capacity.hospitalId];
          if (existing == null ||
              capacity.lastUpdated.isAfter(existing.lastUpdated)) {
            capacityMap[capacity.hospitalId] = capacity;
          }
        }

        // Filter by hospital IDs if specified and we're listening to all
        List<HospitalCapacityFirestore> filteredCapacities = capacityMap.values
            .toList();
        if (hospitalIds != null && hospitalIds.length > 10) {
          filteredCapacities = filteredCapacities
              .where((c) => hospitalIds.contains(c.hospitalId))
              .toList();
        }

        onUpdate(filteredCapacities);
      },
      onError: onError,
    );
  }

  /// Create optimized patient vitals listener
  StreamSubscription<List<PatientVitalsFirestore>> listenToPatientVitals({
    required String listenerId,
    required String patientId,
    int limit = 10,
    required void Function(List<PatientVitalsFirestore>) onUpdate,
    required void Function(Object) onError,
  }) {
    return _performanceService.createOptimizedListener(
      listenerId: listenerId,
      collectionPath: _vitalsCollection,
      filters: [QueryFilter.isEqualTo('patientId', patientId)],
      orderBy: [QueryOrder.desc('timestamp')],
      limit: limit,
      onData: (snapshot) {
        final vitals = snapshot.docs
            .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
            .toList();
        onUpdate(vitals);
      },
      onError: onError,
    );
  }

  /// Create optimized critical vitals listener
  StreamSubscription<List<PatientVitalsFirestore>> listenToCriticalVitals({
    required String listenerId,
    double minSeverityScore = 2.0,
    int limit = 50,
    required void Function(List<PatientVitalsFirestore>) onUpdate,
    required void Function(Object) onError,
  }) {
    return _performanceService.createOptimizedListener(
      listenerId: listenerId,
      collectionPath: _vitalsCollection,
      filters: [
        QueryFilter.isEqualTo('hasAbnormalVitals', true),
        QueryFilter.isGreaterThanOrEqualTo(
          'vitalsSeverityScore',
          minSeverityScore,
        ),
      ],
      orderBy: [
        QueryOrder.desc('vitalsSeverityScore'),
        QueryOrder.desc('timestamp'),
      ],
      limit: limit,
      onData: (snapshot) {
        final vitals = snapshot.docs
            .map((doc) => PatientVitalsFirestore.fromFirestore(doc))
            .toList();
        onUpdate(vitals);
      },
      onError: onError,
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if hospital capacity meets urgency requirements
  bool _meetsUrgencyRequirements(
    HospitalCapacityFirestore capacity,
    UrgencyLevel urgencyLevel,
  ) {
    switch (urgencyLevel) {
      case UrgencyLevel.critical:
        return capacity.availableBeds > 0 && capacity.emergencyAvailable > 0;
      case UrgencyLevel.urgent:
        return capacity.availableBeds >= 2 &&
            capacity.occupancyRate < 0.95 &&
            capacity.averageWaitTime <= 60;
      case UrgencyLevel.standard:
        return capacity.availableBeds >= 3 &&
            capacity.occupancyRate < 0.90 &&
            capacity.averageWaitTime <= 120;
      case UrgencyLevel.nonUrgent:
        return capacity.availableBeds >= 5 &&
            capacity.occupancyRate < 0.85 &&
            capacity.averageWaitTime <= 240;
    }
  }

  /// Calculate hospital score for ranking
  double _calculateHospitalScore(
    HospitalFirestore hospital,
    HospitalCapacityFirestore capacity,
    double? latitude,
    double? longitude,
  ) {
    double score = 0.0;

    // Capacity score (40% weight)
    final capacityScore = (capacity.availableBeds / capacity.totalBeds) * 0.4;
    score += capacityScore;

    // Wait time score (30% weight)
    final waitTimeScore =
        (1.0 - (capacity.averageWaitTime / 240).clamp(0.0, 1.0)) * 0.3;
    score += waitTimeScore;

    // Trauma level score (20% weight)
    final traumaScore = (hospital.traumaLevel / 4.0) * 0.2;
    score += traumaScore;

    // Distance score (10% weight) - only if location provided
    if (latitude != null && longitude != null) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        hospital.location.latitude,
        hospital.location.longitude,
      );
      final distanceScore = (1.0 - (distance / 50.0).clamp(0.0, 1.0)) * 0.1;
      score += distanceScore;
    } else {
      score += 0.05; // Neutral score if no location
    }

    return score;
  }

  /// Calculate distance between two points
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Simplified distance calculation (Haversine formula would be more accurate)
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return (dLat * dLat + dLon * dLon) * 111.0; // Rough conversion to km
  }

  /// Get performance service instance
  FirestorePerformanceService get performanceService => _performanceService;

  /// Dispose resources
  void dispose() {
    _performanceService.dispose();
  }
}

/// Urgency levels for hospital queries
enum UrgencyLevel { nonUrgent, standard, urgent, critical }
