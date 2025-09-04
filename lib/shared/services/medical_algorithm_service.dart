import 'dart:math';
import 'package:logger/logger.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';

/// Medical Algorithm Service implementing clinical decision support algorithms
/// Based on Emergency Severity Index (ESI), MEWS, and other clinical protocols
class MedicalAlgorithmService {
  static final MedicalAlgorithmService _instance =
      MedicalAlgorithmService._internal();
  factory MedicalAlgorithmService() => _instance;
  MedicalAlgorithmService._internal();

  final Logger _logger = Logger();

  /// Assess patient symptoms - alias for analyzePatient for compatibility
  Future<MedicalAssessmentResult> assessSymptoms({
    required String symptoms,
    PatientVitals? vitals,
    Map<String, dynamic>? demographics,
  }) async {
    return await analyzePatient(
      symptoms: symptoms,
      vitals: vitals,
      demographics: demographics,
    );
  }

  /// Comprehensive medical assessment combining multiple clinical algorithms
  Future<MedicalAssessmentResult> analyzePatient({
    required String symptoms,
    required PatientVitals? vitals,
    Map<String, dynamic>? demographics,
    Map<String, dynamic>? aiResult,
  }) async {
    _logger.i('Starting comprehensive medical algorithm analysis');

    // Calculate Emergency Severity Index (ESI)
    final esiLevel = _calculateESI(symptoms, vitals);

    // Calculate Modified Early Warning Score (MEWS)
    final mewsScore = _calculateMEWS(vitals);

    // Calculate symptom-based severity
    final symptomSeverity = _analyzeSymptoms(symptoms);

    // Calculate vitals-based risk
    final vitalsRisk = _analyzeVitals(vitals);

    // Perform trend analysis if historical data available
    final trendAnalysis = _analyzeTrends(vitals);

    // Combine all assessments
    final combinedScore = _combineAssessments(
      esiLevel: esiLevel,
      mewsScore: mewsScore,
      symptomSeverity: symptomSeverity,
      vitalsRisk: vitalsRisk,
      aiResult: aiResult,
    );

    // Generate clinical reasoning
    final reasoning = _generateClinicalReasoning(
      esiLevel: esiLevel,
      mewsScore: mewsScore,
      symptomSeverity: symptomSeverity,
      vitalsRisk: vitalsRisk,
      trendAnalysis: trendAnalysis,
    );

    final result = MedicalAssessmentResult(
      finalScore: combinedScore.clamp(0.0, 10.0),
      esiLevel: esiLevel,
      mewsScore: mewsScore,
      symptomSeverity: symptomSeverity,
      vitalsRisk: vitalsRisk,
      trendAnalysis: trendAnalysis,
      clinicalReasoning: reasoning,
      riskFactors: _identifyRiskFactors(symptoms, vitals),
      recommendations: _generateRecommendations(combinedScore, esiLevel),
      confidence: _calculateConfidence(vitals, symptoms),
    );

    _logger.i(
      'Medical algorithm analysis complete: Score ${result.finalScore.toStringAsFixed(1)}',
    );
    return result;
  }

  /// Emergency Severity Index (ESI) - Standard hospital triage protocol
  int _calculateESI(String symptoms, PatientVitals? vitals) {
    final symptomsLower = symptoms.toLowerCase();

    // ESI Level 1: Immediate (life-threatening)
    if (_isLevel1Emergency(symptomsLower, vitals)) return 1;

    // ESI Level 2: Emergent (high risk of deterioration)
    if (_isLevel2Emergency(symptomsLower, vitals)) return 2;

    // ESI Level 3: Urgent (stable but needs multiple resources)
    if (_isLevel3Urgent(symptomsLower, vitals)) return 3;

    // ESI Level 4: Less urgent (needs one resource)
    if (_isLevel4LessUrgent(symptomsLower, vitals)) return 4;

    // ESI Level 5: Non-urgent (no resources needed)
    return 5;
  }

  bool _isLevel1Emergency(String symptoms, PatientVitals? vitals) {
    // Critical vital signs
    if (vitals != null) {
      if (vitals.heartRate != null &&
          (vitals.heartRate! > 150 || vitals.heartRate! < 40)) {
        return true;
      }
      if (vitals.oxygenSaturation != null && vitals.oxygenSaturation! < 90) {
        return true;
      }
      if (vitals.temperature != null && vitals.temperature! > 104.0) {
        return true;
      }

      // Critical blood pressure
      if (vitals.bloodPressure != null) {
        final bp = _parseBloodPressure(vitals.bloodPressure!);
        if (bp != null && (bp['systolic']! > 200 || bp['systolic']! < 70)) {
          return true;
        }
      }
    }

    // Life-threatening symptoms
    return symptoms.contains('cardiac arrest') ||
        symptoms.contains('not breathing') ||
        symptoms.contains('unresponsive') ||
        symptoms.contains('severe trauma') ||
        symptoms.contains('major bleeding');
  }

  bool _isLevel2Emergency(String symptoms, PatientVitals? vitals) {
    // High-risk vital signs
    if (vitals != null) {
      if (vitals.heartRate != null &&
          (vitals.heartRate! > 130 || vitals.heartRate! < 50)) {
        return true;
      }
      if (vitals.oxygenSaturation != null && vitals.oxygenSaturation! < 95) {
        return true;
      }
      if (vitals.temperature != null && vitals.temperature! > 102.0) {
        return true;
      }
    }

    // High-risk symptoms
    return symptoms.contains('chest pain') ||
        symptoms.contains('difficulty breathing') ||
        symptoms.contains('severe abdominal pain') ||
        symptoms.contains('altered mental status') ||
        symptoms.contains('severe headache');
  }

  bool _isLevel3Urgent(String symptoms, PatientVitals? vitals) {
    // Moderately abnormal vitals
    if (vitals != null) {
      if (vitals.heartRate != null &&
          (vitals.heartRate! > 110 || vitals.heartRate! < 60)) {
        return true;
      }
      if (vitals.temperature != null && vitals.temperature! > 100.4) {
        return true;
      }
    }

    // Urgent symptoms requiring multiple resources
    return symptoms.contains('moderate pain') ||
        symptoms.contains('vomiting') ||
        symptoms.contains('dizziness') ||
        symptoms.contains('rash') ||
        symptoms.contains('injury');
  }

  bool _isLevel4LessUrgent(String symptoms, PatientVitals? vitals) {
    // Mild symptoms requiring one resource
    return symptoms.contains('minor pain') ||
        symptoms.contains('cold symptoms') ||
        symptoms.contains('minor cut') ||
        symptoms.contains('prescription refill');
  }

  /// Modified Early Warning Score (MEWS) - Deterioration risk assessment
  double _calculateMEWS(PatientVitals? vitals) {
    if (vitals == null) return 0.0;

    double score = 0.0;

    // Heart rate scoring
    if (vitals.heartRate != null) {
      final hr = vitals.heartRate!;
      if (hr > 130) {
        score += 3;
      } else if (hr > 110) {
        score += 2;
      } else if (hr > 100) {
        score += 1;
      } else if (hr < 40) {
        score += 3;
      } else if (hr < 50) {
        score += 2;
      }
    }

    // Respiratory rate scoring
    if (vitals.respiratoryRate != null) {
      final rr = vitals.respiratoryRate!;
      if (rr > 30) {
        score += 3;
      } else if (rr > 25) {
        score += 2;
      } else if (rr > 20) {
        score += 1;
      } else if (rr < 8) {
        score += 3;
      }
    }

    // Temperature scoring
    if (vitals.temperature != null) {
      final temp = vitals.temperature!;
      if (temp > 102.2) {
        score += 2;
      } else if (temp < 95.0) {
        score += 2;
      }
    }

    // Blood pressure scoring (systolic)
    if (vitals.bloodPressure != null) {
      final bp = _parseBloodPressure(vitals.bloodPressure!);
      if (bp != null) {
        final systolic = bp['systolic']!;
        if (systolic > 200) {
          score += 3;
        } else if (systolic > 180) {
          score += 2;
        } else if (systolic < 80) {
          score += 3;
        } else if (systolic < 90) {
          score += 2;
        }
      }
    }

    // Oxygen saturation scoring
    if (vitals.oxygenSaturation != null) {
      final spo2 = vitals.oxygenSaturation!;
      if (spo2 < 90) {
        score += 3;
      } else if (spo2 < 95) {
        score += 2;
      } else if (spo2 < 98) {
        score += 1;
      }
    }

    return score;
  }

  /// Analyze symptoms using clinical pattern recognition
  double _analyzeSymptoms(String symptoms) {
    final symptomsLower = symptoms.toLowerCase();
    double severity = 0.0;

    // Critical symptoms (8-10 severity)
    if (symptomsLower.contains('chest pain')) severity = max(severity, 8.0);
    if (symptomsLower.contains('difficulty breathing')) {
      severity = max(severity, 8.5);
    }
    if (symptomsLower.contains('severe pain')) severity = max(severity, 7.5);
    if (symptomsLower.contains('unresponsive')) severity = max(severity, 10.0);
    if (symptomsLower.contains('seizure')) severity = max(severity, 8.0);

    // High-priority symptoms (6-8 severity)
    if (symptomsLower.contains('severe headache')) {
      severity = max(severity, 7.0);
    }
    if (symptomsLower.contains('abdominal pain')) severity = max(severity, 6.5);
    if (symptomsLower.contains('vomiting blood')) severity = max(severity, 8.0);
    if (symptomsLower.contains('confusion')) severity = max(severity, 6.5);

    // Moderate symptoms (4-6 severity)
    if (symptomsLower.contains('fever')) severity = max(severity, 5.0);
    if (symptomsLower.contains('nausea')) severity = max(severity, 4.5);
    if (symptomsLower.contains('dizziness')) severity = max(severity, 5.5);
    if (symptomsLower.contains('headache')) severity = max(severity, 4.0);

    // Low-priority symptoms (1-4 severity)
    if (symptomsLower.contains('minor cut')) severity = max(severity, 2.0);
    if (symptomsLower.contains('cold')) severity = max(severity, 2.5);
    if (symptomsLower.contains('rash')) severity = max(severity, 3.0);

    // Symptom combinations increase severity
    final symptomCount = _countSymptoms(symptomsLower);
    if (symptomCount > 3) severity += 1.0;
    if (symptomCount > 5) severity += 1.5;

    return severity.clamp(0.0, 10.0);
  }

  /// Analyze vital signs for risk assessment
  double _analyzeVitals(PatientVitals? vitals) {
    if (vitals == null) return 0.0;

    double risk = 0.0;

    // Heart rate analysis
    if (vitals.heartRate != null) {
      final hr = vitals.heartRate!;
      if (hr > 150 || hr < 40) {
        risk += 3.0;
      } else if (hr > 120 || hr < 50) {
        risk += 2.0;
      } else if (hr > 100 || hr < 60) {
        risk += 1.0;
      }
    }

    // Oxygen saturation analysis
    if (vitals.oxygenSaturation != null) {
      final spo2 = vitals.oxygenSaturation!;
      if (spo2 < 88) {
        risk += 4.0;
      } else if (spo2 < 92) {
        risk += 3.0;
      } else if (spo2 < 95) {
        risk += 2.0;
      } else if (spo2 < 98) {
        risk += 1.0;
      }
    }

    // Temperature analysis
    if (vitals.temperature != null) {
      final temp = vitals.temperature!;
      if (temp > 104.0 || temp < 95.0) {
        risk += 3.0;
      } else if (temp > 102.0 || temp < 96.0) {
        risk += 2.0;
      } else if (temp > 100.4) {
        risk += 1.0;
      }
    }

    // Blood pressure analysis
    if (vitals.bloodPressure != null) {
      final bp = _parseBloodPressure(vitals.bloodPressure!);
      if (bp != null) {
        final systolic = bp['systolic']!;
        final diastolic = bp['diastolic']!;

        if (systolic > 200 || systolic < 70) {
          risk += 3.0;
        } else if (systolic > 180 || systolic < 90) {
          risk += 2.0;
        } else if (systolic > 160) {
          risk += 1.0;
        }

        if (diastolic > 120 || diastolic < 40) {
          risk += 2.0;
        } else if (diastolic > 100) {
          risk += 1.0;
        }
      }
    }

    return risk.clamp(0.0, 10.0);
  }

  /// Analyze trends in vital signs (basic implementation)
  TrendAnalysis _analyzeTrends(PatientVitals? vitals) {
    // For now, return basic trend analysis
    // In a full implementation, this would analyze historical data
    return TrendAnalysis(
      heartRateTrend: vitals?.heartRate != null ? 'stable' : 'unknown',
      oxygenTrend: vitals?.oxygenSaturation != null ? 'stable' : 'unknown',
      temperatureTrend: vitals?.temperature != null ? 'stable' : 'unknown',
      overallTrend: 'stable',
      riskOfDeterioration: vitals?.hasCriticalVitals == true ? 'high' : 'low',
    );
  }

  /// Combine all assessment scores into final severity score
  double _combineAssessments({
    required int esiLevel,
    required double mewsScore,
    required double symptomSeverity,
    required double vitalsRisk,
    Map<String, dynamic>? aiResult,
  }) {
    // Convert ESI to severity score (inverted: ESI 1 = severity 10)
    final esiSeverity = (6 - esiLevel) * 2.0; // ESI 1->10, ESI 2->8, etc.

    // Weight the different assessments
    double combinedScore = 0.0;

    if (aiResult != null && aiResult['severity_score'] != null) {
      // If AI result available, use it as primary with clinical validation
      final aiScore = (aiResult['severity_score'] as num).toDouble();
      combinedScore =
          aiScore * 0.6 + // AI gets 60% weight
          esiSeverity * 0.2 + // ESI gets 20% weight
          symptomSeverity * 0.1 + // Symptoms get 10% weight
          vitalsRisk * 0.1; // Vitals get 10% weight
    } else {
      // No AI result, use clinical algorithms
      combinedScore =
          esiSeverity * 0.4 + // ESI gets 40% weight
          symptomSeverity * 0.3 + // Symptoms get 30% weight
          vitalsRisk * 0.2 + // Vitals get 20% weight
          mewsScore * 0.1; // MEWS gets 10% weight
    }

    // Apply MEWS boost for deterioration risk
    if (mewsScore >= 5) {
      combinedScore += 1.5; // High MEWS adds urgency
    } else if (mewsScore >= 3) {
      combinedScore += 1.0;
    }

    return combinedScore.clamp(0.0, 10.0);
  }

  /// Generate clinical reasoning explanation
  String _generateClinicalReasoning({
    required int esiLevel,
    required double mewsScore,
    required double symptomSeverity,
    required double vitalsRisk,
    required TrendAnalysis trendAnalysis,
  }) {
    final reasoning = <String>[];

    // ESI reasoning
    switch (esiLevel) {
      case 1:
        reasoning.add(
          'ESI Level 1: Life-threatening condition requiring immediate intervention',
        );
        break;
      case 2:
        reasoning.add(
          'ESI Level 2: High-risk situation with potential for rapid deterioration',
        );
        break;
      case 3:
        reasoning.add(
          'ESI Level 3: Urgent condition requiring multiple medical resources',
        );
        break;
      case 4:
        reasoning.add(
          'ESI Level 4: Less urgent condition requiring single medical resource',
        );
        break;
      case 5:
        reasoning.add(
          'ESI Level 5: Non-urgent condition suitable for outpatient care',
        );
        break;
    }

    // MEWS reasoning
    if (mewsScore >= 5) {
      reasoning.add(
        'MEWS score ${mewsScore.toStringAsFixed(1)} indicates high risk of clinical deterioration',
      );
    } else if (mewsScore >= 3) {
      reasoning.add(
        'MEWS score ${mewsScore.toStringAsFixed(1)} suggests moderate risk requiring monitoring',
      );
    } else if (mewsScore > 0) {
      reasoning.add(
        'MEWS score ${mewsScore.toStringAsFixed(1)} indicates low-moderate risk',
      );
    }

    // Symptom reasoning
    if (symptomSeverity >= 7) {
      reasoning.add(
        'Symptom analysis reveals high-acuity presentation requiring urgent evaluation',
      );
    } else if (symptomSeverity >= 5) {
      reasoning.add(
        'Symptom pattern suggests moderate acuity requiring timely assessment',
      );
    }

    // Vitals reasoning
    if (vitalsRisk >= 3) {
      reasoning.add(
        'Vital signs show significant abnormalities indicating physiological instability',
      );
    } else if (vitalsRisk >= 1) {
      reasoning.add('Vital signs demonstrate mild to moderate abnormalities');
    }

    // Trend reasoning
    if (trendAnalysis.riskOfDeterioration == 'high') {
      reasoning.add(
        'Clinical trends suggest risk of deterioration requiring close monitoring',
      );
    }

    return '${reasoning.join('. ')}.';
  }

  /// Identify specific risk factors
  List<String> _identifyRiskFactors(String symptoms, PatientVitals? vitals) {
    final riskFactors = <String>[];
    final symptomsLower = symptoms.toLowerCase();

    // Symptom-based risk factors
    if (symptomsLower.contains('chest pain')) {
      riskFactors.add('Potential cardiac event');
    }
    if (symptomsLower.contains('difficulty breathing')) {
      riskFactors.add('Respiratory compromise');
    }
    if (symptomsLower.contains('severe headache')) {
      riskFactors.add('Potential neurological emergency');
    }
    if (symptomsLower.contains('abdominal pain')) {
      riskFactors.add('Potential surgical emergency');
    }

    // Vital sign risk factors
    if (vitals != null) {
      if (vitals.heartRate != null && vitals.heartRate! > 120) {
        riskFactors.add('Tachycardia (rapid heart rate)');
      }
      if (vitals.oxygenSaturation != null && vitals.oxygenSaturation! < 95) {
        riskFactors.add('Hypoxemia (low oxygen levels)');
      }
      if (vitals.temperature != null && vitals.temperature! > 101.5) {
        riskFactors.add('Hyperthermia (high fever)');
      }
      if (vitals.bloodPressure != null) {
        final bp = _parseBloodPressure(vitals.bloodPressure!);
        if (bp != null && bp['systolic']! > 160) {
          riskFactors.add('Hypertension (high blood pressure)');
        }
      }
    }

    return riskFactors;
  }

  /// Generate clinical recommendations
  List<String> _generateRecommendations(double severity, int esiLevel) {
    if (severity >= 8.0 || esiLevel <= 2) {
      return [
        'Seek immediate emergency medical attention',
        'Call 911 or go to nearest emergency room',
        'Do not drive yourself - have someone else drive or call ambulance',
        'Monitor symptoms closely and be prepared to provide medical history',
      ];
    } else if (severity >= 6.0 || esiLevel == 3) {
      return [
        'Seek urgent medical care within 1-2 hours',
        'Go to emergency room or urgent care center',
        'Monitor symptoms for any worsening',
        'Have someone accompany you if possible',
      ];
    } else if (severity >= 4.0 || esiLevel == 4) {
      return [
        'Schedule medical evaluation within 24 hours',
        'Consider urgent care or primary care appointment',
        'Monitor symptoms and seek immediate care if worsening',
        'Rest and stay hydrated',
      ];
    } else {
      return [
        'Schedule routine medical consultation',
        'Contact primary care physician for appointment',
        'Monitor symptoms and seek care if they worsen',
        'Practice self-care measures as appropriate',
      ];
    }
  }

  /// Calculate confidence in assessment
  double _calculateConfidence(PatientVitals? vitals, String symptoms) {
    double confidence = 0.5; // Base confidence

    // Increase confidence with more data
    if (vitals != null) {
      confidence += 0.1;
      if (vitals.heartRate != null) confidence += 0.1;
      if (vitals.oxygenSaturation != null) confidence += 0.1;
      if (vitals.bloodPressure != null) confidence += 0.1;
      if (vitals.temperature != null) confidence += 0.1;
    }

    // Increase confidence with detailed symptoms
    if (symptoms.length > 50) confidence += 0.1;
    if (symptoms.length > 100) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Helper methods
  Map<String, int>? _parseBloodPressure(String bp) {
    final parts = bp.split('/');
    if (parts.length != 2) return null;

    final systolic = int.tryParse(parts[0]);
    final diastolic = int.tryParse(parts[1]);

    if (systolic == null || diastolic == null) return null;

    return {'systolic': systolic, 'diastolic': diastolic};
  }

  int _countSymptoms(String symptoms) {
    final commonSymptoms = [
      'pain',
      'fever',
      'nausea',
      'vomiting',
      'dizziness',
      'headache',
      'breathing',
      'chest',
      'abdominal',
      'rash',
      'swelling',
      'bleeding',
    ];

    return commonSymptoms.where((symptom) => symptoms.contains(symptom)).length;
  }
}

/// Result of medical algorithm analysis
class MedicalAssessmentResult {
  final double finalScore;
  final int esiLevel;
  final double mewsScore;
  final double symptomSeverity;
  final double vitalsRisk;
  final TrendAnalysis trendAnalysis;
  final String clinicalReasoning;
  final List<String> riskFactors;
  final List<String> recommendations;
  final double confidence;

  MedicalAssessmentResult({
    required this.finalScore,
    required this.esiLevel,
    required this.mewsScore,
    required this.symptomSeverity,
    required this.vitalsRisk,
    required this.trendAnalysis,
    required this.clinicalReasoning,
    required this.riskFactors,
    required this.recommendations,
    required this.confidence,
  });
}

/// Trend analysis result
class TrendAnalysis {
  final String heartRateTrend;
  final String oxygenTrend;
  final String temperatureTrend;
  final String overallTrend;
  final String riskOfDeterioration;

  TrendAnalysis({
    required this.heartRateTrend,
    required this.oxygenTrend,
    required this.temperatureTrend,
    required this.overallTrend,
    required this.riskOfDeterioration,
  });
}
