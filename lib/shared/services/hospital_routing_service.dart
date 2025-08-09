import 'dart:math' as math;
import 'package:logger/logger.dart';
import 'fhir_service.dart';

/// Service for optimizing hospital routing based on real-time capacity and patient needs
class HospitalRoutingService {
  static final HospitalRoutingService _instance = HospitalRoutingService._internal();
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
      _logger.i('Finding optimal hospital for patient at ($patientLatitude, $patientLongitude)');

      // Get hospital capacities from FHIR endpoints
      final hospitals = await _fhirService.getHospitalCapacities(
        latitude: patientLatitude,
        longitude: patientLongitude,
        radiusKm: maxDistanceKm,
      );

      if (hospitals.isEmpty) {
        throw RoutingException('No hospitals found within ${maxDistanceKm}km radius');
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
        
        scoredHospitals.add(ScoredHospital(
          hospital: hospital,
          score: score,
        ));
      }

      // Sort by score (highest first)
      scoredHospitals.sort((a, b) => b.score.totalScore.compareTo(a.score.totalScore));

      final optimalHospital = scoredHospitals.first;
      
      _logger.i('Optimal hospital selected: ${optimalHospital.hospital.name}');

      return HospitalRoutingResult(
        recommendedHospital: optimalHospital.hospital,
        score: optimalHospital.score,
        alternativeHospitals: scoredHospitals.skip(1).take(2).map((sh) => sh.hospital).toList(),
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

    final totalScore = (
      distanceScore * 0.25 +
      capacityScore * 0.20 +
      severityMatchScore * 0.20 +
      specializationScore * 0.15 +
      waitTimeScore * 0.10 +
      outcomeScore * 0.10
    );

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

  double _calculateSeverityScore(HospitalCapacity hospital, double patientSeverity) {
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

  ScoredHospital({
    required this.hospital,
    required this.score,
  });
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