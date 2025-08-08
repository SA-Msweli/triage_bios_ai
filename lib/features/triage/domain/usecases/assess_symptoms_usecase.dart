import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient_vitals.dart';
import '../entities/triage_result.dart';
import '../repositories/triage_repository.dart';

class AssessSymptomsUseCase {
  final TriageRepository repository;

  AssessSymptomsUseCase(this.repository);

  Future<Either<Failure, TriageResult>> call(AssessSymptomsParams params) async {
    // First try to get latest vitals if not provided
    PatientVitals? vitals = params.vitals;
    
    if (vitals == null) {
      final vitalsResult = await repository.getLatestVitals();
      vitalsResult.fold(
        (failure) => null, // Continue without vitals if unavailable
        (retrievedVitals) => vitals = retrievedVitals,
      );
    }

    // Perform the triage assessment
    return await repository.assessSymptoms(
      symptoms: params.symptoms,
      vitals: vitals,
      demographics: params.demographics,
    );
  }
}

class AssessSymptomsParams {
  final String symptoms;
  final PatientVitals? vitals;
  final Map<String, dynamic>? demographics;

  AssessSymptomsParams({
    required this.symptoms,
    this.vitals,
    this.demographics,
  });
}