import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Service for integrating with hospital FHIR R4 APIs
class FhirService {
  static final FhirService _instance = FhirService._internal();
  factory FhirService() => _instance;
  FhirService._internal();

  final Logger _logger = Logger();
  late final Dio _dio;

  // Test FHIR endpoints (using public test servers)
  static const String _testFhirBaseUrl = 'https://hapi.fhir.org/baseR4';

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: _testFhirBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/fhir+json',
        'Content-Type': 'application/fhir+json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.d('FHIR Request: ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('FHIR Response: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.e('FHIR Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// Get hospital capacity information from FHIR Location resources
  Future<List<HospitalCapacity>> getHospitalCapacities({
    double? latitude,
    double? longitude,
    double radiusKm = 50.0,
  }) async {
    try {
      _logger.i('Fetching hospital capacities from FHIR endpoints');

      // Search for Location resources representing hospitals
      final response = await _dio.get('/Location', queryParameters: {
        '_count': '20',
        'type': 'HOSP', // Hospital type
        '_include': 'Location:organization',
      });

      if (response.statusCode == 200) {
        final bundle = response.data as Map<String, dynamic>;
        final entries = bundle['entry'] as List<dynamic>? ?? [];

        final capacities = <HospitalCapacity>[];
        
        for (final entry in entries) {
          final resource = entry['resource'] as Map<String, dynamic>;
          if (resource['resourceType'] == 'Location') {
            final capacity = _parseLocationToCapacity(resource);
            if (capacity != null) {
              // Filter by distance if coordinates provided
              if (latitude != null && longitude != null) {
                final distance = _calculateDistance(
                  latitude, longitude,
                  capacity.latitude, capacity.longitude,
                );
                if (distance <= radiusKm) {
                  capacity.distanceKm = distance;
                  capacities.add(capacity);
                }
              } else {
                capacities.add(capacity);
              }
            }
          }
        }

        _logger.i('Retrieved ${capacities.length} hospital capacities');
        return capacities;
      } else {
        throw FhirException('Failed to fetch hospital capacities: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching hospital capacities: $e');
      // Return mock data for demo purposes
      return _getMockHospitalCapacities(latitude, longitude);
    }
  }

  /// Get real-time bed availability for a specific hospital
  Future<BedAvailability> getBedAvailability(String hospitalId) async {
    try {
      _logger.i('Fetching bed availability for hospital: $hospitalId');

      // In a real implementation, this would query specific FHIR resources
      // For now, we'll simulate with realistic data
      final response = await _dio.get('/Location/$hospitalId');

      if (response.statusCode == 200) {
        final location = response.data as Map<String, dynamic>;
        return _parseBedAvailability(location);
      } else {
        throw FhirException('Failed to fetch bed availability: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching bed availability: $e');
      // Return mock data for demo
      return _getMockBedAvailability(hospitalId);
    }
  }

  /// Submit patient triage data to hospital FHIR endpoint
  Future<String> submitTriageData({
    required String hospitalId,
    required PatientTriageData triageData,
    required bool hasConsent,
  }) async {
    try {
      if (!hasConsent) {
        throw FhirException('Cannot submit triage data without patient consent');
      }

      _logger.i('Submitting triage data to hospital: $hospitalId');

      // Create FHIR Observation resources for vitals and symptoms
      final observations = _createTriageObservations(triageData);
      
      // Create FHIR Bundle for batch submission
      final bundle = {
        'resourceType': 'Bundle',
        'type': 'batch',
        'entry': observations.map((obs) => {
          'resource': obs,
          'request': {
            'method': 'POST',
            'url': 'Observation',
          },
        }).toList(),
      };

      final response = await _dio.post('/', data: bundle);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBundle = response.data as Map<String, dynamic>;
        final submissionId = responseBundle['id'] ?? 'unknown';
        
        _logger.i('Triage data submitted successfully: $submissionId');
        return submissionId;
      } else {
        throw FhirException('Failed to submit triage data: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error submitting triage data: $e');
      // Return mock submission ID for demo
      return 'mock_submission_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Monitor real-time capacity changes using FHIR subscriptions
  Stream<CapacityUpdate> monitorCapacityUpdates(List<String> hospitalIds) async* {
    _logger.i('Starting capacity monitoring for ${hospitalIds.length} hospitals');

    // In a real implementation, this would use FHIR Subscriptions
    // For demo, we'll simulate periodic updates
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      
      for (final hospitalId in hospitalIds) {
        try {
          final capacity = await getBedAvailability(hospitalId);
          yield CapacityUpdate(
            hospitalId: hospitalId,
            timestamp: DateTime.now(),
            availableBeds: capacity.availableBeds,
            totalBeds: capacity.totalBeds,
            emergencyBeds: capacity.emergencyBeds,
            icuBeds: capacity.icuBeds,
          );
        } catch (e) {
          _logger.w('Failed to get capacity update for $hospitalId: $e');
        }
      }
    }
  }

  // Private helper methods

  HospitalCapacity? _parseLocationToCapacity(Map<String, dynamic> location) {
    try {
      final id = location['id'] as String?;
      final name = location['name'] as String?;
      final position = location['position'] as Map<String, dynamic>?;

      if (id == null || name == null || position == null) {
        return null;
      }

      final latitude = (position['latitude'] as num?)?.toDouble();
      final longitude = (position['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        return null;
      }

      // Extract capacity information from extensions or managingOrganization
      final totalBeds = _extractBedCount(location, 'total') ?? 100;
      final availableBeds = _extractBedCount(location, 'available') ?? (totalBeds * 0.3).round();
      final emergencyBeds = _extractBedCount(location, 'emergency') ?? 20;
      final icuBeds = _extractBedCount(location, 'icu') ?? 10;

      return HospitalCapacity(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        totalBeds: totalBeds,
        availableBeds: availableBeds,
        emergencyBeds: emergencyBeds,
        icuBeds: icuBeds,
        lastUpdated: DateTime.now(),
        fhirEndpoint: _testFhirBaseUrl,
      );
    } catch (e) {
      _logger.w('Failed to parse location to capacity: $e');
      return null;
    }
  }

  int? _extractBedCount(Map<String, dynamic> location, String type) {
    // In a real FHIR implementation, bed counts would be in extensions
    // For demo, we'll use realistic mock values
    switch (type) {
      case 'total':
        return 80 + (location['id'].hashCode % 120);
      case 'available':
        final total = _extractBedCount(location, 'total') ?? 100;
        return (total * (0.2 + (location['id'].hashCode % 40) / 100)).round();
      case 'emergency':
        return 15 + (location['id'].hashCode % 15);
      case 'icu':
        return 8 + (location['id'].hashCode % 12);
      default:
        return null;
    }
  }

  BedAvailability _parseBedAvailability(Map<String, dynamic> location) {
    final id = location['id'] as String;
    return BedAvailability(
      hospitalId: id,
      totalBeds: _extractBedCount(location, 'total') ?? 100,
      availableBeds: _extractBedCount(location, 'available') ?? 30,
      emergencyBeds: _extractBedCount(location, 'emergency') ?? 20,
      icuBeds: _extractBedCount(location, 'icu') ?? 10,
      lastUpdated: DateTime.now(),
    );
  }

  List<Map<String, dynamic>> _createTriageObservations(PatientTriageData triageData) {
    final observations = <Map<String, dynamic>>[];

    // Create heart rate observation
    if (triageData.heartRate != null) {
      observations.add({
        'resourceType': 'Observation',
        'status': 'final',
        'category': [{
          'coding': [{
            'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
            'code': 'vital-signs',
            'display': 'Vital Signs',
          }],
        }],
        'code': {
          'coding': [{
            'system': 'http://loinc.org',
            'code': '8867-4',
            'display': 'Heart rate',
          }],
        },
        'valueQuantity': {
          'value': triageData.heartRate,
          'unit': 'beats/min',
          'system': 'http://unitsofmeasure.org',
          'code': '/min',
        },
        'effectiveDateTime': triageData.timestamp.toIso8601String(),
      });
    }

    // Create oxygen saturation observation
    if (triageData.oxygenSaturation != null) {
      observations.add({
        'resourceType': 'Observation',
        'status': 'final',
        'category': [{
          'coding': [{
            'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
            'code': 'vital-signs',
            'display': 'Vital Signs',
          }],
        }],
        'code': {
          'coding': [{
            'system': 'http://loinc.org',
            'code': '2708-6',
            'display': 'Oxygen saturation',
          }],
        },
        'valueQuantity': {
          'value': triageData.oxygenSaturation,
          'unit': '%',
          'system': 'http://unitsofmeasure.org',
          'code': '%',
        },
        'effectiveDateTime': triageData.timestamp.toIso8601String(),
      });
    }

    // Create severity score observation
    observations.add({
      'resourceType': 'Observation',
      'status': 'final',
      'category': [{
        'coding': [{
          'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
          'code': 'survey',
          'display': 'Survey',
        }],
      }],
      'code': {
        'coding': [{
          'system': 'http://snomed.info/sct',
          'code': '386053000',
          'display': 'Evaluation procedure',
        }],
      },
      'valueQuantity': {
        'value': triageData.severityScore,
        'unit': 'score',
        'system': 'http://unitsofmeasure.org',
        'code': '1',
      },
      'effectiveDateTime': triageData.timestamp.toIso8601String(),
    });

    return observations;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for calculating distance between two points
    const double earthRadius = 6371; // km

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Mock data methods for demo purposes

  List<HospitalCapacity> _getMockHospitalCapacities(double? latitude, double? longitude) {
    return [
      HospitalCapacity(
        id: 'hospital_001',
        name: 'City General Hospital',
        latitude: latitude ?? 40.7128,
        longitude: longitude ?? -74.0060,
        totalBeds: 150,
        availableBeds: 45,
        emergencyBeds: 25,
        icuBeds: 12,
        lastUpdated: DateTime.now(),
        fhirEndpoint: _testFhirBaseUrl,
        distanceKm: 2.5,
      ),
      HospitalCapacity(
        id: 'hospital_002',
        name: 'Metropolitan Medical Center',
        latitude: (latitude ?? 40.7128) + 0.05,
        longitude: (longitude ?? -74.0060) + 0.05,
        totalBeds: 200,
        availableBeds: 38,
        emergencyBeds: 30,
        icuBeds: 18,
        lastUpdated: DateTime.now(),
        fhirEndpoint: _testFhirBaseUrl,
        distanceKm: 5.8,
      ),
      HospitalCapacity(
        id: 'hospital_003',
        name: 'Regional Trauma Center',
        latitude: (latitude ?? 40.7128) - 0.03,
        longitude: (longitude ?? -74.0060) + 0.08,
        totalBeds: 120,
        availableBeds: 22,
        emergencyBeds: 35,
        icuBeds: 15,
        lastUpdated: DateTime.now(),
        fhirEndpoint: _testFhirBaseUrl,
        distanceKm: 7.2,
      ),
    ];
  }

  BedAvailability _getMockBedAvailability(String hospitalId) {
    final random = hospitalId.hashCode % 100;
    return BedAvailability(
      hospitalId: hospitalId,
      totalBeds: 100 + random,
      availableBeds: 20 + (random % 40),
      emergencyBeds: 15 + (random % 20),
      icuBeds: 8 + (random % 15),
      lastUpdated: DateTime.now(),
    );
  }
}

// Data models

class HospitalCapacity {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int totalBeds;
  final int availableBeds;
  final int emergencyBeds;
  final int icuBeds;
  final DateTime lastUpdated;
  final String fhirEndpoint;
  double? distanceKm;

  HospitalCapacity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.totalBeds,
    required this.availableBeds,
    required this.emergencyBeds,
    required this.icuBeds,
    required this.lastUpdated,
    required this.fhirEndpoint,
    this.distanceKm,
  });

  double get occupancyRate => (totalBeds - availableBeds) / totalBeds;
  bool get isNearCapacity => occupancyRate > 0.85;
  bool get hasEmergencyCapacity => emergencyBeds > 5;
}

class BedAvailability {
  final String hospitalId;
  final int totalBeds;
  final int availableBeds;
  final int emergencyBeds;
  final int icuBeds;
  final DateTime lastUpdated;

  BedAvailability({
    required this.hospitalId,
    required this.totalBeds,
    required this.availableBeds,
    required this.emergencyBeds,
    required this.icuBeds,
    required this.lastUpdated,
  });
}

class CapacityUpdate {
  final String hospitalId;
  final DateTime timestamp;
  final int availableBeds;
  final int totalBeds;
  final int emergencyBeds;
  final int icuBeds;

  CapacityUpdate({
    required this.hospitalId,
    required this.timestamp,
    required this.availableBeds,
    required this.totalBeds,
    required this.emergencyBeds,
    required this.icuBeds,
  });
}

class PatientTriageData {
  final String patientId;
  final int? heartRate;
  final double? oxygenSaturation;
  final double? temperature;
  final String? bloodPressure;
  final double severityScore;
  final String symptoms;
  final DateTime timestamp;

  PatientTriageData({
    required this.patientId,
    this.heartRate,
    this.oxygenSaturation,
    this.temperature,
    this.bloodPressure,
    required this.severityScore,
    required this.symptoms,
    required this.timestamp,
  });
}

class FhirException implements Exception {
  final String message;
  FhirException(this.message);
  
  @override
  String toString() => 'FhirException: $message';
}