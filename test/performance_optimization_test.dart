import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/shared/services/firestore_performance_service.dart';
import '../lib/shared/services/optimized_query_service.dart';
import '../lib/shared/services/performance_monitoring_service.dart';
import '../lib/shared/services/connection_pool_manager.dart';
import '../lib/shared/models/performance/query_filter.dart';
import '../lib/shared/models/performance/query_order.dart';
import '../lib/shared/models/performance/paginated_result.dart';
import '../lib/shared/models/performance/performance_metrics.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('Performance Optimization Tests', () {
    late FirestorePerformanceService performanceService;
    late OptimizedQueryService optimizedQueryService;
    late PerformanceMonitoringService monitoringService;
    late ConnectionPoolManager connectionPoolManager;

    setUp(() {
      performanceService = FirestorePerformanceService();
      optimizedQueryService = OptimizedQueryService();
      monitoringService = PerformanceMonitoringService();
      connectionPoolManager = ConnectionPoolManager();
    });

    tearDown(() {
      performanceService.dispose();
      optimizedQueryService.dispose();
      monitoringService.dispose();
      connectionPoolManager.dispose();
    });

    group('FirestorePerformanceService', () {
      test('should create query filters correctly', () {
        final equalFilter = QueryFilter.isEqualTo('field1', 'value1');
        expect(equalFilter.field, equals('field1'));
        expect(equalFilter.type, equals(FilterType.isEqualTo));
        expect(equalFilter.value, equals('value1'));

        final rangeFilter = QueryFilter.isGreaterThan('field2', 100);
        expect(rangeFilter.field, equals('field2'));
        expect(rangeFilter.type, equals(FilterType.isGreaterThan));
        expect(rangeFilter.value, equals(100));

        final arrayFilter = QueryFilter.arrayContainsAny('field3', ['a', 'b']);
        expect(arrayFilter.field, equals('field3'));
        expect(arrayFilter.type, equals(FilterType.arrayContainsAny));
        expect(arrayFilter.value, equals(['a', 'b']));
      });

      test('should create query orders correctly', () {
        final ascOrder = QueryOrder.asc('timestamp');
        expect(ascOrder.field, equals('timestamp'));
        expect(ascOrder.descending, isFalse);

        final descOrder = QueryOrder.desc('createdAt');
        expect(descOrder.field, equals('createdAt'));
        expect(descOrder.descending, isTrue);
      });

      test('should handle paginated results correctly', () {
        final items = ['item1', 'item2', 'item3'];
        final result = PaginatedResult<String>(
          items: items,
          hasMore: true,
          nextPageToken: 'token123',
          totalCount: 100,
        );

        expect(result.items, equals(items));
        expect(result.hasMore, isTrue);
        expect(result.nextPageToken, equals('token123'));
        expect(result.totalCount, equals(100));
        expect(result.pageSize, equals(3));
        expect(result.isEmpty, isFalse);
        expect(result.isNotEmpty, isTrue);
      });

      test('should create empty paginated result', () {
        final result = PaginatedResult<String>.empty();
        expect(result.items, isEmpty);
        expect(result.hasMore, isFalse);
        expect(result.nextPageToken, isNull);
        expect(result.totalCount, isNull);
        expect(result.isEmpty, isTrue);
      });

      test('should track query performance metrics', () {
        const queryId = 'test_query';
        const duration = Duration(milliseconds: 500);
        const resultCount = 25;

        // This would normally be called internally by the performance service
        // We're testing the metrics structure here
        final metrics = QueryPerformanceMetrics(
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

        expect(metrics.queryId, equals(queryId));
        expect(metrics.executionCount, equals(1));
        expect(metrics.averageDuration, equals(duration));
        expect(metrics.errorRate, equals(0.0));
        expect(metrics.isSlow, isFalse);
        expect(metrics.isVerySlow, isFalse);
        expect(metrics.status, equals(QueryPerformanceStatus.good));
      });

      test('should identify slow queries', () {
        final slowMetrics = QueryPerformanceMetrics(
          queryId: 'slow_query',
          executionCount: 1,
          totalDuration: const Duration(seconds: 3),
          averageDuration: const Duration(seconds: 3),
          minDuration: const Duration(seconds: 3),
          maxDuration: const Duration(seconds: 3),
          errorCount: 0,
          lastExecuted: DateTime.now(),
          averageResultCount: 10.0,
        );

        expect(slowMetrics.isSlow, isTrue);
        expect(slowMetrics.isVerySlow, isFalse);
        expect(slowMetrics.status, equals(QueryPerformanceStatus.slow));
      });

      test('should identify very slow queries', () {
        final verySlowMetrics = QueryPerformanceMetrics(
          queryId: 'very_slow_query',
          executionCount: 1,
          totalDuration: const Duration(seconds: 6),
          averageDuration: const Duration(seconds: 6),
          minDuration: const Duration(seconds: 6),
          maxDuration: const Duration(seconds: 6),
          errorCount: 0,
          lastExecuted: DateTime.now(),
          averageResultCount: 10.0,
        );

        expect(verySlowMetrics.isSlow, isTrue);
        expect(verySlowMetrics.isVerySlow, isTrue);
        expect(verySlowMetrics.status, equals(QueryPerformanceStatus.verySlow));
      });

      test('should identify unreliable queries', () {
        final unreliableMetrics = QueryPerformanceMetrics(
          queryId: 'unreliable_query',
          executionCount: 10,
          totalDuration: const Duration(seconds: 5),
          averageDuration: const Duration(milliseconds: 500),
          minDuration: const Duration(milliseconds: 200),
          maxDuration: const Duration(seconds: 1),
          errorCount: 2, // 20% error rate
          lastExecuted: DateTime.now(),
          averageResultCount: 10.0,
        );

        expect(unreliableMetrics.errorRate, equals(20.0));
        expect(
          unreliableMetrics.status,
          equals(QueryPerformanceStatus.unreliable),
        );
      });
    });

    group('PerformanceMonitoringService', () {
      test('should create performance summary correctly', () {
        final summary = PerformanceSummary(
          totalQueries: 100,
          totalErrors: 5,
          averageDuration: const Duration(milliseconds: 800),
          slowQueries: 2,
          verySlowQueries: 1,
          activeListeners: 15,
          cachedQueries: 25,
          errorRate: 5.0,
        );

        expect(summary.totalQueries, equals(100));
        expect(summary.errorRate, equals(5.0));
        expect(summary.overallStatus, equals(PerformanceStatus.good));
        expect(summary.performanceScore, greaterThan(70.0));
      });

      test('should identify performance issues', () {
        final criticalSummary = PerformanceSummary(
          totalQueries: 100,
          totalErrors: 30,
          averageDuration: const Duration(seconds: 2),
          slowQueries: 10,
          verySlowQueries: 5,
          activeListeners: 50,
          cachedQueries: 25,
          errorRate: 30.0,
        );

        expect(
          criticalSummary.overallStatus,
          equals(PerformanceStatus.critical),
        );
        expect(criticalSummary.performanceScore, lessThan(50.0));
      });

      test('should create empty performance summary', () {
        final emptySummary = PerformanceSummary.empty();
        expect(emptySummary.totalQueries, equals(0));
        expect(emptySummary.totalErrors, equals(0));
        expect(emptySummary.errorRate, equals(0.0));
        expect(emptySummary.overallStatus, equals(PerformanceStatus.good));
        expect(emptySummary.performanceScore, equals(100.0));
      });

      test('should track performance trends', () {
        final trends = PerformanceTrends(
          durationTrend: TrendDirection.decreasing,
          errorRateTrend: TrendDirection.increasing,
          listenerCountTrend: TrendDirection.stable,
          overallTrend: TrendDirection.decreasing,
        );

        expect(trends.durationTrend, equals(TrendDirection.decreasing));
        expect(trends.errorRateTrend, equals(TrendDirection.increasing));
        expect(trends.overallStatus, equals(TrendStatus.improving));
      });

      test('should create optimization suggestions', () {
        final suggestion = OptimizationSuggestion(
          type: OptimizationType.indexOptimization,
          priority: OptimizationPriority.high,
          title: 'Add missing indexes',
          description: 'Several queries would benefit from additional indexes',
          impact: 'Reduce query latency by 60-90%',
          effort: OptimizationEffort.low,
          queries: ['query1', 'query2'],
        );

        expect(suggestion.type, equals(OptimizationType.indexOptimization));
        expect(suggestion.priority, equals(OptimizationPriority.high));
        expect(suggestion.queries, contains('query1'));
        expect(suggestion.queries, contains('query2'));
      });
    });

    group('ConnectionPoolManager', () {
      test('should create connection pools', () {
        final pool = connectionPoolManager.getConnectionPool('test_collection');
        expect(pool, isNotNull);
        expect(pool.collectionPath, equals('test_collection'));
        expect(pool.maxConnections, greaterThan(0));
      });

      test('should create listener pools', () {
        final pool = connectionPoolManager.getListenerPool('test_collection');
        expect(pool, isNotNull);
        expect(pool.collectionPath, equals('test_collection'));
        expect(pool.maxListeners, greaterThan(0));
      });

      test('should track pool statistics', () {
        // Create some pools
        connectionPoolManager.getConnectionPool('collection1');
        connectionPoolManager.getListenerPool('collection2');

        final stats = connectionPoolManager.getPoolStatistics();
        expect(stats, isNotEmpty);
        expect(stats.containsKey('collection1'), isTrue);
      });

      test('should handle connection metrics', () {
        final metrics = ConnectionMetrics(
          collectionPath: 'test_collection',
          totalRequests: 100,
          successfulRequests: 95,
          totalDuration: const Duration(seconds: 50),
          averageDuration: const Duration(milliseconds: 500),
          minDuration: const Duration(milliseconds: 100),
          maxDuration: const Duration(seconds: 2),
          lastRequest: DateTime.now(),
        );

        expect(metrics.successRate, equals(95.0));
        expect(metrics.totalRequests, equals(100));
        expect(metrics.averageDuration.inMilliseconds, equals(500));
      });
    });

    group('Integration Tests', () {
      test('should handle complete performance monitoring workflow', () async {
        // Start monitoring
        expect(monitoringService.isMonitoring, isFalse);

        // Note: In a real test, we would start monitoring, but for unit tests
        // we just verify the state management
        expect(() => monitoringService.getCurrentSummary(), returnsNormally);
        expect(monitoringService.getPerformanceHistory(), isEmpty);
      });

      test('should provide performance optimization recommendations', () {
        final suggestions = monitoringService.getOptimizationSuggestions();
        expect(suggestions, isA<List<OptimizationSuggestion>>());
        // Initially empty since no performance data has been collected
        expect(suggestions, isEmpty);
      });

      test('should handle alert configuration', () {
        final config = AlertConfiguration(
          enabled: true,
          threshold: 1000.0,
          cooldownMinutes: 5,
        );

        monitoringService.configureAlert(
          PerformanceAlertType.slowQueries,
          config,
        );

        final retrievedConfig = monitoringService.getAlertConfiguration(
          PerformanceAlertType.slowQueries,
        );
        expect(retrievedConfig, isNotNull);
        expect(retrievedConfig!.enabled, isTrue);
        expect(retrievedConfig.threshold, equals(1000.0));
        expect(retrievedConfig.cooldownMinutes, equals(5));
      });

      test('should handle performance alert creation', () {
        final alert = PerformanceAlert(
          type: PerformanceAlertType.slowQueries,
          severity: AlertSeverity.warning,
          message: 'Query taking too long',
          timestamp: DateTime.now(),
          data: {'queryId': 'test_query', 'duration': 3000},
        );

        expect(alert.type, equals(PerformanceAlertType.slowQueries));
        expect(alert.severity, equals(AlertSeverity.warning));
        expect(alert.data['queryId'], equals('test_query'));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty query results', () {
        final emptyResult = PaginatedResult<String>.empty();
        expect(emptyResult.items, isEmpty);
        expect(emptyResult.hasMore, isFalse);
        expect(emptyResult.pageSize, equals(0));
      });

      test('should handle invalid page tokens gracefully', () {
        // This would be tested with actual Firestore integration
        // For now, we just verify the structure exists
        expect(() => PaginatedResult<String>.empty(), returnsNormally);
      });

      test('should handle connection pool limits', () {
        final pool = connectionPoolManager.getConnectionPool('test_collection');
        expect(pool.maxConnections, greaterThan(0));
        expect(pool.activeConnections, equals(0));
        expect(pool.waitingRequests, equals(0));
      });

      test('should handle listener pool limits', () {
        final pool = connectionPoolManager.getListenerPool('test_collection');
        expect(pool.maxListeners, greaterThan(0));
        expect(pool.activeListeners, equals(0));
        expect(pool.isEmpty, isTrue);
      });
    });
  });
}
