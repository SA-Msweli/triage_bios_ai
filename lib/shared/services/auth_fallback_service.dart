import 'dart:async';
import 'package:logger/logger.dart';
import 'integrated_auth_service.dart';

/// Service that manages authentication fallback mechanisms
class AuthFallbackService {
  static final AuthFallbackService _instance = AuthFallbackService._internal();
  factory AuthFallbackService() => _instance;
  AuthFallbackService._internal();

  final Logger _logger = Logger();
  final IntegratedAuthService _authService = IntegratedAuthService();

  Timer? _healthCheckTimer;
  bool _isMonitoring = false;

  // Fallback configuration
  Duration _healthCheckInterval = const Duration(minutes: 2);
  int _maxFailureCount = 3;
  Duration _fallbackCooldown = const Duration(minutes: 10);

  // Status tracking
  AuthenticationMode _originalMode = AuthenticationMode.local;
  AuthenticationMode _currentMode = AuthenticationMode.local;
  bool _isInFallbackMode = false;
  DateTime? _fallbackStartTime;
  DateTime? _lastHealthCheck;
  int _consecutiveFailures = 0;
  String? _lastError;
  final List<AuthFallbackEvent> _eventHistory = [];

  /// Start monitoring authentication health
  Future<void> startMonitoring({
    Duration? healthCheckInterval,
    int? maxFailureCount,
    Duration? fallbackCooldown,
  }) async {
    if (_isMonitoring) {
      _logger.w('Auth fallback monitoring is already running');
      return;
    }

    _healthCheckInterval = healthCheckInterval ?? _healthCheckInterval;
    _maxFailureCount = maxFailureCount ?? _maxFailureCount;
    _fallbackCooldown = fallbackCooldown ?? _fallbackCooldown;

    _originalMode = _authService.authenticationMode;
    _currentMode = _originalMode;

    _logger.i(
      'Starting auth fallback monitoring with interval: ${_healthCheckInterval.inMinutes} minutes',
    );

    _healthCheckTimer = Timer.periodic(
      _healthCheckInterval,
      (_) => _performHealthCheck(),
    );
    _isMonitoring = true;

    // Perform initial health check
    await _performHealthCheck();

    _logger.i('Auth fallback monitoring started');
  }

  /// Stop monitoring authentication health
  void stopMonitoring() {
    if (!_isMonitoring) {
      _logger.w('Auth fallback monitoring is not running');
      return;
    }

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _isMonitoring = false;

    _logger.i('Auth fallback monitoring stopped');
  }

  /// Manually trigger fallback to local authentication
  Future<bool> triggerFallback(String reason) async {
    if (_isInFallbackMode) {
      _logger.w('Already in fallback mode');
      return false;
    }

    try {
      _logger.w('Triggering manual fallback to local authentication: $reason');

      await _activateFallback(reason, isManual: true);
      return true;
    } catch (e) {
      _logger.e('Failed to trigger fallback: $e');
      return false;
    }
  }

  /// Manually restore primary authentication
  Future<bool> restorePrimary() async {
    if (!_isInFallbackMode) {
      _logger.w('Not in fallback mode');
      return false;
    }

    try {
      _logger.i('Attempting to restore primary authentication');

      // Test primary authentication
      final isHealthy = await _testPrimaryAuth();
      if (isHealthy) {
        await _restorePrimaryAuth('Manual restoration');
        return true;
      } else {
        _logger.w('Primary authentication is still unhealthy, cannot restore');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to restore primary authentication: $e');
      return false;
    }
  }

  /// Get fallback service status
  AuthFallbackStatus getStatus() {
    return AuthFallbackStatus(
      isMonitoring: _isMonitoring,
      originalMode: _originalMode,
      currentMode: _currentMode,
      isInFallbackMode: _isInFallbackMode,
      fallbackStartTime: _fallbackStartTime,
      lastHealthCheck: _lastHealthCheck,
      consecutiveFailures: _consecutiveFailures,
      lastError: _lastError,
      eventHistory: List.from(_eventHistory),
      healthCheckInterval: _healthCheckInterval,
      maxFailureCount: _maxFailureCount,
      fallbackCooldown: _fallbackCooldown,
    );
  }

  /// Update fallback configuration
  void updateConfiguration({
    Duration? healthCheckInterval,
    int? maxFailureCount,
    Duration? fallbackCooldown,
  }) {
    final wasMonitoring = _isMonitoring;

    if (wasMonitoring) {
      stopMonitoring();
    }

    if (healthCheckInterval != null) _healthCheckInterval = healthCheckInterval;
    if (maxFailureCount != null) _maxFailureCount = maxFailureCount;
    if (fallbackCooldown != null) _fallbackCooldown = fallbackCooldown;

    if (wasMonitoring) {
      startMonitoring(
        healthCheckInterval: _healthCheckInterval,
        maxFailureCount: _maxFailureCount,
        fallbackCooldown: _fallbackCooldown,
      );
    }

    _logger.i('Auth fallback configuration updated');
  }

  // Private methods

  Future<void> _performHealthCheck() async {
    _lastHealthCheck = DateTime.now();

    try {
      if (_originalMode == AuthenticationMode.local) {
        // No fallback needed for local-only mode
        return;
      }

      final isHealthy = await _testPrimaryAuth();

      if (isHealthy) {
        _consecutiveFailures = 0;
        _lastError = null;

        // If we're in fallback mode and primary is healthy, try to restore
        if (_isInFallbackMode && _canRestorePrimary()) {
          await _restorePrimaryAuth('Health check passed');
        }
      } else {
        _consecutiveFailures++;
        _lastError = 'Primary authentication health check failed';

        _logger.w(
          'Auth health check failed (${_consecutiveFailures}/${_maxFailureCount})',
        );

        // Trigger fallback if threshold reached
        if (!_isInFallbackMode && _consecutiveFailures >= _maxFailureCount) {
          await _activateFallback('Health check failures exceeded threshold');
        }
      }
    } catch (e) {
      _consecutiveFailures++;
      _lastError = e.toString();
      _logger.e('Auth health check error: $e');
    }
  }

  Future<bool> _testPrimaryAuth() async {
    try {
      switch (_originalMode) {
        case AuthenticationMode.ldapOnly:
        case AuthenticationMode.ldapWithFallback:
          return await _authService.testLdapConnection();
        case AuthenticationMode.local:
          return true; // Local auth is always available
      }
    } catch (e) {
      _logger.e('Primary auth test failed: $e');
      return false;
    }
  }

  Future<void> _activateFallback(String reason, {bool isManual = false}) async {
    try {
      _logger.w('Activating fallback to local authentication: $reason');

      // Switch to local authentication mode
      _currentMode = AuthenticationMode.local;
      _isInFallbackMode = true;
      _fallbackStartTime = DateTime.now();

      // Enable fallback in auth service
      _authService.setLdapFallback(true);

      // Record event
      _addEvent(
        AuthFallbackEventType.fallbackActivated,
        reason,
        isManual: isManual,
      );

      _logger.i('Fallback to local authentication activated');
    } catch (e) {
      _logger.e('Failed to activate fallback: $e');
      rethrow;
    }
  }

  Future<void> _restorePrimaryAuth(String reason) async {
    try {
      _logger.i('Restoring primary authentication: $reason');

      // Switch back to original mode
      _currentMode = _originalMode;
      _isInFallbackMode = false;
      _fallbackStartTime = null;
      _consecutiveFailures = 0;
      _lastError = null;

      // Record event
      _addEvent(AuthFallbackEventType.primaryRestored, reason);

      _logger.i('Primary authentication restored');
    } catch (e) {
      _logger.e('Failed to restore primary authentication: $e');
      rethrow;
    }
  }

  bool _canRestorePrimary() {
    if (!_isInFallbackMode || _fallbackStartTime == null) {
      return false;
    }

    // Wait for cooldown period before attempting to restore
    final timeSinceFallback = DateTime.now().difference(_fallbackStartTime!);
    return timeSinceFallback >= _fallbackCooldown;
  }

  void _addEvent(
    AuthFallbackEventType type,
    String reason, {
    bool isManual = false,
  }) {
    final event = AuthFallbackEvent(
      timestamp: DateTime.now(),
      type: type,
      reason: reason,
      isManual: isManual,
      originalMode: _originalMode,
      currentMode: _currentMode,
    );

    _eventHistory.add(event);

    // Keep only last 100 events
    if (_eventHistory.length > 100) {
      _eventHistory.removeAt(0);
    }
  }
}

/// Authentication fallback status
class AuthFallbackStatus {
  final bool isMonitoring;
  final AuthenticationMode originalMode;
  final AuthenticationMode currentMode;
  final bool isInFallbackMode;
  final DateTime? fallbackStartTime;
  final DateTime? lastHealthCheck;
  final int consecutiveFailures;
  final String? lastError;
  final List<AuthFallbackEvent> eventHistory;
  final Duration healthCheckInterval;
  final int maxFailureCount;
  final Duration fallbackCooldown;

  AuthFallbackStatus({
    required this.isMonitoring,
    required this.originalMode,
    required this.currentMode,
    required this.isInFallbackMode,
    this.fallbackStartTime,
    this.lastHealthCheck,
    required this.consecutiveFailures,
    this.lastError,
    required this.eventHistory,
    required this.healthCheckInterval,
    required this.maxFailureCount,
    required this.fallbackCooldown,
  });

  Map<String, dynamic> toJson() {
    return {
      'isMonitoring': isMonitoring,
      'originalMode': originalMode.name,
      'currentMode': currentMode.name,
      'isInFallbackMode': isInFallbackMode,
      'fallbackStartTime': fallbackStartTime?.toIso8601String(),
      'lastHealthCheck': lastHealthCheck?.toIso8601String(),
      'consecutiveFailures': consecutiveFailures,
      'lastError': lastError,
      'eventHistory': eventHistory.map((e) => e.toJson()).toList(),
      'healthCheckIntervalMinutes': healthCheckInterval.inMinutes,
      'maxFailureCount': maxFailureCount,
      'fallbackCooldownMinutes': fallbackCooldown.inMinutes,
    };
  }

  bool get isHealthy =>
      isMonitoring && consecutiveFailures == 0 && lastError == null;

  Duration? get timeSinceFallback => fallbackStartTime != null
      ? DateTime.now().difference(fallbackStartTime!)
      : null;
}

/// Authentication fallback event
class AuthFallbackEvent {
  final DateTime timestamp;
  final AuthFallbackEventType type;
  final String reason;
  final bool isManual;
  final AuthenticationMode originalMode;
  final AuthenticationMode currentMode;

  AuthFallbackEvent({
    required this.timestamp,
    required this.type,
    required this.reason,
    required this.isManual,
    required this.originalMode,
    required this.currentMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'reason': reason,
      'isManual': isManual,
      'originalMode': originalMode.name,
      'currentMode': currentMode.name,
    };
  }

  factory AuthFallbackEvent.fromJson(Map<String, dynamic> json) {
    return AuthFallbackEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: AuthFallbackEventType.values.firstWhere(
        (t) => t.name == json['type'],
      ),
      reason: json['reason'] as String,
      isManual: json['isManual'] as bool,
      originalMode: AuthenticationMode.values.firstWhere(
        (m) => m.name == json['originalMode'],
      ),
      currentMode: AuthenticationMode.values.firstWhere(
        (m) => m.name == json['currentMode'],
      ),
    );
  }
}

/// Types of fallback events
enum AuthFallbackEventType {
  fallbackActivated,
  primaryRestored,
  healthCheckFailed,
  healthCheckPassed,
}
