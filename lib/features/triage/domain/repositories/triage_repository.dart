import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient_vitals.dart';
import '../entities/triage_result.dart';

abstract class TriageRepository {
  Future<Either<Failure, TriageResult>> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  });
  
  Future<Either<Failure, PatientVitals>> getLatestVitals();
  
  Future<Either<Failure, bool>> checkHealthPermissions();
  
  Future<Either<Failure, void>> requestHealthPermissions();
}