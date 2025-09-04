import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for patient vitals thresholds for automatic triage triggering
class VitalsThresholdFirestore extends Equatable {
  final String id;
  final String patientId;
  final double minHeartRate;
  final double maxHeartRate;
  final double minOxygenSaturation;
  final double maxTemperature;
  final double maxSystolicBP;
  final double maxDiastolicBP;
  final double? minTemperature;
  final double? maxRespiratoryRate;
  final double? minRespiratoryRate;
  final bool enableAutoTriage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? notes;

  const VitalsThresholdFirestore({
    required this.id,
    required this.patientId,
    required this.minHeartRate,
    required this.maxHeartRate,
    required this.minOxygenSaturation,
    required this.maxTemperature,
    required this.maxSystolicBP,
    required this.maxDiastolicBP,
    this.minTemperature,
    this.maxRespiratoryRate,
    this.minRespiratoryRate,
    required this.enableAutoTriage,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.notes,
  });

  /// Check if vitals exceed any threshold
  bool checkThresholds({
    double? heartRate,
    double? oxygenSaturation,
    double? temperature,
    double? systolicBP,
    double? diastolicBP,
    double? respiratoryRate,
  }) {
    if (!enableAutoTriage) return false;

    // Heart rate thresholds
    if (heartRate != null) {
      if (heartRate < minHeartRate || heartRate > maxHeartRate) {
        return true;
      }
    }

    // Oxygen saturation threshold
    if (oxygenSaturation != null && oxygenSaturation < minOxygenSaturation) {
      return true;
    }

    // Temperature thresholds
    if (temperature != null) {
      if (temperature > maxTemperature) return true;
      if (minTemperature != null && temperature < minTemperature!) return true;
    }

    // Blood pressure thresholds
    if (systolicBP != null && systolicBP > maxSystolicBP) return true;
    if (diastolicBP != null && diastolicBP > maxDiastolicBP) return true;

    // Respiratory rate thresholds
    if (respiratoryRate != null) {
      if (maxRespiratoryRate != null && respiratoryRate > maxRespiratoryRate!) {
        return true;
      }
      if (minRespiratoryRate != null && respiratoryRate < minRespiratoryRate!) {
        return true;
      }
    }

    return false;
  }

  /// Get list of threshold violations
  List<String> getViolations({
    double? heartRate,
    double? oxygenSaturation,
    double? temperature,
    double? systolicBP,
    double? diastolicBP,
    double? respiratoryRate,
  }) {
    if (!enableAutoTriage) return [];

    final violations = <String>[];

    // Heart rate violations
    if (heartRate != null) {
      if (heartRate < minHeartRate) {
        violations.add('Heart rate too low: $heartRate (min: $minHeartRate)');
      } else if (heartRate > maxHeartRate) {
        violations.add('Heart rate too high: $heartRate (max: $maxHeartRate)');
      }
    }

    // Oxygen saturation violations
    if (oxygenSaturation != null && oxygenSaturation < minOxygenSaturation) {
      violations.add(
        'Oxygen saturation too low: $oxygenSaturation% (min: $minOxygenSaturation%)',
      );
    }

    // Temperature violations
    if (temperature != null) {
      if (temperature > maxTemperature) {
        violations.add(
          'Temperature too high: $temperature°F (max: $maxTemperature°F)',
        );
      }
      if (minTemperature != null && temperature < minTemperature!) {
        violations.add(
          'Temperature too low: $temperature°F (min: $minTemperature°F)',
        );
      }
    }

    // Blood pressure violations
    if (systolicBP != null && systolicBP > maxSystolicBP) {
      violations.add('Systolic BP too high: $systolicBP (max: $maxSystolicBP)');
    }
    if (diastolicBP != null && diastolicBP > maxDiastolicBP) {
      violations.add(
        'Diastolic BP too high: $diastolicBP (max: $maxDiastolicBP)',
      );
    }

    // Respiratory rate violations
    if (respiratoryRate != null) {
      if (maxRespiratoryRate != null && respiratoryRate > maxRespiratoryRate!) {
        violations.add(
          'Respiratory rate too high: $respiratoryRate (max: $maxRespiratoryRate)',
        );
      }
      if (minRespiratoryRate != null && respiratoryRate < minRespiratoryRate!) {
        violations.add(
          'Respiratory rate too low: $respiratoryRate (min: $minRespiratoryRate)',
        );
      }
    }

    return violations;
  }

  /// Calculate severity score based on how far vitals are from thresholds
  double calculateSeverityScore({
    double? heartRate,
    double? oxygenSaturation,
    double? temperature,
    double? systolicBP,
    double? diastolicBP,
    double? respiratoryRate,
  }) {
    if (!enableAutoTriage) return 0.0;

    double score = 0.0;

    // Heart rate severity
    if (heartRate != null) {
      if (heartRate < minHeartRate) {
        final deviation = (minHeartRate - heartRate) / minHeartRate;
        score += deviation * 2.0; // Weight heart rate highly
      } else if (heartRate > maxHeartRate) {
        final deviation = (heartRate - maxHeartRate) / maxHeartRate;
        score += deviation * 2.0;
      }
    }

    // Oxygen saturation severity (critical vital)
    if (oxygenSaturation != null && oxygenSaturation < minOxygenSaturation) {
      final deviation =
          (minOxygenSaturation - oxygenSaturation) / minOxygenSaturation;
      score += deviation * 3.0; // Weight oxygen saturation very highly
    }

    // Temperature severity
    if (temperature != null) {
      if (temperature > maxTemperature) {
        final deviation = (temperature - maxTemperature) / maxTemperature;
        score += deviation * 1.5;
      }
      if (minTemperature != null && temperature < minTemperature!) {
        final deviation = (minTemperature! - temperature) / minTemperature!;
        score += deviation * 1.5;
      }
    }

    // Blood pressure severity
    if (systolicBP != null && systolicBP > maxSystolicBP) {
      final deviation = (systolicBP - maxSystolicBP) / maxSystolicBP;
      score += deviation * 1.8;
    }
    if (diastolicBP != null && diastolicBP > maxDiastolicBP) {
      final deviation = (diastolicBP - maxDiastolicBP) / maxDiastolicBP;
      score += deviation * 1.8;
    }

    // Respiratory rate severity
    if (respiratoryRate != null) {
      if (maxRespiratoryRate != null && respiratoryRate > maxRespiratoryRate!) {
        final deviation =
            (respiratoryRate - maxRespiratoryRate!) / maxRespiratoryRate!;
        score += deviation * 1.2;
      }
      if (minRespiratoryRate != null && respiratoryRate < minRespiratoryRate!) {
        final deviation =
            (minRespiratoryRate! - respiratoryRate) / minRespiratoryRate!;
        score += deviation * 1.2;
      }
    }

    return score.clamp(0.0, 5.0); // Cap at 5.0 for maximum severity
  }

  /// Create default thresholds for a patient
  factory VitalsThresholdFirestore.createDefault({
    required String id,
    required String patientId,
    String? createdBy,
    String? notes,
  }) {
    return VitalsThresholdFirestore(
      id: id,
      patientId: patientId,
      minHeartRate: 50.0,
      maxHeartRate: 120.0,
      minOxygenSaturation: 90.0,
      maxTemperature: 101.5,
      minTemperature: 95.0,
      maxSystolicBP: 180.0,
      maxDiastolicBP: 120.0,
      maxRespiratoryRate: 24.0,
      minRespiratoryRate: 12.0,
      enableAutoTriage: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      notes:
          notes ?? 'Default vitals thresholds for automatic triage triggering',
    );
  }

  /// Create from Firestore document
  factory VitalsThresholdFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return VitalsThresholdFirestore(
      id: snapshot.id,
      patientId: data['patientId'] as String,
      minHeartRate: (data['minHeartRate'] as num).toDouble(),
      maxHeartRate: (data['maxHeartRate'] as num).toDouble(),
      minOxygenSaturation: (data['minOxygenSaturation'] as num).toDouble(),
      maxTemperature: (data['maxTemperature'] as num).toDouble(),
      maxSystolicBP: (data['maxSystolicBP'] as num).toDouble(),
      maxDiastolicBP: (data['maxDiastolicBP'] as num).toDouble(),
      minTemperature: (data['minTemperature'] as num?)?.toDouble(),
      maxRespiratoryRate: (data['maxRespiratoryRate'] as num?)?.toDouble(),
      minRespiratoryRate: (data['minRespiratoryRate'] as num?)?.toDouble(),
      enableAutoTriage: data['enableAutoTriage'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String?,
      notes: data['notes'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'minHeartRate': minHeartRate,
      'maxHeartRate': maxHeartRate,
      'minOxygenSaturation': minOxygenSaturation,
      'maxTemperature': maxTemperature,
      'maxSystolicBP': maxSystolicBP,
      'maxDiastolicBP': maxDiastolicBP,
      if (minTemperature != null) 'minTemperature': minTemperature,
      if (maxRespiratoryRate != null) 'maxRespiratoryRate': maxRespiratoryRate,
      if (minRespiratoryRate != null) 'minRespiratoryRate': minRespiratoryRate,
      'enableAutoTriage': enableAutoTriage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (notes != null) 'notes': notes,
    };
  }

  VitalsThresholdFirestore copyWith({
    String? id,
    String? patientId,
    double? minHeartRate,
    double? maxHeartRate,
    double? minOxygenSaturation,
    double? maxTemperature,
    double? maxSystolicBP,
    double? maxDiastolicBP,
    double? minTemperature,
    double? maxRespiratoryRate,
    double? minRespiratoryRate,
    bool? enableAutoTriage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? notes,
  }) {
    return VitalsThresholdFirestore(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      minOxygenSaturation: minOxygenSaturation ?? this.minOxygenSaturation,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      maxSystolicBP: maxSystolicBP ?? this.maxSystolicBP,
      maxDiastolicBP: maxDiastolicBP ?? this.maxDiastolicBP,
      minTemperature: minTemperature ?? this.minTemperature,
      maxRespiratoryRate: maxRespiratoryRate ?? this.maxRespiratoryRate,
      minRespiratoryRate: minRespiratoryRate ?? this.minRespiratoryRate,
      enableAutoTriage: enableAutoTriage ?? this.enableAutoTriage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    minHeartRate,
    maxHeartRate,
    minOxygenSaturation,
    maxTemperature,
    maxSystolicBP,
    maxDiastolicBP,
    minTemperature,
    maxRespiratoryRate,
    minRespiratoryRate,
    enableAutoTriage,
    createdAt,
    updatedAt,
    createdBy,
    notes,
  ];
}
