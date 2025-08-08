import 'dart:math' as math;
import 'package:equatable/equatable.dart';

class Hospital extends Equatable {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String phoneNumber;
  final int traumaLevel;
  final List<String> specializations;
  final List<String> certifications;
  final HospitalCapacity capacity;
  final HospitalPerformance performance;
  final String? fhirEndpoint;

  const Hospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phoneNumber,
    required this.traumaLevel,
    required this.specializations,
    required this.certifications,
    required this.capacity,
    required this.performance,
    this.fhirEndpoint,
  });

  double distanceFrom(double lat, double lng) {
    // Haversine formula for distance calculation
    const double earthRadius = 3959; // miles
    final double dLat = _toRadians(latitude - lat);
    final double dLng = _toRadians(longitude - lng);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat) * math.cos(latitude) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  bool hasSpecialization(String specialization) {
    return specializations.contains(specialization.toLowerCase());
  }

  bool get isAvailable => capacity.availableBeds > 0;
  bool get isNearCapacity => capacity.occupancyRate > 0.85;

  @override
  List<Object?> get props => [
        id,
        name,
        latitude,
        longitude,
        address,
        phoneNumber,
        traumaLevel,
        specializations,
        certifications,
        capacity,
        performance,
        fhirEndpoint,
      ];
}

class HospitalCapacity extends Equatable {
  final int totalBeds;
  final int availableBeds;
  final int icuBeds;
  final int emergencyBeds;
  final int staffOnDuty;
  final DateTime lastUpdated;

  const HospitalCapacity({
    required this.totalBeds,
    required this.availableBeds,
    required this.icuBeds,
    required this.emergencyBeds,
    required this.staffOnDuty,
    required this.lastUpdated,
  });

  double get occupancyRate => 
      totalBeds > 0 ? (totalBeds - availableBeds) / totalBeds : 1.0;

  bool get isDataFresh => 
      DateTime.now().difference(lastUpdated).inMinutes < 10;

  @override
  List<Object> get props => [
        totalBeds,
        availableBeds,
        icuBeds,
        emergencyBeds,
        staffOnDuty,
        lastUpdated,
      ];
}

class HospitalPerformance extends Equatable {
  final double averageWaitTime; // minutes
  final double patientSatisfaction; // 0-5 scale
  final double treatmentSuccessRate; // 0-1 scale
  final int monthlyVolume;

  const HospitalPerformance({
    required this.averageWaitTime,
    required this.patientSatisfaction,
    required this.treatmentSuccessRate,
    required this.monthlyVolume,
  });

  @override
  List<Object> get props => [
        averageWaitTime,
        patientSatisfaction,
        treatmentSuccessRate,
        monthlyVolume,
      ];
}