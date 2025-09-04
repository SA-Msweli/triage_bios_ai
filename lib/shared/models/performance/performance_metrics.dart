/// Performance metrics for Firestore queries
class QueryPerformanceMetrics {
  final String queryId;
  final int executionCount;
  final Duration totalDuration;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final int errorCount;
  final DateTime lastExecuted;
  final double averageResultCount;

  const QueryPerformanceMetrics({
    required this.queryId,
    required this.executionCount,
    required this.totalDuration,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.errorCount,
    required this.lastExecuted,
    required this.averageResultCount,
  });

  /// Get error rate as percentage
  double get errorRate {
    return executionCount > 0 ? (errorCount / executionCount) * 100 : 0.0;
  }

  /// Check if query is considered slow
  bool get isSlow => averageDuration > const Duration(seconds: 2);

  /// Check if query is considered very slow
  bool get isVerySlow => averageDuration > const Duration(seconds: 5);

  /// Get performance status
  QueryPerformanceStatus get status {
    if (isVerySlow) return QueryPerformanceStatus.verySlow;
    if (isSlow) return QueryPerformanceStatus.slow;
    if (errorRate > 10) return QueryPerformanceStatus.unreliable;
    return QueryPerformanceStatus.good;
  }

  /// Copy with updated values
  QueryPerformanceMetrics copyWith({
    String? queryId,
    int? executionCount,
    Duration? totalDuration,
    Duration? averageDuration,
    Duration? minDuration,
    Duration? maxDuration,
    int? errorCount,
    DateTime? lastExecuted,
    double? averageResultCount,
  }) {
    return QueryPerformanceMetrics(
      queryId: queryId ?? this.queryId,
      executionCount: executionCount ?? this.executionCount,
      totalDuration: totalDuration ?? this.totalDuration,
      averageDuration: averageDuration ?? this.averageDuration,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      errorCount: errorCount ?? this.errorCount,
      lastExecuted: lastExecuted ?? this.lastExecuted,
      averageResultCount: averageResultCount ?? this.averageResultCount,
    );
  }

  @override
  String toString() {
    return 'QueryPerformanceMetrics('
        'queryId: $queryId, '
        'executions: $executionCount, '
        'avgDuration: ${averageDuration.inMilliseconds}ms, '
        'errorRate: ${errorRate.toStringAsFixed(1)}%'
        ')';
  }
}

/// Query performance status
enum QueryPerformanceStatus { good, slow, verySlow, unreliable }

/// Overall performance summary
class PerformanceSummary {
  final int totalQueries;
  final int totalErrors;
  final Duration averageDuration;
  final int slowQueries;
  final int verySlowQueries;
  final int activeListeners;
  final int cachedQueries;
  final double errorRate;

  const PerformanceSummary({
    required this.totalQueries,
    required this.totalErrors,
    required this.averageDuration,
    required this.slowQueries,
    required this.verySlowQueries,
    required this.activeListeners,
    required this.cachedQueries,
    required this.errorRate,
  });

  /// Create empty summary
  factory PerformanceSummary.empty() {
    return const PerformanceSummary(
      totalQueries: 0,
      totalErrors: 0,
      averageDuration: Duration.zero,
      slowQueries: 0,
      verySlowQueries: 0,
      activeListeners: 0,
      cachedQueries: 0,
      errorRate: 0.0,
    );
  }

  /// Get overall performance status
  PerformanceStatus get overallStatus {
    if (verySlowQueries > 0 || errorRate > 25) {
      return PerformanceStatus.critical;
    }
    if (slowQueries > 0 || errorRate > 10 || activeListeners > 40) {
      return PerformanceStatus.warning;
    }
    return PerformanceStatus.good;
  }

  /// Get performance score (0-100)
  double get performanceScore {
    double score = 100.0;

    // Deduct for errors
    score -= errorRate * 2;

    // Deduct for slow queries
    if (totalQueries > 0) {
      score -= (slowQueries / totalQueries) * 30;
      score -= (verySlowQueries / totalQueries) * 50;
    }

    // Deduct for too many listeners
    if (activeListeners > 30) {
      score -= (activeListeners - 30) * 2;
    }

    return score.clamp(0.0, 100.0);
  }

  @override
  String toString() {
    return 'PerformanceSummary('
        'queries: $totalQueries, '
        'errors: $totalErrors, '
        'avgDuration: ${averageDuration.inMilliseconds}ms, '
        'listeners: $activeListeners, '
        'score: ${performanceScore.toStringAsFixed(1)}'
        ')';
  }
}

/// Overall performance status
enum PerformanceStatus { good, warning, critical }

/// Information about active listeners
class ListenerInfo {
  final String id;
  final DateTime startTime;
  final Duration duration;

  const ListenerInfo({
    required this.id,
    required this.startTime,
    required this.duration,
  });

  /// Check if listener has been active for a long time
  bool get isLongRunning => duration > const Duration(hours: 1);

  @override
  String toString() {
    return 'ListenerInfo(id: $id, duration: ${duration.inMinutes}m)';
  }
}

/// Performance alert
class PerformanceAlert {
  final PerformanceAlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const PerformanceAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    required this.data,
  });

  @override
  String toString() {
    return 'PerformanceAlert($type: $message)';
  }
}

/// Types of performance alerts
enum PerformanceAlertType {
  slowQueries,
  highErrorRate,
  highListenerCount,
  memoryUsage,
  connectionIssues,
}

/// Alert severity levels
enum AlertSeverity { info, warning, critical }
