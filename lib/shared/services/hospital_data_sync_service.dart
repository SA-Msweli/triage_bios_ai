import 'dart:async';
import 'package:logger/logger.dart';
import '../models/firestore/hospital_integration_config_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import 'hospital_integration_config_service.dart';
import 'hospital_api_integration_service.dart';
import 'firestore_data_service.dart';

/// Data synchronization service to keep Firestore updated with real-time hospital data
class HospitalDataSyncService {
  static final HospitalDataSyncService _instance =
      HospitalDataSyncService._internal();
  factory HospitalDataSyncService() => _instance;
  HospitalDataSyncService._internal();

  final Logger _logger = Logger();
  final HospitalIntegrationConfigService _configService =
      HospitalIntegrationConfigService();
  final HospitalAPIIntegrationService _apiService =
      HospitalAPIIntegrationService();
  final FirestoreDataService _firestoreService = FirestoreDataService();

  // Active sync timers
  final Map<String, Timer> _syncTimers = {};
  final Map<String, StreamSubscription> _realTimeSubscriptions = {};

  // Sync statistics
  final Map<String, SyncStatistics> _syncStats = {};

  bool _isInitialized = false;

  /// Initialize the synchronization service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _startAllSyncProcesses();
      _isInitialized = true;
      _logger.i('Hospital data sync service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize hospital data sync service: $e');
      rethrow;
    }
  }

  /// Start synchronization for all configured hospitals
  Future<void> _startAllSyncProcesses() async {
    try {
      final configs = await _configService.getAllHospitalIntegrations(
        isActive: true,
      );

      for (final config in configs) {
        if (config.dataSource != DataSourceType.firestore) {
          await _startHospitalSync(config);
        }
      }

      _logger.i('Started sync processes for ${configs.length} hospitals');
    } catch (e) {
      _logger.e('Failed to start all sync processes: $e');
      rethrow;
    }
  }

  /// Start synchronization for a specific hospital
  Future<void> startHospitalSync(String hospitalId) async {
    try {
      final config = await _configService.getHospitalIntegration(hospitalId);

      if (config == null) {
        _logger.w('No integration config found for hospital $hospitalId');
        return;
      }

      if (config.dataSource == DataSourceType.firestore) {
        _logger.d('Hospital $hospitalId uses Firestore, no sync needed');
        return;
      }

      await _startHospitalSync(config);
      _logger.i('Started sync for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to start sync for hospital $hospitalId: $e');
      rethrow;
    }
  }

  /// Stop synchronization for a specific hospital
  Future<void> stopHospitalSync(String hospitalId) async {
    try {
      // Cancel timer
      _syncTimers[hospitalId]?.cancel();
      _syncTimers.remove(hospitalId);

      // Cancel real-time subscription
      await _realTimeSubscriptions[hospitalId]?.cancel();
      _realTimeSubscriptions.remove(hospitalId);

      // Remove statistics
      _syncStats.remove(hospitalId);

      _logger.i('Stopped sync for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to stop sync for hospital $hospitalId: $e');
    }
  }

  /// Perform manual sync for a hospital
  Future<SyncResult> performManualSync(String hospitalId) async {
    try {
      final config = await _configService.getHospitalIntegration(hospitalId);

      if (config == null) {
        return SyncResult(
          hospitalId: hospitalId,
          success: false,
          timestamp: DateTime.now(),
          errorMessage: 'No integration config found',
        );
      }

      return await _performSync(config);
    } catch (e) {
      _logger.e('Manual sync failed for hospital $hospitalId: $e');
      return SyncResult(
        hospitalId: hospitalId,
        success: false,
        timestamp: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  /// Get sync statistics for a hospital
  SyncStatistics? getSyncStatistics(String hospitalId) {
    return _syncStats[hospitalId];
  }

  /// Get sync statistics for all hospitals
  Map<String, SyncStatistics> getAllSyncStatistics() {
    return Map.from(_syncStats);
  }

  /// Start sync process for a specific hospital configuration
  Future<void> _startHospitalSync(
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      // Stop existing sync if running
      await stopHospitalSync(config.hospitalId);

      // Initialize statistics
      _syncStats[config.hospitalId] = SyncStatistics(
        hospitalId: config.hospitalId,
        totalSyncs: 0,
        successfulSyncs: 0,
        failedSyncs: 0,
        lastSyncTime: null,
        lastSuccessTime: null,
        lastErrorTime: null,
        lastErrorMessage: null,
        averageResponseTime: 0,
      );

      if (config.realTimeEnabled) {
        // Start real-time monitoring
        await _startRealTimeSync(config);
      } else {
        // Start periodic sync
        await _startPeriodicSync(config);
      }
    } catch (e) {
      _logger.e('Failed to start sync for hospital ${config.hospitalId}: $e');
      rethrow;
    }
  }

  /// Start real-time synchronization
  Future<void> _startRealTimeSync(
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      final stream = _apiService.getCapacityUpdatesStream(
        config.hospitalId,
        config,
      );

      final subscription = stream.listen(
        (capacity) async {
          await _updateFirestoreCapacity(config.hospitalId, capacity);
          _updateSyncStatistics(config.hospitalId, true, null);
        },
        onError: (error) {
          _logger.e('Real-time sync error for ${config.hospitalId}: $error');
          _updateSyncStatistics(config.hospitalId, false, error.toString());
        },
      );

      _realTimeSubscriptions[config.hospitalId] = subscription;
      _logger.d('Started real-time sync for hospital ${config.hospitalId}');
    } catch (e) {
      _logger.e(
        'Failed to start real-time sync for hospital ${config.hospitalId}: $e',
      );
      rethrow;
    }
  }

  /// Start periodic synchronization
  Future<void> _startPeriodicSync(
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      // Perform initial sync
      await _performSync(config);

      // Schedule periodic syncs
      final timer = Timer.periodic(
        Duration(minutes: config.syncIntervalMinutes),
        (_) async {
          await _performSync(config);
        },
      );

      _syncTimers[config.hospitalId] = timer;
      _logger.d(
        'Started periodic sync for hospital ${config.hospitalId} (${config.syncIntervalMinutes}min intervals)',
      );
    } catch (e) {
      _logger.e(
        'Failed to start periodic sync for hospital ${config.hospitalId}: $e',
      );
      rethrow;
    }
  }

  /// Perform a single sync operation
  Future<SyncResult> _performSync(
    HospitalIntegrationConfigFirestore config,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.d('Starting sync for hospital ${config.hospitalId}');

      // Get capacity data from API
      final capacity = await _apiService.getHospitalCapacity(
        config.hospitalId,
        config,
      );

      if (capacity != null) {
        // Update Firestore
        await _updateFirestoreCapacity(config.hospitalId, capacity);

        stopwatch.stop();
        _updateSyncStatistics(
          config.hospitalId,
          true,
          null,
          stopwatch.elapsedMilliseconds,
        );

        _logger.d(
          'Sync completed for hospital ${config.hospitalId} in ${stopwatch.elapsedMilliseconds}ms',
        );

        return SyncResult(
          hospitalId: config.hospitalId,
          success: true,
          timestamp: DateTime.now(),
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        throw Exception('No capacity data received from API');
      }
    } catch (e) {
      stopwatch.stop();
      _updateSyncStatistics(
        config.hospitalId,
        false,
        e.toString(),
        stopwatch.elapsedMilliseconds,
      );

      _logger.e('Sync failed for hospital ${config.hospitalId}: $e');

      return SyncResult(
        hospitalId: config.hospitalId,
        success: false,
        timestamp: DateTime.now(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  /// Update Firestore with capacity data
  Future<void> _updateFirestoreCapacity(
    String hospitalId,
    HospitalCapacityFirestore capacity,
  ) async {
    try {
      await _firestoreService.updateHospitalCapacity(capacity);
      _logger.d('Updated Firestore capacity for hospital $hospitalId');
    } catch (e) {
      _logger.e(
        'Failed to update Firestore capacity for hospital $hospitalId: $e',
      );
      rethrow;
    }
  }

  /// Update sync statistics
  void _updateSyncStatistics(
    String hospitalId,
    bool success,
    String? errorMessage, [
    int? responseTimeMs,
  ]) {
    final stats = _syncStats[hospitalId];
    if (stats == null) return;

    final now = DateTime.now();

    _syncStats[hospitalId] = stats.copyWith(
      totalSyncs: stats.totalSyncs + 1,
      successfulSyncs: success
          ? stats.successfulSyncs + 1
          : stats.successfulSyncs,
      failedSyncs: success ? stats.failedSyncs : stats.failedSyncs + 1,
      lastSyncTime: now,
      lastSuccessTime: success ? now : stats.lastSuccessTime,
      lastErrorTime: success ? stats.lastErrorTime : now,
      lastErrorMessage: success ? stats.lastErrorMessage : errorMessage,
      averageResponseTime: responseTimeMs != null
          ? ((stats.averageResponseTime * (stats.totalSyncs - 1)) +
                    responseTimeMs) /
                stats.totalSyncs
          : stats.averageResponseTime,
    );
  }

  /// Restart sync for a hospital (useful after configuration changes)
  Future<void> restartHospitalSync(String hospitalId) async {
    try {
      await stopHospitalSync(hospitalId);
      await startHospitalSync(hospitalId);
      _logger.i('Restarted sync for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to restart sync for hospital $hospitalId: $e');
      rethrow;
    }
  }

  /// Restart all sync processes
  Future<void> restartAllSyncs() async {
    try {
      // Stop all existing syncs
      for (final hospitalId in _syncTimers.keys.toList()) {
        await stopHospitalSync(hospitalId);
      }

      // Start all syncs again
      await _startAllSyncProcesses();

      _logger.i('Restarted all sync processes');
    } catch (e) {
      _logger.e('Failed to restart all syncs: $e');
      rethrow;
    }
  }

  /// Get overall sync health status
  SyncHealthStatus getSyncHealthStatus() {
    final allStats = _syncStats.values.toList();

    if (allStats.isEmpty) {
      return SyncHealthStatus(
        totalHospitals: 0,
        healthyHospitals: 0,
        unhealthyHospitals: 0,
        overallHealthPercentage: 100.0,
        lastChecked: DateTime.now(),
      );
    }

    final now = DateTime.now();
    final healthyThreshold = Duration(
      minutes: 30,
    ); // Consider unhealthy if no sync in 30 minutes

    int healthyCount = 0;
    for (final stats in allStats) {
      if (stats.lastSuccessTime != null &&
          now.difference(stats.lastSuccessTime!) < healthyThreshold) {
        healthyCount++;
      }
    }

    return SyncHealthStatus(
      totalHospitals: allStats.length,
      healthyHospitals: healthyCount,
      unhealthyHospitals: allStats.length - healthyCount,
      overallHealthPercentage: (healthyCount / allStats.length) * 100,
      lastChecked: now,
    );
  }

  /// Dispose all resources
  Future<void> dispose() async {
    try {
      // Cancel all timers
      for (final timer in _syncTimers.values) {
        timer.cancel();
      }
      _syncTimers.clear();

      // Cancel all subscriptions
      for (final subscription in _realTimeSubscriptions.values) {
        await subscription.cancel();
      }
      _realTimeSubscriptions.clear();

      // Clear statistics
      _syncStats.clear();

      _isInitialized = false;
      _logger.i('Hospital data sync service disposed');
    } catch (e) {
      _logger.e('Error disposing hospital data sync service: $e');
    }
  }
}

/// Sync result model
class SyncResult {
  final String hospitalId;
  final bool success;
  final DateTime timestamp;
  final int? responseTimeMs;
  final String? errorMessage;

  const SyncResult({
    required this.hospitalId,
    required this.success,
    required this.timestamp,
    this.responseTimeMs,
    this.errorMessage,
  });
}

/// Sync statistics model
class SyncStatistics {
  final String hospitalId;
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final DateTime? lastSyncTime;
  final DateTime? lastSuccessTime;
  final DateTime? lastErrorTime;
  final String? lastErrorMessage;
  final double averageResponseTime;

  const SyncStatistics({
    required this.hospitalId,
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    this.lastSyncTime,
    this.lastSuccessTime,
    this.lastErrorTime,
    this.lastErrorMessage,
    required this.averageResponseTime,
  });

  SyncStatistics copyWith({
    String? hospitalId,
    int? totalSyncs,
    int? successfulSyncs,
    int? failedSyncs,
    DateTime? lastSyncTime,
    DateTime? lastSuccessTime,
    DateTime? lastErrorTime,
    String? lastErrorMessage,
    double? averageResponseTime,
  }) {
    return SyncStatistics(
      hospitalId: hospitalId ?? this.hospitalId,
      totalSyncs: totalSyncs ?? this.totalSyncs,
      successfulSyncs: successfulSyncs ?? this.successfulSyncs,
      failedSyncs: failedSyncs ?? this.failedSyncs,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSuccessTime: lastSuccessTime ?? this.lastSuccessTime,
      lastErrorTime: lastErrorTime ?? this.lastErrorTime,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
    );
  }

  double get successRate {
    return totalSyncs > 0 ? (successfulSyncs / totalSyncs) * 100 : 0.0;
  }

  bool get isHealthy {
    if (lastSuccessTime == null) return false;
    final now = DateTime.now();
    return now.difference(lastSuccessTime!) < Duration(minutes: 30);
  }
}

/// Sync health status model
class SyncHealthStatus {
  final int totalHospitals;
  final int healthyHospitals;
  final int unhealthyHospitals;
  final double overallHealthPercentage;
  final DateTime lastChecked;

  const SyncHealthStatus({
    required this.totalHospitals,
    required this.healthyHospitals,
    required this.unhealthyHospitals,
    required this.overallHealthPercentage,
    required this.lastChecked,
  });
}
