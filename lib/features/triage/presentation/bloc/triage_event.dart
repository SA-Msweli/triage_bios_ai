import 'package:equatable/equatable.dart';
import '../../domain/entities/patient_vitals.dart';

abstract class TriageEvent extends Equatable {
  const TriageEvent();

  @override
  List<Object?> get props => [];
}

class AssessSymptomsEvent extends TriageEvent {
  final String symptoms;
  final PatientVitals? vitals;
  final Map<String, dynamic>? demographics;

  const AssessSymptomsEvent({
    required this.symptoms,
    this.vitals,
    this.demographics,
  });

  @override
  List<Object?> get props => [symptoms, vitals, demographics];
}

class LoadVitalsEvent extends TriageEvent {
  const LoadVitalsEvent();
}

class RequestHealthPermissionsEvent extends TriageEvent {
  const RequestHealthPermissionsEvent();
}

class CheckHealthPermissionsEvent extends TriageEvent {
  const CheckHealthPermissionsEvent();
}

class ResetTriageEvent extends TriageEvent {
  const ResetTriageEvent();
}