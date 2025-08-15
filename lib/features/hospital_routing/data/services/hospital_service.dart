import 'package:logger/logger.dart';
import '../../domain/entities/hospital.dart';
import '../../../../shared/models/hospital_capacity.dart';

class HospitalService {
  static final HospitalService _instance = HospitalService._internal();
  factory HospitalService() => _instance;
  HospitalService._internal();

  final Logger _logger = Logger();

  /// Get nearby hospitals within specified radius
  Future<List<Hospital>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusMiles = 25.0,
  }) async {
    _logger.i(
      'Fetching hospitals near ($latitude, $longitude) within $radiusMiles miles',
    );

    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock hospital data for demo
    final allHospitals = _getMockHospitals();

    // Filter by distance and sort by proximity
    final nearbyHospitals = allHospitals
        .where(
          (hospital) =>
              hospital.distanceFrom(latitude, longitude) <= radiusMiles,
        )
        .toList();

    nearbyHospitals.sort(
      (a, b) => a
          .distanceFrom(latitude, longitude)
          .compareTo(b.distanceFrom(latitude, longitude)),
    );

    _logger.i('Found ${nearbyHospitals.length} hospitals within radius');
    return nearbyHospitals;
  }

  /// Get optimal hospital recommendation based on severity and preferences
  Future<Hospital?> getOptimalHospital({
    required double latitude,
    required double longitude,
    required double severityScore,
    String? requiredSpecialization,
    double maxDistance = 50.0,
  }) async {
    _logger.i('Finding optimal hospital for severity $severityScore');

    final nearbyHospitals = await getNearbyHospitals(
      latitude: latitude,
      longitude: longitude,
      radiusMiles: maxDistance,
    );

    if (nearbyHospitals.isEmpty) return null;

    // Filter by specialization if required
    var candidates = nearbyHospitals;
    if (requiredSpecialization != null) {
      candidates = candidates
          .where((h) => h.hasSpecialization(requiredSpecialization))
          .toList();
    }

    if (candidates.isEmpty) {
      // Fallback to all hospitals if no specialized ones found
      candidates = nearbyHospitals;
    }

    // Score hospitals based on multiple factors
    candidates.sort((a, b) {
      final scoreA = _calculateHospitalScore(
        a,
        latitude,
        longitude,
        severityScore,
      );
      final scoreB = _calculateHospitalScore(
        b,
        latitude,
        longitude,
        severityScore,
      );
      return scoreB.compareTo(scoreA); // Higher score is better
    });

    final optimal = candidates.first;
    _logger.i('Optimal hospital: ${optimal.name}');
    return optimal;
  }

  double _calculateHospitalScore(
    Hospital hospital,
    double lat,
    double lng,
    double severity,
  ) {
    double score = 100.0; // Base score

    // Distance penalty (closer is better)
    final distance = hospital.distanceFrom(lat, lng);
    score -= distance * 2; // 2 points per mile

    // Capacity bonus (more available beds is better)
    if (hospital.capacity.availableBeds > 10) {
      score += 20;
    } else if (hospital.capacity.availableBeds > 5) {
      score += 10;
    } else if (hospital.capacity.availableBeds == 0) {
      score -= 50; // Heavy penalty for no beds
    }

    // Trauma level bonus for high severity
    if (severity >= 8.0) {
      score +=
          hospital.traumaLevel * 10; // Higher trauma level for critical cases
    }

    // Performance bonus
    score += hospital.performance.treatmentSuccessRate * 20;
    score -=
        hospital.performance.averageWaitTime * 0.1; // Penalty for long waits

    // Occupancy penalty
    if (hospital.capacity.occupancyRate > 0.9) {
      score -= 30; // Heavy penalty for overcrowded hospitals
    } else if (hospital.capacity.occupancyRate > 0.8) {
      score -= 15;
    }

    return score;
  }

  List<Hospital> _getMockHospitals() {
    final now = DateTime.now();

    return [
      Hospital(
        id: 'hosp_001',
        name: 'City General Hospital',
        latitude: 40.7589, // NYC coordinates for demo
        longitude: -73.9851,
        address: '123 Medical Center Dr, New York, NY 10001',
        phoneNumber: '(555) 123-4567',
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'trauma', 'neurology'],
        certifications: ['Joint Commission', 'Magnet', 'Trauma Center Level I'],
        capacity: HospitalCapacity.fromBasic(
          id: 'hosp_001',
          name: 'City General Hospital',
          totalBeds: 450,
          availableBeds: 23,
          icuBeds: 8,
          emergencyBeds: 12,
          staffOnDuty: 85,
          lastUpdated: now.subtract(const Duration(minutes: 3)),
        ),
        performance: const HospitalPerformance(
          averageWaitTime: 45.0,
          patientSatisfaction: 4.2,
          treatmentSuccessRate: 0.94,
          monthlyVolume: 2800,
        ),
      ),

      Hospital(
        id: 'hosp_002',
        name: 'Metropolitan Medical Center',
        latitude: 40.7505,
        longitude: -73.9934,
        address: '456 Healthcare Ave, New York, NY 10002',
        phoneNumber: '(555) 234-5678',
        traumaLevel: 2,
        specializations: ['emergency', 'orthopedics', 'pediatrics'],
        certifications: ['Joint Commission', 'Baby-Friendly'],
        capacity: HospitalCapacity.fromBasic(
          id: 'hosp_002',
          name: 'Metropolitan Medical Center',
          totalBeds: 320,
          availableBeds: 45,
          icuBeds: 12,
          emergencyBeds: 18,
          staffOnDuty: 62,
          lastUpdated: now.subtract(const Duration(minutes: 1)),
        ),
        performance: const HospitalPerformance(
          averageWaitTime: 32.0,
          patientSatisfaction: 4.5,
          treatmentSuccessRate: 0.91,
          monthlyVolume: 1950,
        ),
      ),

      Hospital(
        id: 'hosp_003',
        name: 'St. Mary\'s Emergency Hospital',
        latitude: 40.7614,
        longitude: -73.9776,
        address: '789 Emergency Blvd, New York, NY 10003',
        phoneNumber: '(555) 345-6789',
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'stroke', 'trauma'],
        certifications: ['Joint Commission', 'Comprehensive Stroke Center'],
        capacity: HospitalCapacity.fromBasic(
          id: 'hosp_003',
          name: 'St. Mary\'s Emergency Hospital',
          totalBeds: 280,
          availableBeds: 8,
          icuBeds: 3,
          emergencyBeds: 6,
          staffOnDuty: 48,
          lastUpdated: now.subtract(const Duration(minutes: 5)),
        ),
        performance: const HospitalPerformance(
          averageWaitTime: 28.0,
          patientSatisfaction: 4.7,
          treatmentSuccessRate: 0.96,
          monthlyVolume: 2200,
        ),
      ),

      Hospital(
        id: 'hosp_004',
        name: 'University Hospital',
        latitude: 40.7282,
        longitude: -73.9942,
        address: '321 University Way, New York, NY 10004',
        phoneNumber: '(555) 456-7890',
        traumaLevel: 1,
        specializations: ['emergency', 'research', 'oncology', 'neurosurgery'],
        certifications: ['Joint Commission', 'Magnet', 'NCI Cancer Center'],
        capacity: HospitalCapacity.fromBasic(
          id: 'hosp_004',
          name: 'University Hospital',
          totalBeds: 520,
          availableBeds: 67,
          icuBeds: 15,
          emergencyBeds: 25,
          staffOnDuty: 95,
          lastUpdated: now.subtract(const Duration(minutes: 2)),
        ),
        performance: const HospitalPerformance(
          averageWaitTime: 52.0,
          patientSatisfaction: 4.1,
          treatmentSuccessRate: 0.93,
          monthlyVolume: 3100,
        ),
      ),

      Hospital(
        id: 'hosp_005',
        name: 'Riverside Community Hospital',
        latitude: 40.7831,
        longitude: -73.9712,
        address: '654 Riverside Dr, New York, NY 10005',
        phoneNumber: '(555) 567-8901',
        traumaLevel: 3,
        specializations: ['emergency', 'family medicine', 'internal medicine'],
        certifications: ['Joint Commission'],
        capacity: HospitalCapacity.fromBasic(
          id: 'hosp_005',
          name: 'Riverside Community Hospital',
          totalBeds: 180,
          availableBeds: 32,
          icuBeds: 6,
          emergencyBeds: 14,
          staffOnDuty: 35,
          lastUpdated: now.subtract(const Duration(minutes: 7)),
        ),
        performance: const HospitalPerformance(
          averageWaitTime: 25.0,
          patientSatisfaction: 4.3,
          treatmentSuccessRate: 0.89,
          monthlyVolume: 1200,
        ),
        fhirEndpoint: 'https://api.riverside.org/fhir/R4',
      ),
    ];
  }
}
