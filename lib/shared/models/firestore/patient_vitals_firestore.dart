import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for patient vitals data
class PatientVitalsFirestore extends Equatable {
  final String id;
  final String patientId;
  final String? deviceId;
  final double? heartRate;
  final double? bloodPressureSystolic;
  final double? bloodPressureDiastolic;
  final double? oxygenSaturation;
  final double? temperature;
  final double? respiratoryRate;
  final VitalsSource source;
  final double accuracy;
  final DateTime timestamp;
  final bool isValidated;

  const PatientVitalsFirestore({
    required this.id,
    required this.patientId,
    this.deviceId,
    this.heartRate,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.oxygenSaturation,
    this.temperature,
    this.respiratoryRate,
    required this.source,
    required this.accuracy,
    required this.timestamp,
    required this.isValidated,
  });

  /// Check if vitals are within normal ranges
  bool get hasAbnormalVitals {
    if (heartRate != null && (heartRate! < 60 || heartRate! > 100)) return true;
    if (oxygenSaturation != null && oxygenSaturation! < 95) return true;
    if (temperature != null && (temperature! < 97 || temperature! > 99.5))
      return true;
    if (bloodPressureSystolic != null && bloodPressureSystolic! > 140)
      return true;
    if (bloodPressureDiastolic != null && bloodPressureDiastolic! > 90)
      return true;
    return false;
  }

  /// Calculate vitals severity score (0-3)
  double get vitalsSeverityScore {
    double score = 0.0;

    // Heart rate scoring
    if (heartRate != null) {
      if (heartRate! < 50 || heartRate! > 120)
        score += 2.5;
      else if (heartRate! < 60 || heartRate! > 100)
        score += 1.0;
    }

    // Oxygen saturation scoring
    if (oxygenSaturation != null) {
      if (oxygenSaturation! < 90)
        score += 3.0;
      else if (oxygenSaturation! < 95)
        score += 1.5;
    }

    // Temperature scoring
    if (temperature != null) {
      if (temperature! > 101.5 || temperature! < 95)
        score += 2.5;
      else if (temperature! > 99.5 || temperature! < 97)
        score += 1.0;
    }

    // Blood pressure scoring
    if (bloodPressureSystolic != null && bloodPressureDiastolic != null) {
      if (bloodPressureSystolic! > 180 || bloodPressureDiastolic! > 120)
        score += 3.0;
      else if (bloodPressureSystolic! > 140 || bloodPressureDiastolic! > 90)
        score += 1.0;
    }

    return score > 3.0 ? 3.0 : score;
  }

  /// Create from Firestore document
  factory PatientVitalsFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return PatientVitalsFirestore(
      id: snapshot.id,
      patientId: data['patientId'] as String,
      deviceId: data['deviceId'] as String?,
      heartRate: (data['heartRate'] as num?)?.toDouble(),
      bloodPressureSystolic: (data['bloodPressureSystolic'] as num?)
          ?.toDouble(),
      bloodPressureDiastolic: (data['bloodPressureDiastolic'] as num?)
          ?.toDouble(),
      oxygenSaturation: (data['oxygenSaturation'] as num?)?.toDouble(),
      temperature: (data['temperature'] as num?)?.toDouble(),
      respiratoryRate: (data['respiratoryRate'] as num?)?.toDouble(),
      source: VitalsSource.fromString(data['source'] as String),
      accuracy: (data['accuracy'] as num).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isValidated: data['isValidated'] as bool,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      if (deviceId != null) 'deviceId': deviceId,
      if (heartRate != null) 'heartRate': heartRate,
      if (bloodPressureSystolic != null)
        'bloodPressureSystolic': bloodPressureSystolic,
      if (bloodPressureDiastolic != null)
        'bloodPressureDiastolic': bloodPressureDiastolic,
      if (oxygenSaturation != null) 'oxygenSaturation': oxygenSaturation,
      if (temperature != null) 'temperature': temperature,
      if (respiratoryRate != null) 'respiratoryRate': respiratoryRate,
      'source': source.toString(),
      'accuracy': accuracy,
      'timestamp': Timestamp.fromDate(timestamp),
      'isValidated': isValidated,
      'hasAbnormalVitals': hasAbnormalVitals,
      'vitalsSeverityScore': vitalsSeverityScore,
    };
  }

  PatientVitalsFirestore copyWith({
    String? id,
    String? patientId,
    String? deviceId,
    double? heartRate,
    double? bloodPressureSystolic,
    double? bloodPressureDiastolic,
    double? oxygenSaturation,
    double? temperature,
    double? respiratoryRate,
    VitalsSource? source,
    double? accuracy,
    DateTime? timestamp,
    bool? isValidated,
  }) {
    return PatientVitalsFirestore(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      deviceId: deviceId ?? this.deviceId,
      heartRate: heartRate ?? this.heartRate,
      bloodPressureSystolic:
          bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic:
          bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
      temperature: temperature ?? this.temperature,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      source: source ?? this.source,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      isValidated: isValidated ?? this.isValidated,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    deviceId,
    heartRate,
    bloodPressureSystolic,
    bloodPressureDiastolic,
    oxygenSaturation,
    temperature,
    respiratoryRate,
    source,
    accuracy,
    timestamp,
    isValidated,
  ];
}

enum VitalsSource {
  appleHealth,
  googleFit,
  manual,
  device;

  factory VitalsSource.fromString(String value) {
    switch (value) {
      case 'apple_health':
        return VitalsSource.appleHealth;
      case 'google_fit':
        return VitalsSource.googleFit;
      case 'manual':
        return VitalsSource.manual;
      case 'device':
        return VitalsSource.device;
      default:
        return VitalsSource.manual;
    }
  }

  @override
  String toString() {
    switch (this) {
      case VitalsSource.appleHealth:
        return 'apple_health';
      case VitalsSource.googleFit:
        return 'google_fit';
      case VitalsSource.manual:
        return 'manual';
      case VitalsSource.device:
        return 'device';
    }
  }
}
