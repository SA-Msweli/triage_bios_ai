import 'package:logger/logger.dart';
import '../features/triage/data/datasources/triage_service.dart';
import '../features/triage/domain/entities/patient_vitals.dart';

/// Demo script to showcase the AI triage functionality
class TriageDemo {
  static final Logger _logger = Logger();

  static Future<void> runDemo() async {
    _logger.i('🚀 Starting Triage-BIOS.ai Demo');
    
    // Initialize the triage service
    final triageService = TriageService();
    triageService.initialize(
      watsonxApiKey: 'demo_api_key',
      watsonxProjectId: 'demo_project',
    );

    // Demo scenarios
    await _demoBasicTriage();
    await _demoVitalsEnhancedTriage();
    await _demoCriticalCase();
    await _demoHealthCheck();

    _logger.i('✅ Demo completed successfully!');
  }

  static Future<void> _demoBasicTriage() async {
    _logger.i('\n📋 Demo 1: Basic Symptom Analysis');
    
    final triageService = TriageService();
    
    final result = await triageService.performTriageAssessment(
      symptoms: 'I have a headache and feel dizzy. It started this morning.',
      includeVitals: false,
    );

    _logger.i('Symptoms: "I have a headache and feel dizzy"');
    _logger.i('Severity Score: ${result.severityScore}/10');
    _logger.i('Urgency Level: ${result.urgencyLevelString}');
    _logger.i('Explanation: ${result.explanation}');
    _logger.i('Recommended Actions: ${result.recommendedActions.join(', ')}');
  }

  static Future<void> _demoVitalsEnhancedTriage() async {
    _logger.i('\n💓 Demo 2: Vitals-Enhanced Triage');
    
    final triageService = TriageService();
    
    // Create mock vitals data
    final vitals = PatientVitals(
      heartRate: 130, // Elevated
      oxygenSaturation: 92.0, // Low
      temperature: 99.8,
      bloodPressure: '150/95', // Elevated
      timestamp: DateTime.now(),
      deviceSource: 'Apple Watch Series 9',
    );

    final result = await triageService.performTriageAssessment(
      symptoms: 'I have chest pain and feel short of breath',
      providedVitals: vitals,
    );

    _logger.i('Symptoms: "I have chest pain and feel short of breath"');
    _logger.i('Vitals: HR=${vitals.heartRate}, SpO2=${vitals.oxygenSaturation}%, BP=${vitals.bloodPressure}');
    _logger.i('Severity Score: ${result.severityScore}/10 (${result.vitalsContribution?.toStringAsFixed(1)} from vitals)');
    _logger.i('Urgency Level: ${result.urgencyLevelString}');
    _logger.i('Vitals Impact: ${result.vitalsExplanation}');
    _logger.i('Recommended Actions: ${result.recommendedActions.join(', ')}');
  }

  static Future<void> _demoCriticalCase() async {
    _logger.i('\n🚨 Demo 3: Critical Emergency Case');
    
    final triageService = TriageService();
    
    // Create critical vitals
    final criticalVitals = PatientVitals(
      heartRate: 45, // Bradycardia
      oxygenSaturation: 88.0, // Critical hypoxemia
      temperature: 104.2, // High fever
      bloodPressure: '200/130', // Hypertensive crisis
      timestamp: DateTime.now(),
      deviceSource: 'Medical Monitor',
    );

    final result = await triageService.performTriageAssessment(
      symptoms: 'I feel very unwell, confused, and having trouble breathing',
      providedVitals: criticalVitals,
    );

    _logger.i('Symptoms: "I feel very unwell, confused, and having trouble breathing"');
    _logger.i('Critical Vitals: HR=${criticalVitals.heartRate}, SpO2=${criticalVitals.oxygenSaturation}%, Temp=${criticalVitals.temperature}°F');
    _logger.i('Severity Score: ${result.severityScore}/10 (${result.vitalsContribution?.toStringAsFixed(1)} from vitals)');
    _logger.i('Urgency Level: ${result.urgencyLevelString}');
    _logger.i('Critical Alert: ${result.isCritical ? "IMMEDIATE ATTENTION REQUIRED" : "Standard care"}');
    _logger.i('Recommended Actions: ${result.recommendedActions.join(', ')}');
  }

  static Future<void> _demoHealthCheck() async {
    _logger.i('\n🔍 Demo 4: System Health Check');
    
    final triageService = TriageService();
    
    final healthStatus = await triageService.performHealthCheck();
    
    _logger.i('System Health Status:');
    healthStatus.forEach((service, isHealthy) {
      final status = isHealthy ? '✅ Healthy' : '❌ Unhealthy';
      _logger.i('  $service: $status');
    });
  }
}

/// Example usage
void main() async {
  await TriageDemo.runDemo();
}