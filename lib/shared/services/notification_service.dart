import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'real_time_monitoring_service.dart';

/// Service for handling notifications and alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final Logger _logger = Logger();
  final RealTimeMonitoringService _monitoringService =
      RealTimeMonitoringService();

  // Stream controllers for UI notifications
  final StreamController<AppNotification> _notificationsController =
      StreamController<AppNotification>.broadcast();

  // Active subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Notification settings
  bool _isInitialized = false;
  bool _capacityAlertsEnabled = true;
  bool _vitalsAlertsEnabled = true;
  bool _soundEnabled = true;
  AlertSeverity _minimumSeverity = AlertSeverity.warning;

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Stream of app notifications
  Stream<AppNotification> get notifications => _notificationsController.stream;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('Notification service already initialized');
      return;
    }

    try {
      _logger.i('Initializing notification service...');

      // Subscribe to capacity alerts
      _subscriptions.add(
        _monitoringService.capacityAlerts.listen(_handleCapacityAlert),
      );

      // Subscribe to vitals alerts
      _subscriptions.add(
        _monitoringService.vitalsAlerts.listen(_handleVitalsAlert),
      );

      _isInitialized = true;
      _logger.i('Notification service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  /// Show a custom notification
  void showNotification({
    required String title,
    required String message,
    AlertSeverity severity = AlertSeverity.info,
    Duration? duration,
    VoidCallback? onTap,
    Map<String, dynamic>? data,
  }) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      severity: severity,
      timestamp: DateTime.now(),
      duration: duration ?? _getDefaultDuration(severity),
      onTap: onTap,
      data: data,
    );

    _notificationsController.add(notification);
  }

  /// Show capacity alert notification
  void showCapacityAlert(CapacityAlert alert) {
    if (!_capacityAlertsEnabled ||
        alert.severity.index < _minimumSeverity.index) {
      return;
    }

    final notification = AppNotification(
      id: 'capacity_${alert.hospitalId}_${alert.timestamp.millisecondsSinceEpoch}',
      title: _getCapacityAlertTitle(alert.type),
      message: alert.message,
      severity: alert.severity,
      timestamp: alert.timestamp,
      duration: _getDefaultDuration(alert.severity),
      icon: _getCapacityAlertIcon(alert.type),
      data: {
        'type': 'capacity_alert',
        'hospitalId': alert.hospitalId,
        'alertType': alert.type.toString(),
      },
    );

    _notificationsController.add(notification);
  }

  /// Show vitals alert notification
  void showVitalsAlert(VitalsAlert alert) {
    if (!_vitalsAlertsEnabled ||
        alert.severity.index < _minimumSeverity.index) {
      return;
    }

    final notification = AppNotification(
      id: 'vitals_${alert.patientId}_${alert.timestamp.millisecondsSinceEpoch}',
      title: _getVitalsAlertTitle(alert.type),
      message: alert.message,
      severity: alert.severity,
      timestamp: alert.timestamp,
      duration: _getDefaultDuration(alert.severity),
      icon: _getVitalsAlertIcon(alert.type),
      data: {
        'type': 'vitals_alert',
        'patientId': alert.patientId,
        'alertType': alert.type.toString(),
      },
    );

    _notificationsController.add(notification);
  }

  // ============================================================================
  // SETTINGS
  // ============================================================================

  /// Enable/disable capacity alerts
  void setCapacityAlertsEnabled(bool enabled) {
    _capacityAlertsEnabled = enabled;
    _logger.i('Capacity alerts ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Enable/disable vitals alerts
  void setVitalsAlertsEnabled(bool enabled) {
    _vitalsAlertsEnabled = enabled;
    _logger.i('Vitals alerts ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Enable/disable sound notifications
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    _logger.i('Sound notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Set minimum severity level for notifications
  void setMinimumSeverity(AlertSeverity severity) {
    _minimumSeverity = severity;
    _logger.i('Minimum notification severity set to: ${severity.name}');
  }

  /// Get current settings
  NotificationSettings get settings => NotificationSettings(
    capacityAlertsEnabled: _capacityAlertsEnabled,
    vitalsAlertsEnabled: _vitalsAlertsEnabled,
    soundEnabled: _soundEnabled,
    minimumSeverity: _minimumSeverity,
  );

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Handle capacity alerts from monitoring service
  void _handleCapacityAlert(CapacityAlert alert) {
    _logger.d(
      'Received capacity alert: ${alert.type} for hospital ${alert.hospitalId}',
    );
    showCapacityAlert(alert);
  }

  /// Handle vitals alerts from monitoring service
  void _handleVitalsAlert(VitalsAlert alert) {
    _logger.d(
      'Received vitals alert: ${alert.type} for patient ${alert.patientId}',
    );
    showVitalsAlert(alert);
  }

  /// Get default duration based on severity
  Duration _getDefaultDuration(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Duration(seconds: 10);
      case AlertSeverity.warning:
        return const Duration(seconds: 6);
      case AlertSeverity.info:
        return const Duration(seconds: 4);
    }
  }

  /// Get capacity alert title
  String _getCapacityAlertTitle(CapacityAlertType type) {
    switch (type) {
      case CapacityAlertType.criticalCapacity:
        return 'Critical Capacity';
      case CapacityAlertType.highCapacity:
        return 'High Capacity';
      case CapacityAlertType.emergencyBedsLow:
        return 'Emergency Beds Low';
      case CapacityAlertType.icuBedsLow:
        return 'ICU Beds Low';
      case CapacityAlertType.longWaitTimes:
        return 'Long Wait Times';
      case CapacityAlertType.staleData:
        return 'Data Update Issue';
    }
  }

  /// Get vitals alert title
  String _getVitalsAlertTitle(VitalsAlertType type) {
    switch (type) {
      case VitalsAlertType.criticalVitals:
        return 'Critical Vitals';
      case VitalsAlertType.abnormalVitals:
        return 'Abnormal Vitals';
      case VitalsAlertType.lowOxygen:
        return 'Low Oxygen';
      case VitalsAlertType.abnormalHeartRate:
        return 'Abnormal Heart Rate';
    }
  }

  /// Get capacity alert icon
  IconData _getCapacityAlertIcon(CapacityAlertType type) {
    switch (type) {
      case CapacityAlertType.criticalCapacity:
      case CapacityAlertType.highCapacity:
        return Icons.warning;
      case CapacityAlertType.emergencyBedsLow:
        return Icons.emergency;
      case CapacityAlertType.icuBedsLow:
        return Icons.local_hospital;
      case CapacityAlertType.longWaitTimes:
        return Icons.access_time;
      case CapacityAlertType.staleData:
        return Icons.sync_problem;
    }
  }

  /// Get vitals alert icon
  IconData _getVitalsAlertIcon(VitalsAlertType type) {
    switch (type) {
      case VitalsAlertType.criticalVitals:
      case VitalsAlertType.abnormalVitals:
        return Icons.health_and_safety;
      case VitalsAlertType.lowOxygen:
        return Icons.air;
      case VitalsAlertType.abnormalHeartRate:
        return Icons.favorite;
    }
  }

  /// Dispose resources
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _notificationsController.close();
    _isInitialized = false;
  }
}

// ============================================================================
// MODELS
// ============================================================================

/// App notification model
class AppNotification {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final Duration duration;
  final IconData? icon;
  final VoidCallback? onTap;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.duration,
    this.icon,
    this.onTap,
    this.data,
  });

  /// Get notification color based on severity
  Color get color {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.info:
        return Colors.blue;
    }
  }

  /// Get background color for notification
  Color get backgroundColor {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red.withValues(alpha: 0.1);
      case AlertSeverity.warning:
        return Colors.orange.withValues(alpha: 0.1);
      case AlertSeverity.info:
        return Colors.blue.withValues(alpha: 0.1);
    }
  }
}

/// Notification settings model
class NotificationSettings {
  final bool capacityAlertsEnabled;
  final bool vitalsAlertsEnabled;
  final bool soundEnabled;
  final AlertSeverity minimumSeverity;

  const NotificationSettings({
    required this.capacityAlertsEnabled,
    required this.vitalsAlertsEnabled,
    required this.soundEnabled,
    required this.minimumSeverity,
  });
}
