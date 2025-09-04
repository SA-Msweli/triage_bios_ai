import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/services/gemini_service.dart';
import '../../../../shared/services/health_service.dart';
import '../../../../shared/services/firestore_data_service.dart';
import '../../../../shared/models/firestore/patient_vitals_firestore.dart';
import '../../../../shared/models/firestore/triage_result_firestore.dart';
import '../../domain/entities/patient_vitals.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/triage_repository.dart';

class TriageRepositoryImpl implements TriageRepository {
  final GeminiService geminiService;
  final HealthService healthService;
  final FirestoreDataService firestoreService;

  TriageRepositoryImpl({
    required this.geminiService,
    required this.healthService,
    required this.firestoreService,
  });

  @override
  Future<Either<Failure, TriageResult>> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    try {
      // Use the correct GeminiService method
      final result = await geminiService.assessSymptoms(
        symptoms: symptoms,
        vitals: vitals,
        demographics: demographics,
      );

      return Right(result);
    } on TriageFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(
        TriageFailure('Unexpected error during triage assessment: $e'),
      );
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
      return Left(
        PermissionFailure('Failed to request health permissions: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> storeTriageResult(TriageResult result) async {
    try {
      // Convert domain entity to Firestore model
      final firestoreResult = TriageResultFirestore.fromDomain(result);

      // Store in Firestore
      await firestoreService.storeTriageResult(firestoreResult);

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to store triage result: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> storePatientVitals(PatientVitals vitals) async {
    try {
      // Convert domain entity to Firestore model
      final firestoreVitals = PatientVitalsFirestore.fromDomain(vitals);

      // Store in Firestore
      await firestoreService.storePatientVitals(firestoreVitals);

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to store patient vitals: $e'));
    }
  }

  @override
  Future<Either<Failure, List<TriageResult>>> getPatientHistory(
    String patientId,
  ) async {
    try {
      // Get triage results from Firestore
      final firestoreResults = await firestoreService.getPatientTriageResults(
        patientId,
      );

      // Convert to domain entities
      final results = firestoreResults.map((fr) => fr.toDomain()).toList();

      return Right(results);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get patient history: $e'));
    }
  }

  @override
  Stream<List<TriageResult>> watchPatientHistory(String patientId) {
    return firestoreService
        .listenToPatientTriageResults(patientId)
        .map(
          (firestoreResults) =>
              firestoreResults.map((fr) => fr.toDomain()).toList(),
        );
  }
}
