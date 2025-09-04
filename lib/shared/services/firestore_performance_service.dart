import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';
import '../models/performance/query_filter.dart';
import '../models/performance/query_order.dart';
import '../models/performance/paginated_result.dart';
import '../models/performance/performance_metrics.dart';

/// Service for optimizing Firestore performance with query optimization,
/// connection pooling, pagination, and performance monitoring
class FirestorePerformanceService {
  static final FirestorePerformanceService _instance =
      FirestorePerformanceService._internal();
  factory FirestorePerformanceService() => _instance;
  FirestorePerformanceService._internal();

  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  // Performance monitoring
  final Map<String, QueryPerformanceMetrics> _queryMetrics = {};
  final Map<String, StreamSubscription> _activeListeners = {};
  final Map<String, DateTime> _listenerStartTimes = {};

  // Connection pooling
  final Map<String, Query> _queryPool = {};
  final Map<String, Timer> _queryPoolTimers = {};

  // Pagination cache
  final Map<String, PaginationCache> _paginationCache = {};

  // Performance thresholds
  static const Duration _slowQueryThreshold = Duration(seconds: 2);
  static const Duration _verySlowQueryThreshold = Duration(seconds: 5);
  static const int _maxActiveListeners = 50;
  static const int _maxCachedQueries = 100;

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // ============================================================================
  // OPTIMIZED QUERY METHODS
  // ============================================================================

  /// Execute optimized query with performance monitoring
  Future<QuerySnapshot<Map<String, dynamic>>> executeOptimizedQuery({
    required String collectionPath,
    required String queryId,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
    DocumentSnapshot? startAfter,
    bool useCache = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Build query
      Query<Map<String, dynamic>> query = _firestore.collection(collectionPath);

      // Apply filters
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        for (final order in orderBy) {
          query = query.orderBy(order.field, descending: order.descending);
        }
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Check query pool for cached query
      final queryKey = _generateQueryKey(
        collectionPath,
        filters,
        orderBy,
        limit,
      );
      if (useCache && _queryPool.containsKey(queryKey)) {
        _logger.d('Using cached query for: $queryId');
      } else {
        _queryPool[queryKey] = query;
        _scheduleQueryPoolCleanup(queryKey);
      }

      // Execute query
      final result = await query.get();

      stopwatch.stop();

      // Record performance metrics
      _recordQueryMetrics(queryId, stopwatch.elapsed, result.docs.length);

      return result;
    } catch (e) {
      stopwatch.stop();
      _recordQueryError(queryId, stopwatch.elapsed, e);
      rethrow;
    }
  }

  /// Execute paginated query with optimized performance
  Future<PaginatedResult<T>> executePaginatedQuery<T>({
    required String collectionPath,
    required String queryId,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) fromFirestore,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int pageSize = 20,
    String? pageToken,
    bool useCache = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Check pagination cache
      final cacheKey = _generatePaginationCacheKey(queryId, pageToken);
      if (useCache && _paginationCache.containsKey(cacheKey)) {
        final cached = _paginationCache[cacheKey]!;
        if (cached.isValid) {
          _logger.d('Returning cached paginated result for: $queryId');
          return PaginatedResult<T>(
            items: cached.items.cast<T>(),
            nextPageToken: cached.nextPageToken,
            hasMore: cached.hasMore,
            totalCount: cached.totalCount,
          );
        }
      }

      // Decode page token to get start document
      DocumentSnapshot? startAfter;
      if (pageToken != null) {
        startAfter = await _decodePageToken(pageToken);
      }

      // Execute query
      final result = await executeOptimizedQuery(
        collectionPath: collectionPath,
        queryId: queryId,
        filters: filters,
        orderBy: orderBy,
        limit: pageSize + 1, // Get one extra to check if there are more
        startAfter: startAfter,
        useCache: useCache,
      );

      // Process results
      final docs = result.docs;
      final hasMore = docs.length > pageSize;
      final items = docs.take(pageSize).map(fromFirestore).toList();

      // Generate next page token
      String? nextPageToken;
      if (hasMore && docs.isNotEmpty) {
        nextPageToken = _encodePageToken(docs[pageSize - 1]);
      }

      // Cache result
      final paginatedResult = PaginatedResult<T>(
        items: items,
        nextPageToken: nextPageToken,
        hasMore: hasMore,
        totalCount: null, // We don't calculate total count for performance
      );

      _cachePaginatedResult(cacheKey, paginatedResult);

      stopwatch.stop();
      _recordQueryMetrics(queryId, stopwatch.elapsed, items.length);

      return paginatedResult;
    } catch (e) {
      stopwatch.stop();
      _recordQueryError(queryId, stopwatch.elapsed, e);
      rethrow;
    }
  }

  // ============================================================================
  // CONNECTION POOLING AND LISTENER MANAGEMENT
  // ============================================================================

  /// Create optimized real-time listener with connection pooling
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  createOptimizedListener({
    required String listenerId,
    required String collectionPath,
    required void Function(QuerySnapshot<Map<String, dynamic>>) onData,
    required void Function(Object) onError,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
    bool includeMetadataChanges = false,
  }) {
    // Check listener limits
    if (_activeListeners.length >= _maxActiveListeners) {
      _logger.w(
        'Maximum active listeners reached. Cleaning up oldest listeners.',
      );
      _cleanupOldestListeners(5);
    }

    // Cancel existing listener if any
    _activeListeners[listenerId]?.cancel();

    try {
      // Build query
      Query<Map<String, dynamic>> query = _firestore.collection(collectionPath);

      // Apply filters
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        for (final order in orderBy) {
          query = query.orderBy(order.field, descending: order.descending);
        }
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Create listener with performance monitoring
      final subscription = query
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen(
            (snapshot) {
              final stopwatch = Stopwatch()..start();

              try {
                onData(snapshot);
                stopwatch.stop();

                // Record listener performance
                _recordListenerMetrics(
                  listenerId,
                  stopwatch.elapsed,
                  snapshot.docs.length,
                );
              } catch (e) {
                stopwatch.stop();
                _recordListenerError(listenerId, stopwatch.elapsed, e);
                onError(e);
              }
            },
            onError: (error) {
              _recordListenerError(listenerId, Duration.zero, error);
              onError(error);
            },
          );

      // Track listener
      _activeListeners[listenerId] = subscription;
      _listenerStartTimes[listenerId] = DateTime.now();

      _logger.d('Created optimized listener: $listenerId');
      return subscription;
    } catch (e) {
      _logger.e('Failed to create optimized listener $listenerId: $e');
      rethrow;
    }
  }

  /// Cancel listener and clean up resources
  Future<void> cancelListener(String listenerId) async {
    final subscription = _activeListeners.remove(listenerId);
    if (subscription != null) {
      await subscription.cancel();
      _listenerStartTimes.remove(listenerId);
      _logger.d('Cancelled listener: $listenerId');
    }
  }

  /// Cancel all listeners
  Future<void> cancelAllListeners() async {
    final futures = <Future<void>>[];

    for (final entry in _activeListeners.entries) {
      futures.add(entry.value.cancel());
    }

    await Future.wait(futures);

    _activeListeners.clear();
    _listenerStartTimes.clear();

    _logger.i('Cancelled all ${futures.length} listeners');
  }

  /// Get active listener information
  Map<String, ListenerInfo> getActiveListeners() {
    final result = <String, ListenerInfo>{};

    for (final entry in _activeListeners.entries) {
      final listenerId = entry.key;
      final startTime = _listenerStartTimes[listenerId];

      result[listenerId] = ListenerInfo(
        id: listenerId,
        startTime: startTime ?? DateTime.now(),
        duration: startTime != null
            ? DateTime.now().difference(startTime)
            : Duration.zero,
      );
    }

    return result;
  }

  // ============================================================================
  // PERFORMANCE MONITORING AND ALERTING
  // ============================================================================

  /// Get query performance metrics
  Map<String, QueryPerformanceMetrics> getQueryMetrics() {
    return Map.from(_queryMetrics);
  }

  /// Get performance summary
  PerformanceSummary getPerformanceSummary() {
    final allMetrics = _queryMetrics.values.toList();

    if (allMetrics.isEmpty) {
      return PerformanceSummary.empty();
    }

    // Calculate statistics
    final totalQueries = allMetrics.fold<int>(
      0,
      (sum, m) => sum + m.executionCount,
    );
    final totalErrors = allMetrics.fold<int>(0, (sum, m) => sum + m.errorCount);
    final avgDuration =
        allMetrics.fold<Duration>(
          Duration.zero,
          (sum, m) => sum + m.averageDuration,
        ) ~/
        allMetrics.length;

    final slowQueries = allMetrics
        .where((m) => m.averageDuration > _slowQueryThreshold)
        .length;

    final verySlowQueries = allMetrics
        .where((m) => m.averageDuration > _verySlowQueryThreshold)
        .length;

    return PerformanceSummary(
      totalQueries: totalQueries,
      totalErrors: totalErrors,
      averageDuration: avgDuration,
      slowQueries: slowQueries,
      verySlowQueries: verySlowQueries,
      activeListeners: _activeListeners.length,
      cachedQueries: _queryPool.length,
      errorRate: totalQueries > 0 ? (totalErrors / totalQueries) * 100 : 0.0,
    );
  }

  /// Check for performance alerts
  List<PerformanceAlert> checkPerformanceAlerts() {
    final alerts = <PerformanceAlert>[];
    final summary = getPerformanceSummary();

    // Check for too many active listeners
    if (summary.activeListeners > _maxActiveListeners * 0.8) {
      alerts.add(
        PerformanceAlert(
          type: PerformanceAlertType.highListenerCount,
          severity: summary.activeListeners > _maxActiveListeners * 0.9
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          message:
              'High number of active listeners: ${summary.activeListeners}',
          timestamp: DateTime.now(),
          data: {
            'count': summary.activeListeners,
            'limit': _maxActiveListeners,
          },
        ),
      );
    }

    // Check for high error rate
    if (summary.errorRate > 10.0) {
      alerts.add(
        PerformanceAlert(
          type: PerformanceAlertType.highErrorRate,
          severity: summary.errorRate > 25.0
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          message:
              'High query error rate: ${summary.errorRate.toStringAsFixed(1)}%',
          timestamp: DateTime.now(),
          data: {'errorRate': summary.errorRate},
        ),
      );
    }

    // Check for slow queries
    if (summary.verySlowQueries > 0) {
      alerts.add(
        PerformanceAlert(
          type: PerformanceAlertType.slowQueries,
          severity: AlertSeverity.warning,
          message: '${summary.verySlowQueries} very slow queries detected',
          timestamp: DateTime.now(),
          data: {'count': summary.verySlowQueries},
        ),
      );
    }

    // Check individual query metrics
    for (final entry in _queryMetrics.entries) {
      final queryId = entry.key;
      final metrics = entry.value;

      if (metrics.averageDuration > _verySlowQueryThreshold) {
        alerts.add(
          PerformanceAlert(
            type: PerformanceAlertType.slowQueries,
            severity: AlertSeverity.critical,
            message:
                'Query "$queryId" is very slow: ${metrics.averageDuration.inMilliseconds}ms',
            timestamp: DateTime.now(),
            data: {
              'queryId': queryId,
              'duration': metrics.averageDuration.inMilliseconds,
            },
          ),
        );
      }
    }

    return alerts;
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Apply filter to query
  Query<Map<String, dynamic>> _applyFilter(
    Query<Map<String, dynamic>> query,
    QueryFilter filter,
  ) {
    switch (filter.type) {
      case FilterType.isEqualTo:
        return query.where(filter.field, isEqualTo: filter.value);
      case FilterType.isNotEqualTo:
        return query.where(filter.field, isNotEqualTo: filter.value);
      case FilterType.isLessThan:
        return query.where(filter.field, isLessThan: filter.value);
      case FilterType.isLessThanOrEqualTo:
        return query.where(filter.field, isLessThanOrEqualTo: filter.value);
      case FilterType.isGreaterThan:
        return query.where(filter.field, isGreaterThan: filter.value);
      case FilterType.isGreaterThanOrEqualTo:
        return query.where(filter.field, isGreaterThanOrEqualTo: filter.value);
      case FilterType.arrayContains:
        return query.where(filter.field, arrayContains: filter.value);
      case FilterType.arrayContainsAny:
        return query.where(filter.field, arrayContainsAny: filter.value);
      case FilterType.whereIn:
        return query.where(filter.field, whereIn: filter.value);
      case FilterType.whereNotIn:
        return query.where(filter.field, whereNotIn: filter.value);
      case FilterType.isNull:
        return query.where(filter.field, isNull: true);
      case FilterType.isNotNull:
        return query.where(filter.field, isNull: false);
    }
  }

  /// Generate query cache key
  String _generateQueryKey(
    String collection,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
  ) {
    final buffer = StringBuffer(collection);

    if (filters != null) {
      for (final filter in filters) {
        buffer.write('_${filter.field}_${filter.type.name}_${filter.value}');
      }
    }

    if (orderBy != null) {
      for (final order in orderBy) {
        buffer.write('_${order.field}_${order.descending}');
      }
    }

    if (limit != null) {
      buffer.write('_limit_$limit');
    }

    return buffer.toString();
  }

  /// Generate pagination cache key
  String _generatePaginationCacheKey(String queryId, String? pageToken) {
    return '${queryId}_${pageToken ?? 'first'}';
  }

  /// Encode page token from document snapshot
  String _encodePageToken(DocumentSnapshot doc) {
    // Simple encoding - in production, you might want to use a more secure method
    return '${doc.reference.path}:${doc.get('createdAt')?.millisecondsSinceEpoch ?? 0}';
  }

  /// Decode page token to document snapshot
  Future<DocumentSnapshot?> _decodePageToken(String pageToken) async {
    try {
      final parts = pageToken.split(':');
      if (parts.length != 2) return null;

      final docPath = parts[0];
      return await _firestore.doc(docPath).get();
    } catch (e) {
      _logger.w('Failed to decode page token: $e');
      return null;
    }
  }

  /// Cache paginated result
  void _cachePaginatedResult<T>(String cacheKey, PaginatedResult<T> result) {
    _paginationCache[cacheKey] = PaginationCache(
      items: result.items,
      nextPageToken: result.nextPageToken,
      hasMore: result.hasMore,
      totalCount: result.totalCount,
      cachedAt: DateTime.now(),
    );

    // Clean up old cache entries
    if (_paginationCache.length > _maxCachedQueries) {
      _cleanupPaginationCache();
    }
  }

  /// Schedule query pool cleanup
  void _scheduleQueryPoolCleanup(String queryKey) {
    _queryPoolTimers[queryKey]?.cancel();
    _queryPoolTimers[queryKey] = Timer(const Duration(minutes: 10), () {
      _queryPool.remove(queryKey);
      _queryPoolTimers.remove(queryKey);
    });
  }

  /// Clean up oldest listeners
  void _cleanupOldestListeners(int count) {
    final sortedListeners = _listenerStartTimes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (int i = 0; i < math.min(count, sortedListeners.length); i++) {
      final listenerId = sortedListeners[i].key;
      cancelListener(listenerId);
    }
  }

  /// Clean up pagination cache
  void _cleanupPaginationCache() {
    final sortedEntries = _paginationCache.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

    // Remove oldest 25% of entries
    final removeCount = (_paginationCache.length * 0.25).ceil();
    for (int i = 0; i < removeCount; i++) {
      _paginationCache.remove(sortedEntries[i].key);
    }
  }

  /// Record query performance metrics
  void _recordQueryMetrics(String queryId, Duration duration, int resultCount) {
    final existing = _queryMetrics[queryId];

    if (existing == null) {
      _queryMetrics[queryId] = QueryPerformanceMetrics(
        queryId: queryId,
        executionCount: 1,
        totalDuration: duration,
        averageDuration: duration,
        minDuration: duration,
        maxDuration: duration,
        errorCount: 0,
        lastExecuted: DateTime.now(),
        averageResultCount: resultCount.toDouble(),
      );
    } else {
      final newCount = existing.executionCount + 1;
      final newTotal = existing.totalDuration + duration;
      final newAverage = newTotal ~/ newCount;

      _queryMetrics[queryId] = existing.copyWith(
        executionCount: newCount,
        totalDuration: newTotal,
        averageDuration: newAverage,
        minDuration: duration < existing.minDuration
            ? duration
            : existing.minDuration,
        maxDuration: duration > existing.maxDuration
            ? duration
            : existing.maxDuration,
        lastExecuted: DateTime.now(),
        averageResultCount:
            (existing.averageResultCount * existing.executionCount +
                resultCount) /
            newCount,
      );
    }

    // Log slow queries
    if (duration > _slowQueryThreshold) {
      _logger.w(
        'Slow query detected: $queryId took ${duration.inMilliseconds}ms',
      );
    }
  }

  /// Record query error
  void _recordQueryError(String queryId, Duration duration, Object error) {
    final existing = _queryMetrics[queryId];

    if (existing == null) {
      _queryMetrics[queryId] = QueryPerformanceMetrics(
        queryId: queryId,
        executionCount: 1,
        totalDuration: duration,
        averageDuration: duration,
        minDuration: duration,
        maxDuration: duration,
        errorCount: 1,
        lastExecuted: DateTime.now(),
        averageResultCount: 0.0,
      );
    } else {
      _queryMetrics[queryId] = existing.copyWith(
        errorCount: existing.errorCount + 1,
        lastExecuted: DateTime.now(),
      );
    }

    _logger.e('Query error for $queryId: $error');
  }

  /// Record listener performance metrics
  void _recordListenerMetrics(
    String listenerId,
    Duration duration,
    int resultCount,
  ) {
    // Similar to query metrics but for listeners
    _recordQueryMetrics('listener_$listenerId', duration, resultCount);
  }

  /// Record listener error
  void _recordListenerError(
    String listenerId,
    Duration duration,
    Object error,
  ) {
    _recordQueryError('listener_$listenerId', duration, error);
  }

  /// Dispose resources
  void dispose() {
    cancelAllListeners();

    for (final timer in _queryPoolTimers.values) {
      timer.cancel();
    }

    _queryPool.clear();
    _queryPoolTimers.clear();
    _paginationCache.clear();
    _queryMetrics.clear();
  }
}
