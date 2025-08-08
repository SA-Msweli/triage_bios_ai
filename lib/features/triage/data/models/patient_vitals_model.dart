import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/patient_vitals.dart';

part 'patient_vitals_model.g.dart';

@JsonSerializable()
class PatientVitalsModel extends PatientVitals {
  const PatientVitalsModel({
    super.heartRate,
    super.bloodPressure,
    super.temperature,
    super.oxygenSaturation,
    super.respiratoryRate,
    super.heartRateVariability,
    required super.timestamp,
    super.deviceSource,
    super.dataQuality,
  });

  factory PatientVitalsModel.fromJson(Map<String, dynamic> json) =>
      _$PatientVitalsModelFromJson(json);

  Map<String, dynamic> toJson() => _$PatientVitalsModelToJson(this);

  factory PatientVitalsModel.fromEntity(PatientVitals vitals) {
    return PatientVitalsModel(
      heartRate: vitals.heartRate,
      bloodPressure: vitals.bloodPressure,
      temperature: vitals.temperature,
      oxygenSaturation: vitals.oxygenSaturation,
      respiratoryRate: vitals.respiratoryRate,
      heartRateVariability: vitals.heartRateVariability,
      timestamp: vitals.timestamp,
      deviceSource: vitals.deviceSource,
      dataQuality: vitals.dataQuality,
    );
  }

  PatientVitals toEntity() {
    return PatientVitals(
      heartRate: heartRate,
      bloodPressure: bloodPressure,
      temperature: temperature,
      oxygenSaturation: oxygenSaturation,
      respiratoryRate: respiratoryRate,
      heartRateVariability: heartRateVariability,
      timestamp: timestamp,
      deviceSource: deviceSource,
      dataQuality: dataQuality,
    );
  }
}