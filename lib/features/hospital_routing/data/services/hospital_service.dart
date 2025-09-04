import 'package:logger/logger.dart';
import 'dart:async';
import '../../domain/entities/hospital.dart';
import '../../../../shared/models/hospital_capacity.dart';
import '../../../../shared/services/firestore_data_service.dart';
import '../../../../shared/models/firestore/hospital_firestore.dart';
import '../../../../shared/models/firestore/hospital_capacity_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class HospitalService {
  static final HospitalService _instance = HospitalService._internal();
  factory HospitalService() => _instance;
  HospitalService._internal();

  final Logger _logger = Logger();
  final FirestoreDataService _firestoreService = FirestoreDataService();

  // Caching layer
  final Map<String, List<Hospital>> _hospitalCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, HospitalCapacity> _capacityCache = {};
  final Map<String, DateTime> _capacityCacheTimestamps = {};

  // Real-time listeners
  final Map<String, StreamSubscription> _capacityListeners = {};
  final StreamController<List<HospitalCapacity>> _capacityUpdatesController =
      StreamController<List<HospitalCapacity>>.broadcast();

  /// Get nearby hospitals within specified radius using Firestore
  Future<List<Hospital>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusMiles = 25.0,
  }) async {
    _logger.i(
      'Fetching hospitals near ($latitude, $longitude) within $radiusMiles miles from Firestore',
    );

    try {
      // Check cache first
      final cacheKey = '${latitude}_${longitude}_$radiusMiles';
      if (_isCacheValid(cacheKey)) {
        _logger.i('Returning cached hospitals for location');
        return _hospitalCache[cacheKey]!;
      }

      // Convert miles to kilometers for Firestore query
      final radiusKm = radiusMiles * 1.60934;

      // Get hospitals from Firestore
      final hospitalFirestoreList = await _firestoreService
          .getHospitalsInRadius(
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
            limit: 50,
          );

      // Get capacity data for all hospitals
      final hospitalIds = hospitalFirestoreList.map((h) => h.id).toList();
      final capacities = await _firestoreService.getHospitalCapacities(
        hospitalIds,
      );
      final capacityMap = <String, HospitalCapacityFirestore>{};
      for (final capacity in capacities) {
        capacityMap[capacity.hospitalId] = capacity;
      }

      // Convert to Hospital entities
      final hospitals = <Hospital>[];
      for (final hospitalFirestore in hospitalFirestoreList) {
        final capacity = capacityMap[hospitalFirestore.id];
        if (capacity != null) {
          final hospital = _convertToHospital(hospitalFirestore, capacity);
          hospitals.add(hospital);
        }
      }

      // Cache the results
      _hospitalCache[cacheKey] = hospitals;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.i(
        'Found ${hospitals.length} hospitals within radius from Firestore',
      );
      return hospitals;
    } catch (e) {
      _logger.e('Failed to fetch hospitals from Firestore: $e');
      // Fallback to mock data if Firestore fails
      return _getMockHospitalsFallback(latitude, longitude, radiusMiles);
    }
  }

  /// Get optimal hospital recommendation using Firestore queries
  Future<Hospital?> getOptimalHospital({
    required double latitude,
    required double longitude,
    required double severityScore,
    String? requiredSpecialization,
    double maxDistance = 50.0,
  }) async {
    _logger.i(
      'Finding optimal hospital for severity $severityScore using Firestore',
    );

    try {
      // Convert miles to kilometers
      final radiusKm = maxDistance * 1.60934;

      // Use Firestore advanced query for optimal hospital selection
      final specializations = requiredSpecialization != null
          ? [requiredSpecialization]
          : <String>[];

      final hospitalFirestoreList = await _firestoreService
          .queryHospitalsAdvanced(
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
            requiredSpecializations: specializations.isNotEmpty
                ? specializations
                : null,
            minTraumaLevel: severityScore >= 8.0 ? 1 : null,
            isActive: true,
            minAvailableBeds: severityScore >= 7.0 ? 1 : 3,
            maxOccupancyRate: severityScore >= 8.0 ? 1.0 : 0.95,
            sortByDistance: true,
            limit: 10,
          );

      if (hospitalFirestoreList.isEmpty) {
        _logger.w(
          'No hospitals found matching criteria, falling back to nearby search',
        );
        final nearbyHospitals = await getNearbyHospitals(
          latitude: latitude,
          longitude: longitude,
          radiusMiles: maxDistance,
        );
        return nearbyHospitals.isNotEmpty ? nearbyHospitals.first : null;
      }

      // Get capacity data for scoring
      final hospitalIds = hospitalFirestoreList.map((h) => h.id).toList();
      final capacities = await _firestoreService.getHospitalCapacities(
        hospitalIds,
      );
      final capacityMap = <String, HospitalCapacityFirestore>{};
      for (final capacity in capacities) {
        capacityMap[capacity.hospitalId] = capacity;
      }

      // Convert to Hospital entities and score them
      final scoredHospitals = <Map<String, dynamic>>[];
      for (final hospitalFirestore in hospitalFirestoreList) {
        final capacity = capacityMap[hospitalFirestore.id];
        if (capacity != null) {
          final hospital = _convertToHospital(hospitalFirestore, capacity);
          final score = _calculateHospitalScore(
            hospital,
            latitude,
            longitude,
            severityScore,
          );
          scoredHospitals.add({'hospital': hospital, 'score': score});
        }
      }

      if (scoredHospitals.isEmpty) return null;

      // Sort by score (higher is better)
      scoredHospitals.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );

      final optimal = scoredHospitals.first['hospital'] as Hospital;
      _logger.i('Optimal hospital from Firestore: ${optimal.name}');
      return optimal;
    } catch (e) {
      _logger.e('Failed to find optimal hospital from Firestore: $e');
      // Fallback to original implementation
      return _getOptimalHospitalFallback(
        latitude: latitude,
        longitude: longitude,
        severityScore: severityScore,
        requiredSpecialization: requiredSpecialization,
        maxDistance: maxDistance,
      );
    }
  }

  /// Real-time hospital capacity monitoring
  Stream<List<HospitalCapacity>> listenToHospitalCapacities(
    List<String> hospitalIds,
  ) {
    _logger.i(
      'Setting up real-time capacity monitoring for ${hospitalIds.length} hospitals',
    );

    // Clean up existing listeners
    _cleanupCapacityListeners();

    // Set up new listener
    final subscription = _firestoreService
        .listenToHospitalCapacities(hospitalIds)
        .listen(
          (capacities) {
            _logger.i(
              'Received capacity updates for ${capacities.length} hospitals',
            );

            // Update cache
            for (final capacity in capacities) {
              final hospitalCapacity = _convertToHospitalCapacity(capacity);
              _capacityCache[capacity.hospitalId] = hospitalCapacity;
              _capacityCacheTimestamps[capacity.hospitalId] = DateTime.now();
            }

            // Broadcast updates
            final hospitalCapacities = capacities
                .map(_convertToHospitalCapacity)
                .toList();
            _capacityUpdatesController.add(hospitalCapacities);
          },
          onError: (error) {
            _logger.e('Error in capacity monitoring: $error');
          },
        );

    _capacityListeners['main'] = subscription;
    return _capacityUpdatesController.stream;
  }

  /// Get real-time capacity updates stream
  Stream<List<HospitalCapacity>> get capacityUpdatesStream =>
      _capacityUpdatesController.stream;

  /// Get hospital capacity with caching
  Future<HospitalCapacity?> getHospitalCapacity(String hospitalId) async {
    try {
      // Check cache first
      if (_isCapacityCacheValid(hospitalId)) {
        _logger.i('Returning cached capacity for hospital $hospitalId');
        return _capacityCache[hospitalId];
      }

      // Fetch from Firestore
      final capacityFirestore = await _firestoreService.getHospitalCapacity(
        hospitalId,
      );
      if (capacityFirestore == null) return null;

      final capacity = _convertToHospitalCapacity(capacityFirestore);

      // Cache the result
      _capacityCache[hospitalId] = capacity;
      _capacityCacheTimestamps[hospitalId] = DateTime.now();

      return capacity;
    } catch (e) {
      _logger.e('Failed to get hospital capacity: $e');
      return null;
    }
  }

  /// Update hospital capacity in Firestore
  Future<void> updateHospitalCapacity(HospitalCapacity capacity) async {
    try {
      final capacityFirestore = _convertToHospitalCapacityFirestore(capacity);
      await _firestoreService.updateHospitalCapacity(capacityFirestore);

      // Update cache
      _capacityCache[capacity.id] = capacity;
      _capacityCacheTimestamps[capacity.id] = DateTime.now();

      _logger.i('Updated hospital capacity for ${capacity.name}');
    } catch (e) {
      _logger.e('Failed to update hospital capacity: $e');
      rethrow;
    }
  }

  /// Get hospitals with available capacity using Firestore queries
  Future<List<Hospital>> getAvailableHospitals({
    double? latitude,
    double? longitude,
    double? radiusKm,
    int minAvailableBeds = 1,
    double maxOccupancyRate = 0.95,
    int limit = 20,
  }) async {
    try {
      _logger.i('Fetching available hospitals from Firestore');

      // Get hospitals with available capacity
      final capacities = await _firestoreService.getAvailableCapacities(
        minAvailableBeds: minAvailableBeds,
        maxOccupancyRate: maxOccupancyRate,
        limit: limit,
      );

      if (capacities.isEmpty) return [];

      // Get hospital details
      final hospitalIds = capacities.map((c) => c.hospitalId).toList();
      final hospitals = <Hospital>[];

      for (final hospitalId in hospitalIds) {
        final hospitalFirestore = await _firestoreService.getHospitalById(
          hospitalId,
        );
        final capacity = capacities.firstWhere(
          (c) => c.hospitalId == hospitalId,
        );

        if (hospitalFirestore != null) {
          final hospital = _convertToHospital(hospitalFirestore, capacity);

          // Apply location filtering if specified
          if (latitude != null && longitude != null && radiusKm != null) {
            final distance =
                hospital.distanceFrom(latitude, longitude) *
                1.60934; // Convert to km
            if (distance <= radiusKm) {
              hospitals.add(hospital);
            }
          } else {
            hospitals.add(hospital);
          }
        }
      }

      _logger.i('Found ${hospitals.length} available hospitals');
      return hospitals;
    } catch (e) {
      _logger.e('Failed to get available hospitals: $e');
      return [];
    }
  }

  /// Clear all caches
  void clearCache() {
    _hospitalCache.clear();
    _cacheTimestamps.clear();
    _capacityCache.clear();
    _capacityCacheTimestamps.clear();
    _logger.i('Hospital service cache cleared');
  }

  /// Dispose resources
  void dispose() {
    _cleanupCapacityListeners();
    _capacityUpdatesController.close();
    clearCache();
    _logger.i('Hospital service disposed');
  }

  // Helper methods
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final age = DateTime.now().difference(timestamp);
    return age < AppConstants.hospitalCacheDuration &&
        _hospitalCache.containsKey(cacheKey);
  }

  bool _isCapacityCacheValid(String hospitalId) {
    final timestamp = _capacityCacheTimestamps[hospitalId];
    if (timestamp == null) return false;

    final age = DateTime.now().difference(timestamp);
    return age < AppConstants.vitalsCacheDuration &&
        _capacityCache.containsKey(hospitalId);
  }

  void _cleanupCapacityListeners() {
    for (final subscription in _capacityListeners.values) {
      subscription.cancel();
    }
    _capacityListeners.clear();
  }

  Hospital _convertToHospital(
    HospitalFirestore hospitalFirestore,
    HospitalCapacityFirestore capacityFirestore,
  ) {
    return Hospital(
      id: hospitalFirestore.id,
      name: hospitalFirestore.name,
      latitude: hospitalFirestore.location.latitude,
      longitude: hospitalFirestore.location.longitude,
      address:
          '${hospitalFirestore.address.street}, ${hospitalFirestore.address.city}, ${hospitalFirestore.address.state} ${hospitalFirestore.address.zipCode}',
      phoneNumber: hospitalFirestore.contact.phone,
      traumaLevel: hospitalFirestore.traumaLevel,
      specializations: hospitalFirestore.specializations,
      certifications: hospitalFirestore.certifications,
      capacity: _convertToHospitalCapacity(capacityFirestore),
      performance: HospitalPerformance(
        averageWaitTime: capacityFirestore.averageWaitTime,
        patientSatisfaction: 4.2, // Default value, could be enhanced
        treatmentSuccessRate: 0.92, // Default value, could be enhanced
        monthlyVolume: capacityFirestore.totalBeds * 50, // Estimated
      ),
    );
  }

  HospitalCapacity _convertToHospitalCapacity(
    HospitalCapacityFirestore capacityFirestore,
  ) {
    return HospitalCapacity(
      id: capacityFirestore.hospitalId,
      name: '', // Will be filled by caller if needed
      latitude: null, // Will be filled by caller if needed
      longitude: null, // Will be filled by caller if needed
      totalBeds: capacityFirestore.totalBeds,
      availableBeds: capacityFirestore.availableBeds,
      icuBeds: capacityFirestore.icuBeds,
      emergencyBeds: capacityFirestore.emergencyBeds,
      staffOnDuty: capacityFirestore.staffOnDuty,
      patientsInQueue: capacityFirestore.patientsInQueue,
      averageWaitTime: capacityFirestore.averageWaitTime,
      lastUpdated: capacityFirestore.lastUpdated,
    );
  }

  HospitalCapacityFirestore _convertToHospitalCapacityFirestore(
    HospitalCapacity capacity,
  ) {
    return HospitalCapacityFirestore(
      id: '', // Will be generated by Firestore
      hospitalId: capacity.id,
      totalBeds: capacity.totalBeds,
      availableBeds: capacity.availableBeds,
      icuBeds: capacity.icuBeds,
      icuAvailable: capacity
          .icuBeds, // Assuming all ICU beds are available for simplicity
      emergencyBeds: capacity.emergencyBeds,
      emergencyAvailable:
          capacity.emergencyBeds, // Assuming all emergency beds are available
      staffOnDuty: capacity.staffOnDuty,
      patientsInQueue: capacity.patientsInQueue,
      averageWaitTime: capacity.averageWaitTime,
      lastUpdated: capacity.lastUpdated,
      dataSource: DataSource.firestore,
      isRealTime: true,
    );
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
      ),
    ];
  }

  // Fallback methods for when Firestore is unavailable
  Future<List<Hospital>> _getMockHospitalsFallback(
    double latitude,
    double longitude,
    double radiusMiles,
  ) async {
    _logger.w('Using fallback mock hospitals due to Firestore unavailability');

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

    return nearbyHospitals;
  }

  Future<Hospital?> _getOptimalHospitalFallback({
    required double latitude,
    required double longitude,
    required double severityScore,
    String? requiredSpecialization,
    required double maxDistance,
  }) async {
    _logger.w(
      'Using fallback optimal hospital selection due to Firestore unavailability',
    );

    final nearbyHospitals = await _getMockHospitalsFallback(
      latitude,
      longitude,
      maxDistance,
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

    return candidates.first;
  }
}
