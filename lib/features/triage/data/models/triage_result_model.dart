import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/entities/patient_vitals.dart';

part 'triage_result_model.g.dart';

@JsonSerializable()
class TriageResultModel extends TriageResult {
  const TriageResultModel({
    required super.assessmentId,
    required super.severityScore,
    required super.confidenceLower,
    required super.confidenceUpper,
    required super.urgencyLevel,
    required super.explanation,
    required super.keySymptoms,
    required super.concerningFindings,
    required super.recommendedActions,
    super.vitals,
    super.vitalsContribution,
    required super.aiModelVersion,
    required super.timestamp,
  });

  factory TriageResultModel.fromJson(Map<String, dynamic> json) =>
      _$TriageResultModelFromJson(json);

  Map<String, dynamic> toJson() => _$TriageResultModelToJson(this);

  factory TriageResultModel.fromEntity(TriageResult result) {
    return TriageResultModel(
      assessmentId: result.assessmentId,
      severityScore: result.severityScore,
      confidenceLower: result.confidenceLower,
      confidenceUpper: result.confidenceUpper,
      urgencyLevel: result.urgencyLevel,
      explanation: result.explanation,
      keySymptoms: result.keySymptoms,
      concerningFindings: result.concerningFindings,
      recommendedActions: result.recommendedActions,
      vitals: result.vitals,
      vitalsContribution: result.vitalsContribution,
      aiModelVersion: result.aiModelVersion,
      timestamp: result.timestamp,
    );
  }

  TriageResult toEntity() {
    return TriageResult(
      assessmentId: assessmentId,
      severityScore: severityScore,
      confidenceLower: confidenceLower,
      confidenceUpper: confidenceUpper,
      urgencyLevel: urgencyLevel,
      explanation: explanation,
      keySymptoms: keySymptoms,
      concerningFindings: concerningFindings,
      recommendedActions: recommendedActions,
      vitals: vitals,
      vitalsContribution: vitalsContribution,
      aiModelVersion: aiModelVersion,
      timestamp: timestamp,
    );
  }
}
