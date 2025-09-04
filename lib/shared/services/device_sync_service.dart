import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'firebase_service.dart';
import 'wearable_device_service.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';
import '../models/firestore/patient_vitals_firestore.dart';

/// Service for handling device data synchronization with offline support and conflict resolution
class DeviceSyncService {
  static final DeviceSyncService _instance = DeviceSyncService._internal();
  factory DeviceSyncService() => _instance;
  DeviceSyncService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final FirebaseService _firebaseService = FirebaseService();
  final WearableDeviceService _wearableService = WearableDeviceService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // Collection names
  static const String _syncQueueCollection = 'sync_queue';
  static const String _conflictResolutionCollection = 'conflict_resolution';

  // Local storage keys
  static const String _offlineVitalsKey = 'offline_vitals';
  static const String _syncStatusKey = 'sync_status';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Sync state
  Timer? _syncTimer;
  bool _isOnline = true;
  bool _isSyncing = false;
  final List<PatientVitals> _offlineQueue = [];

  /// Initialize the device sync service
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing device sync service...');

      // Load offline data from local storage
      await _loadOfflineData();

      // Start connectivity monitoring
      _startConnectivityMonitoring();

      // Start periodic sync
      _startPeriodicSync();

      _logger.i('Device sync service initialized successfully');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize device sync service: $e');
      return false;
    }
  }

  /// Queue vitals data for synchronization (works offline)
  Future<void> queueVitalsForSync({
    required String patientId,
    required PatientVitals vitals,
    String? deviceId,
  }) async {
    try {
      // Add metadata for sync
      final vitalsWithMetadata = PatientVitals(
        heartRate: vitals.heartRate,
        bloodPressure: vitals.bloodPressure,
        bloodPressureSystolic: vitals.bloodPressureSystolic,
        bloodPressureDiastolic: vitals.bloodPressureDiastolic,
        temperature: vitals.temperature,
        oxygenSaturation: vitals.oxygenSaturation,
        respiratoryRate: vitals.respiratoryRate,
        heartRateVariability: vitals.heartRateVariability,
        timestamp: vitals.timestamp,
        deviceSource: vitals.deviceSource,
        deviceId: deviceId ?? vitals.deviceId,
        source: vitals.source,
        dataQuality: vitals.dataQuality,
        accuracy: vitals.accuracy,
      );

      if (_isOnline) {
        // Try to sync immediately if online
        try {
          await _wearableService.storeDeviceVitals(
            patientId: patientId,
            vitals: vitalsWithMetadata,
            deviceId: deviceId,
          );
          _logger.i('Vitals synced immediately for patient $patientId');
          return;
        } catch (e) {
          _logger.w('Immediate sync failed, queuing for later: $e');
          _isOnline = false; // Mark as offline if sync fails
        }
      }

      // Queue for offline sync
      _offlineQueue.add(vitalsWithMetadata);
      await _saveOfflineData();

      _logger.i('Vitals queued for offline sync: patient $patientId');
    } catch (e) {
      _logger.e('Failed to queue vitals for sync: $e');
      rethrow;
    }
  }

  /// Sync all queued data when connection is restored
  Future<void> syncQueuedData() async {
    if (_isSyncing || _offlineQueue.isEmpty) return;

    _isSyncing = true;
    _logger.i('Starting sync of ${_offlineQueue.length} queued vitals records');

    try {
      final syncResults = <SyncResult>[];
      final conflictsToResolve = <ConflictData>[];

      for (int i = 0; i < _offlineQueue.length; i++) {
        final vitals = _offlineQueue[i];

        try {
          // Check for conflicts before syncing
          final hasConflict = await _checkForConflicts(vitals);

          if (hasConflict) {
            conflictsToResolve.add(
              ConflictData(
                vitals: vitals,
                index: i,
                conflictType: ConflictType.timestampOverlap,
              ),
            );
            continue;
          }

          // Sync the vitals
          await _wearableService.storeDeviceVitals(
            patientId:
                vitals.deviceId ?? 'unknown', // This should be passed properly
            vitals: vitals,
          );

          syncResults.add(SyncResult(index: i, success: true, vitals: vitals));
        } catch (e) {
          _logger.e('Failed to sync vitals at index $i: $e');
          syncResults.add(
            SyncResult(
              index: i,
              success: false,
              vitals: vitals,
              error: e.toString(),
            ),
          );
        }
      }

      // Handle conflicts
      if (conflictsToResolve.isNotEmpty) {
        await _resolveConflicts(conflictsToResolve);
      }

      // Remove successfully synced items
      final successfulIndices =
          syncResults
              .where((result) => result.success)
              .map((result) => result.index)
              .toList()
            ..sort((a, b) => b.compareTo(a)); // Sort in descending order

      for (final index in successfulIndices) {
        _offlineQueue.removeAt(index);
      }

      await _saveOfflineData();
      await _updateSyncStatus(syncResults);

      _logger.i(
        'Sync completed: ${syncResults.where((r) => r.success).length} successful, '
        '${syncResults.where((r) => !r.success).length} failed, '
        '${conflictsToResolve.length} conflicts',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Check network connectivity and sync status
  Future<bool> checkConnectivity() async {
    try {
      // Try a simple Firestore operation to check connectivity
      await _firestore.collection('connectivity_test').limit(1).get();

      if (!_isOnline) {
        _isOnline = true;
        _logger.i('Connection restored, starting sync...');
        await syncQueuedData();
      }

      return true;
    } catch (e) {
      if (_isOnline) {
        _isOnline = false;
        _logger.w('Connection lost, switching to offline mode');
      }
      return false;
    }
  }

  /// Get sync status information
  Future<SyncStatus> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getInt(_lastSyncKey);
      final syncStatusJson = prefs.getString(_syncStatusKey);

      return SyncStatus(
        isOnline: _isOnline,
        isSyncing: _isSyncing,
        queuedItems: _offlineQueue.length,
        lastSyncTime: lastSyncTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)
            : null,
        lastSyncResult: syncStatusJson != null
            ? SyncStatusResult.fromJson(jsonDecode(syncStatusJson))
            : null,
      );
    } catch (e) {
      _logger.e('Failed to get sync status: $e');
      return SyncStatus(
        isOnline: _isOnline,
        isSyncing: _isSyncing,
        queuedItems: _offlineQueue.length,
        lastSyncTime: null,
        lastSyncResult: null,
      );
    }
  }

  /// Force a manual sync
  Future<void> forcSync() async {
    _logger.i('Manual sync requested');
    await checkConnectivity();
    if (_isOnline) {
      await syncQueuedData();
    } else {
      throw Exception('Cannot sync: device is offline');
    }
  }

  /// Clear all queued data (use with caution)
  Future<void> clearQueue() async {
    _offlineQueue.clear();
    await _saveOfflineData();
    _logger.w('Sync queue cleared');
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _logger.i('Device sync service disposed');
  }

  // Private helper methods

  Future<void> _loadOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString(_offlineVitalsKey);

      if (offlineDataJson != null) {
        final List<dynamic> offlineData = jsonDecode(offlineDataJson);
        _offlineQueue.clear();

        for (final item in offlineData) {
          try {
            final vitals = PatientVitals.fromJson(item as Map<String, dynamic>);
            _offlineQueue.add(vitals);
          } catch (e) {
            _logger.w('Failed to parse offline vitals data: $e');
          }
        }

        _logger.i('Loaded ${_offlineQueue.length} offline vitals records');
      }
    } catch (e) {
      _logger.e('Failed to load offline data: $e');
    }
  }

  Future<void> _saveOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineData = _offlineQueue
          .map((vitals) => vitals.toJson())
          .toList();
      await prefs.setString(_offlineVitalsKey, jsonEncode(offlineData));
    } catch (e) {
      _logger.e('Failed to save offline data: $e');
    }
  }

  void _startConnectivityMonitoring() {
    Timer.periodic(Duration(seconds: 30), (timer) async {
      await checkConnectivity();
    });
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (_isOnline && _offlineQueue.isNotEmpty) {
        await syncQueuedData();
      }
    });
  }

  Future<bool> _checkForConflicts(PatientVitals vitals) async {
    try {
      // Check for existing vitals within a 2-minute window
      final startTime = vitals.timestamp.subtract(Duration(minutes: 1));
      final endTime = vitals.timestamp.add(Duration(minutes: 1));

      final querySnapshot = await _firestore
          .collection('patient_vitals')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startTime))
          .where('timestamp', isLessThan: Timestamp.fromDate(endTime))
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      _logger.e('Failed to check for conflicts: $e');
      return false;
    }
  }

  Future<void> _resolveConflicts(List<ConflictData> conflicts) async {
    for (final conflict in conflicts) {
      try {
        // Use server-side timestamp precedence and data quality for resolution
        final existingVitals = await _getExistingVitals(conflict.vitals);

        if (existingVitals != null) {
          final shouldOverwrite = _shouldOverwriteExisting(
            conflict.vitals,
            existingVitals,
          );

          if (shouldOverwrite) {
            // Store the new vitals (overwriting)
            await _wearableService.storeDeviceVitals(
              patientId: conflict.vitals.deviceId ?? 'unknown',
              vitals: conflict.vitals,
            );
            _logger.i('Conflict resolved: New vitals stored (higher quality)');
          } else {
            _logger.i(
              'Conflict resolved: Existing vitals kept (higher quality)',
            );
          }
        }

        // Log the conflict resolution
        await _logConflictResolution(conflict, existingVitals);
      } catch (e) {
        _logger.e('Failed to resolve conflict: $e');
      }
    }
  }

  Future<PatientVitalsFirestore?> _getExistingVitals(
    PatientVitals vitals,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('patient_vitals')
          .where('timestamp', isEqualTo: Timestamp.fromDate(vitals.timestamp))
          .where('deviceId', isEqualTo: vitals.deviceId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return PatientVitalsFirestore.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get existing vitals: $e');
      return null;
    }
  }

  bool _shouldOverwriteExisting(
    PatientVitals newVitals,
    PatientVitalsFirestore existingVitals,
  ) {
    // Compare data quality/accuracy
    final newQuality = newVitals.dataQuality ?? newVitals.accuracy ?? 0.5;
    final existingQuality = existingVitals.accuracy;

    // Prefer higher quality data
    if (newQuality > existingQuality + 0.1) return true;
    if (existingQuality > newQuality + 0.1) return false;

    // If quality is similar, prefer more recent timestamp
    return newVitals.timestamp.isAfter(existingVitals.timestamp);
  }

  Future<void> _logConflictResolution(
    ConflictData conflict,
    PatientVitalsFirestore? existingVitals,
  ) async {
    try {
      final resolutionLog = {
        'id': _uuid.v4(),
        'conflictType': conflict.conflictType.toString(),
        'newVitalsTimestamp': Timestamp.fromDate(conflict.vitals.timestamp),
        'existingVitalsTimestamp': existingVitals != null
            ? Timestamp.fromDate(existingVitals.timestamp)
            : null,
        'resolution': existingVitals != null
            ? (_shouldOverwriteExisting(conflict.vitals, existingVitals)
                  ? 'overwrite'
                  : 'keep_existing')
            : 'store_new',
        'resolvedAt': FieldValue.serverTimestamp(),
        'deviceId': conflict.vitals.deviceId,
      };

      await _firestore
          .collection(_conflictResolutionCollection)
          .add(resolutionLog);
    } catch (e) {
      _logger.e('Failed to log conflict resolution: $e');
    }
  }

  Future<void> _updateSyncStatus(List<SyncResult> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update last sync timestamp
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

      // Update sync status
      final statusResult = SyncStatusResult(
        totalItems: results.length,
        successfulItems: results.where((r) => r.success).length,
        failedItems: results.where((r) => !r.success).length,
        timestamp: DateTime.now(),
      );

      await prefs.setString(_syncStatusKey, jsonEncode(statusResult.toJson()));
    } catch (e) {
      _logger.e('Failed to update sync status: $e');
    }
  }
}

// Supporting classes

class SyncResult {
  final int index;
  final bool success;
  final PatientVitals vitals;
  final String? error;

  SyncResult({
    required this.index,
    required this.success,
    required this.vitals,
    this.error,
  });
}

class ConflictData {
  final PatientVitals vitals;
  final int index;
  final ConflictType conflictType;

  ConflictData({
    required this.vitals,
    required this.index,
    required this.conflictType,
  });
}

enum ConflictType { timestampOverlap, deviceMismatch, dataQualityDifference }

class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int queuedItems;
  final DateTime? lastSyncTime;
  final SyncStatusResult? lastSyncResult;

  SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    required this.queuedItems,
    this.lastSyncTime,
    this.lastSyncResult,
  });
}

class SyncStatusResult {
  final int totalItems;
  final int successfulItems;
  final int failedItems;
  final DateTime timestamp;

  SyncStatusResult({
    required this.totalItems,
    required this.successfulItems,
    required this.failedItems,
    required this.timestamp,
  });

  factory SyncStatusResult.fromJson(Map<String, dynamic> json) {
    return SyncStatusResult(
      totalItems: json['totalItems'] as int,
      successfulItems: json['successfulItems'] as int,
      failedItems: json['failedItems'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalItems': totalItems,
      'successfulItems': successfulItems,
      'failedItems': failedItems,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
