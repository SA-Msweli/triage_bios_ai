import 'package:equatable/equatable.dart';
import 'patient_vitals.dart';

enum UrgencyLevel { critical, urgent, standard, nonUrgent }

class TriageResult extends Equatable {
  final String assessmentId;
  final double severityScore;
  final double confidenceLower;
  final double confidenceUpper;
  final UrgencyLevel urgencyLevel;
  final String explanation;
  final List<String> keySymptoms;
  final List<String> concerningFindings;
  final List<String> recommendedActions;
  final PatientVitals? vitals;
  final double? vitalsContribution;
  final String aiModelVersion;
  final DateTime timestamp;

  const TriageResult({
    required this.assessmentId,
    required this.severityScore,
    required this.confidenceLower,
    required this.confidenceUpper,
    required this.urgencyLevel,
    required this.explanation,
    required this.keySymptoms,
    required this.concerningFindings,
    required this.recommendedActions,
    this.vitals,
    this.vitalsContribution,
    required this.aiModelVersion,
    required this.timestamp,
  });

  static UrgencyLevel _getUrgencyLevel(double score) {
    if (score >= 8.0) return UrgencyLevel.critical;
    if (score >= 6.0) return UrgencyLevel.urgent;
    if (score >= 4.0) return UrgencyLevel.standard;
    return UrgencyLevel.nonUrgent;
  }

  factory TriageResult.fromScore({
    required String assessmentId,
    required double baseScore,
    required double confidenceLower,
    required double confidenceUpper,
    required String explanation,
    required List<String> keySymptoms,
    required List<String> concerningFindings,
    required List<String> recommendedActions,
    PatientVitals? vitals,
    required String aiModelVersion,
  }) {
    final vitalsBoost = vitals?.vitalsSeverityBoost ?? 0.0;
    final finalScore = (baseScore + vitalsBoost).clamp(0.0, 10.0);

    return TriageResult(
      assessmentId: assessmentId,
      severityScore: finalScore,
      confidenceLower: confidenceLower,
      confidenceUpper: confidenceUpper,
      urgencyLevel: _getUrgencyLevel(finalScore),
      explanation: explanation,
      keySymptoms: keySymptoms,
      concerningFindings: concerningFindings,
      recommendedActions: recommendedActions,
      vitals: vitals,
      vitalsContribution: vitalsBoost,
      aiModelVersion: aiModelVersion,
      timestamp: DateTime.now(),
    );
  }

  /// Create TriageResult from Map (for deserialization)
  factory TriageResult.fromMap(Map<String, dynamic> map) {
    return TriageResult(
      assessmentId: map['assessmentId'] as String,
      severityScore: (map['severityScore'] as num).toDouble(),
      confidenceLower: (map['confidenceLower'] as num).toDouble(),
      confidenceUpper: (map['confidenceUpper'] as num).toDouble(),
      urgencyLevel: UrgencyLevel.values.firstWhere(
        (e) => e.toString() == 'UrgencyLevel.${map['urgencyLevel']}',
        orElse: () => UrgencyLevel.standard,
      ),
      explanation: map['explanation'] as String,
      keySymptoms: List<String>.from(map['keySymptoms'] ?? []),
      concerningFindings: List<String>.from(map['concerningFindings'] ?? []),
      recommendedActions: List<String>.from(map['recommendedActions'] ?? []),
      vitals: map['vitals'] != null
          ? PatientVitals.fromJson(map['vitals'] as Map<String, dynamic>)
          : null,
      vitalsContribution: map['vitalsContribution'] != null
          ? (map['vitalsContribution'] as num).toDouble()
          : null,
      aiModelVersion: map['aiModelVersion'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  /// Convert TriageResult to Map (for serialization)
  Map<String, dynamic> toMap() {
    return {
      'assessmentId': assessmentId,
      'severityScore': severityScore,
      'confidenceLower': confidenceLower,
      'confidenceUpper': confidenceUpper,
      'urgencyLevel': urgencyLevel.toString().split('.').last,
      'explanation': explanation,
      'keySymptoms': keySymptoms,
      'concerningFindings': concerningFindings,
      'recommendedActions': recommendedActions,
      'vitals': vitals?.toJson(),
      'vitalsContribution': vitalsContribution,
      'aiModelVersion': aiModelVersion,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isCritical => urgencyLevel == UrgencyLevel.critical;
  bool get requiresImmediateAttention => severityScore >= 8.0;

  String get urgencyLevelString {
    switch (urgencyLevel) {
      case UrgencyLevel.critical:
        return 'CRITICAL';
      case UrgencyLevel.urgent:
        return 'URGENT';
      case UrgencyLevel.standard:
        return 'STANDARD';
      case UrgencyLevel.nonUrgent:
        return 'NON-URGENT';
    }
  }

  String get vitalsExplanation {
    if (vitals == null ||
        vitalsContribution == null ||
        vitalsContribution == 0) {
      return 'No wearable vitals data available for assessment.';
    }

    final boost = vitalsContribution!;
    final vitalsText = <String>[];

    if (vitals!.heartRate != null) {
      final hr = vitals!.heartRate!;
      if (hr > 120) {
        vitalsText.add('elevated heart rate ($hr bpm)');
      } else if (hr < 50) {
        vitalsText.add('low heart rate ($hr bpm)');
      }
    }

    if (vitals!.oxygenSaturation != null && vitals!.oxygenSaturation! < 95) {
      vitalsText.add('low oxygen saturation (${vitals!.oxygenSaturation}%)');
    }

    if (vitals!.temperature != null && vitals!.temperature! > 101.5) {
      vitalsText.add('fever (${vitals!.temperature}°F)');
    }

    if (vitalsText.isEmpty) {
      return 'Vitals data contributed +${boost.toStringAsFixed(1)} points to severity score.';
    }

    return 'Concerning vitals detected: ${vitalsText.join(', ')}. This increased the severity score by +${boost.toStringAsFixed(1)} points.';
  }

  @override
  List<Object?> get props => [
    assessmentId,
    severityScore,
    confidenceLower,
    confidenceUpper,
    urgencyLevel,
    explanation,
    keySymptoms,
    concerningFindings,
    recommendedActions,
    vitals,
    vitalsContribution,
    aiModelVersion,
    timestamp,
  ];
}
