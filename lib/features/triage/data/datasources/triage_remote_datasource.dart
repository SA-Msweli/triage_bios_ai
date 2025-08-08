import '../../../../shared/services/watsonx_service.dart';
import '../../domain/entities/patient_vitals.dart';
import '../../domain/entities/triage_result.dart';

abstract class TriageRemoteDataSource {
  Future<TriageResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  });
  
  Future<bool> checkServiceHealth();
}

class TriageRemoteDataSourceImpl implements TriageRemoteDataSource {
  final WatsonxService watsonxService;

  TriageRemoteDataSourceImpl({required this.watsonxService});

  @override
  Future<TriageResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    return await watsonxService.assessSymptoms(
      symptoms: symptoms,
      vitals: vitals,
      demographics: demographics,
    );
  }

  @override
  Future<bool> checkServiceHealth() async {
    return await watsonxService.isHealthy();
  }
}