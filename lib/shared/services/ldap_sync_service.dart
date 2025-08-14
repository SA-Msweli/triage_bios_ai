import 'dart:async';
import 'package:logger/logger.dart';
import 'integrated_auth_service.dart';
import 'ldap_service.dart';

/// Service for automatic LDAP user synchronization and monitoring
class LdapSyncService {
  static final LdapSyncService _instance = LdapSyncService._internal();
  factory LdapSyncService() => _instance;
  LdapSyncService._internal();

  final Logger _logger = Logger();
  final IntegratedAuthService _authService = IntegratedAuthService();

  Timer? _syncTimer;
  Timer? _monitoringTimer;
  bool _isRunning = false;

  // Configuration
  Duration _syncInterval = const Duration(minutes: 15);
  Duration _monitoringInterval = const Duration(minutes: 5);
  bool _autoSyncEnabled = false;

  // Status tracking
  DateTime? _lastSyncTime;
  DateTime? _lastSuccessfulSync;
  String? _lastSyncError;
  int _consecutiveFailures = 0;
  final int _maxConsecutiveFailures = 3;

  /// Start the LDAP synchronization service
  Future<void> start({
    Duration? syncInterval,
    Duration? monitoringInterval,
    bool autoSync = true,
  }) async {
    if (_isRunning) {
      _logger.w('LDAP sync service is already running');
      return;
    }

    try {
      _syncInterval = syncInterval ?? _syncInterval;
      _monitoringInterval = monitoringInterval ?? _monitoringInterval;
      _autoSyncEnabled = autoSync;

      _logger.i(
        'Starting LDAP sync service with sync interval: ${_syncInterval.inMinutes} minutes',
      );

      // Start monitoring timer
      _monitoringTimer = Timer.periodic(
        _monitoringInterval,
        (_) => _monitorLdapConnection(),
      );

      // Start sync timer if auto sync is enabled
      if (_autoSyncEnabled) {
        _syncTimer = Timer.periodic(
          _syncInterval,
          (_) => _performScheduledSync(),
        );
      }

      _isRunning = true;

      // Perform initial sync
      if (_autoSyncEnabled) {
        await _performScheduledSync();
      }

      _logger.i('LDAP sync service started successfully');
    } catch (e) {
      _logger.e('Failed to start LDAP sync service: $e');
      rethrow;
    }
  }

  /// Stop the LDAP synchronization service
  void stop() {
    if (!_isRunning) {
      _logger.w('LDAP sync service is not running');
      return;
    }

    _syncTimer?.cancel();
    _monitoringTimer?.cancel();
    _syncTimer = null;
    _monitoringTimer = null;
    _isRunning = false;

    _logger.i('LDAP sync service stopped');
  }

  /// Perform manual synchronization
  Future<LdapSyncResult> performManualSync() async {
    _logger.i('Performing manual LDAP synchronization');
    return await _performSync(isManual: true);
  }

  /// Get synchronization status
  LdapSyncServiceStatus getStatus() {
    return LdapSyncServiceStatus(
      isRunning: _isRunning,
      autoSyncEnabled: _autoSyncEnabled,
      syncInterval: _syncInterval,
      monitoringInterval: _monitoringInterval,
      lastSyncTime: _lastSyncTime,
      lastSuccessfulSync: _lastSuccessfulSync,
      lastSyncError: _lastSyncError,
      consecutiveFailures: _consecutiveFailures,
      ldapSyncStatus: _authService.getLdapSyncStatus(),
    );
  }

  /// Update sync configuration
  void updateConfiguration({
    Duration? syncInterval,
    Duration? monitoringInterval,
    bool? autoSync,
  }) {
    final wasRunning = _isRunning;

    if (wasRunning) {
      stop();
    }

    if (syncInterval != null) _syncInterval = syncInterval;
    if (monitoringInterval != null) _monitoringInterval = monitoringInterval;
    if (autoSync != null) _autoSyncEnabled = autoSync;

    if (wasRunning) {
      start(
        syncInterval: _syncInterval,
        monitoringInterval: _monitoringInterval,
        autoSync: _autoSyncEnabled,
      );
    }

    _logger.i('LDAP sync configuration updated');
  }

  // Private methods

  Future<void> _performScheduledSync() async {
    if (_authService.authenticationMode == AuthenticationMode.local) {
      return;
    }

    try {
      await _performSync(isManual: false);
    } catch (e) {
      _logger.e('Scheduled LDAP sync failed: $e');
    }
  }

  Future<LdapSyncResult> _performSync({required bool isManual}) async {
    _lastSyncTime = DateTime.now();

    try {
      _logger.i(
        '${isManual ? 'Manual' : 'Scheduled'} LDAP synchronization started',
      );

      final result = await _authService.synchronizeUsersFromLdap();

      if (result.success) {
        _lastSuccessfulSync = DateTime.now();
        _lastSyncError = null;
        _consecutiveFailures = 0;

        _logger.i(
          'LDAP synchronization completed successfully: '
          '${result.successCount} users synced, ${result.errorCount} errors',
        );
      } else {
        _consecutiveFailures++;
        _lastSyncError = result.error;

        _logger.e(
          'LDAP synchronization failed (${_consecutiveFailures}/${_maxConsecutiveFailures}): '
          '${result.error}',
        );

        // Disable auto sync if too many consecutive failures
        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          _logger.e(
            'Too many consecutive LDAP sync failures, disabling auto sync',
          );
          _autoSyncEnabled = false;
          _syncTimer?.cancel();
          _syncTimer = null;
        }
      }

      return result;
    } catch (e) {
      _consecutiveFailures++;
      _lastSyncError = e.toString();

      _logger.e('LDAP synchronization error: $e');
      return LdapSyncResult.error('Synchronization error: $e');
    }
  }

  Future<void> _monitorLdapConnection() async {
    if (_authService.authenticationMode == AuthenticationMode.local) {
      return;
    }

    try {
      final isConnected = await _authService.testLdapConnection();

      if (!isConnected) {
        _logger.w('LDAP connection test failed during monitoring');

        // Try to reconnect
        await _authService.initialize();

        final reconnectTest = await _authService.testLdapConnection();
        if (reconnectTest) {
          _logger.i('LDAP connection restored');
        } else {
          _logger.e('Failed to restore LDAP connection');
        }
      }
    } catch (e) {
      _logger.e('LDAP connection monitoring error: $e');
    }
  }
}

/// LDAP sync service status
class LdapSyncServiceStatus {
  final bool isRunning;
  final bool autoSyncEnabled;
  final Duration syncInterval;
  final Duration monitoringInterval;
  final DateTime? lastSyncTime;
  final DateTime? lastSuccessfulSync;
  final String? lastSyncError;
  final int consecutiveFailures;
  final LdapSyncStatus ldapSyncStatus;

  LdapSyncServiceStatus({
    required this.isRunning,
    required this.autoSyncEnabled,
    required this.syncInterval,
    required this.monitoringInterval,
    this.lastSyncTime,
    this.lastSuccessfulSync,
    this.lastSyncError,
    required this.consecutiveFailures,
    required this.ldapSyncStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'autoSyncEnabled': autoSyncEnabled,
      'syncIntervalMinutes': syncInterval.inMinutes,
      'monitoringIntervalMinutes': monitoringInterval.inMinutes,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'lastSuccessfulSync': lastSuccessfulSync?.toIso8601String(),
      'lastSyncError': lastSyncError,
      'consecutiveFailures': consecutiveFailures,
      'ldapSyncStatus': ldapSyncStatus.toJson(),
    };
  }

  bool get hasRecentError => lastSyncError != null && consecutiveFailures > 0;

  bool get isHealthy =>
      isRunning &&
      (lastSuccessfulSync != null &&
          DateTime.now().difference(lastSuccessfulSync!).inHours < 24) &&
      consecutiveFailures == 0;
}
