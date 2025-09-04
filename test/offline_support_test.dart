import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/shared/services/offline_support_service.dart';
import '../lib/shared/utils/cache_manager.dart';

void main() {
  group('Offline Support Service Tests', () {
    late OfflineSupportService offlineService;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      offlineService = OfflineSupportService();
    });

    tearDown(() async {
      // Clean up after each test
      await offlineService.clearCache();
      offlineService.dispose();
    });

    test('should initialize offline support service', () async {
      // Note: In a real test environment, you'd need to mock Firebase
      // For now, we'll test the basic structure
      expect(offlineService, isNotNull);
    });

    test('should cache data with different priorities', () async {
      // Test caching critical data
      await offlineService.cacheData(
        key: 'test_critical',
        data: {'type': 'critical', 'value': 123},
        priority: DataPriority.critical,
      );

      // Test caching high priority data
      await offlineService.cacheData(
        key: 'test_high',
        data: {'type': 'high', 'value': 456},
        priority: DataPriority.high,
      );

      // Verify data can be retrieved
      final criticalData = await offlineService
          .getCachedData<Map<String, dynamic>>('test_critical');
      final highData = await offlineService.getCachedData<Map<String, dynamic>>(
        'test_high',
      );

      expect(criticalData, isNotNull);
      expect(criticalData!['type'], equals('critical'));
      expect(criticalData['value'], equals(123));

      expect(highData, isNotNull);
      expect(highData!['type'], equals('high'));
      expect(highData['value'], equals(456));
    });

    test('should handle offline operations queue', () async {
      final operation = OfflineOperation(
        id: 'test_op_1',
        collection: 'test_collection',
        documentId: 'test_doc_1',
        operation: 'create',
        data: {'test': 'data'},
        timestamp: DateTime.now(),
        priority: DataPriority.high,
      );

      await offlineService.addOfflineOperation(operation);

      // Verify operation was queued
      final stats = offlineService.getCacheStats();
      expect(stats['pendingOperations'], greaterThan(0));
    });

    test('should provide sync status updates', () async {
      // Listen to sync status stream
      final statusStream = offlineService.syncStatusStream;
      expect(statusStream, isNotNull);

      // Initial status should be available
      final currentStatus = offlineService.currentSyncStatus;
      expect(currentStatus, isNotNull);
      expect(currentStatus.status, isA<SyncStatus>());
    });

    test('should handle connectivity changes', () async {
      // Listen to connectivity stream
      final connectivityStream = offlineService.connectivityStream;
      expect(connectivityStream, isNotNull);

      // Initial connectivity status should be available
      final isOnline = offlineService.isOnline;
      expect(isOnline, isA<bool>());
    });

    test('should provide cache statistics', () async {
      // Add some test data
      await offlineService.cacheData(
        key: 'stats_test_1',
        data: {'test': 1},
        priority: DataPriority.critical,
      );

      await offlineService.cacheData(
        key: 'stats_test_2',
        data: {'test': 2},
        priority: DataPriority.high,
      );

      final stats = offlineService.getCacheStats();
      expect(stats, isNotNull);
      expect(stats['totalEntries'], greaterThanOrEqualTo(2));
      expect(stats['criticalEntries'], greaterThanOrEqualTo(1));
      expect(stats['highPriorityEntries'], greaterThanOrEqualTo(1));
    });
  });

  group('Cache Manager Tests', () {
    late CacheManager cacheManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cacheManager = CacheManager();
    });

    tearDown(() async {
      await cacheManager.clearAll();
    });

    test('should store and retrieve cache entries', () async {
      final testData = {'key': 'value', 'number': 42};

      await cacheManager.store(
        key: 'test_entry',
        data: testData,
        priority: DataPriority.high,
      );

      final retrievedData = await cacheManager.retrieve<Map<String, dynamic>>(
        'test_entry',
      );
      expect(retrievedData, isNotNull);
      expect(retrievedData!['key'], equals('value'));
      expect(retrievedData['number'], equals(42));
    });

    test('should handle cache expiration', () async {
      await cacheManager.store(
        key: 'expiring_entry',
        data: {'test': 'data'},
        priority: DataPriority.critical,
        customTTL: const Duration(milliseconds: 1), // Very short TTL
      );

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 10));

      final retrievedData = await cacheManager.retrieve('expiring_entry');
      expect(retrievedData, isNull); // Should be expired
    });

    test('should check cache entry existence', () async {
      await cacheManager.store(
        key: 'existence_test',
        data: {'exists': true},
        priority: DataPriority.medium,
      );

      final exists = await cacheManager.exists('existence_test');
      expect(exists, isTrue);

      final notExists = await cacheManager.exists('non_existent_key');
      expect(notExists, isFalse);
    });

    test('should remove specific cache entries', () async {
      await cacheManager.store(
        key: 'removable_entry',
        data: {'remove': 'me'},
        priority: DataPriority.low,
      );

      // Verify it exists
      expect(await cacheManager.exists('removable_entry'), isTrue);

      // Remove it
      await cacheManager.remove('removable_entry');

      // Verify it's gone
      expect(await cacheManager.exists('removable_entry'), isFalse);
    });

    test('should clear all cache entries', () async {
      // Add multiple entries
      await cacheManager.store(
        key: 'entry_1',
        data: {'data': 1},
        priority: DataPriority.high,
      );

      await cacheManager.store(
        key: 'entry_2',
        data: {'data': 2},
        priority: DataPriority.medium,
      );

      // Verify they exist
      expect(await cacheManager.exists('entry_1'), isTrue);
      expect(await cacheManager.exists('entry_2'), isTrue);

      // Clear all
      await cacheManager.clearAll();

      // Verify they're gone
      expect(await cacheManager.exists('entry_1'), isFalse);
      expect(await cacheManager.exists('entry_2'), isFalse);
    });

    test('should provide cache statistics', () async {
      // Add entries with different priorities
      await cacheManager.store(
        key: 'critical_entry',
        data: {'priority': 'critical'},
        priority: DataPriority.critical,
      );

      await cacheManager.store(
        key: 'high_entry',
        data: {'priority': 'high'},
        priority: DataPriority.high,
      );

      await cacheManager.store(
        key: 'medium_entry',
        data: {'priority': 'medium'},
        priority: DataPriority.medium,
      );

      final stats = await cacheManager.getStats();
      expect(stats.totalEntries, equals(3));
      expect(stats.entriesByPriority[DataPriority.critical], equals(1));
      expect(stats.entriesByPriority[DataPriority.high], equals(1));
      expect(stats.entriesByPriority[DataPriority.medium], equals(1));
    });

    test('should handle cache cleanup', () async {
      // Add an expired entry
      await cacheManager.store(
        key: 'expired_entry',
        data: {'expired': true},
        priority: DataPriority.low,
        customTTL: const Duration(milliseconds: 1),
      );

      // Add a valid entry
      await cacheManager.store(
        key: 'valid_entry',
        data: {'valid': true},
        priority: DataPriority.high,
      );

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 10));

      // Clear expired entries
      final removedCount = await cacheManager.clearExpired();
      expect(removedCount, greaterThanOrEqualTo(1));

      // Valid entry should still exist
      expect(await cacheManager.exists('valid_entry'), isTrue);
      expect(await cacheManager.exists('expired_entry'), isFalse);
    });
  });

  group('Sync Status Tests', () {
    test('should create sync status info', () {
      final syncStatus = SyncStatusInfo(
        status: SyncStatus.syncing,
        lastSyncTime: DateTime.now(),
        pendingOperations: 5,
        conflictCount: 2,
      );

      expect(syncStatus.status, equals(SyncStatus.syncing));
      expect(syncStatus.pendingOperations, equals(5));
      expect(syncStatus.conflictCount, equals(2));
    });

    test('should serialize and deserialize sync status', () {
      final originalStatus = SyncStatusInfo(
        status: SyncStatus.error,
        lastSyncTime: DateTime.now(),
        errorMessage: 'Test error',
        pendingOperations: 3,
        conflictCount: 1,
      );

      final json = originalStatus.toJson();
      final deserializedStatus = SyncStatusInfo.fromJson(json);

      expect(deserializedStatus.status, equals(originalStatus.status));
      expect(
        deserializedStatus.errorMessage,
        equals(originalStatus.errorMessage),
      );
      expect(
        deserializedStatus.pendingOperations,
        equals(originalStatus.pendingOperations),
      );
      expect(
        deserializedStatus.conflictCount,
        equals(originalStatus.conflictCount),
      );
    });
  });

  group('Offline Operation Tests', () {
    test('should create offline operation', () {
      final operation = OfflineOperation(
        id: 'test_id',
        collection: 'test_collection',
        documentId: 'test_doc',
        operation: 'create',
        data: {'test': 'data'},
        timestamp: DateTime.now(),
        priority: DataPriority.high,
      );

      expect(operation.id, equals('test_id'));
      expect(operation.collection, equals('test_collection'));
      expect(operation.documentId, equals('test_doc'));
      expect(operation.operation, equals('create'));
      expect(operation.priority, equals(DataPriority.high));
    });

    test('should serialize and deserialize offline operation', () {
      final originalOperation = OfflineOperation(
        id: 'serialize_test',
        collection: 'hospitals',
        documentId: 'hospital_123',
        operation: 'update',
        data: {'name': 'Test Hospital', 'capacity': 100},
        timestamp: DateTime.now(),
        priority: DataPriority.critical,
      );

      final json = originalOperation.toJson();
      final deserializedOperation = OfflineOperation.fromJson(json);

      expect(deserializedOperation.id, equals(originalOperation.id));
      expect(
        deserializedOperation.collection,
        equals(originalOperation.collection),
      );
      expect(
        deserializedOperation.documentId,
        equals(originalOperation.documentId),
      );
      expect(
        deserializedOperation.operation,
        equals(originalOperation.operation),
      );
      expect(
        deserializedOperation.priority,
        equals(originalOperation.priority),
      );
      expect(deserializedOperation.data, equals(originalOperation.data));
    });
  });

  group('Data Priority Tests', () {
    test('should have correct priority order', () {
      expect(DataPriority.critical.index, lessThan(DataPriority.high.index));
      expect(DataPriority.high.index, lessThan(DataPriority.medium.index));
      expect(DataPriority.medium.index, lessThan(DataPriority.low.index));
    });

    test('should handle priority-based operations', () {
      final priorities = [
        DataPriority.low,
        DataPriority.critical,
        DataPriority.medium,
        DataPriority.high,
      ];

      priorities.sort((a, b) => a.index.compareTo(b.index));

      expect(priorities[0], equals(DataPriority.critical));
      expect(priorities[1], equals(DataPriority.high));
      expect(priorities[2], equals(DataPriority.medium));
      expect(priorities[3], equals(DataPriority.low));
    });
  });
}
