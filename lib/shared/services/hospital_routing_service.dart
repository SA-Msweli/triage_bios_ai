import 'dart:math' as math;
import 'package:logger/logger.dart';
import '../models/hospital_capacity.dart';

/// Service for optimizing hospital routing based on real-time capacity and patient needs
class HospitalRoutingService {
  static final HospitalRoutingService _instance =
      HospitalRoutingService._internal();
  factory HospitalRoutingService() => _instance;
  HospitalRoutingService._internal();

  final Logger _logger = Logger();

  Future<List<HospitalCapacity>> _getMockHospitalCapacities({
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Create a list of mock hospitals
    return [
      HospitalCapacity(
        id: 'mock_hospital_1',
        name: 'General Mock Hospital',
        latitude: 40.7128, // Example: NYC area
        longitude: -74.0060,
        totalBeds: 200,
        availableBeds: 50,
        icuBeds: 10,
        emergencyBeds: 20,
        staffOnDuty: 70,
        averageWaitTime: 45, // minutes
        // Removed: specializations: ['general', 'cardiology', 'pediatrics'],
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      HospitalCapacity(
        id: 'mock_hospital_2',
        name: 'City Central Mock Clinic',
        latitude: 40.7580, // Example: NYC area
        longitude: -73.9855,
        totalBeds: 150,
        availableBeds: 20,
        icuBeds: 5,
        emergencyBeds: 10,
        staffOnDuty: 45,
        averageWaitTime: 90, // minutes
        // Removed: specializations: ['general', 'orthopedics'],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      HospitalCapacity.fromBasic( // Using the .fromBasic factory
        id: 'mock_hospital_3',
        name: 'Suburban Mock Medical Center',
        totalBeds: 300,
        availableBeds: 120,
        icuBeds: 25,
        emergencyBeds: 30,
        staffOnDuty: 90,
        // Removed: averageWaitTime: 30, (fromBasic doesn't take it, defaults to 0)
        // Removed: specializations: ['general', 'trauma', 'neurology'],
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
        latitude: 40.6892, // Example: NYC area
        longitude: -74.0445,
      ),
       HospitalCapacity(
        id: 'mock_hospital_4',
        name: 'Rural Health Mock Facility',
        latitude: 40.8000, // Example: Further out
        longitude: -74.1000,
        totalBeds: 80,
        availableBeds: 30,
        icuBeds: 4,
        emergencyBeds: 8,
        staffOnDuty: 25,
        averageWaitTime: 20,
        // Removed: specializations: ['general', 'family_medicine'],
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ];
  }

  // Public method for triage_portal_page.dart or other uses
  Future<List<HospitalCapacity>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    _logger.i('Fetching nearby mock hospitals for ($latitude, $longitude) within ${radiusKm}km');
    
    // Get all mock hospitals
    final allMockHospitals = await _getMockHospitalCapacities(
      latitude: latitude, 
      longitude: longitude, 
      radiusKm: radiusKm
    );
    
    // Calculate distance for each and filter
    final nearbyHospitals = <HospitalCapacity>[];
    for (final hospital in allMockHospitals) {
      final double dist = _calculateDistance(
        latitude, 
        longitude, 
        hospital.latitude ?? 0.0, 
        hospital.longitude ?? 0.0
      );
      // Only include if within radius and update distance
      if (dist <= radiusKm) {
        nearbyHospitals.add(hospital.copyWith(distanceKm: dist));
      }
    }
    
    _logger.i('Found ${nearbyHospitals.length} mock hospitals within ${radiusKm}km.');
    return nearbyHospitals;
  }

  /// Find optimal hospital for patient based on severity, location, and real-time capacity
  Future<HospitalRoutingResult> findOptimalHospital({
    required double patientLatitude,
    required double patientLongitude,
    required double severityScore,
    required List<String> specializations,
    double maxDistanceKm = 50.0,
  }) async {
    try {
      _logger.i(
        'Finding optimal hospital for patient at ($patientLatitude, $patientLongitude)',
      );

      final hospitalsFromMock = await _getMockHospitalCapacities(
        latitude: patientLatitude,
        longitude: patientLongitude,
        radiusKm: maxDistanceKm,
      );

      if (hospitalsFromMock.isEmpty) {
        throw RoutingException(
          'No mock hospitals available.',
        );
      }
      
      final hospitals = hospitalsFromMock.map((h) {
        final dist = _calculateDistance(patientLatitude, patientLongitude, h.latitude ?? 0.0, h.longitude ?? 0.0);
        return h.copyWith(distanceKm: dist);
      }).where((h) => h.distanceKm! <= maxDistanceKm).toList();

      if (hospitals.isEmpty) {
        throw RoutingException(
          'No mock hospitals found within ${maxDistanceKm}km radius after filtering.',
        );
      }

      final scoredHospitals = <ScoredHospital>[];
      for (final hospital in hospitals) {
        final score = await _calculateHospitalScore(
          hospital: hospital,
          patientLatitude: patientLatitude,
          patientLongitude: patientLongitude,
          severityScore: severityScore,
          specializations: specializations,
        );
        scoredHospitals.add(ScoredHospital(hospital: hospital, score: score));
      }

      scoredHospitals.sort(
        (a, b) => b.score.totalScore.compareTo(a.score.totalScore),
      );

      if (scoredHospitals.isEmpty) {
        throw RoutingException(
          'No suitable hospital found after scoring.',
        );
      }

      final optimalHospital = scoredHospitals.first;
      _logger.i('Optimal hospital selected: ${optimalHospital.hospital.name}');

      return HospitalRoutingResult(
        recommendedHospital: optimalHospital.hospital,
        score: optimalHospital.score,
        alternativeHospitals: scoredHospitals
            .skip(1)
            .take(2)
            .map((sh) => sh.hospital)
            .toList(),
        routingMetrics: _calculateRoutingMetrics(optimalHospital),
      );
    } catch (e) {
      _logger.e('Error finding optimal hospital: $e');
      rethrow;
    }
  }

  Future<HospitalScore> _calculateHospitalScore({
    required HospitalCapacity hospital,
    required double patientLatitude,
    required double patientLongitude,
    required double severityScore,
    required List<String> specializations, // Patient's required specializations
  }) async {
    final distance = hospital.distanceKm ?? _calculateDistance(patientLatitude, patientLongitude, hospital.latitude ?? 0, hospital.longitude ?? 0);
    
    final distanceScore = math.exp(-distance / 15.0);
    final capacityScore = _calculateCapacityScore(hospital);
    final severityMatchScore = _calculateSeverityScore(hospital, severityScore);
    
    // Simplified Specialization scoring logic as HospitalCapacity model doesn't store specializations
    double specializationScore = 0.3; // Base score if specific specializations are needed but hospital data is limited
    if (specializations.isEmpty || specializations.any((s) => s.toLowerCase() == 'general')) {
      specializationScore = 0.7; // Higher if general care is acceptable or no specifics needed
    } else {
      // Heuristic: Check if hospital name contains any requested specialization keywords
      // This is a basic mock approach.
      if (specializations.any((reqSpec) => hospital.name.toLowerCase().contains(reqSpec.toLowerCase()))) {
        specializationScore = 0.8; // Better score if name matches a keyword
      }
    }

    final waitTimeScore = math.exp(-(hospital.averageWaitTime / 60.0));
    final outcomeScore = 0.8; // Placeholder

    final totalScore =
        (distanceScore * 0.25) +
        (capacityScore * 0.20) +
        (severityMatchScore * 0.20) +
        (specializationScore * 0.15) +
        (waitTimeScore * 0.10) +
        (outcomeScore * 0.10);

    return HospitalScore(
      totalScore: totalScore,
      distanceScore: distanceScore,
      capacityScore: capacityScore,
      severityMatchScore: severityMatchScore,
      specializationScore: specializationScore,
      waitTimeScore: waitTimeScore,
      outcomeScore: outcomeScore,
      distance: distance,
    );
  }

  double _calculateCapacityScore(HospitalCapacity hospital) {
    final occupancyRate = hospital.occupancyRate;
    if (occupancyRate < 0.7) return 1.0;
    if (occupancyRate < 0.85) return 0.8;
    if (occupancyRate < 0.95) return 0.4;
    return 0.1;
  }

  double _calculateSeverityScore(
    HospitalCapacity hospital,
    double patientSeverity,
  ) {
    if (patientSeverity >= 8.0) {
      return hospital.hasEmergencyCapacity && hospital.emergencyBeds > 0 ? 1.0 : 0.2;
    } else if (patientSeverity >= 5.0) {
      return hospital.hasEmergencyCapacity ? 0.9 : 0.5;
    } else {
      return 0.7;
    }
  }

  RoutingMetrics _calculateRoutingMetrics(ScoredHospital scoredHospital) {
    final hospital = scoredHospital.hospital;
    final score = scoredHospital.score;
    final currentDistanceKm = hospital.distanceKm ?? score.distance;
    final travelTimeMinutes = (currentDistanceKm / 40.0 * 60).round();
    final estimatedWaitTimeMinutes = hospital.averageWaitTime.round();
    final treatmentStartTime = DateTime.now().add(
      Duration(minutes: travelTimeMinutes + estimatedWaitTimeMinutes),
    );
    return RoutingMetrics(
      travelTimeMinutes: travelTimeMinutes,
      estimatedWaitTimeMinutes: estimatedWaitTimeMinutes,
      treatmentStartTime: treatmentStartTime,
      outcomeConfidence: score.outcomeScore,
      distanceKm: currentDistanceKm,
    );
  }

  Future<List<HospitalCapacity>> optimizeHospitalRoutes(
    List<HospitalCapacity> hospitals, {
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      _logger.i('Optimizing hospital routes for ${hospitals.length} hospitals');
      final hospitalsWithCalculatedInfo = hospitals.map((hospital) {
        final distance = _calculateDistance(
          userLatitude,
          userLongitude,
          hospital.latitude ?? 0.0,
          hospital.longitude ?? 0.0,
        );
        final travelTimeMinutes = (distance / 40.0) * 60;
        return {
          'hospital': hospital.copyWith(distanceKm: distance),
          'distance': distance,
          'travelTime': travelTimeMinutes,
          'score': _calculateOptimizationScore(
            hospital.copyWith(distanceKm: distance),
            distance,
            travelTimeMinutes,
          ),
        };
      }).toList();
      hospitalsWithCalculatedInfo.sort(
        (a, b) => (a['score'] as double).compareTo(b['score'] as double),
      );
      return hospitalsWithCalculatedInfo
          .map((item) => item['hospital'] as HospitalCapacity)
          .toList();
    } catch (e) {
      _logger.e('Failed to optimize hospital routes: $e');
      return hospitals;
    }
  }

  double _calculateOptimizationScore(
    HospitalCapacity hospital,
    double distance,
    double travelTime,
  ) {
    double score = travelTime;
    final occupancyPenalty = hospital.occupancyRate * 30;
    score += occupancyPenalty;
    if (hospital.hasEmergencyCapacity && hospital.emergencyBeds > 0) score -= 10;
    if (hospital.icuBeds > 0) score -= 5;
    return score;
  }

  Future<void> initialize() async {
    try {
      _logger.i('Initializing hospital routing service (mock mode)');
      await Future.delayed(const Duration(milliseconds: 100));
      _logger.i('Hospital routing service initialized successfully (mock mode)');
    } catch (e) {
      _logger.e('Failed to initialize hospital routing service (mock mode): $e');
      rethrow;
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

class HospitalRoutingResult {
  final HospitalCapacity recommendedHospital;
  final HospitalScore score;
  final List<HospitalCapacity> alternativeHospitals;
  final RoutingMetrics routingMetrics;
  HospitalRoutingResult({
    required this.recommendedHospital,
    required this.score,
    required this.alternativeHospitals,
    required this.routingMetrics,
  });
}

class HospitalScore {
  final double totalScore;
  final double distanceScore;
  final double capacityScore;
  final double severityMatchScore;
  final double specializationScore;
  final double waitTimeScore;
  final double outcomeScore;
  final double distance;
  HospitalScore({
    required this.totalScore,
    required this.distanceScore,
    required this.capacityScore,
    required this.severityMatchScore,
    required this.specializationScore,
    required this.waitTimeScore,
    required this.outcomeScore,
    required this.distance,
  });
}

class ScoredHospital {
  final HospitalCapacity hospital;
  final HospitalScore score;
  ScoredHospital({required this.hospital, required this.score});
}

class RoutingMetrics {
  final int travelTimeMinutes;
  final int estimatedWaitTimeMinutes;
  final DateTime treatmentStartTime;
  final double outcomeConfidence;
  final double distanceKm;
  RoutingMetrics({
    required this.travelTimeMinutes,
    required this.estimatedWaitTimeMinutes,
    required this.treatmentStartTime,
    required this.outcomeConfidence,
    required this.distanceKm,
  });
}

class RoutingException implements Exception {
  final String message;
  RoutingException(this.message);
  @override
  String toString() => 'RoutingException: $message';
}
