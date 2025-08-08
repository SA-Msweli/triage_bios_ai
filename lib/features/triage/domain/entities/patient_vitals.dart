import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patient_vitals.g.dart';

@JsonSerializable()
class PatientVitals extends Equatable {
  final int? heartRate;
  final String? bloodPressure;
  final double? temperature;
  final double? oxygenSaturation;
  final int? respiratoryRate;
  final double? heartRateVariability;
  final DateTime timestamp;
  final String? deviceSource;
  final double? dataQuality;

  const PatientVitals({
    this.heartRate,
    this.bloodPressure,
    this.temperature,
    this.oxygenSaturation,
    this.respiratoryRate,
    this.heartRateVariability,
    required this.timestamp,
    this.deviceSource,
    this.dataQuality,
  });

  bool get hasCriticalVitals {
    if (heartRate != null) {
      if (heartRate! > 120 || heartRate! < 50) {
        return true;
      }
    }

    if (oxygenSaturation != null && oxygenSaturation! < 90) {
      return true;
    }

    if (temperature != null && temperature! > 101.5) {
      return true;
    }

    // Check blood pressure for hypertensive crisis
    if (bloodPressure != null) {
      final parts = bloodPressure!.split('/');
      if (parts.length == 2) {
        final systolic = int.tryParse(parts[0]);
        final diastolic = int.tryParse(parts[1]);
        if (systolic != null && diastolic != null) {
          if (systolic > 180 || diastolic > 120) {
            return true;
          }
          if (systolic < 90 || diastolic < 60) {
            return true;
          }
        }
      }
    }

    return false;
  }

  double get vitalsSeverityBoost {
    double boost = 0.0;

    // Heart rate contribution
    if (heartRate != null) {
      if (heartRate! > 120) {
        boost += 2.0;
      } else if (heartRate! < 50) {
        boost += 2.5;
      } else if (heartRate! > 100) {
        boost += 1.0;
      }
    }

    // Oxygen saturation contribution
    if (oxygenSaturation != null) {
      if (oxygenSaturation! < 90) {
        boost += 3.0;
      } else if (oxygenSaturation! < 95) {
        boost += 1.5;
      }
    }

    // Temperature contribution
    if (temperature != null) {
      if (temperature! > 103) {
        boost += 2.5;
      } else if (temperature! > 101.5) {
        boost += 1.5;
      }
    }

    // Blood pressure contribution
    if (bloodPressure != null) {
      final parts = bloodPressure!.split('/');
      if (parts.length == 2) {
        final systolic = int.tryParse(parts[0]);
        final diastolic = int.tryParse(parts[1]);
        if (systolic != null && diastolic != null) {
          if (systolic > 180 || diastolic > 120) {
            boost += 3.0;
          } else if (systolic < 90 || diastolic < 60) {
            boost += 2.0;
          }
        }
      }
    }

    return boost.clamp(0.0, 3.0); // Cap at +3 points
  }

  factory PatientVitals.fromJson(Map<String, dynamic> json) =>
      _$PatientVitalsFromJson(json);

  Map<String, dynamic> toJson() => _$PatientVitalsToJson(this);

  @override
  List<Object?> get props => [
    heartRate,
    bloodPressure,
    temperature,
    oxygenSaturation,
    respiratoryRate,
    heartRateVariability,
    timestamp,
    deviceSource,
    dataQuality,
  ];
}
