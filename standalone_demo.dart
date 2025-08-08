// Standalone demo without Flutter dependencies
import 'dart:async';

// Mock classes to demonstrate the AI triage functionality
class PatientVitals {
  final int? heartRate;
  final String? bloodPressure;
  final double? temperature;
  final double? oxygenSaturation;
  final DateTime timestamp;
  final String? deviceSource;

  const PatientVitals({
    this.heartRate,
    this.bloodPressure,
    this.temperature,
    this.oxygenSaturation,
    required this.timestamp,
    this.deviceSource,
  });

  bool get hasCriticalVitals {
    if (heartRate != null && (heartRate! > 120 || heartRate! < 50)) return true;
    if (oxygenSaturation != null && oxygenSaturation! < 90) return true;
    if (temperature != null && temperature! > 101.5) return true;
    return false;
  }

  double get vitalsSeverityBoost {
    double boost = 0.0;
    if (heartRate != null) {
      if (heartRate! > 120) boost += 2.0;
      else if (heartRate! < 50) boost += 2.5;
    }
    if (oxygenSaturation != null && oxygenSaturation! < 95) boost += 1.5;
    if (temperature != null && temperature! > 101.5) boost += 1.5;
    return boost.clamp(0.0, 3.0);
  }
}

enum UrgencyLevel { critical, urgent, standard, nonUrgent }

class TriageResult {
  final String assessmentId;
  final double severityScore;
  final UrgencyLevel urgencyLevel;
  final String explanation;
  final List<String> keySymptoms;
  final List<String> recommendedActions;
  final PatientVitals? vitals;
  final double? vitalsContribution;
  final DateTime timestamp;

  TriageResult({
    required this.assessmentId,
    required this.severityScore,
    required this.urgencyLevel,
    required this.explanation,
    required this.keySymptoms,
    required this.recommendedActions,
    this.vitals,
    this.vitalsContribution,
    required this.timestamp,
  });

  bool get isCritical => urgencyLevel == UrgencyLevel.critical;
  
  String get urgencyLevelString {
    switch (urgencyLevel) {
      case UrgencyLevel.critical: return 'CRITICAL';
      case UrgencyLevel.urgent: return 'URGENT';
      case UrgencyLevel.standard: return 'STANDARD';
      case UrgencyLevel.nonUrgent: return 'NON-URGENT';
    }
  }

  String get vitalsExplanation {
    if (vitals == null || vitalsContribution == null || vitalsContribution == 0) {
      return 'No wearable vitals data available for assessment.';
    }
    return 'Vitals data contributed +${vitalsContribution!.toStringAsFixed(1)} points to severity score.';
  }
}

class MockWatsonxTriageService {
  Future<TriageResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
  }) async {
    // Simulate API call delay
    await Future.delayed(Duration(milliseconds: 600));
    
    // Mock AI analysis
    final symptomsLower = symptoms.toLowerCase();
    double baseScore = 3.0;
    
    if (symptomsLower.contains('chest pain') || 
        symptomsLower.contains('difficulty breathing') ||
        symptomsLower.contains('severe pain')) {
      baseScore = 7.0;
    } else if (symptomsLower.contains('headache') || 
               symptomsLower.contains('nausea') ||
               symptomsLower.contains('dizziness')) {
      baseScore = 5.0;
    } else if (symptomsLower.contains('fever') || 
               symptomsLower.contains('cough')) {
      baseScore = 4.0;
    }
    
    final vitalsBoost = vitals?.vitalsSeverityBoost ?? 0.0;
    final finalScore = (baseScore + vitalsBoost).clamp(0.0, 10.0);
    
    UrgencyLevel urgencyLevel;
    List<String> recommendedActions;
    
    if (finalScore >= 8.0) {
      urgencyLevel = UrgencyLevel.critical;
      recommendedActions = ['Call 911 immediately', 'Do not drive yourself'];
    } else if (finalScore >= 6.0) {
      urgencyLevel = UrgencyLevel.urgent;
      recommendedActions = ['Seek emergency care promptly', 'Monitor symptoms closely'];
    } else if (finalScore >= 4.0) {
      urgencyLevel = UrgencyLevel.standard;
      recommendedActions = ['Visit emergency room when convenient', 'Monitor symptoms'];
    } else {
      urgencyLevel = UrgencyLevel.nonUrgent;
      recommendedActions = ['Schedule appointment with primary care', 'Rest and hydrate'];
    }
    
    return TriageResult(
      assessmentId: 'triage_${DateTime.now().millisecondsSinceEpoch}',
      severityScore: finalScore,
      urgencyLevel: urgencyLevel,
      explanation: _generateExplanation(symptomsLower, vitals, finalScore),
      keySymptoms: _extractKeySymptoms(symptomsLower),
      recommendedActions: recommendedActions,
      vitals: vitals,
      vitalsContribution: vitalsBoost,
      timestamp: DateTime.now(),
    );
  }

  String _generateExplanation(String symptoms, PatientVitals? vitals, double score) {
    final parts = <String>[];
    
    if (symptoms.contains('chest pain')) {
      parts.add('Chest pain requires immediate evaluation to rule out cardiac events');
    } else if (symptoms.contains('difficulty breathing')) {
      parts.add('Breathing difficulties can indicate serious respiratory or cardiac issues');
    } else {
      parts.add('Symptoms suggest ${score >= 6 ? 'urgent' : 'routine'} medical attention needed');
    }
    
    if (vitals != null && vitals.vitalsSeverityBoost > 0) {
      parts.add('Concerning vital signs detected, increasing urgency level');
    }
    
    return parts.join('. ');
  }

  List<String> _extractKeySymptoms(String symptoms) {
    final keySymptoms = <String>[];
    
    if (symptoms.contains('chest pain')) keySymptoms.add('chest pain');
    if (symptoms.contains('difficulty breathing')) keySymptoms.add('difficulty breathing');
    if (symptoms.contains('headache')) keySymptoms.add('headache');
    if (symptoms.contains('nausea')) keySymptoms.add('nausea');
    if (symptoms.contains('fever')) keySymptoms.add('fever');
    
    return keySymptoms.isEmpty ? ['general symptoms'] : keySymptoms;
  }
}

void main() async {
  print('🚀 Starting Triage-BIOS.ai Demo');
  
  final triageService = MockWatsonxTriageService();

  // Demo 1: Basic Symptom Analysis
  print('\n📋 Demo 1: Basic Symptom Analysis');
  
  final result1 = await triageService.assessSymptoms(
    symptoms: 'I have a headache and feel dizzy. It started this morning.',
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

  final result2 = await triageService.assessSymptoms(
    symptoms: 'I have chest pain and feel short of breath',
    vitals: vitals,
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

  final result3 = await triageService.assessSymptoms(
    symptoms: 'I feel very unwell, confused, and having trouble breathing',
    vitals: criticalVitals,
  );

  print('Symptoms: "I feel very unwell, confused, and having trouble breathing"');
  print('Critical Vitals: HR=${criticalVitals.heartRate}, SpO2=${criticalVitals.oxygenSaturation}%, Temp=${criticalVitals.temperature}°F');
  print('Severity Score: ${result3.severityScore}/10 (${result3.vitalsContribution?.toStringAsFixed(1)} from vitals)');
  print('Urgency Level: ${result3.urgencyLevelString}');
  print('Critical Alert: ${result3.isCritical ? "🚨 IMMEDIATE ATTENTION REQUIRED" : "Standard care"}');
  print('Recommended Actions: ${result3.recommendedActions.join(', ')}');

  print('\n✅ Demo completed successfully!');
  print('\n🎯 Key Features Demonstrated:');
  print('  ✓ AI-powered symptom analysis using watsonx.ai (simulated)');
  print('  ✓ Wearable vitals integration with severity enhancement');
  print('  ✓ Critical case detection and emergency alerting');
  print('  ✓ Explainable AI reasoning and recommendations');
  print('  ✓ Multi-level urgency classification');
}