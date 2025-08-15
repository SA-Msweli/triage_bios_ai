import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for triage assessment results
class TriageResultFirestore extends Equatable {
  final String id;
  final String patientId;
  final String sessionId;
  final String symptoms;
  final double severityScore;
  final UrgencyLevel urgencyLevel;
  final String aiReasoning;
  final List<String> recommendedActions;
  final double vitalsContribution;
  final double confidence;
  final String? recommendedHospitalId;
  final double? estimatedWaitTime;
  final DateTime createdAt;
  final String watsonxModelVersion;

  const TriageResultFirestore({
    required this.id,
    required this.patientId,
    required this.sessionId,
    required this.symptoms,
    required this.severityScore,
    required this.urgencyLevel,
    required this.aiReasoning,
    required this.recommendedActions,
    required this.vitalsContribution,
    required this.confidence,
    this.recommendedHospitalId,
    this.estimatedWaitTime,
    required this.createdAt,
    required this.watsonxModelVersion,
  });

  /// Check if this is a critical case requiring immediate attention
  bool get isCritical => urgencyLevel == UrgencyLevel.critical;

  /// Check if this case requires urgent care
  bool get isUrgent => urgencyLevel == UrgencyLevel.urgent || isCritical;

  /// Get color code for urgency level
  String get urgencyColor {
    switch (urgencyLevel) {
      case UrgencyLevel.nonUrgent:
        return '#4CAF50'; // Green
      case UrgencyLevel.standard:
        return '#FF9800'; // Orange
      case UrgencyLevel.urgent:
        return '#F44336'; // Red
      case UrgencyLevel.critical:
        return '#9C27B0'; // Purple
    }
  }

  /// Create from Firestore document
  factory TriageResultFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return TriageResultFirestore(
      id: snapshot.id,
      patientId: data['patientId'] as String,
      sessionId: data['sessionId'] as String,
      symptoms: data['symptoms'] as String,
      severityScore: (data['severityScore'] as num).toDouble(),
      urgencyLevel: UrgencyLevel.fromString(data['urgencyLevel'] as String),
      aiReasoning: data['aiReasoning'] as String,
      recommendedActions: List<String>.from(data['recommendedActions'] as List),
      vitalsContribution: (data['vitalsContribution'] as num).toDouble(),
      confidence: (data['confidence'] as num).toDouble(),
      recommendedHospitalId: data['recommendedHospitalId'] as String?,
      estimatedWaitTime: (data['estimatedWaitTime'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      watsonxModelVersion: data['watsonxModelVersion'] as String,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'sessionId': sessionId,
      'symptoms': symptoms,
      'severityScore': severityScore,
      'urgencyLevel': urgencyLevel.toString(),
      'aiReasoning': aiReasoning,
      'recommendedActions': recommendedActions,
      'vitalsContribution': vitalsContribution,
      'confidence': confidence,
      if (recommendedHospitalId != null)
        'recommendedHospitalId': recommendedHospitalId,
      if (estimatedWaitTime != null) 'estimatedWaitTime': estimatedWaitTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'watsonxModelVersion': watsonxModelVersion,
      'isCritical': isCritical,
      'isUrgent': isUrgent,
    };
  }

  TriageResultFirestore copyWith({
    String? id,
    String? patientId,
    String? sessionId,
    String? symptoms,
    double? severityScore,
    UrgencyLevel? urgencyLevel,
    String? aiReasoning,
    List<String>? recommendedActions,
    double? vitalsContribution,
    double? confidence,
    String? recommendedHospitalId,
    double? estimatedWaitTime,
    DateTime? createdAt,
    String? watsonxModelVersion,
  }) {
    return TriageResultFirestore(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      sessionId: sessionId ?? this.sessionId,
      symptoms: symptoms ?? this.symptoms,
      severityScore: severityScore ?? this.severityScore,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      recommendedActions: recommendedActions ?? this.recommendedActions,
      vitalsContribution: vitalsContribution ?? this.vitalsContribution,
      confidence: confidence ?? this.confidence,
      recommendedHospitalId:
          recommendedHospitalId ?? this.recommendedHospitalId,
      estimatedWaitTime: estimatedWaitTime ?? this.estimatedWaitTime,
      createdAt: createdAt ?? this.createdAt,
      watsonxModelVersion: watsonxModelVersion ?? this.watsonxModelVersion,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    sessionId,
    symptoms,
    severityScore,
    urgencyLevel,
    aiReasoning,
    recommendedActions,
    vitalsContribution,
    confidence,
    recommendedHospitalId,
    estimatedWaitTime,
    createdAt,
    watsonxModelVersion,
  ];
}

enum UrgencyLevel {
  nonUrgent,
  standard,
  urgent,
  critical;

  factory UrgencyLevel.fromString(String value) {
    switch (value.toUpperCase()) {
      case 'NON_URGENT':
        return UrgencyLevel.nonUrgent;
      case 'STANDARD':
        return UrgencyLevel.standard;
      case 'URGENT':
        return UrgencyLevel.urgent;
      case 'CRITICAL':
        return UrgencyLevel.critical;
      default:
        return UrgencyLevel.standard;
    }
  }

  @override
  String toString() {
    switch (this) {
      case UrgencyLevel.nonUrgent:
        return 'NON_URGENT';
      case UrgencyLevel.standard:
        return 'STANDARD';
      case UrgencyLevel.urgent:
        return 'URGENT';
      case UrgencyLevel.critical:
        return 'CRITICAL';
    }
  }

  String get displayName {
    switch (this) {
      case UrgencyLevel.nonUrgent:
        return 'Non-Urgent';
      case UrgencyLevel.standard:
        return 'Standard';
      case UrgencyLevel.urgent:
        return 'Urgent';
      case UrgencyLevel.critical:
        return 'Critical';
    }
  }
}
