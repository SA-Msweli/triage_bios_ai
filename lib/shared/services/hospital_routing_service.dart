import 'dart:math' as math;
import 'package:logger/logger.dart';
import 'fhir_service.dart';
import '../models/hospital_capacity.dart';

/// Service for optimizing hospital routing based on real-time capacity and patient needs
class HospitalRoutingService {
  static final HospitalRoutingService _instance =
      HospitalRoutingService._internal();
  factory HospitalRoutingService() => _instance;
  HospitalRoutingService._internal();

  final Logger _logger = Logger();
  final FhirService _fhirService = FhirService();

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

      // Get hospital capacities from FHIR endpoints
      final hospitals = await _fhirService.getHospitalCapacities(
        latitude: patientLatitude,
        longitude: patientLongitude,
        radiusKm: maxDistanceKm,
      );

      if (hospitals.isEmpty) {
        throw RoutingException(
          'No hospitals found within ${maxDistanceKm}km radius',
        );
      }

      // Score each hospital based on multiple factors
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

      // Sort by score (highest first)
      scoredHospitals.sort(
        (a, b) => b.score.totalScore.compareTo(a.score.totalScore),
      );

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

  /// Calculate comprehensive hospital score based on multiple factors
  Future<HospitalScore> _calculateHospitalScore({
    required HospitalCapacity hospital,
    required double patientLatitude,
    required double patientLongitude,
    required double severityScore,
    required List<String> specializations,
  }) async {
    final distance = hospital.distanceKm ?? 10.0;
    final distanceScore = math.exp(-distance / 15.0);
    final capacityScore = _calculateCapacityScore(hospital);
    final severityMatchScore = _calculateSeverityScore(hospital, severityScore);
    final specializationScore = 0.8;
    final waitTimeScore = 0.7;
    final outcomeScore = 0.8;

    final totalScore =
        (distanceScore * 0.25 +
        capacityScore * 0.20 +
        severityMatchScore * 0.20 +
        specializationScore * 0.15 +
        waitTimeScore * 0.10 +
        outcomeScore * 0.10);

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

    if (occupancyRate < 0.7) {
      return 1.0;
    } else if (occupancyRate < 0.85) {
      return 0.8;
    } else if (occupancyRate < 0.95) {
      return 0.4;
    } else {
      return 0.1;
    }
  }

  double _calculateSeverityScore(
    HospitalCapacity hospital,
    double patientSeverity,
  ) {
    if (patientSeverity >= 8.0) {
      return hospital.hasEmergencyCapacity ? 1.0 : 0.3;
    } else if (patientSeverity >= 6.0) {
      return hospital.hasEmergencyCapacity ? 0.9 : 0.7;
    } else {
      return 0.8;
    }
  }

  RoutingMetrics _calculateRoutingMetrics(ScoredHospital scoredHospital) {
    final hospital = scoredHospital.hospital;
    final score = scoredHospital.score;

    final travelTimeMinutes = (score.distance / 40.0 * 60).round();
    final occupancyRate = hospital.occupancyRate;
    final waitTimeMinutes = (15 * (1 + occupancyRate * 2)).round();

    final treatmentStartTime = DateTime.now().add(
      Duration(minutes: travelTimeMinutes + waitTimeMinutes),
    );

    return RoutingMetrics(
      travelTimeMinutes: travelTimeMinutes,
      estimatedWaitTimeMinutes: waitTimeMinutes,
      treatmentStartTime: treatmentStartTime,
      outcomeConfidence: score.outcomeScore,
      distanceKm: score.distance,
    );
  }

  /// Optimize hospital list by travel time and capacity
  Future<List<HospitalCapacity>> optimizeHospitalRoutes(
    List<HospitalCapacity> hospitals, {
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      _logger.i('Optimizing hospital routes for ${hospitals.length} hospitals');

      // Calculate distance and travel time for each hospital
      final hospitalsWithDistance = hospitals.map((hospital) {
        final distance = _calculateDistance(
          userLatitude,
          userLongitude,
          hospital.latitude ?? 0.0,
          hospital.longitude ?? 0.0,
        );

        // Estimate travel time (assuming average speed of 40 km/h in city)
        final travelTimeMinutes = (distance / 40.0) * 60;

        return {
          'hospital': hospital,
          'distance': distance,
          'travelTime': travelTimeMinutes,
          'score': _calculateOptimizationScore(
            hospital,
            distance,
            travelTimeMinutes,
          ),
        };
      }).toList();

      // Sort by optimization score (lower is better)
      hospitalsWithDistance.sort(
        (a, b) => (a['score'] as double).compareTo(b['score'] as double),
      );

      // Return optimized list
      return hospitalsWithDistance
          .map((item) => item['hospital'] as HospitalCapacity)
          .toList();
    } catch (e) {
      _logger.e('Failed to optimize hospital routes: $e');
      return hospitals; // Return original list if optimization fails
    }
  }

  /// Calculate optimization score considering distance, capacity, and urgency
  double _calculateOptimizationScore(
    HospitalCapacity hospital,
    double distance,
    double travelTime,
  ) {
    // Base score from travel time (minutes)
    double score = travelTime;

    // Penalty for low availability (higher occupancy = higher score)
    final occupancyPenalty =
        hospital.occupancyRate * 30; // Up to 30 minutes penalty
    score += occupancyPenalty;

    // Bonus for emergency bed availability
    if (hospital.emergencyBeds > 0) {
      score -= 10; // 10 minute bonus
    }

    // Bonus for ICU bed availability
    if (hospital.icuBeds > 0) {
      score -= 5; // 5 minute bonus
    }

    return score;
  }

  /// Initialize the routing service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing hospital routing service');
      // Initialize any required services or configurations
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Simulate initialization
      _logger.i('Hospital routing service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize hospital routing service: $e');
      rethrow;
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

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

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

// Data models
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
