import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'firebase_service.dart';
import 'firestore_data_service.dart';
import 'multi_platform_health_service.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/device_status_firestore.dart';
import '../models/firestore/vitals_threshold_firestore.dart';

/// Service for managing wearable device data integration with Firestore
class WearableDeviceService {
  static final WearableDeviceService _instance =
      WearableDeviceService._internal();
  factory WearableDeviceService() => _instance;
  WearableDeviceService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final FirebaseService _firebaseService = FirebaseService();
  final FirestoreDataService _firestoreDataService = FirestoreDataService();
  final MultiPlatformHealthService _healthService =
      MultiPlatformHealthService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // Collection names
  static const String _deviceStatusCollection = 'device_status';
  static const String _vitalsThresholdsCollection = 'vitals_thresholds';
  static const String _vitalsTriggersCollection = 'vitals_triggers';
  static const String _deviceSyncCollection = 'device_sync_status';

  // Sync and monitoring state
  Timer? _syncTimer;
  Timer? _monitoringTimer;
  final Map<String, StreamSubscription> _deviceListeners = {};
  bool _isInitialized = false;
  bool _autoTriageEnabled = true;

  /// Initialize the wearable device service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _logger.i('Initializing wearable device service...');

      // Initialize Firebase and health services
      if (!_firebaseService.isInitialized) {
        await _firebaseService.initialize();
      }

      await _healthService.initialize();

      // Start device monitoring and sync
      await _startDeviceMonitoring();
      await _startPeriodicSync();

      _isInitialized = true;
      _logger.i('Wearable device service initialized successfully');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize wearable device service: $e');
      return false;
    }
  }

  /// Store patient vitals from wearable devices in Firestore
  Future<void> storeDeviceVitals({
    required String patientId,
    required PatientVitals vitals,
    String? deviceId,
  }) async {
    try {
      // Convert to Firestore model
      final vitalsFirestore = PatientVitalsFirestore(
        id: _uuid.v4(),
        patientId: patientId,
        deviceId: deviceId ?? vitals.deviceId,
        heartRate: vitals.heartRate?.toDouble(),
        bloodPressureSystolic: vitals.bloodPressureSystolic?.toDouble(),
        bloodPressureDiastolic: vitals.bloodPressureDiastolic?.toDouble(),
        oxygenSaturation: vitals.oxygenSaturation,
        temperature: vitals.temperature,
        respiratoryRate: vitals.respiratoryRate?.toDouble(),
        source: _mapVitalsSource(vitals.source ?? vitals.deviceSource),
        accuracy: vitals.dataQuality ?? vitals.accuracy ?? 0.8,
        timestamp: vitals.timestamp,
        isValidated: (vitals.dataQuality ?? 0.8) > 0.7,
      );

      // Store in Firestore
      await _firestore
          .collection('patient_vitals')
          .add(vitalsFirestore.toFirestore());

      _logger.i(
        'Device vitals stored for patient $patientId from ${vitals.deviceSource}',
      );

      // Check for automatic triage triggering
      if (_autoTriageEnabled && vitalsFirestore.hasAbnormalVitals) {
        await _checkTriageThresholds(patientId, vitalsFirestore);
      }

      // Update device status
      if (deviceId != null) {
        await _updateDeviceStatus(deviceId, vitals.deviceSource ?? 'Unknown');
      }
    } catch (e) {
      _logger.e('Failed to store device vitals: $e');
      rethrow;
    }
  }

  /// Update device status with connectivity and data quality metrics
  Future<void> updateDeviceStatus({
    required String deviceId,
    required String deviceName,
    required String platform,
    required bool isConnected,
    required DateTime lastSync,
    double? batteryLevel,
    double? dataQuality,
    List<String>? supportedDataTypes,
  }) async {
    try {
      final deviceStatus = DeviceStatusFirestore(
        id: deviceId,
        deviceName: deviceName,
        platform: platform,
        isConnected: isConnected,
        lastSync: lastSync,
        batteryLevel: batteryLevel ?? 0.0,
        dataQuality: dataQuality ?? 0.8,
        supportedDataTypes: supportedDataTypes ?? [],
        lastUpdated: DateTime.now(),
        connectionIssues: !isConnected,
        syncFailures: 0,
      );

      await _firestore
          .collection(_deviceStatusCollection)
          .doc(deviceId)
          .set(deviceStatus.toFirestore());

      _logger.i('Device status updated: $deviceName ($platform)');
    } catch (e) {
      _logger.e('Failed to update device status: $e');
      rethrow;
    }
  }

  /// Get device status for a specific device
  Future<DeviceStatusFirestore?> getDeviceStatus(String deviceId) async {
    try {
      final doc = await _firestore
          .collection(_deviceStatusCollection)
          .doc(deviceId)
          .get();

      return doc.exists ? DeviceStatusFirestore.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get device status: $e');
      return null;
    }
  }

  /// Get all connected devices for a patient
  Future<List<DeviceStatusFirestore>> getPatientDevices(
    String patientId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_deviceStatusCollection)
          .where('patientId', isEqualTo: patientId)
          .where('isConnected', isEqualTo: true)
          .orderBy('lastSync', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => DeviceStatusFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get patient devices: $e');
      return [];
    }
  }

  /// Set vitals thresholds for automatic triage triggering
  Future<void> setVitalsThresholds({
    required String patientId,
    double? minHeartRate,
    double? maxHeartRate,
    double? minOxygenSaturation,
    double? maxTemperature,
    double? maxSystolicBP,
    double? maxDiastolicBP,
    bool? enableAutoTriage,
  }) async {
    try {
      final thresholds = VitalsThresholdFirestore(
        id: _uuid.v4(),
        patientId: patientId,
        minHeartRate: minHeartRate ?? 50.0,
        maxHeartRate: maxHeartRate ?? 120.0,
        minOxygenSaturation: minOxygenSaturation ?? 90.0,
        maxTemperature: maxTemperature ?? 101.5,
        maxSystolicBP: maxSystolicBP ?? 180.0,
        maxDiastolicBP: maxDiastolicBP ?? 120.0,
        enableAutoTriage: enableAutoTriage ?? true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_vitalsThresholdsCollection)
          .doc(patientId)
          .set(thresholds.toFirestore());

      _logger.i('Vitals thresholds set for patient $patientId');
    } catch (e) {
      _logger.e('Failed to set vitals thresholds: $e');
      rethrow;
    }
  }

  /// Get vitals thresholds for a patient
  Future<VitalsThresholdFirestore?> getVitalsThresholds(
    String patientId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_vitalsThresholdsCollection)
          .doc(patientId)
          .get();

      return doc.exists ? VitalsThresholdFirestore.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get vitals thresholds: $e');
      return null;
    }
  }

  /// Sync device data with conflict resolution
  Future<void> syncDeviceData({
    required String patientId,
    bool forceSync = false,
  }) async {
    try {
      _logger.i('Starting device data sync for patient $patientId');

      // Get latest vitals from all connected devices
      final latestVitals = await _healthService.getLatestVitals();
      if (latestVitals == null) {
        _logger.w('No vitals data available for sync');
        return;
      }

      // Check for conflicts with existing data
      final existingVitals = await _getRecentVitals(
        patientId,
        Duration(minutes: 10),
      );

      if (!forceSync && existingVitals.isNotEmpty) {
        final hasConflict = await _detectSyncConflicts(
          latestVitals,
          existingVitals,
        );
        if (hasConflict) {
          await _resolveSyncConflicts(patientId, latestVitals, existingVitals);
          return;
        }
      }

      // Store the synced vitals
      await storeDeviceVitals(patientId: patientId, vitals: latestVitals);

      // Update sync status
      await _updateSyncStatus(patientId, success: true);

      _logger.i('Device data sync completed for patient $patientId');
    } catch (e) {
      _logger.e('Device data sync failed for patient $patientId: $e');
      await _updateSyncStatus(patientId, success: false, error: e.toString());
      rethrow;
    }
  }

  /// Enable/disable automatic triage triggering
  void setAutoTriageEnabled(bool enabled) {
    _autoTriageEnabled = enabled;
    _logger.i(
      'Automatic triage triggering ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Listen to device status updates
  Stream<List<DeviceStatusFirestore>> listenToDeviceStatus(String patientId) {
    return _firestore
        .collection(_deviceStatusCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('lastSync', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DeviceStatusFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Listen to vitals threshold violations
  Stream<List<Map<String, dynamic>>> listenToThresholdViolations(
    String patientId,
  ) {
    return _firestore
        .collection(_vitalsTriggersCollection)
        .where('patientId', isEqualTo: patientId)
        .where('isActive', isEqualTo: true)
        .orderBy('triggeredAt', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList(),
        );
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _monitoringTimer?.cancel();

    for (final subscription in _deviceListeners.values) {
      subscription.cancel();
    }
    _deviceListeners.clear();

    _isInitialized = false;
    _logger.i('Wearable device service disposed');
  }

  // Private helper methods

  Future<void> _startDeviceMonitoring() async {
    _monitoringTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
      try {
        final connectedDevices = _healthService.getConnectedDevices();

        for (final device in connectedDevices) {
          await updateDeviceStatus(
            deviceId: device.id,
            deviceName: device.name,
            platform: device.platform,
            isConnected: device.isConnected,
            lastSync: device.lastSync,
            batteryLevel: device.batteryLevel,
            supportedDataTypes: device.supportedDataTypes,
          );
        }
      } catch (e) {
        _logger.e('Device monitoring error: $e');
      }
    });
  }

  Future<void> _startPeriodicSync() async {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        // This would typically sync for all active patients
        // For now, we'll just log the sync attempt
        _logger.d('Periodic device sync check');
      } catch (e) {
        _logger.e('Periodic sync error: $e');
      }
    });
  }

  Future<void> _updateDeviceStatus(String deviceId, String deviceName) async {
    try {
      await _firestore
          .collection(_deviceStatusCollection)
          .doc(deviceId)
          .update({
            'lastSync': FieldValue.serverTimestamp(),
            'isConnected': true,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      _logger.e('Failed to update device status: $e');
    }
  }

  Future<void> _checkTriageThresholds(
    String patientId,
    PatientVitalsFirestore vitals,
  ) async {
    try {
      final thresholds = await getVitalsThresholds(patientId);
      if (thresholds == null || !thresholds.enableAutoTriage) {
        return;
      }

      bool thresholdViolated = false;
      List<String> violations = [];

      // Check heart rate
      if (vitals.heartRate != null) {
        if (vitals.heartRate! < thresholds.minHeartRate) {
          thresholdViolated = true;
          violations.add('Heart rate too low: ${vitals.heartRate}');
        } else if (vitals.heartRate! > thresholds.maxHeartRate) {
          thresholdViolated = true;
          violations.add('Heart rate too high: ${vitals.heartRate}');
        }
      }

      // Check oxygen saturation
      if (vitals.oxygenSaturation != null &&
          vitals.oxygenSaturation! < thresholds.minOxygenSaturation) {
        thresholdViolated = true;
        violations.add(
          'Oxygen saturation too low: ${vitals.oxygenSaturation}%',
        );
      }

      // Check temperature
      if (vitals.temperature != null &&
          vitals.temperature! > thresholds.maxTemperature) {
        thresholdViolated = true;
        violations.add('Temperature too high: ${vitals.temperature}°F');
      }

      // Check blood pressure
      if (vitals.bloodPressureSystolic != null &&
          vitals.bloodPressureSystolic! > thresholds.maxSystolicBP) {
        thresholdViolated = true;
        violations.add('Systolic BP too high: ${vitals.bloodPressureSystolic}');
      }

      if (vitals.bloodPressureDiastolic != null &&
          vitals.bloodPressureDiastolic! > thresholds.maxDiastolicBP) {
        thresholdViolated = true;
        violations.add(
          'Diastolic BP too high: ${vitals.bloodPressureDiastolic}',
        );
      }

      if (thresholdViolated) {
        await _triggerAutoTriage(patientId, vitals, violations);
      }
    } catch (e) {
      _logger.e('Failed to check triage thresholds: $e');
    }
  }

  Future<void> _triggerAutoTriage(
    String patientId,
    PatientVitalsFirestore vitals,
    List<String> violations,
  ) async {
    try {
      final trigger = {
        'id': _uuid.v4(),
        'patientId': patientId,
        'vitalsId': vitals.id,
        'violations': violations,
        'severityScore': vitals.vitalsSeverityScore,
        'triggeredAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'triageInitiated': false,
      };

      await _firestore.collection(_vitalsTriggersCollection).add(trigger);

      _logger.w(
        'Auto-triage triggered for patient $patientId: ${violations.join(', ')}',
      );

      // Here you would typically trigger the actual triage process
      // For now, we'll just log the trigger
    } catch (e) {
      _logger.e('Failed to trigger auto-triage: $e');
    }
  }

  VitalsSource _mapVitalsSource(String? source) {
    if (source == null) return VitalsSource.device;

    final lowerSource = source.toLowerCase();
    if (lowerSource.contains('apple')) return VitalsSource.appleHealth;
    if (lowerSource.contains('google') || lowerSource.contains('fit'))
      return VitalsSource.googleFit;
    return VitalsSource.device;
  }

  Future<List<PatientVitalsFirestore>> _getRecentVitals(
    String patientId,
    Duration timeWindow,
  ) async {
    try {
      final cutoffTime = DateTime.now().subtract(timeWindow);

      final querySnapshot = await _firestore
          .collection('patient_vitals')
          .where('patientId', isEqualTo: patientId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => PatientVitalsFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get recent vitals: $e');
      return [];
    }
  }

  Future<bool> _detectSyncConflicts(
    PatientVitals newVitals,
    List<PatientVitalsFirestore> existingVitals,
  ) async {
    // Check for conflicts based on timestamp and significant value differences
    for (final existing in existingVitals) {
      final timeDiff = newVitals.timestamp.difference(existing.timestamp).abs();

      // If timestamps are very close (within 2 minutes), check for value conflicts
      if (timeDiff.inMinutes < 2) {
        if (_hasSignificantValueDifference(newVitals, existing)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _hasSignificantValueDifference(
    PatientVitals newVitals,
    PatientVitalsFirestore existing,
  ) {
    // Check heart rate difference
    if (newVitals.heartRate != null && existing.heartRate != null) {
      final diff = (newVitals.heartRate! - existing.heartRate!).abs();
      if (diff > 10) return true; // More than 10 BPM difference
    }

    // Check oxygen saturation difference
    if (newVitals.oxygenSaturation != null &&
        existing.oxygenSaturation != null) {
      final diff = (newVitals.oxygenSaturation! - existing.oxygenSaturation!)
          .abs();
      if (diff > 2.0) return true; // More than 2% difference
    }

    // Check temperature difference
    if (newVitals.temperature != null && existing.temperature != null) {
      final diff = (newVitals.temperature! - existing.temperature!).abs();
      if (diff > 1.0) return true; // More than 1°F difference
    }

    return false;
  }

  Future<void> _resolveSyncConflicts(
    String patientId,
    PatientVitals newVitals,
    List<PatientVitalsFirestore> existingVitals,
  ) async {
    try {
      _logger.w('Resolving sync conflicts for patient $patientId');

      // Use server-side timestamp precedence and higher data quality
      final newQuality = newVitals.dataQuality ?? 0.5;

      bool shouldStore = true;
      for (final existing in existingVitals) {
        if (existing.accuracy > newQuality &&
            existing.timestamp.isAfter(
              newVitals.timestamp.subtract(Duration(minutes: 1)),
            )) {
          shouldStore = false;
          break;
        }
      }

      if (shouldStore) {
        await storeDeviceVitals(patientId: patientId, vitals: newVitals);
        _logger.i('Conflict resolved: New vitals stored (higher quality)');
      } else {
        _logger.i('Conflict resolved: Existing vitals kept (higher quality)');
      }
    } catch (e) {
      _logger.e('Failed to resolve sync conflicts: $e');
    }
  }

  Future<void> _updateSyncStatus(
    String patientId, {
    required bool success,
    String? error,
  }) async {
    try {
      final syncStatus = {
        'patientId': patientId,
        'lastSyncAt': FieldValue.serverTimestamp(),
        'success': success,
        'error': error,
        'syncCount': FieldValue.increment(1),
      };

      await _firestore
          .collection(_deviceSyncCollection)
          .doc(patientId)
          .set(syncStatus, SetOptions(merge: true));
    } catch (e) {
      _logger.e('Failed to update sync status: $e');
    }
  }
}
