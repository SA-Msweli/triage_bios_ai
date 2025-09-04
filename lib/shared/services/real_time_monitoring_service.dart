import 'dart:async';
import 'package:logger/logger.dart';
import 'firestore_data_service.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/triage_result_firestore.dart';

/// Service for real-time monitoring of hospital capacity and patient vitals
class RealTimeMonitoringService {
  static final RealTimeMonitoringService _instance =
      RealTimeMonitoringService._internal();
  factory RealTimeMonitoringService() => _instance;
  RealTimeMonitoringService._internal();

  final Logger _logger = Logger();
  final FirestoreDataService _firestoreService = FirestoreDataService();

  // Stream controllers for real-time updates
  final StreamController<List<HospitalCapacityFirestore>>
  _capacityUpdatesController =
      StreamController<List<HospitalCapacityFirestore>>.broadcast();

  final StreamController<List<PatientVitalsFirestore>>
  _criticalVitalsController =
      StreamController<List<PatientVitalsFirestore>>.broadcast();

  final StreamController<List<TriageResultFirestore>>
  _criticalTriageController =
      StreamController<List<TriageResultFirestore>>.broadcast();

  final StreamController<CapacityAlert> _capacityAlertsController =
      StreamController<CapacityAlert>.broadcast();

  final StreamController<VitalsAlert> _vitalsAlertsController =
      StreamController<VitalsAlert>.broadcast();

  // Active subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};

  // Monitoring state
  bool _isMonitoring = false;
  List<String> _monitoredHospitalIds = [];

  // ============================================================================
  // PUBLIC STREAMS
  // ============================================================================

  /// Stream of hospital capacity updates
  Stream<List<HospitalCapacityFirestore>> get capacityUpdates =>
      _capacityUpdatesController.stream;

  /// Stream of critical patient vitals
  Stream<List<PatientVitalsFirestore>> get criticalVitals =>
      _criticalVitalsController.stream;

  /// Stream of critical triage cases
  Stream<List<TriageResultFirestore>> get criticalTriage =>
      _criticalTriageController.stream;

  /// Stream of capacity alerts
  Stream<CapacityAlert> get capacityAlerts => _capacityAlertsController.stream;

  /// Stream of vitals alerts
  Stream<VitalsAlert> get vitalsAlerts => _vitalsAlertsController.stream;

  // ============================================================================
  // MONITORING CONTROL
  // ============================================================================

  /// Start monitoring hospital capacities and patient vitals
  Future<void> startMonitoring({
    List<String>? hospitalIds,
    bool monitorAllHospitals = true,
  }) async {
    if (_isMonitoring) {
      _logger.w('Real-time monitoring is already active');
      return;
    }

    try {
      _isMonitoring = true;
      _monitoredHospitalIds = hospitalIds ?? [];

      _logger.i('Starting real-time monitoring...');

      // Start capacity monitoring
      if (monitorAllHospitals) {
        await _startAllCapacityMonitoring();
      } else if (hospitalIds != null && hospitalIds.isNotEmpty) {
        await _startSpecificCapacityMonitoring(hospitalIds);
      }

      // Start critical vitals monitoring
      await _startCriticalVitalsMonitoring();

      // Start critical triage monitoring
      await _startCriticalTriageMonitoring();

      _logger.i('Real-time monitoring started successfully');
    } catch (e) {
      _logger.e('Failed to start real-time monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  /// Stop all monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      _logger.w('Real-time monitoring is not active');
      return;
    }

    try {
      _logger.i('Stopping real-time monitoring...');

      // Cancel all subscriptions
      for (final subscription in _subscriptions.values) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      _isMonitoring = false;
      _monitoredHospitalIds.clear();

      _logger.i('Real-time monitoring stopped');
    } catch (e) {
      _logger.e('Error stopping real-time monitoring: $e');
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Get list of monitored hospital IDs
  List<String> get monitoredHospitalIds => List.from(_monitoredHospitalIds);

  // ============================================================================
  // PRIVATE MONITORING METHODS
  // ============================================================================

  /// Start monitoring all hospital capacities
  Future<void> _startAllCapacityMonitoring() async {
    final subscription = _firestoreService.listenToAllCapacityUpdates().listen(
      (capacities) {
        _capacityUpdatesController.add(capacities);
        _checkCapacityAlerts(capacities);
      },
      onError: (error) {
        _logger.e('Error in capacity monitoring stream: $error');
      },
    );

    _subscriptions['all_capacity'] = subscription;
  }

  /// Start monitoring specific hospital capacities
  Future<void> _startSpecificCapacityMonitoring(
    List<String> hospitalIds,
  ) async {
    final subscription = _firestoreService
        .listenToHospitalCapacities(hospitalIds)
        .listen(
          (capacities) {
            _capacityUpdatesController.add(capacities);
            _checkCapacityAlerts(capacities);
          },
          onError: (error) {
            _logger.e('Error in specific capacity monitoring stream: $error');
          },
        );

    _subscriptions['specific_capacity'] = subscription;
  }

  /// Start monitoring critical patient vitals
  Future<void> _startCriticalVitalsMonitoring() async {
    final subscription = _firestoreService
        .listenToCriticalVitals(minSeverityScore: 2.0)
        .listen(
          (vitals) {
            _criticalVitalsController.add(vitals);
            _checkVitalsAlerts(vitals);
          },
          onError: (error) {
            _logger.e('Error in critical vitals monitoring stream: $error');
          },
        );

    _subscriptions['critical_vitals'] = subscription;
  }

  /// Start monitoring critical triage cases
  Future<void> _startCriticalTriageMonitoring() async {
    final subscription = _firestoreService.listenToCriticalTriageCases().listen(
      (triageResults) {
        _criticalTriageController.add(triageResults);
      },
      onError: (error) {
        _logger.e('Error in critical triage monitoring stream: $error');
      },
    );

    _subscriptions['critical_triage'] = subscription;
  }

  // ============================================================================
  // ALERT PROCESSING
  // ============================================================================

  /// Check for capacity alerts and emit them
  void _checkCapacityAlerts(List<HospitalCapacityFirestore> capacities) {
    for (final capacity in capacities) {
      // Check for critical capacity alerts
      if (capacity.occupancyRate > 0.95) {
        _capacityAlertsController.add(
          CapacityAlert(
            hospitalId: capacity.hospitalId,
            type: CapacityAlertType.criticalCapacity,
            message:
                'Hospital at critical capacity (${(capacity.occupancyRate * 100).toStringAsFixed(1)}%)',
            severity: AlertSeverity.critical,
            timestamp: DateTime.now(),
            data: capacity,
          ),
        );
      } else if (capacity.occupancyRate > 0.85) {
        _capacityAlertsController.add(
          CapacityAlert(
            hospitalId: capacity.hospitalId,
            type: CapacityAlertType.highCapacity,
            message:
                'Hospital approaching capacity (${(capacity.occupancyRate * 100).toStringAsFixed(1)}%)',
            severity: AlertSeverity.warning,
            timestamp: DateTime.now(),
            data: capacity,
          ),
        );
      }

      // Check for emergency bed alerts
      if (capacity.emergencyAvailable <= 2 && capacity.emergencyBeds > 0) {
        _capacityAlertsController.add(
          CapacityAlert(
            hospitalId: capacity.hospitalId,
            type: CapacityAlertType.emergencyBedsLow,
            message:
                'Emergency beds critically low (${capacity.emergencyAvailable} remaining)',
            severity: AlertSeverity.critical,
            timestamp: DateTime.now(),
            data: capacity,
          ),
        );
      }

      // Check for ICU bed alerts
      if (capacity.icuAvailable <= 1 && capacity.icuBeds > 0) {
        _capacityAlertsController.add(
          CapacityAlert(
            hospitalId: capacity.hospitalId,
            type: CapacityAlertType.icuBedsLow,
            message:
                'ICU beds critically low (${capacity.icuAvailable} remaining)',
            severity: AlertSeverity.critical,
            timestamp: DateTime.now(),
            data: capacity,
          ),
        );
      }

      // Check for long wait times
      if (capacity.averageWaitTime > 120) {
        _capacityAlertsController.add(
          CapacityAlert(
            hospitalId: capacity.hospitalId,
            type: CapacityAlertType.longWaitTimes,
            message:
                'Extended wait times (${capacity.averageWaitTime.toStringAsFixed(0)} minutes)',
            severity: AlertSeverity.warning,
            timestamp: DateTime.now(),
            data: capacity,
          ),
        );
      }

      // Check for stale data
      if (!capacity.isDataFresh) {
        _capacityAlertsController.add(
          CapacityAlert(
            hospitalId: capacity.hospitalId,
            type: CapacityAlertType.staleData,
            message:
                'Hospital data is stale (last updated: ${_formatTimestamp(capacity.lastUpdated)})',
            severity: AlertSeverity.info,
            timestamp: DateTime.now(),
            data: capacity,
          ),
        );
      }
    }
  }

  /// Check for vitals alerts and emit them
  void _checkVitalsAlerts(List<PatientVitalsFirestore> vitalsList) {
    for (final vitals in vitalsList) {
      if (vitals.vitalsSeverityScore >= 2.5) {
        _vitalsAlertsController.add(
          VitalsAlert(
            patientId: vitals.patientId,
            type: VitalsAlertType.criticalVitals,
            message:
                'Critical vitals detected (severity: ${vitals.vitalsSeverityScore.toStringAsFixed(1)})',
            severity: AlertSeverity.critical,
            timestamp: DateTime.now(),
            data: vitals,
          ),
        );
      } else if (vitals.vitalsSeverityScore >= 1.5) {
        _vitalsAlertsController.add(
          VitalsAlert(
            patientId: vitals.patientId,
            type: VitalsAlertType.abnormalVitals,
            message:
                'Abnormal vitals detected (severity: ${vitals.vitalsSeverityScore.toStringAsFixed(1)})',
            severity: AlertSeverity.warning,
            timestamp: DateTime.now(),
            data: vitals,
          ),
        );
      }

      // Specific vital alerts
      if (vitals.oxygenSaturation != null && vitals.oxygenSaturation! < 90) {
        _vitalsAlertsController.add(
          VitalsAlert(
            patientId: vitals.patientId,
            type: VitalsAlertType.lowOxygen,
            message:
                'Critical oxygen saturation: ${vitals.oxygenSaturation!.toStringAsFixed(1)}%',
            severity: AlertSeverity.critical,
            timestamp: DateTime.now(),
            data: vitals,
          ),
        );
      }

      if (vitals.heartRate != null &&
          (vitals.heartRate! < 50 || vitals.heartRate! > 120)) {
        _vitalsAlertsController.add(
          VitalsAlert(
            patientId: vitals.patientId,
            type: VitalsAlertType.abnormalHeartRate,
            message:
                'Abnormal heart rate: ${vitals.heartRate!.toStringAsFixed(0)} bpm',
            severity: vitals.heartRate! < 40 || vitals.heartRate! > 140
                ? AlertSeverity.critical
                : AlertSeverity.warning,
            timestamp: DateTime.now(),
            data: vitals,
          ),
        );
      }
    }
  }

  // ============================================================================
  // PATIENT VITALS MONITORING
  // ============================================================================

  /// Listen to patient vitals for a specific patient
  Stream<List<PatientVitalsFirestore>> listenToPatientVitals(
    String patientId, {
    int limit = 10,
  }) {
    return _firestoreService.listenToPatientVitals(patientId, limit: limit);
  }

  /// Listen to patient vitals for multiple patients
  Stream<List<PatientVitalsFirestore>> listenToMultiplePatientVitals(
    List<String> patientIds, {
    int limitPerPatient = 5,
  }) async* {
    if (patientIds.isEmpty) {
      yield [];
      return;
    }

    // Create a stream that combines vitals from multiple patients
    final streamControllers =
        <String, StreamController<List<PatientVitalsFirestore>>>{};
    final latestVitals = <String, List<PatientVitalsFirestore>>{};

    try {
      // Set up individual patient streams
      for (final patientId in patientIds) {
        final controller = StreamController<List<PatientVitalsFirestore>>();
        streamControllers[patientId] = controller;
        latestVitals[patientId] = [];

        // Subscribe to individual patient vitals
        _firestoreService
            .listenToPatientVitals(patientId, limit: limitPerPatient)
            .listen(
              (vitals) {
                latestVitals[patientId] = vitals;
                controller.add(vitals);
              },
              onError: (error) {
                _logger.e(
                  'Error listening to vitals for patient $patientId: $error',
                );
                controller.addError(error);
              },
            );
      }

      // Combine all patient vitals into a single stream
      await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
        final allVitals = <PatientVitalsFirestore>[];
        for (final vitals in latestVitals.values) {
          allVitals.addAll(vitals);
        }

        // Sort by timestamp (most recent first)
        allVitals.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        yield allVitals;
      }
    } finally {
      // Clean up controllers
      for (final controller in streamControllers.values) {
        await controller.close();
      }
    }
  }

  /// Get real-time vitals statistics for monitoring dashboard
  Stream<VitalsStatistics> getVitalsStatistics({
    List<String>? patientIds,
    Duration timeWindow = const Duration(hours: 1),
  }) async* {
    await for (final vitals
        in patientIds != null
            ? listenToMultiplePatientVitals(patientIds)
            : criticalVitals) {
      final now = DateTime.now();
      final windowStart = now.subtract(timeWindow);

      // Filter vitals within time window
      final recentVitals = vitals
          .where((v) => v.timestamp.isAfter(windowStart))
          .toList();

      if (recentVitals.isEmpty) {
        yield VitalsStatistics.empty();
        continue;
      }

      // Calculate statistics
      final totalPatients = recentVitals.map((v) => v.patientId).toSet().length;
      final criticalCount = recentVitals
          .where((v) => v.vitalsSeverityScore >= 2.5)
          .length;
      final warningCount = recentVitals
          .where(
            (v) => v.vitalsSeverityScore >= 1.5 && v.vitalsSeverityScore < 2.5,
          )
          .length;
      final stableCount = recentVitals
          .where((v) => v.vitalsSeverityScore < 1.5)
          .length;

      // Calculate average severity
      final avgSeverity = recentVitals.isNotEmpty
          ? recentVitals.fold<double>(
                  0,
                  (sum, v) => sum + v.vitalsSeverityScore,
                ) /
                recentVitals.length
          : 0.0;

      // Find most recent vitals per patient
      final latestVitalsPerPatient = <String, PatientVitalsFirestore>{};
      for (final vital in recentVitals) {
        final existing = latestVitalsPerPatient[vital.patientId];
        if (existing == null || vital.timestamp.isAfter(existing.timestamp)) {
          latestVitalsPerPatient[vital.patientId] = vital;
        }
      }

      yield VitalsStatistics(
        totalPatients: totalPatients,
        criticalCount: criticalCount,
        warningCount: warningCount,
        stableCount: stableCount,
        averageSeverity: avgSeverity,
        timeWindow: timeWindow,
        lastUpdated: now,
        latestVitalsPerPatient: latestVitalsPerPatient.values.toList(),
      );
    }
  }

  // ============================================================================
  // ENHANCED MONITORING METHODS
  // ============================================================================

  /// Start monitoring specific patients with enhanced vitals tracking
  Future<void> startPatientMonitoring(List<String> patientIds) async {
    if (patientIds.isEmpty) return;

    try {
      _logger.i(
        'Starting enhanced patient monitoring for ${patientIds.length} patients',
      );

      for (final patientId in patientIds) {
        final subscriptionKey = 'patient_vitals_$patientId';

        // Cancel existing subscription if any
        _subscriptions[subscriptionKey]?.cancel();

        // Start new subscription
        final subscription = listenToPatientVitals(patientId).listen(
          (vitals) {
            // Check for critical vitals and emit alerts
            for (final vital in vitals) {
              if (vital.vitalsSeverityScore >= 2.0) {
                _checkVitalsAlerts([vital]);
              }
            }
          },
          onError: (error) {
            _logger.e('Error monitoring patient $patientId: $error');
          },
        );

        _subscriptions[subscriptionKey] = subscription;
      }

      _logger.i('Enhanced patient monitoring started successfully');
    } catch (e) {
      _logger.e('Failed to start enhanced patient monitoring: $e');
      rethrow;
    }
  }

  /// Stop monitoring specific patients
  Future<void> stopPatientMonitoring(List<String> patientIds) async {
    for (final patientId in patientIds) {
      final subscriptionKey = 'patient_vitals_$patientId';
      await _subscriptions[subscriptionKey]?.cancel();
      _subscriptions.remove(subscriptionKey);
    }

    _logger.i('Stopped monitoring ${patientIds.length} patients');
  }

  /// Get current monitoring status
  MonitoringStatus get monitoringStatus {
    final capacitySubscriptions = _subscriptions.keys
        .where((key) => key.contains('capacity'))
        .length;
    final vitalsSubscriptions = _subscriptions.keys
        .where((key) => key.contains('vitals'))
        .length;
    final triageSubscriptions = _subscriptions.keys
        .where((key) => key.contains('triage'))
        .length;

    return MonitoringStatus(
      isActive: _isMonitoring,
      hospitalCount: _monitoredHospitalIds.length,
      capacitySubscriptions: capacitySubscriptions,
      vitalsSubscriptions: vitalsSubscriptions,
      triageSubscriptions: triageSubscriptions,
      totalSubscriptions: _subscriptions.length,
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _capacityUpdatesController.close();
    _criticalVitalsController.close();
    _criticalTriageController.close();
    _capacityAlertsController.close();
    _vitalsAlertsController.close();
  }
}

// ============================================================================
// ALERT MODELS
// ============================================================================

/// Hospital capacity alert
class CapacityAlert {
  final String hospitalId;
  final CapacityAlertType type;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final HospitalCapacityFirestore data;

  const CapacityAlert({
    required this.hospitalId,
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.data,
  });
}

/// Patient vitals alert
class VitalsAlert {
  final String patientId;
  final VitalsAlertType type;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final PatientVitalsFirestore data;

  const VitalsAlert({
    required this.patientId,
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.data,
  });
}

/// Types of capacity alerts
enum CapacityAlertType {
  criticalCapacity,
  highCapacity,
  emergencyBedsLow,
  icuBedsLow,
  longWaitTimes,
  staleData,
}

/// Types of vitals alerts
enum VitalsAlertType {
  criticalVitals,
  abnormalVitals,
  lowOxygen,
  abnormalHeartRate,
}

/// Alert severity levels
enum AlertSeverity { info, warning, critical }

// ============================================================================
// MONITORING STATISTICS MODELS
// ============================================================================

/// Vitals statistics for monitoring dashboard
class VitalsStatistics {
  final int totalPatients;
  final int criticalCount;
  final int warningCount;
  final int stableCount;
  final double averageSeverity;
  final Duration timeWindow;
  final DateTime lastUpdated;
  final List<PatientVitalsFirestore> latestVitalsPerPatient;

  const VitalsStatistics({
    required this.totalPatients,
    required this.criticalCount,
    required this.warningCount,
    required this.stableCount,
    required this.averageSeverity,
    required this.timeWindow,
    required this.lastUpdated,
    required this.latestVitalsPerPatient,
  });

  factory VitalsStatistics.empty() {
    return VitalsStatistics(
      totalPatients: 0,
      criticalCount: 0,
      warningCount: 0,
      stableCount: 0,
      averageSeverity: 0.0,
      timeWindow: const Duration(hours: 1),
      lastUpdated: DateTime.now(),
      latestVitalsPerPatient: [],
    );
  }

  /// Get overall status based on statistics
  VitalsOverallStatus get overallStatus {
    if (criticalCount > 0) return VitalsOverallStatus.critical;
    if (warningCount > 0) return VitalsOverallStatus.warning;
    if (totalPatients > 0) return VitalsOverallStatus.stable;
    return VitalsOverallStatus.noData;
  }

  /// Get percentage of patients in each category
  Map<String, double> get percentages {
    if (totalPatients == 0) {
      return {'critical': 0.0, 'warning': 0.0, 'stable': 0.0};
    }

    return {
      'critical': (criticalCount / totalPatients) * 100,
      'warning': (warningCount / totalPatients) * 100,
      'stable': (stableCount / totalPatients) * 100,
    };
  }
}

/// Overall vitals status
enum VitalsOverallStatus { noData, stable, warning, critical }

/// Monitoring status information
class MonitoringStatus {
  final bool isActive;
  final int hospitalCount;
  final int capacitySubscriptions;
  final int vitalsSubscriptions;
  final int triageSubscriptions;
  final int totalSubscriptions;

  const MonitoringStatus({
    required this.isActive,
    required this.hospitalCount,
    required this.capacitySubscriptions,
    required this.vitalsSubscriptions,
    required this.triageSubscriptions,
    required this.totalSubscriptions,
  });

  /// Get monitoring health status
  MonitoringHealth get health {
    if (!isActive) return MonitoringHealth.inactive;
    if (totalSubscriptions == 0) return MonitoringHealth.noSubscriptions;
    if (capacitySubscriptions > 0 && vitalsSubscriptions > 0) {
      return MonitoringHealth.healthy;
    }
    return MonitoringHealth.partial;
  }
}

/// Monitoring health status
enum MonitoringHealth { inactive, noSubscriptions, partial, healthy }
