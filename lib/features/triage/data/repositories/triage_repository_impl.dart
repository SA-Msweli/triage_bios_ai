import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/services/watsonx_service.dart';
import '../../../../shared/services/health_service.dart';
import '../../domain/entities/patient_vitals.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/triage_repository.dart';

class TriageRepositoryImpl implements TriageRepository {
  final WatsonxService watsonxService;
  final HealthService healthService;

  TriageRepositoryImpl({
    required this.watsonxService,
    required this.healthService,
  });

  @override
  Future<Either<Failure, TriageResult>> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    try {
      final result = await watsonxService.assessSymptoms(
        symptoms: symptoms,
        vitals: vitals,
        demographics: demographics,
      );
      
      return Right(result);
    } on TriageFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TriageFailure('Unexpected error during triage assessment: $e'));
    }
  }

  @override
  Future<Either<Failure, PatientVitals>> getLatestVitals() async {
    try {
      final vitals = await healthService.getLatestVitals();
      
      if (vitals == null) {
        return const Left(HealthDataFailure('No health data available'));
      }
      
      return Right(vitals);
    } catch (e) {
      return Left(HealthDataFailure('Failed to retrieve health data: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkHealthPermissions() async {
    try {
      final hasPermissions = await healthService.hasHealthPermissions();
      return Right(hasPermissions);
    } catch (e) {
      return Left(PermissionFailure('Failed to check health permissions: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> requestHealthPermissions() async {
    try {
      await healthService.requestPermissions();
      return const Right(null);
    } catch (e) {
      return Left(PermissionFailure('Failed to request health permissions: $e'));
    }
  }
}