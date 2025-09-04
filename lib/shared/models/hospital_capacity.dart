import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'firestore/hospital_firestore.dart';
import 'firestore/hospital_capacity_firestore.dart';

/// Unified hospital capacity model used across the application
class HospitalCapacity extends Equatable {
  // Basic identification
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  // Hospital ID for Firestore compatibility
  String get hospitalId => id;

  // Capacity data
  final int totalBeds;
  final int availableBeds;
  final int icuBeds;
  final int emergencyBeds;
  final int staffOnDuty;
  final int patientsInQueue;
  final double averageWaitTime;
  final DateTime lastUpdated;

  // Optional data
  final double? distanceKm;

  const HospitalCapacity({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    required this.totalBeds,
    required this.availableBeds,
    required this.icuBeds,
    required this.emergencyBeds,
    required this.staffOnDuty,
    this.patientsInQueue = 0,
    this.averageWaitTime = 0.0,
    required this.lastUpdated,
    this.distanceKm,
  });

  factory HospitalCapacity.initial() {
    return HospitalCapacity(
      id: 'demo_hospital',
      name: 'Demo Hospital',
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

  /// Create from HospitalFirestore data
  factory HospitalCapacity.fromFirestore(HospitalFirestore hospital) {
    return HospitalCapacity(
      id: hospital.id,
      name: hospital.name,
      latitude: hospital.location.latitude,
      longitude: hospital.location.longitude,
      // Use default capacity values since HospitalFirestore doesn't have capacity data
      // In a real implementation, this would come from a separate capacity service
      totalBeds: 200,
      availableBeds: 50,
      icuBeds: 10,
      emergencyBeds: 15,
      staffOnDuty: 30,
      patientsInQueue: 5,
      averageWaitTime: 45.0,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create from HospitalCapacityFirestore data
  factory HospitalCapacity.fromFirestoreCapacity(
    HospitalCapacityFirestore capacity,
  ) {
    return HospitalCapacity(
      id: capacity.hospitalId,
      name:
          'Hospital ${capacity.hospitalId}', // Would need to fetch hospital name separately
      totalBeds: capacity.totalBeds,
      availableBeds: capacity.availableBeds,
      icuBeds: capacity.icuBeds,
      emergencyBeds: capacity.emergencyAvailable,
      staffOnDuty: capacity.staffOnDuty,
      patientsInQueue: capacity.patientsInQueue,
      averageWaitTime: capacity.averageWaitTime.toDouble(),
      lastUpdated: capacity.lastUpdated,
    );
  }

  /// Create from basic capacity data (for hospital routing)
  factory HospitalCapacity.fromBasic({
    required String id,
    required String name,
    required int totalBeds,
    required int availableBeds,
    required int icuBeds,
    required int emergencyBeds,
    required int staffOnDuty,
    required DateTime lastUpdated,
    double? latitude,
    double? longitude,
  }) {
    return HospitalCapacity(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      totalBeds: totalBeds,
      availableBeds: availableBeds,
      icuBeds: icuBeds,
      emergencyBeds: emergencyBeds,
      staffOnDuty: staffOnDuty,
      lastUpdated: lastUpdated,
    );
  }

  // Computed properties
  double get occupancyRate =>
      totalBeds > 0 ? (totalBeds - availableBeds) / totalBeds : 1.0;

  double get capacityPercentage => occupancyRate * 100;

  bool get isNearCapacity => occupancyRate > 0.85;
  bool get isAtCapacity => occupancyRate > 0.95;
  bool get hasEmergencyCapacity => emergencyBeds > 5;

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

  bool get isDataFresh => DateTime.now().difference(lastUpdated).inMinutes < 10;

  HospitalCapacity copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    int? totalBeds,
    int? availableBeds,
    int? icuBeds,
    int? emergencyBeds,
    int? staffOnDuty,
    int? patientsInQueue,
    double? averageWaitTime,
    DateTime? lastUpdated,
    double? distanceKm,
  }) {
    return HospitalCapacity(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalBeds: totalBeds ?? this.totalBeds,
      availableBeds: availableBeds ?? this.availableBeds,
      icuBeds: icuBeds ?? this.icuBeds,
      emergencyBeds: emergencyBeds ?? this.emergencyBeds,
      staffOnDuty: staffOnDuty ?? this.staffOnDuty,
      patientsInQueue: patientsInQueue ?? this.patientsInQueue,
      averageWaitTime: averageWaitTime ?? this.averageWaitTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    latitude,
    longitude,
    totalBeds,
    availableBeds,
    icuBeds,
    emergencyBeds,
    staffOnDuty,
    patientsInQueue,
    averageWaitTime,
    lastUpdated,
    distanceKm,
  ];
}
