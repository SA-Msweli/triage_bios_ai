import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'firestore_data_service.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/patient_vitals_firestore.dart';
import '../models/firestore/triage_result_firestore.dart';
import '../models/firestore/patient_consent_firestore.dart';
import 'dart:math' as math;

/// Service for migrating data from mock sources to Firestore and seeding realistic data
class DataMigrationService {
  static final DataMigrationService _instance = DataMigrationService._internal();
  factory DataMigrationService() => _instance;
  DataMigrationService._internal();

  final Logger _logger = Logger();
  final FirestoreDataService _firestoreService = FirestoreDataService();
  final Uuid _uuid = const Uuid();
  final math.Random _random = math.Random();

  // ============================================================================
  // HOSPITAL DATA SEEDING
  // ============================================================================

  /// Seed comprehensive hospital data for major metropolitan areas
  Future<void> seedHospitalData() async {
    try {
      _logger.i('Starting hospital data seeding...');

      final hospitals = _generateRealisticHospitals();
      final capacities = <HospitalCapacityFirestore>[];

      // Create hospitals and their capacities
      for (final hospital in hospitals) {
        try {
          final hospitalId = await _firestoreService.createHospital(hospital);
          
          // Generate realistic capacity data for this hospital
          final capacity = _generateHospitalCapacity(hospitalId, hospital);
          capacities.add(capacity);
          
          _logger.d('Created hospital: ${hospital.name} (ID: $hospitalId)');
        } catch (e) {
          _logger.w('Failed to create hospital ${hospital.name}: $e');
        }
      }

      // Batch update capacities
      if (capacities.isNotEmpty) {
        await _firestoreService.batchUpdateCapacities(capacities);
      }

      _logger.i('Hospital data seeding completed: ${hospitals.length} hospitals created');
    } catch (e) {
      _logger.e('Failed to seed hospital data: $e');
      rethrow;
    }
  }

  /// Generate realistic hospital data for major cities
  List<HospitalFirestore> _generateRealisticHospitals() {
    final hospitals = <HospitalFirestore>[];
    final now = DateTime.now();

    // New York City Hospitals
    hospitals.addAll([
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'NewYork-Presbyterian Hospital',
        address: const HospitalAddress(
          street: '525 E 68th St',
          city: 'New York',
          state: 'NY',
          zipCode: '10065',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 40.7648, longitude: -73.9540),
        contact: const HospitalContact(
          phone: '(212) 746-5454',
          email: 'info@nyp.org',
          website: 'https://www.nyp.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'neurology', 'oncology', 'trauma'],
        certifications: ['Joint Commission', 'Magnet', 'Trauma Center Level I'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 6:00 AM - 10:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'Mount Sinai Hospital',
        address: const HospitalAddress(
          street: '1 Gustave L. Levy Pl',
          city: 'New York',
          state: 'NY',
          zipCode: '10029',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 40.7903, longitude: -73.9505),
        contact: const HospitalContact(
          phone: '(212) 241-6500',
          email: 'info@mountsinai.org',
          website: 'https://www.mountsinai.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'orthopedics', 'pediatrics'],
        certifications: ['Joint Commission', 'Magnet'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 5:30 AM - 11:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
    ]);

    // Los Angeles Hospitals
    hospitals.addAll([
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'Cedars-Sinai Medical Center',
        address: const HospitalAddress(
          street: '8700 Beverly Blvd',
          city: 'Los Angeles',
          state: 'CA',
          zipCode: '90048',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 34.0759, longitude: -118.3772),
        contact: const HospitalContact(
          phone: '(310) 423-3277',
          email: 'info@cshs.org',
          website: 'https://www.cedars-sinai.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'oncology', 'neurosurgery'],
        certifications: ['Joint Commission', 'Magnet', 'Comprehensive Cancer Center'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 6:00 AM - 9:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'UCLA Medical Center',
        address: const HospitalAddress(
          street: '757 Westwood Plaza',
          city: 'Los Angeles',
          state: 'CA',
          zipCode: '90095',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 34.0689, longitude: -118.4452),
        contact: const HospitalContact(
          phone: '(310) 825-9111',
          email: 'info@ucla.edu',
          website: 'https://www.uclahealth.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'trauma', 'pediatrics', 'research'],
        certifications: ['Joint Commission', 'Magnet', 'Trauma Center Level I'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 5:00 AM - 10:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
    ]);

    // Chicago Hospitals
    hospitals.addAll([
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'Northwestern Memorial Hospital',
        address: const HospitalAddress(
          street: '251 E Huron St',
          city: 'Chicago',
          state: 'IL',
          zipCode: '60611',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 41.8955, longitude: -87.6214),
        contact: const HospitalContact(
          phone: '(312) 926-2000',
          email: 'info@nm.org',
          website: 'https://www.nm.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'neurology', 'transplant'],
        certifications: ['Joint Commission', 'Magnet', 'Comprehensive Stroke Center'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 6:00 AM - 10:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
    ]);

    // Houston Hospitals
    hospitals.addAll([
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'Houston Methodist Hospital',
        address: const HospitalAddress(
          street: '6565 Fannin St',
          city: 'Houston',
          state: 'TX',
          zipCode: '77030',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 29.7097, longitude: -95.3967),
        contact: const HospitalContact(
          phone: '(713) 790-3311',
          email: 'info@houstonmethodist.org',
          website: 'https://www.houstonmethodist.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'cardiology', 'oncology', 'orthopedics'],
        certifications: ['Joint Commission', 'Magnet'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 5:30 AM - 11:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
    ]);

    // Miami Hospitals
    hospitals.addAll([
      HospitalFirestore(
        id: _uuid.v4(),
        name: 'Jackson Memorial Hospital',
        address: const HospitalAddress(
          street: '1611 NW 12th Ave',
          city: 'Miami',
          state: 'FL',
          zipCode: '33136',
          country: 'USA',
        ),
        location: const HospitalLocation(latitude: 25.7867, longitude: -80.2109),
        contact: const HospitalContact(
          phone: '(305) 585-1111',
          email: 'info@jhsmiami.org',
          website: 'https://www.jacksonhealth.org',
        ),
        traumaLevel: 1,
        specializations: ['emergency', 'trauma', 'burn', 'pediatrics'],
        certifications: ['Joint Commission', 'Trauma Center Level I', 'Burn Center'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 6:00 AM - 10:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
    ]);

    // Add smaller community hospitals
    hospitals.addAll(_generateCommunityHospitals());

    return hospitals;
  }

  /// Generate community hospitals with varied characteristics
  List<HospitalFirestore> _generateCommunityHospitals() {
    final hospitals = <HospitalFirestore>[];
    final now = DateTime.now();

    final communityHospitals = [
      {
        'name': 'Riverside Community Hospital',
        'city': 'New York',
        'state': 'NY',
        'lat': 40.7831,
        'lng': -73.9712,
        'traumaLevel': 3,
        'specializations': ['emergency', 'family medicine', 'internal medicine'],
      },
      {
        'name': 'Westside Medical Center',
        'city': 'Los Angeles',
        'state': 'CA',
        'lat': 34.0522,
        'lng': -118.2437,
        'traumaLevel': 2,
        'specializations': ['emergency', 'orthopedics', 'cardiology'],
      },
      {
        'name': 'Northshore Regional Hospital',
        'city': 'Chicago',
        'state': 'IL',
        'lat': 41.9278,
        'lng': -87.6445,
        'traumaLevel': 2,
        'specializations': ['emergency', 'pediatrics', 'women\'s health'],
      },
      {
        'name': 'Bayview General Hospital',
        'city': 'Miami',
        'state': 'FL',
        'lat': 25.7617,
        'lng': -80.1918,
        'traumaLevel': 3,
        'specializations': ['emergency', 'geriatrics', 'rehabilitation'],
      },
    ];

    for (final hospitalData in communityHospitals) {
      hospitals.add(HospitalFirestore(
        id: _uuid.v4(),
        name: hospitalData['name'] as String,
        address: HospitalAddress(
          street: '${_random.nextInt(9999) + 1} Medical Center Dr',
          city: hospitalData['city'] as String,
          state: hospitalData['state'] as String,
          zipCode: '${_random.nextInt(90000) + 10000}',
          country: 'USA',
        ),
        location: HospitalLocation(
          latitude: hospitalData['lat'] as double,
          longitude: hospitalData['lng'] as double,
        ),
        contact: HospitalContact(
          phone: '(${_random.nextInt(900) + 100}) ${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}',
          email: 'info@${hospitalData['name'].toString().toLowerCase().replaceAll(' ', '').replaceAll('\'', '')}.org',
          website: 'https://www.${hospitalData['name'].toString().toLowerCase().replaceAll(' ', '').replaceAll('\'', '')}.org',
        ),
        traumaLevel: hospitalData['traumaLevel'] as int,
        specializations: hospitalData['specializations'] as List<String>,
        certifications: ['Joint Commission'],
        operatingHours: const HospitalOperatingHours(
          emergency: '24/7',
          general: 'Mon-Sun 6:00 AM - 10:00 PM',
        ),
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ));
    }

    return hospitals;
  }

  /// Generate realistic capacity data for a hospital
  HospitalCapacityFirestore _generateHospitalCapacity(String hospitalId, HospitalFirestore hospital) {
    // Base capacity on trauma level and specializations
    int baseBeds;
    switch (hospital.traumaLevel) {
      case 1:
        baseBeds = 400 + _random.nextInt(200); // 400-600 beds
        break;
      case 2:
        baseBeds = 200 + _random.nextInt(200); // 200-400 beds
        break;
      case 3:
        baseBeds = 100 + _random.nextInt(150); // 100-250 beds
        break;
      default:
        baseBeds = 80 + _random.nextInt(120); // 80-200 beds
    }

    final totalBeds = baseBeds;
    final occupancyRate = 0.65 + (_random.nextDouble() * 0.25); // 65-90% occupancy
    final availableBeds = (totalBeds * (1 - occupancyRate)).round();
    
    final icuBeds = (totalBeds * 0.1).round(); // 10% ICU beds
    final icuOccupancyRate = 0.7 + (_random.nextDouble() * 0.25); // 70-95% ICU occupancy
    final icuAvailable = (icuBeds * (1 - icuOccupancyRate)).round();
    
    final emergencyBeds = (totalBeds * 0.15).round(); // 15% emergency beds
    final emergencyOccupancyRate = 0.6 + (_random.nextDouble() * 0.3); // 60-90% emergency occupancy
    final emergencyAvailable = (emergencyBeds * (1 - emergencyOccupancyRate)).round();

    final staffOnDuty = (totalBeds * 0.8).round() + _random.nextInt(20); // ~0.8 staff per bed
    final patientsInQueue = _random.nextInt(15); // 0-15 patients in queue
    final averageWaitTime = 15.0 + (_random.nextDouble() * 45.0); // 15-60 minutes

    return HospitalCapacityFirestore(
      id: _uuid.v4(),
      hospitalId: hospitalId,
      totalBeds: totalBeds,
      availableBeds: availableBeds,
      icuBeds: icuBeds,
      icuAvailable: icuAvailable,
      emergencyBeds: emergencyBeds,
      emergencyAvailable: emergencyAvailable,
      staffOnDuty: staffOnDuty,
      patientsInQueue: patientsInQueue,
      averageWaitTime: averageWaitTime,
      lastUpdated: DateTime.now().subtract(Duration(minutes: _random.nextInt(10))),
      dataSource: DataSource.firestore,
      isRealTime: _random.nextBool(),
    );
  }
 
 // ============================================================================
  // MOCK DATA MIGRATION
  // ============================================================================

  /// Migrate existing mock hospital data from HospitalService to Firestore
  Future<void> migrateFromMockData() async {
    try {
      _logger.i('Starting mock data migration...');

      // Get existing mock hospitals from the old service
      final mockHospitals = _getMockHospitalsFromOldService();
      
      for (final mockHospital in mockHospitals) {
        try {
          // Convert mock hospital to Firestore format
          final hospital = _convertMockHospitalToFirestore(mockHospital);
          final hospitalId = await _firestoreService.createHospital(hospital);
          
          // Convert and create capacity data
          final capacity = _convertMockCapacityToFirestore(hospitalId, mockHospital);
          await _firestoreService.updateHospitalCapacity(capacity);
          
          _logger.d('Migrated hospital: ${hospital.name}');
        } catch (e) {
          _logger.w('Failed to migrate hospital: $e');
        }
      }

      _logger.i('Mock data migration completed: ${mockHospitals.length} hospitals migrated');
    } catch (e) {
      _logger.e('Failed to migrate mock data: $e');
      rethrow;
    }
  }

  /// Get mock hospitals from the old HospitalService format
  List<Map<String, dynamic>> _getMockHospitalsFromOldService() {
    final now = DateTime.now();
    
    return [
      {
        'id': 'hosp_001',
        'name': 'City General Hospital',
        'latitude': 40.7589,
        'longitude': -73.9851,
        'address': '123 Medical Center Dr, New York, NY 10001',
        'phoneNumber': '(555) 123-4567',
        'traumaLevel': 1,
        'specializations': ['emergency', 'cardiology', 'trauma', 'neurology'],
        'certifications': ['Joint Commission', 'Magnet', 'Trauma Center Level I'],
        'totalBeds': 450,
        'availableBeds': 23,
        'icuBeds': 8,
        'emergencyBeds': 12,
        'staffOnDuty': 85,
        'lastUpdated': now.subtract(const Duration(minutes: 3)),
      },
      {
        'id': 'hosp_002',
        'name': 'Metropolitan Medical Center',
        'latitude': 40.7505,
        'longitude': -73.9934,
        'address': '456 Healthcare Ave, New York, NY 10002',
        'phoneNumber': '(555) 234-5678',
        'traumaLevel': 2,
        'specializations': ['emergency', 'orthopedics', 'pediatrics'],
        'certifications': ['Joint Commission', 'Baby-Friendly'],
        'totalBeds': 320,
        'availableBeds': 45,
        'icuBeds': 12,
        'emergencyBeds': 18,
        'staffOnDuty': 62,
        'lastUpdated': now.subtract(const Duration(minutes: 1)),
      },
      {
        'id': 'hosp_003',
        'name': 'St. Mary\'s Emergency Hospital',
        'latitude': 40.7614,
        'longitude': -73.9776,
        'address': '789 Emergency Blvd, New York, NY 10003',
        'phoneNumber': '(555) 345-6789',
        'traumaLevel': 1,
        'specializations': ['emergency', 'cardiology', 'stroke', 'trauma'],
        'certifications': ['Joint Commission', 'Comprehensive Stroke Center'],
        'totalBeds': 280,
        'availableBeds': 8,
        'icuBeds': 3,
        'emergencyBeds': 6,
        'staffOnDuty': 48,
        'lastUpdated': now.subtract(const Duration(minutes: 5)),
      },
      {
        'id': 'hosp_004',
        'name': 'University Hospital',
        'latitude': 40.7282,
        'longitude': -73.9942,
        'address': '321 University Way, New York, NY 10004',
        'phoneNumber': '(555) 456-7890',
        'traumaLevel': 1,
        'specializations': ['emergency', 'research', 'oncology', 'neurosurgery'],
        'certifications': ['Joint Commission', 'Magnet', 'NCI Cancer Center'],
        'totalBeds': 520,
        'availableBeds': 67,
        'icuBeds': 15,
        'emergencyBeds': 25,
        'staffOnDuty': 95,
        'lastUpdated': now.subtract(const Duration(minutes: 2)),
      },
      {
        'id': 'hosp_005',
        'name': 'Riverside Community Hospital',
        'latitude': 40.7831,
        'longitude': -73.9712,
        'address': '654 Riverside Dr, New York, NY 10005',
        'phoneNumber': '(555) 567-8901',
        'traumaLevel': 3,
        'specializations': ['emergency', 'family medicine', 'internal medicine'],
        'certifications': ['Joint Commission'],
        'totalBeds': 180,
        'availableBeds': 32,
        'icuBeds': 6,
        'emergencyBeds': 14,
        'staffOnDuty': 35,
        'lastUpdated': now.subtract(const Duration(minutes: 7)),
      },
    ];
  }

  /// Convert mock hospital data to Firestore format
  HospitalFirestore _convertMockHospitalToFirestore(Map<String, dynamic> mockHospital) {
    final now = DateTime.now();
    final addressParts = (mockHospital['address'] as String).split(', ');
    
    return HospitalFirestore(
      id: mockHospital['id'] as String,
      name: mockHospital['name'] as String,
      address: HospitalAddress(
        street: addressParts.isNotEmpty ? addressParts[0] : 'Unknown Street',
        city: addressParts.length > 1 ? addressParts[1] : 'Unknown City',
        state: addressParts.length > 2 ? addressParts[2].split(' ')[0] : 'NY',
        zipCode: addressParts.length > 2 ? addressParts[2].split(' ').last : '10001',
        country: 'USA',
      ),
      location: HospitalLocation(
        latitude: (mockHospital['latitude'] as num).toDouble(),
        longitude: (mockHospital['longitude'] as num).toDouble(),
      ),
      contact: HospitalContact(
        phone: mockHospital['phoneNumber'] as String,
        email: 'info@${mockHospital['name'].toString().toLowerCase().replaceAll(' ', '').replaceAll('\'', '')}.org',
        website: 'https://www.${mockHospital['name'].toString().toLowerCase().replaceAll(' ', '').replaceAll('\'', '')}.org',
      ),
      traumaLevel: mockHospital['traumaLevel'] as int,
      specializations: List<String>.from(mockHospital['specializations'] as List),
      certifications: List<String>.from(mockHospital['certifications'] as List),
      operatingHours: const HospitalOperatingHours(
        emergency: '24/7',
        general: 'Mon-Sun 6:00 AM - 10:00 PM',
      ),
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );
  }

  /// Convert mock capacity data to Firestore format
  HospitalCapacityFirestore _convertMockCapacityToFirestore(
    String hospitalId,
    Map<String, dynamic> mockHospital,
  ) {
    final totalBeds = mockHospital['totalBeds'] as int;
    final availableBeds = mockHospital['availableBeds'] as int;
    final icuBeds = mockHospital['icuBeds'] as int;
    final emergencyBeds = mockHospital['emergencyBeds'] as int;
    final staffOnDuty = mockHospital['staffOnDuty'] as int;
    
    // Calculate ICU and emergency availability (assume 70% occupancy)
    final icuAvailable = (icuBeds * 0.3).round();
    final emergencyAvailable = (emergencyBeds * 0.3).round();
    
    return HospitalCapacityFirestore(
      id: _uuid.v4(),
      hospitalId: hospitalId,
      totalBeds: totalBeds,
      availableBeds: availableBeds,
      icuBeds: icuBeds,
      icuAvailable: icuAvailable,
      emergencyBeds: emergencyBeds,
      emergencyAvailable: emergencyAvailable,
      staffOnDuty: staffOnDuty,
      patientsInQueue: _random.nextInt(10),
      averageWaitTime: 20.0 + (_random.nextDouble() * 40.0),
      lastUpdated: mockHospital['lastUpdated'] as DateTime,
      dataSource: DataSource.firestore,
      isRealTime: false,
    );
  }

  // ============================================================================
  // SAMPLE DATA GENERATION
  // ============================================================================

  /// Generate sample patient vitals data for testing
  Future<void> generateSamplePatientData({
    int patientCount = 10,
    int vitalsPerPatient = 5,
    int triageResultsPerPatient = 2,
  }) async {
    try {
      _logger.i('Generating sample patient data...');

      for (int i = 0; i < patientCount; i++) {
        final patientId = 'patient_${_uuid.v4()}';
        
        // Generate vitals history
        for (int j = 0; j < vitalsPerPatient; j++) {
          final vitals = _generateSampleVitals(patientId, j);
          await _firestoreService.storePatientVitals(vitals);
        }
        
        // Generate triage results
        for (int k = 0; k < triageResultsPerPatient; k++) {
          final result = _generateSampleTriageResult(patientId, k);
          await _firestoreService.storeTriageResult(result);
        }
        
        // Generate consent record
        final consent = _generateSampleConsent(patientId);
        await _firestoreService.storePatientConsent(consent);
        
        _logger.d('Generated data for patient: $patientId');
      }

      _logger.i('Sample patient data generation completed: $patientCount patients');
    } catch (e) {
      _logger.e('Failed to generate sample patient data: $e');
      rethrow;
    }
  }

  /// Generate realistic patient vitals
  PatientVitalsFirestore _generateSampleVitals(String patientId, int index) {
    final baseTime = DateTime.now().subtract(Duration(hours: index * 2));
    
    // Generate realistic vitals with some variation
    final heartRate = 60.0 + _random.nextDouble() * 40.0; // 60-100 bpm
    final systolic = 110.0 + _random.nextDouble() * 30.0; // 110-140 mmHg
    final diastolic = 70.0 + _random.nextDouble() * 20.0; // 70-90 mmHg
    final oxygenSat = 95.0 + _random.nextDouble() * 5.0; // 95-100%
    final temperature = 97.0 + _random.nextDouble() * 3.0; // 97-100°F
    final respiratory = 12.0 + _random.nextDouble() * 8.0; // 12-20 breaths/min
    
    // Occasionally generate abnormal vitals
    final isAbnormal = _random.nextDouble() < 0.2; // 20% chance
    
    return PatientVitalsFirestore(
      id: _uuid.v4(),
      patientId: patientId,
      deviceId: _random.nextBool() ? 'device_${_random.nextInt(1000)}' : null,
      heartRate: isAbnormal && _random.nextBool() ? (heartRate + 40) : heartRate,
      bloodPressureSystolic: isAbnormal && _random.nextBool() ? (systolic + 30) : systolic,
      bloodPressureDiastolic: isAbnormal && _random.nextBool() ? (diastolic + 20) : diastolic,
      oxygenSaturation: isAbnormal && _random.nextBool() ? (oxygenSat - 10) : oxygenSat,
      temperature: isAbnormal && _random.nextBool() ? (temperature + 3) : temperature,
      respiratoryRate: respiratory,
      source: VitalsSource.values[_random.nextInt(VitalsSource.values.length)],
      accuracy: 0.85 + _random.nextDouble() * 0.15, // 85-100% accuracy
      timestamp: baseTime,
      isValidated: _random.nextBool(),
    );
  }

  /// Generate sample triage result
  TriageResultFirestore _generateSampleTriageResult(String patientId, int index) {
    final symptoms = [
      'Chest pain and shortness of breath',
      'Severe headache and dizziness',
      'Abdominal pain and nausea',
      'Fever and body aches',
      'Back pain and muscle spasms',
    ];
    
    final urgencyLevels = UrgencyLevel.values;
    final urgencyLevel = urgencyLevels[_random.nextInt(urgencyLevels.length)];
    
    double severityScore;
    switch (urgencyLevel) {
      case UrgencyLevel.critical:
        severityScore = 8.0 + _random.nextDouble() * 2.0; // 8-10
        break;
      case UrgencyLevel.urgent:
        severityScore = 6.0 + _random.nextDouble() * 2.0; // 6-8
        break;
      case UrgencyLevel.standard:
        severityScore = 4.0 + _random.nextDouble() * 2.0; // 4-6
        break;
      case UrgencyLevel.nonUrgent:
        severityScore = 1.0 + _random.nextDouble() * 3.0; // 1-4
        break;
    }
    
    return TriageResultFirestore(
      id: _uuid.v4(),
      patientId: patientId,
      sessionId: 'session_${_uuid.v4()}',
      symptoms: symptoms[_random.nextInt(symptoms.length)],
      severityScore: severityScore,
      urgencyLevel: urgencyLevel,
      aiReasoning: 'AI assessment based on symptoms and vitals analysis. ${urgencyLevel.displayName} priority assigned.',
      recommendedActions: _getRecommendedActions(urgencyLevel),
      vitalsContribution: _random.nextDouble() * 3.0, // 0-3 points from vitals
      confidence: 0.7 + _random.nextDouble() * 0.3, // 70-100% confidence
      estimatedWaitTime: _getEstimatedWaitTime(urgencyLevel),
      createdAt: DateTime.now().subtract(Duration(hours: index * 6)),
      watsonxModelVersion: 'granite-3-8b-instruct-v1.0',
    );
  }

  /// Generate sample patient consent
  PatientConsentFirestore _generateSampleConsent(String patientId) {
    final consentTypes = ConsentType.values;
    final consentType = consentTypes[_random.nextInt(consentTypes.length)];
    
    return PatientConsentFirestore(
      id: _uuid.v4(),
      patientId: patientId,
      providerId: 'provider_${_random.nextInt(100)}',
      consentType: consentType,
      dataScopes: ['vitals', 'triage_results', 'medical_history'],
      grantedAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
      expiresAt: DateTime.now().add(Duration(days: 365)), // 1 year
      isActive: true,
      blockchainTxId: 'tx_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}',
      ipAddress: '192.168.1.${_random.nextInt(255)}',
      consentDetails: {
        'grantedBy': patientId,
        'reason': 'Emergency treatment consent',
        'location': 'Mobile App',
      },
    );
  }

  /// Get recommended actions based on urgency level
  List<String> _getRecommendedActions(UrgencyLevel urgencyLevel) {
    switch (urgencyLevel) {
      case UrgencyLevel.critical:
        return ['Call 911 immediately', 'Do not drive yourself', 'Prepare medical history'];
      case UrgencyLevel.urgent:
        return ['Seek emergency care within 1 hour', 'Monitor symptoms closely', 'Have someone drive you'];
      case UrgencyLevel.standard:
        return ['Visit emergency room when convenient', 'Monitor symptoms', 'Consider urgent care'];
      case UrgencyLevel.nonUrgent:
        return ['Schedule appointment with primary care', 'Monitor symptoms', 'Rest and hydrate'];
    }
  }

  /// Get estimated wait time based on urgency level
  double _getEstimatedWaitTime(UrgencyLevel urgencyLevel) {
    switch (urgencyLevel) {
      case UrgencyLevel.critical:
        return 0.0; // Immediate
      case UrgencyLevel.urgent:
        return 15.0 + _random.nextDouble() * 15.0; // 15-30 minutes
      case UrgencyLevel.standard:
        return 30.0 + _random.nextDouble() * 30.0; // 30-60 minutes
      case UrgencyLevel.nonUrgent:
        return 60.0 + _random.nextDouble() * 60.0; // 60-120 minutes
    }
  }
  //============================================================================
  // DATA VALIDATION AND INTEGRITY
  // ============================================================================

  /// Validate data integrity after migration or seeding
  Future<ValidationResult> validateDataIntegrity() async {
    try {
      _logger.i('Starting data integrity validation...');

      final result = ValidationResult();

      // Validate hospitals
      final hospitals = await _firestoreService.getHospitals(limit: 1000);
      result.hospitalCount = hospitals.length;
      result.hospitalsValid = hospitals.where((h) => _validateHospital(h)).length;

      // Validate hospital capacities
      final hospitalIds = hospitals.map((h) => h.id).toList();
      final capacities = await _firestoreService.getHospitalCapacities(hospitalIds);
      result.capacityCount = capacities.length;
      result.capacitiesValid = capacities.where((c) => _validateCapacity(c)).length;

      // Check for orphaned capacities (capacities without hospitals)
      final orphanedCapacities = capacities.where((c) => 
          !hospitalIds.contains(c.hospitalId)).length;
      result.orphanedCapacities = orphanedCapacities;

      // Validate data freshness
      final staleCapacities = capacities.where((c) => !c.isDataFresh).length;
      result.staleCapacities = staleCapacities;

      // Calculate validation scores
      result.hospitalValidationScore = result.hospitalsValid / result.hospitalCount;
      result.capacityValidationScore = result.capacitiesValid / result.capacityCount;
      result.overallScore = (result.hospitalValidationScore + result.capacityValidationScore) / 2;

      _logger.i('Data integrity validation completed');
      _logger.i('Hospitals: ${result.hospitalsValid}/${result.hospitalCount} valid');
      _logger.i('Capacities: ${result.capacitiesValid}/${result.capacityCount} valid');
      _logger.i('Overall score: ${(result.overallScore * 100).toStringAsFixed(1)}%');

      return result;
    } catch (e) {
      _logger.e('Failed to validate data integrity: $e');
      return ValidationResult.error(e.toString());
    }
  }

  /// Validate individual hospital data
  bool _validateHospital(HospitalFirestore hospital) {
    // Check required fields
    if (hospital.name.isEmpty) return false;
    if (hospital.address.street.isEmpty) return false;
    if (hospital.address.city.isEmpty) return false;
    if (hospital.contact.phone.isEmpty) return false;
    if (hospital.contact.email.isEmpty) return false;
    
    // Check location coordinates
    if (hospital.location.latitude < -90 || hospital.location.latitude > 90) return false;
    if (hospital.location.longitude < -180 || hospital.location.longitude > 180) return false;
    
    // Check trauma level
    if (hospital.traumaLevel < 1 || hospital.traumaLevel > 4) return false;
    
    // Check specializations
    if (hospital.specializations.isEmpty) return false;
    
    return true;
  }

  /// Validate individual capacity data
  bool _validateCapacity(HospitalCapacityFirestore capacity) {
    // Check bed counts
    if (capacity.totalBeds <= 0) return false;
    if (capacity.availableBeds < 0) return false;
    if (capacity.availableBeds > capacity.totalBeds) return false;
    if (capacity.icuBeds < 0) return false;
    if (capacity.emergencyBeds < 0) return false;
    
    // Check staff count
    if (capacity.staffOnDuty < 0) return false;
    
    // Check wait time
    if (capacity.averageWaitTime < 0) return false;
    
    // Check occupancy rate calculation
    final calculatedOccupancy = (capacity.totalBeds - capacity.availableBeds) / capacity.totalBeds;
    if ((calculatedOccupancy - capacity.occupancyRate).abs() > 0.01) return false;
    
    return true;
  }

  // ============================================================================
  // DEVELOPMENT UTILITIES
  // ============================================================================

  /// Reset all development data (use with caution!)
  Future<void> resetDevelopmentData() async {
    try {
      _logger.w('Resetting all development data...');

      // This is a destructive operation - only for development
      final batch = _firestoreService.getFirestoreBatch();

      // Delete all hospitals
      final hospitalsQuery = await _firestoreService.getAllDocumentsFromCollection('hospitals');
      for (final doc in hospitalsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete all capacities
      final capacitiesQuery = await _firestoreService.getAllDocumentsFromCollection('hospital_capacity');
      for (final doc in capacitiesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete all patient data
      final vitalsQuery = await _firestoreService.getAllDocumentsFromCollection('patient_vitals');
      for (final doc in vitalsQuery.docs) {
        batch.delete(doc.reference);
      }

      final triageQuery = await _firestoreService.getAllDocumentsFromCollection('triage_results');
      for (final doc in triageQuery.docs) {
        batch.delete(doc.reference);
      }

      final consentsQuery = await _firestoreService.getAllDocumentsFromCollection('patient_consents');
      for (final doc in consentsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.i('Development data reset completed');
    } catch (e) {
      _logger.e('Failed to reset development data: $e');
      rethrow;
    }
  }

  /// Reseed all data (reset + seed)
  Future<void> reseedAllData() async {
    try {
      _logger.i('Reseeding all data...');
      
      await resetDevelopmentData();
      await seedHospitalData();
      await generateSamplePatientData();
      
      final validation = await validateDataIntegrity();
      _logger.i('Reseeding completed with ${(validation.overallScore * 100).toStringAsFixed(1)}% validation score');
    } catch (e) {
      _logger.e('Failed to reseed data: $e');
      rethrow;
    }
  }

  /// Get data statistics
  Future<DataStatistics> getDataStatistics() async {
    try {
      final stats = DataStatistics();

      // Hospital statistics
      final hospitals = await _firestoreService.getHospitals(limit: 1000);
      stats.totalHospitals = hospitals.length;
      stats.activeHospitals = hospitals.where((h) => h.isActive).length;
      stats.traumaLevel1Hospitals = hospitals.where((h) => h.traumaLevel == 1).length;

      // Capacity statistics
      final hospitalIds = hospitals.map((h) => h.id).toList();
      final capacities = await _firestoreService.getHospitalCapacities(hospitalIds);
      stats.totalCapacityRecords = capacities.length;
      stats.averageOccupancyRate = capacities.isNotEmpty
          ? capacities.fold<double>(0, (sum, c) => sum + c.occupancyRate) / capacities.length
          : 0.0;

      // Patient data statistics (sample counts)
      final vitalsQuery = await _firestoreService.getCountFromCollection('patient_vitals');
      stats.totalVitalsRecords = vitalsQuery.count ?? 0;

      final triageQuery = await _firestoreService.getCountFromCollection('triage_results');
      stats.totalTriageResults = triageQuery.count ?? 0;

      final consentsQuery = await _firestoreService.getCountFromCollection('patient_consents');
      stats.totalConsentRecords = consentsQuery.count ?? 0;

      return stats;
    } catch (e) {
      _logger.e('Failed to get data statistics: $e');
      return DataStatistics();
    }
  }
}

// ============================================================================
// SUPPORTING CLASSES
// ============================================================================

class ValidationResult {
  int hospitalCount = 0;
  int hospitalsValid = 0;
  int capacityCount = 0;
  int capacitiesValid = 0;
  int orphanedCapacities = 0;
  int staleCapacities = 0;
  double hospitalValidationScore = 0.0;
  double capacityValidationScore = 0.0;
  double overallScore = 0.0;
  String? error;

  ValidationResult();

  ValidationResult.error(this.error);

  bool get isValid => error == null && overallScore > 0.9;
  bool get hasWarnings => orphanedCapacities > 0 || staleCapacities > 0;
}

class DataStatistics {
  int totalHospitals = 0;
  int activeHospitals = 0;
  int traumaLevel1Hospitals = 0;
  int totalCapacityRecords = 0;
  double averageOccupancyRate = 0.0;
  int totalVitalsRecords = 0;
  int totalTriageResults = 0;
  int totalConsentRecords = 0;

  @override
  String toString() {
    return '''
Data Statistics:
- Hospitals: $totalHospitals total, $activeHospitals active, $traumaLevel1Hospitals trauma level 1
- Capacity Records: $totalCapacityRecords (avg occupancy: ${(averageOccupancyRate * 100).toStringAsFixed(1)}%)
- Patient Data: $totalVitalsRecords vitals, $totalTriageResults triage results, $totalConsentRecords consents
''';
  }
}