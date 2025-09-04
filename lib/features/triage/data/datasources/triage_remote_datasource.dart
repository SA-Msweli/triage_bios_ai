import '../../../../shared/services/gemini_service.dart';
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
  final GeminiService geminiService;

  TriageRemoteDataSourceImpl({required this.geminiService});

  @override
  Future<TriageResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    // Use the correct GeminiService method
    return await geminiService.assessSymptoms(
      symptoms: symptoms,
      vitals: vitals,
      demographics: demographics,
    );
  }

  @override
  Future<bool> checkServiceHealth() async {
    try {
      // Use the correct health check method
      final healthStatus = await geminiService.getHealthStatus();
      return healthStatus['gemini'] == true;
    } catch (e) {
      return false;
    }
  }
}
