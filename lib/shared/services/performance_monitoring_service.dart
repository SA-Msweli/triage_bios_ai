import 'dart:async';
import 'dart:math' as math;
import 'package:logger/logger.dart';
import 'firestore_performance_service.dart';
import 'optimized_query_service.dart';
import '../models/performance/performance_metrics.dart';

/// Service for monitoring and alerting on Firestore performance
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  final Logger _logger = Logger();
  final FirestorePerformanceService _performanceService =
      FirestorePerformanceService();
  final OptimizedQueryService _queryService = OptimizedQueryService();

  // Monitoring state
  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  Timer? _alertTimer;

  // Alert streams
  final StreamController<PerformanceAlert> _alertController =
      StreamController<PerformanceAlert>.broadcast();
  final StreamController<PerformanceSummary> _summaryController =
      StreamController<PerformanceSummary>.broadcast();

  // Performance history
  final List<PerformanceSummary> _performanceHistory = [];
  static const int _maxHistoryEntries = 100;

  // Alert configuration
  final Map<PerformanceAlertType, AlertConfiguration> _alertConfig = {
    PerformanceAlertType.slowQueries: AlertConfiguration(
      enabled: true,
      threshold: 2000, // 2 seconds
      cooldownMinutes: 5,
    ),
    PerformanceAlertType.highErrorRate: AlertConfiguration(
      enabled: true,
      threshold: 10.0, // 10%
      cooldownMinutes: 3,
    ),
    PerformanceAlertType.highListenerCount: AlertConfiguration(
      enabled: true,
      threshold: 40, // 40 listeners
      cooldownMinutes: 10,
    ),
  };

  // Alert cooldowns
  final Map<String, DateTime> _alertCooldowns = {};

  // ============================================================================
  // PUBLIC STREAMS
  // ============================================================================

  /// Stream of performance alerts
  Stream<PerformanceAlert> get alerts => _alertController.stream;

  /// Stream of performance summaries
  Stream<PerformanceSummary> get summaries => _summaryController.stream;

  // ============================================================================
  // MONITORING CONTROL
  // ============================================================================

  /// Start performance monitoring
  Future<void> startMonitoring({
    Duration interval = const Duration(minutes: 1),
    Duration alertInterval = const Duration(seconds: 30),
  }) async {
    if (_isMonitoring) {
      _logger.w('Performance monitoring is already active');
      return;
    }

    try {
      _isMonitoring = true;
      _logger.i('Starting performance monitoring...');

      // Start periodic performance collection
      _monitoringTimer = Timer.periodic(
        interval,
        (_) => _collectPerformanceMetrics(),
      );

      // Start periodic alert checking
      _alertTimer = Timer.periodic(alertInterval, (_) => _checkAndEmitAlerts());

      // Collect initial metrics
      await _collectPerformanceMetrics();

      _logger.i('Performance monitoring started successfully');
    } catch (e) {
      _logger.e('Failed to start performance monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  /// Stop performance monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      _logger.w('Performance monitoring is not active');
      return;
    }

    try {
      _logger.i('Stopping performance monitoring...');

      _monitoringTimer?.cancel();
      _alertTimer?.cancel();
      _monitoringTimer = null;
      _alertTimer = null;

      _isMonitoring = false;

      _logger.i('Performance monitoring stopped');
    } catch (e) {
      _logger.e('Error stopping performance monitoring: $e');
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  // ============================================================================
  // PERFORMANCE METRICS
  // ============================================================================

  /// Get current performance summary
  PerformanceSummary getCurrentSummary() {
    return _performanceService.getPerformanceSummary();
  }

  /// Get performance history
  List<PerformanceSummary> getPerformanceHistory() {
    return List.from(_performanceHistory);
  }

  /// Get query performance metrics
  Map<String, QueryPerformanceMetrics> getQueryMetrics() {
    return _performanceService.getQueryMetrics();
  }

  /// Get performance trends over time
  PerformanceTrends getPerformanceTrends() {
    if (_performanceHistory.length < 2) {
      return PerformanceTrends.empty();
    }

    final recent = _performanceHistory.takeLast(10).toList();
    final older = _performanceHistory.length > 20
        ? _performanceHistory.takeLast(20).take(10).toList()
        : recent;

    // Calculate trends
    final avgRecentDuration =
        recent.fold<Duration>(
          Duration.zero,
          (sum, s) => sum + s.averageDuration,
        ) ~/
        recent.length;

    final avgOlderDuration =
        older.fold<Duration>(
          Duration.zero,
          (sum, s) => sum + s.averageDuration,
        ) ~/
        older.length;

    final avgRecentErrors =
        recent.fold<double>(0.0, (sum, s) => sum + s.errorRate) / recent.length;

    final avgOlderErrors =
        older.fold<double>(0.0, (sum, s) => sum + s.errorRate) / older.length;

    final avgRecentListeners =
        recent.fold<int>(0, (sum, s) => sum + s.activeListeners) ~/
        recent.length;

    final avgOlderListeners =
        older.fold<int>(0, (sum, s) => sum + s.activeListeners) ~/ older.length;

    return PerformanceTrends(
      durationTrend: _calculateTrend(
        avgOlderDuration.inMilliseconds.toDouble(),
        avgRecentDuration.inMilliseconds.toDouble(),
      ),
      errorRateTrend: _calculateTrend(avgOlderErrors, avgRecentErrors),
      listenerCountTrend: _calculateTrend(
        avgOlderListeners.toDouble(),
        avgRecentListeners.toDouble(),
      ),
      overallTrend: _calculateOverallTrend(recent, older),
    );
  }

  /// Get top slow queries
  List<QueryPerformanceMetrics> getSlowQueries({int limit = 10}) {
    final metrics = _performanceService.getQueryMetrics().values.toList();
    metrics.sort((a, b) => b.averageDuration.compareTo(a.averageDuration));
    return metrics.take(limit).toList();
  }

  /// Get queries with high error rates
  List<QueryPerformanceMetrics> getUnreliableQueries({int limit = 10}) {
    final metrics = _performanceService
        .getQueryMetrics()
        .values
        .where((m) => m.errorRate > 5.0)
        .toList();
    metrics.sort((a, b) => b.errorRate.compareTo(a.errorRate));
    return metrics.take(limit).toList();
  }

  // ============================================================================
  // ALERT CONFIGURATION
  // ============================================================================

  /// Configure alert settings
  void configureAlert(PerformanceAlertType type, AlertConfiguration config) {
    _alertConfig[type] = config;
    _logger.d('Updated alert configuration for $type: $config');
  }

  /// Get alert configuration
  AlertConfiguration? getAlertConfiguration(PerformanceAlertType type) {
    return _alertConfig[type];
  }

  /// Enable/disable specific alert type
  void setAlertEnabled(PerformanceAlertType type, bool enabled) {
    final config = _alertConfig[type];
    if (config != null) {
      _alertConfig[type] = config.copyWith(enabled: enabled);
    }
  }

  // ============================================================================
  // PERFORMANCE OPTIMIZATION SUGGESTIONS
  // ============================================================================

  /// Get performance optimization suggestions
  List<OptimizationSuggestion> getOptimizationSuggestions() {
    final suggestions = <OptimizationSuggestion>[];
    final summary = getCurrentSummary();
    final queryMetrics = getQueryMetrics();

    // Check for slow queries
    final slowQueries = queryMetrics.values
        .where((m) => m.averageDuration > const Duration(seconds: 2))
        .toList();

    if (slowQueries.isNotEmpty) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.indexOptimization,
          priority: OptimizationPriority.high,
          title: 'Optimize slow queries',
          description:
              'Found ${slowQueries.length} queries with average duration > 2s',
          impact: 'Reduce query response time by 50-80%',
          effort: OptimizationEffort.medium,
          queries: slowQueries.map((q) => q.queryId).toList(),
        ),
      );
    }

    // Check for high listener count
    if (summary.activeListeners > 30) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.listenerOptimization,
          priority: OptimizationPriority.medium,
          title: 'Reduce active listeners',
          description:
              'High number of active listeners (${summary.activeListeners})',
          impact: 'Reduce memory usage and improve performance',
          effort: OptimizationEffort.low,
        ),
      );
    }

    // Check for high error rate
    if (summary.errorRate > 10) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.errorReduction,
          priority: OptimizationPriority.critical,
          title: 'Reduce query errors',
          description:
              'High error rate: ${summary.errorRate.toStringAsFixed(1)}%',
          impact: 'Improve application reliability',
          effort: OptimizationEffort.high,
        ),
      );
    }

    // Check for missing indexes
    final potentialIndexIssues = queryMetrics.values
        .where(
          (m) =>
              m.averageDuration > const Duration(milliseconds: 500) &&
              m.executionCount > 10,
        )
        .toList();

    if (potentialIndexIssues.isNotEmpty) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.indexOptimization,
          priority: OptimizationPriority.medium,
          title: 'Add missing indexes',
          description: 'Queries that might benefit from additional indexes',
          impact: 'Reduce query latency by 60-90%',
          effort: OptimizationEffort.low,
          queries: potentialIndexIssues.map((q) => q.queryId).toList(),
        ),
      );
    }

    // Sort by priority
    suggestions.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return suggestions;
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Collect performance metrics
  Future<void> _collectPerformanceMetrics() async {
    try {
      final summary = _performanceService.getPerformanceSummary();

      // Add to history
      _performanceHistory.add(summary);
      if (_performanceHistory.length > _maxHistoryEntries) {
        _performanceHistory.removeAt(0);
      }

      // Emit summary
      _summaryController.add(summary);

      _logger.d('Collected performance metrics: $summary');
    } catch (e) {
      _logger.e('Failed to collect performance metrics: $e');
    }
  }

  /// Check and emit alerts
  Future<void> _checkAndEmitAlerts() async {
    try {
      final alerts = _performanceService.checkPerformanceAlerts();

      for (final alert in alerts) {
        if (_shouldEmitAlert(alert)) {
          _alertController.add(alert);
          _recordAlertCooldown(alert);
          _logger.w('Performance alert: ${alert.message}');
        }
      }
    } catch (e) {
      _logger.e('Failed to check performance alerts: $e');
    }
  }

  /// Check if alert should be emitted (considering cooldowns)
  bool _shouldEmitAlert(PerformanceAlert alert) {
    final config = _alertConfig[alert.type];
    if (config == null || !config.enabled) {
      return false;
    }

    final cooldownKey = '${alert.type}_${alert.message.hashCode}';
    final lastAlert = _alertCooldowns[cooldownKey];

    if (lastAlert != null) {
      final cooldownDuration = Duration(minutes: config.cooldownMinutes);
      if (DateTime.now().difference(lastAlert) < cooldownDuration) {
        return false;
      }
    }

    return true;
  }

  /// Record alert cooldown
  void _recordAlertCooldown(PerformanceAlert alert) {
    final cooldownKey = '${alert.type}_${alert.message.hashCode}';
    _alertCooldowns[cooldownKey] = DateTime.now();
  }

  /// Calculate trend between two values
  TrendDirection _calculateTrend(double oldValue, double newValue) {
    if (oldValue == 0) return TrendDirection.stable;

    final change = (newValue - oldValue) / oldValue;
    if (change > 0.1) return TrendDirection.increasing;
    if (change < -0.1) return TrendDirection.decreasing;
    return TrendDirection.stable;
  }

  /// Calculate overall trend
  TrendDirection _calculateOverallTrend(
    List<PerformanceSummary> recent,
    List<PerformanceSummary> older,
  ) {
    final recentScore =
        recent.fold<double>(0.0, (sum, s) => sum + s.performanceScore) /
        recent.length;
    final olderScore =
        older.fold<double>(0.0, (sum, s) => sum + s.performanceScore) /
        older.length;

    return _calculateTrend(olderScore, recentScore);
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _alertController.close();
    _summaryController.close();
    _performanceHistory.clear();
    _alertCooldowns.clear();
  }
}

// ============================================================================
// SUPPORTING MODELS
// ============================================================================

/// Alert configuration
class AlertConfiguration {
  final bool enabled;
  final double threshold;
  final int cooldownMinutes;

  const AlertConfiguration({
    required this.enabled,
    required this.threshold,
    required this.cooldownMinutes,
  });

  AlertConfiguration copyWith({
    bool? enabled,
    double? threshold,
    int? cooldownMinutes,
  }) {
    return AlertConfiguration(
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
    );
  }

  @override
  String toString() {
    return 'AlertConfiguration(enabled: $enabled, threshold: $threshold, cooldown: ${cooldownMinutes}m)';
  }
}

/// Performance trends
class PerformanceTrends {
  final TrendDirection durationTrend;
  final TrendDirection errorRateTrend;
  final TrendDirection listenerCountTrend;
  final TrendDirection overallTrend;

  const PerformanceTrends({
    required this.durationTrend,
    required this.errorRateTrend,
    required this.listenerCountTrend,
    required this.overallTrend,
  });

  factory PerformanceTrends.empty() {
    return const PerformanceTrends(
      durationTrend: TrendDirection.stable,
      errorRateTrend: TrendDirection.stable,
      listenerCountTrend: TrendDirection.stable,
      overallTrend: TrendDirection.stable,
    );
  }

  /// Get overall trend status
  TrendStatus get overallStatus {
    if (overallTrend == TrendDirection.decreasing) return TrendStatus.improving;
    if (overallTrend == TrendDirection.increasing) return TrendStatus.degrading;
    return TrendStatus.stable;
  }
}

/// Trend direction
enum TrendDirection { increasing, decreasing, stable }

/// Trend status
enum TrendStatus { improving, degrading, stable }

/// Optimization suggestion
class OptimizationSuggestion {
  final OptimizationType type;
  final OptimizationPriority priority;
  final String title;
  final String description;
  final String impact;
  final OptimizationEffort effort;
  final List<String>? queries;

  const OptimizationSuggestion({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.impact,
    required this.effort,
    this.queries,
  });

  @override
  String toString() {
    return 'OptimizationSuggestion($priority: $title)';
  }
}

/// Types of optimizations
enum OptimizationType {
  indexOptimization,
  listenerOptimization,
  errorReduction,
  cacheOptimization,
  queryStructure,
}

/// Optimization priority
enum OptimizationPriority { low, medium, high, critical }

/// Optimization effort required
enum OptimizationEffort { low, medium, high }

/// Extension for list operations
extension ListExtensions<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}
