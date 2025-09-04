import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Manager for optimizing Firestore connections and listeners
class ConnectionPoolManager {
  static final ConnectionPoolManager _instance =
      ConnectionPoolManager._internal();
  factory ConnectionPoolManager() => _instance;
  ConnectionPoolManager._internal();

  final Logger _logger = Logger();

  // Connection pools
  final Map<String, ConnectionPool> _connectionPools = {};
  final Map<String, ListenerPool> _listenerPools = {};

  // Configuration
  static const int _maxConnectionsPerPool = 10;
  static const int _maxListenersPerPool = 20;
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _idleTimeout = Duration(minutes: 5);

  // Monitoring
  final Map<String, ConnectionMetrics> _connectionMetrics = {};
  Timer? _cleanupTimer;

  // ============================================================================
  // CONNECTION POOL MANAGEMENT
  // ============================================================================

  /// Get or create connection pool for a collection
  ConnectionPool getConnectionPool(String collectionPath) {
    return _connectionPools.putIfAbsent(collectionPath, () {
      _logger.d('Creating connection pool for: $collectionPath');
      return ConnectionPool(
        collectionPath: collectionPath,
        maxConnections: _maxConnectionsPerPool,
        connectionTimeout: _connectionTimeout,
        idleTimeout: _idleTimeout,
      );
    });
  }

  /// Get or create listener pool for a collection
  ListenerPool getListenerPool(String collectionPath) {
    return _listenerPools.putIfAbsent(collectionPath, () {
      _logger.d('Creating listener pool for: $collectionPath');
      return ListenerPool(
        collectionPath: collectionPath,
        maxListeners: _maxListenersPerPool,
        idleTimeout: _idleTimeout,
      );
    });
  }

  /// Execute query with connection pooling
  Future<QuerySnapshot<Map<String, dynamic>>> executePooledQuery({
    required String collectionPath,
    required Query<Map<String, dynamic>> query,
    String? poolKey,
  }) async {
    final pool = getConnectionPool(collectionPath);
    final connection = await pool.acquireConnection(poolKey);

    try {
      final stopwatch = Stopwatch()..start();
      final result = await query.get();
      stopwatch.stop();

      // Record metrics
      _recordConnectionMetrics(collectionPath, stopwatch.elapsed, true);

      return result;
    } catch (e) {
      _recordConnectionMetrics(collectionPath, Duration.zero, false);
      rethrow;
    } finally {
      pool.releaseConnection(connection);
    }
  }

  /// Create pooled listener
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> createPooledListener({
    required String collectionPath,
    required String listenerId,
    required Query<Map<String, dynamic>> query,
    required void Function(QuerySnapshot<Map<String, dynamic>>) onData,
    required void Function(Object) onError,
    bool includeMetadataChanges = false,
  }) {
    final pool = getListenerPool(collectionPath);

    return pool.createListener(
      listenerId: listenerId,
      query: query,
      onData: onData,
      onError: onError,
      includeMetadataChanges: includeMetadataChanges,
    );
  }

  /// Cancel pooled listener
  Future<void> cancelPooledListener(
    String collectionPath,
    String listenerId,
  ) async {
    final pool = _listenerPools[collectionPath];
    if (pool != null) {
      await pool.cancelListener(listenerId);
    }
  }

  // ============================================================================
  // MONITORING AND METRICS
  // ============================================================================

  /// Get connection metrics
  Map<String, ConnectionMetrics> getConnectionMetrics() {
    return Map.from(_connectionMetrics);
  }

  /// Get pool statistics
  Map<String, PoolStatistics> getPoolStatistics() {
    final stats = <String, PoolStatistics>{};

    for (final entry in _connectionPools.entries) {
      final pool = entry.value;
      stats[entry.key] = PoolStatistics(
        collectionPath: entry.key,
        type: PoolType.connection,
        activeConnections: pool.activeConnections,
        totalConnections: pool.totalConnections,
        maxConnections: pool.maxConnections,
        waitingRequests: pool.waitingRequests,
        averageWaitTime: pool.averageWaitTime,
      );
    }

    for (final entry in _listenerPools.entries) {
      final pool = entry.value;
      final existing = stats[entry.key];
      if (existing != null) {
        stats[entry.key] = existing.copyWith(
          activeListeners: pool.activeListeners,
          totalListeners: pool.totalListeners,
          maxListeners: pool.maxListeners,
        );
      } else {
        stats[entry.key] = PoolStatistics(
          collectionPath: entry.key,
          type: PoolType.listener,
          activeListeners: pool.activeListeners,
          totalListeners: pool.totalListeners,
          maxListeners: pool.maxListeners,
        );
      }
    }

    return stats;
  }

  /// Start cleanup timer
  void startCleanup({Duration interval = const Duration(minutes: 1)}) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) => _performCleanup());
    _logger.d('Started connection pool cleanup timer');
  }

  /// Stop cleanup timer
  void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _logger.d('Stopped connection pool cleanup timer');
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Record connection metrics
  void _recordConnectionMetrics(
    String collectionPath,
    Duration duration,
    bool success,
  ) {
    final existing = _connectionMetrics[collectionPath];

    if (existing == null) {
      _connectionMetrics[collectionPath] = ConnectionMetrics(
        collectionPath: collectionPath,
        totalRequests: 1,
        successfulRequests: success ? 1 : 0,
        totalDuration: duration,
        averageDuration: duration,
        minDuration: duration,
        maxDuration: duration,
        lastRequest: DateTime.now(),
      );
    } else {
      final newTotal = existing.totalRequests + 1;
      final newSuccessful = existing.successfulRequests + (success ? 1 : 0);
      final newTotalDuration = existing.totalDuration + duration;
      final newAverage = newTotalDuration ~/ newTotal;

      _connectionMetrics[collectionPath] = existing.copyWith(
        totalRequests: newTotal,
        successfulRequests: newSuccessful,
        totalDuration: newTotalDuration,
        averageDuration: newAverage,
        minDuration: duration < existing.minDuration
            ? duration
            : existing.minDuration,
        maxDuration: duration > existing.maxDuration
            ? duration
            : existing.maxDuration,
        lastRequest: DateTime.now(),
      );
    }
  }

  /// Perform cleanup of idle connections and listeners
  void _performCleanup() {
    try {
      // Cleanup connection pools
      for (final pool in _connectionPools.values) {
        pool.cleanup();
      }

      // Cleanup listener pools
      for (final pool in _listenerPools.values) {
        pool.cleanup();
      }

      // Remove empty pools
      _connectionPools.removeWhere((_, pool) => pool.isEmpty);
      _listenerPools.removeWhere((_, pool) => pool.isEmpty);

      _logger.d('Performed connection pool cleanup');
    } catch (e) {
      _logger.e('Error during connection pool cleanup: $e');
    }
  }

  /// Dispose all resources
  void dispose() {
    stopCleanup();

    // Close all connection pools
    for (final pool in _connectionPools.values) {
      pool.dispose();
    }
    _connectionPools.clear();

    // Close all listener pools
    for (final pool in _listenerPools.values) {
      pool.dispose();
    }
    _listenerPools.clear();

    _connectionMetrics.clear();

    _logger.i('Disposed connection pool manager');
  }
}

// ============================================================================
// CONNECTION POOL
// ============================================================================

/// Pool for managing Firestore connections
class ConnectionPool {
  final String collectionPath;
  final int maxConnections;
  final Duration connectionTimeout;
  final Duration idleTimeout;

  final Queue<PooledConnection> _availableConnections =
      Queue<PooledConnection>();
  final Set<PooledConnection> _activeConnections = <PooledConnection>{};
  final Queue<Completer<PooledConnection>> _waitingRequests =
      Queue<Completer<PooledConnection>>();

  final List<Duration> _waitTimes = [];
  static const int _maxWaitTimeHistory = 100;

  ConnectionPool({
    required this.collectionPath,
    required this.maxConnections,
    required this.connectionTimeout,
    required this.idleTimeout,
  });

  /// Acquire connection from pool
  Future<PooledConnection> acquireConnection(String? key) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Try to get available connection
      if (_availableConnections.isNotEmpty) {
        final connection = _availableConnections.removeFirst();
        _activeConnections.add(connection);
        connection.markActive();

        stopwatch.stop();
        _recordWaitTime(stopwatch.elapsed);

        return connection;
      }

      // Create new connection if under limit
      if (totalConnections < maxConnections) {
        final connection = PooledConnection(
          id: '${collectionPath}_${DateTime.now().millisecondsSinceEpoch}',
          collectionPath: collectionPath,
          key: key,
        );

        _activeConnections.add(connection);
        connection.markActive();

        stopwatch.stop();
        _recordWaitTime(stopwatch.elapsed);

        return connection;
      }

      // Wait for available connection
      final completer = Completer<PooledConnection>();
      _waitingRequests.add(completer);

      // Set timeout
      Timer(connectionTimeout, () {
        if (!completer.isCompleted) {
          _waitingRequests.remove(completer);
          completer.completeError(
            TimeoutException('Connection timeout', connectionTimeout),
          );
        }
      });

      final connection = await completer.future;

      stopwatch.stop();
      _recordWaitTime(stopwatch.elapsed);

      return connection;
    } catch (e) {
      stopwatch.stop();
      _recordWaitTime(stopwatch.elapsed);
      rethrow;
    }
  }

  /// Release connection back to pool
  void releaseConnection(PooledConnection connection) {
    if (!_activeConnections.remove(connection)) {
      return; // Connection not from this pool
    }

    connection.markIdle();

    // Serve waiting request if any
    if (_waitingRequests.isNotEmpty) {
      final completer = _waitingRequests.removeFirst();
      _activeConnections.add(connection);
      connection.markActive();
      completer.complete(connection);
    } else {
      // Return to available pool
      _availableConnections.add(connection);
    }
  }

  /// Cleanup idle connections
  void cleanup() {
    final now = DateTime.now();

    _availableConnections.removeWhere((connection) {
      if (now.difference(connection.lastUsed) > idleTimeout) {
        connection.dispose();
        return true;
      }
      return false;
    });
  }

  /// Get pool statistics
  int get activeConnections => _activeConnections.length;
  int get availableConnections => _availableConnections.length;
  int get totalConnections => activeConnections + availableConnections;
  int get waitingRequests => _waitingRequests.length;
  bool get isEmpty => totalConnections == 0 && waitingRequests == 0;

  Duration get averageWaitTime {
    if (_waitTimes.isEmpty) return Duration.zero;
    final total = _waitTimes.fold<int>(
      0,
      (sum, duration) => sum + duration.inMicroseconds,
    );
    return Duration(microseconds: total ~/ _waitTimes.length);
  }

  /// Record wait time
  void _recordWaitTime(Duration waitTime) {
    _waitTimes.add(waitTime);
    if (_waitTimes.length > _maxWaitTimeHistory) {
      _waitTimes.removeAt(0);
    }
  }

  /// Dispose pool
  void dispose() {
    // Cancel waiting requests
    while (_waitingRequests.isNotEmpty) {
      final completer = _waitingRequests.removeFirst();
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection pool disposed'));
      }
    }

    // Dispose all connections
    for (final connection in _availableConnections) {
      connection.dispose();
    }
    _availableConnections.clear();

    for (final connection in _activeConnections) {
      connection.dispose();
    }
    _activeConnections.clear();

    _waitTimes.clear();
  }
}

// ============================================================================
// LISTENER POOL
// ============================================================================

/// Pool for managing Firestore listeners
class ListenerPool {
  final String collectionPath;
  final int maxListeners;
  final Duration idleTimeout;

  final Map<String, PooledListener> _listeners = {};
  final Logger _logger = Logger();

  ListenerPool({
    required this.collectionPath,
    required this.maxListeners,
    required this.idleTimeout,
  });

  /// Create listener in pool
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> createListener({
    required String listenerId,
    required Query<Map<String, dynamic>> query,
    required void Function(QuerySnapshot<Map<String, dynamic>>) onData,
    required void Function(Object) onError,
    bool includeMetadataChanges = false,
  }) {
    // Cancel existing listener if any
    final existing = _listeners[listenerId];
    if (existing != null) {
      existing.subscription.cancel();
      _listeners.remove(listenerId);
    }

    // Check listener limit
    if (_listeners.length >= maxListeners) {
      _logger.w(
        'Listener pool at capacity for $collectionPath. Cleaning up oldest listeners.',
      );
      _cleanupOldestListeners(5);
    }

    // Create new listener
    final subscription = query
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .listen(onData, onError: onError);

    final pooledListener = PooledListener(
      id: listenerId,
      subscription: subscription,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
    );

    _listeners[listenerId] = pooledListener;

    _logger.d('Created pooled listener: $listenerId');
    return subscription;
  }

  /// Cancel listener
  Future<void> cancelListener(String listenerId) async {
    final listener = _listeners.remove(listenerId);
    if (listener != null) {
      await listener.subscription.cancel();
      _logger.d('Cancelled pooled listener: $listenerId');
    }
  }

  /// Cleanup idle listeners
  void cleanup() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _listeners.entries) {
      if (now.difference(entry.value.lastActivity) > idleTimeout) {
        toRemove.add(entry.key);
      }
    }

    for (final listenerId in toRemove) {
      cancelListener(listenerId);
    }

    if (toRemove.isNotEmpty) {
      _logger.d('Cleaned up ${toRemove.length} idle listeners');
    }
  }

  /// Cleanup oldest listeners
  void _cleanupOldestListeners(int count) {
    final sortedListeners = _listeners.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    for (int i = 0; i < count && i < sortedListeners.length; i++) {
      cancelListener(sortedListeners[i].key);
    }
  }

  /// Get pool statistics
  int get activeListeners => _listeners.length;
  int get totalListeners => _listeners.length;
  bool get isEmpty => _listeners.isEmpty;

  /// Dispose pool
  void dispose() {
    final futures = <Future<void>>[];

    for (final listener in _listeners.values) {
      futures.add(listener.subscription.cancel());
    }

    Future.wait(futures).then((_) {
      _listeners.clear();
      _logger.d('Disposed listener pool for $collectionPath');
    });
  }
}

// ============================================================================
// SUPPORTING CLASSES
// ============================================================================

/// Pooled connection wrapper
class PooledConnection {
  final String id;
  final String collectionPath;
  final String? key;
  DateTime lastUsed;
  bool isActive;

  PooledConnection({required this.id, required this.collectionPath, this.key})
    : lastUsed = DateTime.now(),
      isActive = false;

  void markActive() {
    isActive = true;
    lastUsed = DateTime.now();
  }

  void markIdle() {
    isActive = false;
    lastUsed = DateTime.now();
  }

  void dispose() {
    // Cleanup connection resources if needed
  }

  @override
  String toString() => 'PooledConnection($id, active: $isActive)';
}

/// Pooled listener wrapper
class PooledListener {
  final String id;
  final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subscription;
  final DateTime createdAt;
  DateTime lastActivity;

  PooledListener({
    required this.id,
    required this.subscription,
    required this.createdAt,
    required this.lastActivity,
  });

  void updateActivity() {
    lastActivity = DateTime.now();
  }

  @override
  String toString() =>
      'PooledListener($id, age: ${DateTime.now().difference(createdAt).inMinutes}m)';
}

/// Connection metrics
class ConnectionMetrics {
  final String collectionPath;
  final int totalRequests;
  final int successfulRequests;
  final Duration totalDuration;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final DateTime lastRequest;

  const ConnectionMetrics({
    required this.collectionPath,
    required this.totalRequests,
    required this.successfulRequests,
    required this.totalDuration,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.lastRequest,
  });

  double get successRate {
    return totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0.0;
  }

  ConnectionMetrics copyWith({
    String? collectionPath,
    int? totalRequests,
    int? successfulRequests,
    Duration? totalDuration,
    Duration? averageDuration,
    Duration? minDuration,
    Duration? maxDuration,
    DateTime? lastRequest,
  }) {
    return ConnectionMetrics(
      collectionPath: collectionPath ?? this.collectionPath,
      totalRequests: totalRequests ?? this.totalRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      totalDuration: totalDuration ?? this.totalDuration,
      averageDuration: averageDuration ?? this.averageDuration,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      lastRequest: lastRequest ?? this.lastRequest,
    );
  }

  @override
  String toString() {
    return 'ConnectionMetrics($collectionPath: ${totalRequests} requests, ${successRate.toStringAsFixed(1)}% success)';
  }
}

/// Pool statistics
class PoolStatistics {
  final String collectionPath;
  final PoolType type;
  final int activeConnections;
  final int totalConnections;
  final int maxConnections;
  final int waitingRequests;
  final Duration averageWaitTime;
  final int activeListeners;
  final int totalListeners;
  final int maxListeners;

  const PoolStatistics({
    required this.collectionPath,
    required this.type,
    this.activeConnections = 0,
    this.totalConnections = 0,
    this.maxConnections = 0,
    this.waitingRequests = 0,
    this.averageWaitTime = Duration.zero,
    this.activeListeners = 0,
    this.totalListeners = 0,
    this.maxListeners = 0,
  });

  double get connectionUtilization {
    return maxConnections > 0
        ? (activeConnections / maxConnections) * 100
        : 0.0;
  }

  double get listenerUtilization {
    return maxListeners > 0 ? (activeListeners / maxListeners) * 100 : 0.0;
  }

  PoolStatistics copyWith({
    String? collectionPath,
    PoolType? type,
    int? activeConnections,
    int? totalConnections,
    int? maxConnections,
    int? waitingRequests,
    Duration? averageWaitTime,
    int? activeListeners,
    int? totalListeners,
    int? maxListeners,
  }) {
    return PoolStatistics(
      collectionPath: collectionPath ?? this.collectionPath,
      type: type ?? this.type,
      activeConnections: activeConnections ?? this.activeConnections,
      totalConnections: totalConnections ?? this.totalConnections,
      maxConnections: maxConnections ?? this.maxConnections,
      waitingRequests: waitingRequests ?? this.waitingRequests,
      averageWaitTime: averageWaitTime ?? this.averageWaitTime,
      activeListeners: activeListeners ?? this.activeListeners,
      totalListeners: totalListeners ?? this.totalListeners,
      maxListeners: maxListeners ?? this.maxListeners,
    );
  }

  @override
  String toString() {
    return 'PoolStatistics($collectionPath: ${activeConnections}/${maxConnections} connections, ${activeListeners}/${maxListeners} listeners)';
  }
}

/// Pool type
enum PoolType { connection, listener, mixed }
