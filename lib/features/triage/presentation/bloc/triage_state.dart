import 'package:equatable/equatable.dart';
import '../../domain/entities/patient_vitals.dart';
import '../../domain/entities/triage_result.dart';

abstract class TriageState extends Equatable {
  const TriageState();

  @override
  List<Object?> get props => [];
}

class TriageInitial extends TriageState {
  const TriageInitial();
}

class TriageLoading extends TriageState {
  const TriageLoading();
}

class VitalsLoading extends TriageState {
  const VitalsLoading();
}

class VitalsLoaded extends TriageState {
  final PatientVitals vitals;
  final bool hasPermissions;

  const VitalsLoaded({
    required this.vitals,
    required this.hasPermissions,
  });

  @override
  List<Object?> get props => [vitals, hasPermissions];
}

class VitalsError extends TriageState {
  final String message;
  final bool hasPermissions;

  const VitalsError({
    required this.message,
    required this.hasPermissions,
  });

  @override
  List<Object?> get props => [message, hasPermissions];
}

class TriageAssessmentComplete extends TriageState {
  final TriageResult result;
  final PatientVitals? vitals;

  const TriageAssessmentComplete({
    required this.result,
    this.vitals,
  });

  @override
  List<Object?> get props => [result, vitals];
}

class TriageError extends TriageState {
  final String message;

  const TriageError(this.message);

  @override
  List<Object?> get props => [message];
}

class HealthPermissionsState extends TriageState {
  final bool hasPermissions;
  final bool isRequesting;

  const HealthPermissionsState({
    required this.hasPermissions,
    this.isRequesting = false,
  });

  @override
  List<Object?> get props => [hasPermissions, isRequesting];
}