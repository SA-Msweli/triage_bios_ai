import 'lib/features/triage/data/datasources/triage_service.dart';
import 'lib/features/triage/domain/entities/patient_vitals.dart';

/// Simple demo without Flutter dependencies
void main() async {
  print('🚀 Starting Triage-BIOS.ai Demo');
  
  // Initialize the triage service
  final triageService = TriageService();
  triageService.initialize(
    watsonxApiKey: 'demo_api_key',
    watsonxProjectId: 'demo_project',
  );

  // Demo 1: Basic Symptom Analysis
  print('\n📋 Demo 1: Basic Symptom Analysis');
  
  final result1 = await triageService.performTriageAssessment(
    symptoms: 'I have a headache and feel dizzy. It started this morning.',
    includeVitals: false,
  );

  print('Symptoms: "I have a headache and feel dizzy"');
  print('Severity Score: ${result1.severityScore}/10');
  print('Urgency Level: ${result1.urgencyLevelString}');
  print('Explanation: ${result1.explanation}');
  print('Recommended Actions: ${result1.recommendedActions.join(', ')}');

  // Demo 2: Vitals-Enhanced Triage
  print('\n💓 Demo 2: Vitals-Enhanced Triage');
  
  final vitals = PatientVitals(
    heartRate: 130, // Elevated
    oxygenSaturation: 92.0, // Low
    temperature: 99.8,
    bloodPressure: '150/95', // Elevated
    timestamp: DateTime.now(),
    deviceSource: 'Apple Watch Series 9',
  );

  final result2 = await triageService.performTriageAssessment(
    symptoms: 'I have chest pain and feel short of breath',
    providedVitals: vitals,
  );

  print('Symptoms: "I have chest pain and feel short of breath"');
  print('Vitals: HR=${vitals.heartRate}, SpO2=${vitals.oxygenSaturation}%, BP=${vitals.bloodPressure}');
  print('Severity Score: ${result2.severityScore}/10 (${result2.vitalsContribution?.toStringAsFixed(1)} from vitals)');
  print('Urgency Level: ${result2.urgencyLevelString}');
  print('Vitals Impact: ${result2.vitalsExplanation}');
  print('Recommended Actions: ${result2.recommendedActions.join(', ')}');

  // Demo 3: Critical Emergency Case
  print('\n🚨 Demo 3: Critical Emergency Case');
  
  final criticalVitals = PatientVitals(
    heartRate: 45, // Bradycardia
    oxygenSaturation: 88.0, // Critical hypoxemia
    temperature: 104.2, // High fever
    bloodPressure: '200/130', // Hypertensive crisis
    timestamp: DateTime.now(),
    deviceSource: 'Medical Monitor',
  );

  final result3 = await triageService.performTriageAssessment(
    symptoms: 'I feel very unwell, confused, and having trouble breathing',
    providedVitals: criticalVitals,
  );

  print('Symptoms: "I feel very unwell, confused, and having trouble breathing"');
  print('Critical Vitals: HR=${criticalVitals.heartRate}, SpO2=${criticalVitals.oxygenSaturation}%, Temp=${criticalVitals.temperature}°F');
  print('Severity Score: ${result3.severityScore}/10 (${result3.vitalsContribution?.toStringAsFixed(1)} from vitals)');
  print('Urgency Level: ${result3.urgencyLevelString}');
  print('Critical Alert: ${result3.isCritical ? "IMMEDIATE ATTENTION REQUIRED" : "Standard care"}');
  print('Recommended Actions: ${result3.recommendedActions.join(', ')}');

  // Demo 4: System Health Check
  print('\n🔍 Demo 4: System Health Check');
  
  final healthStatus = await triageService.performHealthCheck();
  
  print('System Health Status:');
  healthStatus.forEach((service, isHealthy) {
    final status = isHealthy ? '✅ Healthy' : '❌ Unhealthy';
    print('  $service: $status');
  });

  print('\n✅ Demo completed successfully!');
}