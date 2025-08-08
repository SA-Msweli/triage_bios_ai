import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class HospitalCapacity extends Equatable {
  final int totalBeds;
  final int availableBeds;
  final int icuBeds;
  final int emergencyBeds;
  final int staffOnDuty;
  final int patientsInQueue;
  final double averageWaitTime;
  final DateTime lastUpdated;

  const HospitalCapacity({
    required this.totalBeds,
    required this.availableBeds,
    required this.icuBeds,
    required this.emergencyBeds,
    required this.staffOnDuty,
    required this.patientsInQueue,
    required this.averageWaitTime,
    required this.lastUpdated,
  });

  factory HospitalCapacity.initial() {
    return HospitalCapacity(
      totalBeds: 450,
      availableBeds: 23,
      icuBeds: 8,
      emergencyBeds: 12,
      staffOnDuty: 85,
      patientsInQueue: 0,
      averageWaitTime: 0.0,
      lastUpdated: DateTime.now(),
    );
  }

  double get occupancyRate =>
      totalBeds > 0 ? (totalBeds - availableBeds) / totalBeds : 1.0;

  double get capacityPercentage => occupancyRate * 100;

  bool get isNearCapacity => occupancyRate > 0.85;
  bool get isAtCapacity => occupancyRate > 0.95;

  String get capacityStatus {
    if (isAtCapacity) return 'At Capacity';
    if (isNearCapacity) return 'Near Capacity';
    return 'Available';
  }

  Color get capacityColor {
    if (isAtCapacity) return const Color(0xFFD32F2F); // Red
    if (isNearCapacity) return const Color(0xFFFF9800); // Orange
    return const Color(0xFF388E3C); // Green
  }

  bool get isDataFresh => DateTime.now().difference(lastUpdated).inMinutes < 5;

  HospitalCapacity copyWith({
    int? totalBeds,
    int? availableBeds,
    int? icuBeds,
    int? emergencyBeds,
    int? staffOnDuty,
    int? patientsInQueue,
    double? averageWaitTime,
    DateTime? lastUpdated,
  }) {
    return HospitalCapacity(
      totalBeds: totalBeds ?? this.totalBeds,
      availableBeds: availableBeds ?? this.availableBeds,
      icuBeds: icuBeds ?? this.icuBeds,
      emergencyBeds: emergencyBeds ?? this.emergencyBeds,
      staffOnDuty: staffOnDuty ?? this.staffOnDuty,
      patientsInQueue: patientsInQueue ?? this.patientsInQueue,
      averageWaitTime: averageWaitTime ?? this.averageWaitTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object> get props => [
    totalBeds,
    availableBeds,
    icuBeds,
    emergencyBeds,
    staffOnDuty,
    patientsInQueue,
    averageWaitTime,
    lastUpdated,
  ];
}
