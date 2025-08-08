import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class PatientQueueItem extends Equatable {
  final String id;
  final String name;
  final int age;
  final double severityScore;
  final String urgencyLevel;
  final String symptoms;
  final Map<String, dynamic> vitals;
  final DateTime arrivalTime;
  final int estimatedWaitTime;
  final String triageNurse;
  final String deviceSource;

  const PatientQueueItem({
    required this.id,
    required this.name,
    required this.age,
    required this.severityScore,
    required this.urgencyLevel,
    required this.symptoms,
    required this.vitals,
    required this.arrivalTime,
    required this.estimatedWaitTime,
    required this.triageNurse,
    required this.deviceSource,
  });

  bool get isCritical => severityScore >= 8.0;
  bool get isUrgent => severityScore >= 6.0;

  Color get urgencyColor {
    switch (urgencyLevel) {
      case 'CRITICAL':
        return const Color(0xFFD32F2F); // Red
      case 'URGENT':
        return const Color(0xFFFF9800); // Orange
      case 'STANDARD':
        return const Color(0xFF1976D2); // Blue
      case 'NON_URGENT':
        return const Color(0xFF388E3C); // Green
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  String get waitTimeDisplay {
    if (estimatedWaitTime == 0) {
      return 'Immediate';
    } else if (estimatedWaitTime < 60) {
      return '${estimatedWaitTime}m';
    } else {
      final hours = estimatedWaitTime ~/ 60;
      final minutes = estimatedWaitTime % 60;
      return '${hours}h ${minutes}m';
    }
  }

  String get arrivalTimeDisplay {
    final now = DateTime.now();
    final difference = now.difference(arrivalTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${arrivalTime.day}/${arrivalTime.month}';
    }
  }

  bool get hasAbnormalVitals {
    final heartRate = vitals['heartRate'] as int?;
    final oxygenSaturation = vitals['oxygenSaturation'] as double?;
    final temperature = vitals['temperature'] as double?;

    if (heartRate != null && (heartRate > 100 || heartRate < 60)) return true;
    if (oxygenSaturation != null && oxygenSaturation < 95.0) return true;
    if (temperature != null && temperature > 100.4) return true;

    return false;
  }

  PatientQueueItem copyWith({
    String? id,
    String? name,
    int? age,
    double? severityScore,
    String? urgencyLevel,
    String? symptoms,
    Map<String, dynamic>? vitals,
    DateTime? arrivalTime,
    int? estimatedWaitTime,
    String? triageNurse,
    String? deviceSource,
  }) {
    return PatientQueueItem(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      severityScore: severityScore ?? this.severityScore,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      symptoms: symptoms ?? this.symptoms,
      vitals: vitals ?? this.vitals,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      estimatedWaitTime: estimatedWaitTime ?? this.estimatedWaitTime,
      triageNurse: triageNurse ?? this.triageNurse,
      deviceSource: deviceSource ?? this.deviceSource,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    age,
    severityScore,
    urgencyLevel,
    symptoms,
    vitals,
    arrivalTime,
    estimatedWaitTime,
    triageNurse,
    deviceSource,
  ];
}
