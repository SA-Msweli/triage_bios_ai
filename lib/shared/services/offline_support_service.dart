import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firebase_service.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/triage_result_firestore.dart';

/// Enumeration for sync status
enum SyncStatus { synced, syncing, offline, error, conflictResolution }

/// Enumeration for data priority levels
enum DataPriority {
  critical, // Emergency contacts, critical hospital data
  high, // Hospital capacity, patient vitals
  medium, // Triage results, patient history
  low, // Analytics, logs
}

/// Model for sync status information
class SyncStatusInfo {
  final SyncStatus status;
  final DateTime lastSyncTime;
  final String? errorMessage;
  final int pendingOperations;
  final int conflictCount;

  const SyncStatusInfo({
    required this.status,
    required this.lastSyncTime,
    this.errorMessage,
    this.pendingOperations = 0,
    this.conflictCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'lastSyncTime': lastSyncTime.toIso8601String(),
    'errorMessage': errorMessage,
    'pendingOperations': pendingOperations,
    'conflictCount': conflictCount,
  };

  factory SyncStatusInfo.fromJson(Map<String, dynamic> json) => SyncStatusInfo(
    status: SyncStatus.values.firstWhere((e) => e.name == json['status']),
    lastSyncTime: DateTime.parse(json['lastSyncTime']),
    errorMessage: json['errorMessage'],
    pendingOperations: json['pendingOperations'] ?? 0,
    conflictCount: json['conflictCount'] ?? 0,
  );
}

/// Model for offline data operations
class OfflineOperation {
  final String id;
  final String collection;
  final String documentId;
  final String operation; // 'create', 'update', 'delete'
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final DataPriority priority;

  const OfflineOperation({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.operation,
    this.data,
    required this.timestamp,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'documentId': documentId,
    'operation': operation,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'priority': priority.name,
  };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) =>
      OfflineOperation(
        id: json['id'],
        collection: json['collection'],
        documentId: json['documentId'],
        operation: json['operation'],
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp']),
        priority: DataPriority.values.firstWhere(
          (e) => e.name == json['priority'],
        ),
      );
}

/// Service for managing offline support and intelligent caching
class OfflineSupportService {
  static final OfflineSupportService _instance =
      OfflineSupportService._internal();
  factory OfflineSupportService() => _instance;
  OfflineSupportService._internal();

  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  // Stream controllers for real-time status updates
  final StreamController<SyncStatusInfo> _syncStatusController =
      StreamController<SyncStatusInfo>.broadcast();
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  // Cache management
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, DataPriority> _cachePriorities = {};

  // Offline operations queue
  final List<OfflineOperation> _pendingOperations = [];

  // Configuration
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration _criticalDataTTL = Duration(minutes: 5);
  static const Duration _highPriorityTTL = Duration(minutes: 15);
  static const Duration _mediumPriorityTTL = Duration(hours: 1);
  static const Duration _lowPriorityTTL = Duration(hours: 6);

  // State
  bool _isOnline = true;
  SyncStatusInfo _currentSyncStatus = SyncStatusInfo(
    status: SyncStatus.synced,
    lastSyncTime: DateTime.now(),
  );

  /// Initialize offline support service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing offline support service...');

      // Configure Firestore offline persistence
      await _configureFirestoreOfflineSettings();

      // Load cached data and pending operations
      await _loadCachedData();
      await _loadPendingOperations();

      // Start connectivity monitoring
      _startConnectivityMonitoring();

      // Start periodic sync
      _startPeriodicSync();

      _logger.i('Offline support service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize offline support service: $e');
      rethrow;
    }
  }

  /// Configure Firestore offline persistence settings
  Future<void> _configureFirestoreOfflineSettings() async {
    try {
      final firestore = _firebaseService.firestore;

      // Configure offline persistence with optimized settings
      if (!kIsWeb) {
        // Mobile platforms support full offline persistence
        await firestore.enablePersistence(
          const PersistenceSettings(synchronizeTabs: true),
        );
        _logger.i('Firestore offline persistence enabled for mobile');
      } else {
        // Web platform has limited offline support
        await firestore.enablePersistence(
          const PersistenceSettings(synchronizeTabs: true),
        );
        _logger.i('Firestore offline persistence enabled for web');
      }

      // Configure cache settings for optimal performance
      firestore.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: kIsWeb
            ? 40 * 1024 * 1024
            : Settings
                  .CACHE_SIZE_UNLIMITED, // 40MB for web, unlimited for mobile
        ignoreUndefinedProperties: false,
      );
    } catch (e) {
      _logger.w('Firestore offline persistence configuration failed: $e');
      // Continue without offline persistence if it fails
    }
  }

  /// Start monitoring network connectivity
  void _startConnectivityMonitoring() {
    // Monitor Firestore connection state
    _firebaseService.firestore.snapshotsInSync().listen(
      (_) {
        if (!_isOnline) {
          _isOnline = true;
          _connectivityController.add(true);
          _updateSyncStatus(SyncStatus.syncing);
          _processPendingOperations();
        }
      },
      onError: (error) {
        if (_isOnline) {
          _isOnline = false;
          _connectivityController.add(false);
          _updateSyncStatus(SyncStatus.offline);
        }
      },
    );
  }

  /// Start periodic sync process
  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && _pendingOperations.isNotEmpty) {
        _processPendingOperations();
      }
      _cleanupExpiredCache();
    });
  }

  /// Update sync status and notify listeners
  void _updateSyncStatus(SyncStatus status, {String? errorMessage}) {
    _currentSyncStatus = SyncStatusInfo(
      status: status,
      lastSyncTime: status == SyncStatus.synced
          ? DateTime.now()
          : _currentSyncStatus.lastSyncTime,
      errorMessage: errorMessage,
      pendingOperations: _pendingOperations.length,
      conflictCount: _pendingOperations
          .where((op) => op.operation == 'conflict')
          .length,
    );

    _syncStatusController.add(_currentSyncStatus);
    _saveSyncStatus();
  }

  /// Get current sync status stream
  Stream<SyncStatusInfo> get syncStatusStream => _syncStatusController.stream;

  /// Get current connectivity stream
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Get current sync status
  SyncStatusInfo get currentSyncStatus => _currentSyncStatus;

  /// Check if device is currently online
  bool get isOnline => _isOnline;

  /// Cache data with intelligent prioritization
  Future<void> cacheData({
    required String key,
    required dynamic data,
    required DataPriority priority,
    Duration? customTTL,
  }) async {
    try {
      final now = DateTime.now();

      // Store in memory cache
      _memoryCache[key] = data;
      _cacheTimestamps[key] = now;
      _cachePriorities[key] = priority;

      // Store in persistent cache for critical and high priority data
      if (priority == DataPriority.critical || priority == DataPriority.high) {
        await _saveToPersistentCache(key, data, priority, customTTL);
      }

      // Cleanup cache if it exceeds size limit
      await _cleanupCacheIfNeeded();
    } catch (e) {
      _logger.e('Failed to cache data for key $key: $e');
    }
  }

  /// Retrieve cached data
  Future<T?> getCachedData<T>(String key) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        final timestamp = _cacheTimestamps[key];
        final priority = _cachePriorities[key];

        if (timestamp != null &&
            priority != null &&
            !_isCacheExpired(timestamp, priority)) {
          return _memoryCache[key] as T?;
        } else {
          // Remove expired data
          _memoryCache.remove(key);
          _cacheTimestamps.remove(key);
          _cachePriorities.remove(key);
        }
      }

      // Check persistent cache
      return await _getFromPersistentCache<T>(key);
    } catch (e) {
      _logger.e('Failed to retrieve cached data for key $key: $e');
      return null;
    }
  }

  /// Check if cache entry is expired
  bool _isCacheExpired(DateTime timestamp, DataPriority priority) {
    final now = DateTime.now();
    final age = now.difference(timestamp);

    switch (priority) {
      case DataPriority.critical:
        return age > _criticalDataTTL;
      case DataPriority.high:
        return age > _highPriorityTTL;
      case DataPriority.medium:
        return age > _mediumPriorityTTL;
      case DataPriority.low:
        return age > _lowPriorityTTL;
    }
  }

  /// Save data to persistent cache
  Future<void> _saveToPersistentCache(
    String key,
    dynamic data,
    DataPriority priority,
    Duration? customTTL,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheEntry = {
        'data': data,
        'priority': priority.name,
        'timestamp': DateTime.now().toIso8601String(),
        'customTTL': customTTL?.inMilliseconds,
      };

      await prefs.setString('cache_$key', jsonEncode(cacheEntry));
    } catch (e) {
      _logger.e('Failed to save to persistent cache: $e');
    }
  }

  /// Get data from persistent cache
  Future<T?> _getFromPersistentCache<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('cache_$key');

      if (cacheData != null) {
        final cacheEntry = jsonDecode(cacheData);
        final timestamp = DateTime.parse(cacheEntry['timestamp']);
        final priority = DataPriority.values.firstWhere(
          (e) => e.name == cacheEntry['priority'],
        );

        if (!_isCacheExpired(timestamp, priority)) {
          return cacheEntry['data'] as T?;
        } else {
          // Remove expired entry
          await prefs.remove('cache_$key');
        }
      }

      return null;
    } catch (e) {
      _logger.e('Failed to get from persistent cache: $e');
      return null;
    }
  }

  /// Add offline operation to queue
  Future<void> addOfflineOperation(OfflineOperation operation) async {
    try {
      _pendingOperations.add(operation);
      await _savePendingOperations();
      _updateSyncStatus(_isOnline ? SyncStatus.syncing : SyncStatus.offline);

      // Try to process immediately if online
      if (_isOnline) {
        _processPendingOperations();
      }
    } catch (e) {
      _logger.e('Failed to add offline operation: $e');
    }
  }

  /// Process pending offline operations
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty || !_isOnline) return;

    try {
      _updateSyncStatus(SyncStatus.syncing);

      // Sort operations by priority and timestamp
      _pendingOperations.sort((a, b) {
        final priorityComparison = a.priority.index.compareTo(b.priority.index);
        if (priorityComparison != 0) return priorityComparison;
        return a.timestamp.compareTo(b.timestamp);
      });

      final batch = _firebaseService.firestore.batch();
      final processedOperations = <OfflineOperation>[];

      for (final operation in _pendingOperations) {
        try {
          await _processOperation(operation, batch);
          processedOperations.add(operation);
        } catch (e) {
          _logger.e('Failed to process operation ${operation.id}: $e');
          // Handle conflicts or errors
          if (e.toString().contains('conflict') ||
              e.toString().contains('version')) {
            await _handleConflict(operation);
          }
        }
      }

      // Commit batch operations
      if (processedOperations.isNotEmpty) {
        await batch.commit();

        // Remove processed operations
        for (final op in processedOperations) {
          _pendingOperations.remove(op);
        }

        await _savePendingOperations();
      }

      _updateSyncStatus(
        _pendingOperations.isEmpty ? SyncStatus.synced : SyncStatus.syncing,
      );
    } catch (e) {
      _logger.e('Failed to process pending operations: $e');
      _updateSyncStatus(SyncStatus.error, errorMessage: e.toString());
    }
  }

  /// Process individual operation
  Future<void> _processOperation(
    OfflineOperation operation,
    WriteBatch batch,
  ) async {
    final docRef = _firebaseService.firestore
        .collection(operation.collection)
        .doc(operation.documentId);

    switch (operation.operation) {
      case 'create':
        if (operation.data != null) {
          batch.set(docRef, operation.data!);
        }
        break;
      case 'update':
        if (operation.data != null) {
          batch.update(docRef, operation.data!);
        }
        break;
      case 'delete':
        batch.delete(docRef);
        break;
    }
  }

  /// Handle data conflicts with server-side timestamp precedence
  Future<void> _handleConflict(OfflineOperation operation) async {
    try {
      _updateSyncStatus(SyncStatus.conflictResolution);

      // Get current server data
      final docRef = _firebaseService.firestore
          .collection(operation.collection)
          .doc(operation.documentId);

      final serverDoc = await docRef.get();

      if (serverDoc.exists) {
        final serverData = serverDoc.data() as Map<String, dynamic>;
        final serverTimestamp = serverData['updatedAt'] as Timestamp?;

        if (serverTimestamp != null) {
          final serverTime = serverTimestamp.toDate();

          // Server-side timestamp precedence: if server data is newer, discard local changes
          if (serverTime.isAfter(operation.timestamp)) {
            _logger.i(
              'Server data is newer, discarding local changes for ${operation.documentId}',
            );

            // Update local cache with server data
            await cacheData(
              key: '${operation.collection}_${operation.documentId}',
              data: serverData,
              priority: DataPriority.high,
            );

            // Remove conflicted operation
            _pendingOperations.remove(operation);
            await _savePendingOperations();
            return;
          }
        }
      }

      // If local data is newer or server data doesn't exist, retry the operation
      await _processOperation(operation, _firebaseService.firestore.batch());
    } catch (e) {
      _logger.e('Failed to handle conflict for operation ${operation.id}: $e');
    }
  }

  /// Manually trigger sync
  Future<void> manualSync() async {
    try {
      _logger.i('Manual sync triggered');
      _updateSyncStatus(SyncStatus.syncing);

      if (_isOnline) {
        await _processPendingOperations();
        await _refreshCriticalData();
      } else {
        _updateSyncStatus(
          SyncStatus.offline,
          errorMessage: 'Device is offline',
        );
      }
    } catch (e) {
      _logger.e('Manual sync failed: $e');
      _updateSyncStatus(SyncStatus.error, errorMessage: e.toString());
    }
  }

  /// Refresh critical data from server
  Future<void> _refreshCriticalData() async {
    try {
      // Refresh critical hospital data
      final hospitalsSnapshot = await _firebaseService.firestore
          .collection('hospitals')
          .where('isActive', isEqualTo: true)
          .limit(50)
          .get();

      for (final doc in hospitalsSnapshot.docs) {
        await cacheData(
          key: 'hospital_${doc.id}',
          data: doc.data(),
          priority: DataPriority.critical,
        );
      }

      // Refresh hospital capacity data
      final capacitySnapshot = await _firebaseService.firestore
          .collection('hospital_capacity')
          .orderBy('lastUpdated', descending: true)
          .limit(100)
          .get();

      for (final doc in capacitySnapshot.docs) {
        await cacheData(
          key: 'capacity_${doc.id}',
          data: doc.data(),
          priority: DataPriority.high,
        );
      }
    } catch (e) {
      _logger.e('Failed to refresh critical data: $e');
    }
  }

  /// Clean up expired cache entries
  Future<void> _cleanupExpiredCache() async {
    try {
      final now = DateTime.now();
      final expiredKeys = <String>[];

      // Check memory cache
      for (final entry in _cacheTimestamps.entries) {
        final priority = _cachePriorities[entry.key];
        if (priority != null && _isCacheExpired(entry.value, priority)) {
          expiredKeys.add(entry.key);
        }
      }

      // Remove expired entries
      for (final key in expiredKeys) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
        _cachePriorities.remove(key);
      }

      // Clean up persistent cache
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));

      for (final key in keys) {
        final cacheData = prefs.getString(key);
        if (cacheData != null) {
          try {
            final cacheEntry = jsonDecode(cacheData);
            final timestamp = DateTime.parse(cacheEntry['timestamp']);
            final priority = DataPriority.values.firstWhere(
              (e) => e.name == cacheEntry['priority'],
            );

            if (_isCacheExpired(timestamp, priority)) {
              await prefs.remove(key);
            }
          } catch (e) {
            // Remove corrupted cache entries
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
      _logger.e('Failed to cleanup expired cache: $e');
    }
  }

  /// Clean up cache if it exceeds size limit
  Future<void> _cleanupCacheIfNeeded() async {
    try {
      // Estimate memory cache size (rough calculation)
      final estimatedSize = _memoryCache.length * 1024; // Rough estimate

      if (estimatedSize > _maxCacheSize) {
        // Remove low priority items first
        final lowPriorityKeys = _cachePriorities.entries
            .where((entry) => entry.value == DataPriority.low)
            .map((entry) => entry.key)
            .toList();

        for (final key in lowPriorityKeys) {
          _memoryCache.remove(key);
          _cacheTimestamps.remove(key);
          _cachePriorities.remove(key);

          if (_memoryCache.length * 1024 < _maxCacheSize * 0.8) break;
        }
      }
    } catch (e) {
      _logger.e('Failed to cleanup cache: $e');
    }
  }

  /// Load cached data from persistent storage
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));

      for (final key in keys) {
        final cacheData = prefs.getString(key);
        if (cacheData != null) {
          try {
            final cacheEntry = jsonDecode(cacheData);
            final timestamp = DateTime.parse(cacheEntry['timestamp']);
            final priority = DataPriority.values.firstWhere(
              (e) => e.name == cacheEntry['priority'],
            );

            if (!_isCacheExpired(timestamp, priority)) {
              final cacheKey = key.substring(6); // Remove 'cache_' prefix
              _memoryCache[cacheKey] = cacheEntry['data'];
              _cacheTimestamps[cacheKey] = timestamp;
              _cachePriorities[cacheKey] = priority;
            }
          } catch (e) {
            // Remove corrupted cache entries
            await prefs.remove(key);
          }
        }
      }

      _logger.i('Loaded ${_memoryCache.length} cached entries');
    } catch (e) {
      _logger.e('Failed to load cached data: $e');
    }
  }

  /// Load pending operations from persistent storage
  Future<void> _loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsData = prefs.getString('pending_operations');

      if (operationsData != null) {
        final operationsList = jsonDecode(operationsData) as List;
        _pendingOperations.clear();

        for (final opData in operationsList) {
          _pendingOperations.add(OfflineOperation.fromJson(opData));
        }

        _logger.i('Loaded ${_pendingOperations.length} pending operations');
      }
    } catch (e) {
      _logger.e('Failed to load pending operations: $e');
    }
  }

  /// Save pending operations to persistent storage
  Future<void> _savePendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsData = _pendingOperations
          .map((op) => op.toJson())
          .toList();
      await prefs.setString('pending_operations', jsonEncode(operationsData));
    } catch (e) {
      _logger.e('Failed to save pending operations: $e');
    }
  }

  /// Save sync status to persistent storage
  Future<void> _saveSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'sync_status',
        jsonEncode(_currentSyncStatus.toJson()),
      );
    } catch (e) {
      _logger.e('Failed to save sync status: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      _cacheTimestamps.clear();
      _cachePriorities.clear();

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));

      for (final key in keys) {
        await prefs.remove(key);
      }

      _logger.i('Cache cleared successfully');
    } catch (e) {
      _logger.e('Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final stats = <DataPriority, int>{};
    for (final priority in _cachePriorities.values) {
      stats[priority] = (stats[priority] ?? 0) + 1;
    }

    return {
      'totalEntries': _memoryCache.length,
      'criticalEntries': stats[DataPriority.critical] ?? 0,
      'highPriorityEntries': stats[DataPriority.high] ?? 0,
      'mediumPriorityEntries': stats[DataPriority.medium] ?? 0,
      'lowPriorityEntries': stats[DataPriority.low] ?? 0,
      'pendingOperations': _pendingOperations.length,
      'isOnline': _isOnline,
      'lastSyncTime': _currentSyncStatus.lastSyncTime.toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    _syncStatusController.close();
    _connectivityController.close();
  }
}
