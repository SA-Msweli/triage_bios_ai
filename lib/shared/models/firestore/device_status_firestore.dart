import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for wearable device status tracking
class DeviceStatusFirestore extends Equatable {
  final String id;
  final String deviceName;
  final String platform;
  final bool isConnected;
  final DateTime lastSync;
  final double batteryLevel;
  final double dataQuality;
  final List<String> supportedDataTypes;
  final DateTime lastUpdated;
  final bool connectionIssues;
  final int syncFailures;
  final String? patientId;

  const DeviceStatusFirestore({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.isConnected,
    required this.lastSync,
    required this.batteryLevel,
    required this.dataQuality,
    required this.supportedDataTypes,
    required this.lastUpdated,
    required this.connectionIssues,
    required this.syncFailures,
    this.patientId,
  });

  /// Check if device needs attention (low battery, connection issues, etc.)
  bool get needsAttention {
    if (!isConnected) return true;
    if (batteryLevel < 0.2) return true; // Less than 20% battery
    if (connectionIssues) return true;
    if (syncFailures > 3) return true;

    // Check if last sync was more than 30 minutes ago
    final timeSinceSync = DateTime.now().difference(lastSync);
    if (timeSinceSync.inMinutes > 30) return true;

    return false;
  }

  /// Get device health status
  DeviceHealthStatus get healthStatus {
    if (!isConnected) return DeviceHealthStatus.disconnected;
    if (batteryLevel < 0.1) return DeviceHealthStatus.critical;
    if (needsAttention) return DeviceHealthStatus.warning;
    return DeviceHealthStatus.healthy;
  }

  /// Get connectivity quality score (0-1)
  double get connectivityScore {
    double score = 1.0;

    if (!isConnected) return 0.0;

    // Reduce score based on sync failures
    score -= (syncFailures * 0.1).clamp(0.0, 0.5);

    // Reduce score based on time since last sync
    final timeSinceSync = DateTime.now().difference(lastSync);
    if (timeSinceSync.inMinutes > 10) {
      score -= 0.2;
    }
    if (timeSinceSync.inMinutes > 30) {
      score -= 0.3;
    }

    // Factor in data quality
    score *= dataQuality;

    return score.clamp(0.0, 1.0);
  }

  /// Create from Firestore document
  factory DeviceStatusFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return DeviceStatusFirestore(
      id: snapshot.id,
      deviceName: data['deviceName'] as String,
      platform: data['platform'] as String,
      isConnected: data['isConnected'] as bool,
      lastSync: (data['lastSync'] as Timestamp).toDate(),
      batteryLevel: (data['batteryLevel'] as num).toDouble(),
      dataQuality: (data['dataQuality'] as num).toDouble(),
      supportedDataTypes: List<String>.from(data['supportedDataTypes'] as List),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      connectionIssues: data['connectionIssues'] as bool? ?? false,
      syncFailures: data['syncFailures'] as int? ?? 0,
      patientId: data['patientId'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'deviceName': deviceName,
      'platform': platform,
      'isConnected': isConnected,
      'lastSync': Timestamp.fromDate(lastSync),
      'batteryLevel': batteryLevel,
      'dataQuality': dataQuality,
      'supportedDataTypes': supportedDataTypes,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'connectionIssues': connectionIssues,
      'syncFailures': syncFailures,
      if (patientId != null) 'patientId': patientId,
      'needsAttention': needsAttention,
      'healthStatus': healthStatus.toString(),
      'connectivityScore': connectivityScore,
    };
  }

  DeviceStatusFirestore copyWith({
    String? id,
    String? deviceName,
    String? platform,
    bool? isConnected,
    DateTime? lastSync,
    double? batteryLevel,
    double? dataQuality,
    List<String>? supportedDataTypes,
    DateTime? lastUpdated,
    bool? connectionIssues,
    int? syncFailures,
    String? patientId,
  }) {
    return DeviceStatusFirestore(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      isConnected: isConnected ?? this.isConnected,
      lastSync: lastSync ?? this.lastSync,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      dataQuality: dataQuality ?? this.dataQuality,
      supportedDataTypes: supportedDataTypes ?? this.supportedDataTypes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      connectionIssues: connectionIssues ?? this.connectionIssues,
      syncFailures: syncFailures ?? this.syncFailures,
      patientId: patientId ?? this.patientId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    deviceName,
    platform,
    isConnected,
    lastSync,
    batteryLevel,
    dataQuality,
    supportedDataTypes,
    lastUpdated,
    connectionIssues,
    syncFailures,
    patientId,
  ];
}

/// Device health status enumeration
enum DeviceHealthStatus {
  healthy,
  warning,
  critical,
  disconnected;

  @override
  String toString() {
    switch (this) {
      case DeviceHealthStatus.healthy:
        return 'healthy';
      case DeviceHealthStatus.warning:
        return 'warning';
      case DeviceHealthStatus.critical:
        return 'critical';
      case DeviceHealthStatus.disconnected:
        return 'disconnected';
    }
  }

  factory DeviceHealthStatus.fromString(String value) {
    switch (value) {
      case 'healthy':
        return DeviceHealthStatus.healthy;
      case 'warning':
        return DeviceHealthStatus.warning;
      case 'critical':
        return DeviceHealthStatus.critical;
      case 'disconnected':
        return DeviceHealthStatus.disconnected;
      default:
        return DeviceHealthStatus.disconnected;
    }
  }
}
