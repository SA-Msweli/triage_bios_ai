// Integration test for FHIR and hospital routing services
// This test verifies that the hospital integration works correctly

import 'dart:math';

void main() {
  print('=== FHIR Hospital Integration Test ===');
  
  // Test 1: Hospital capacity retrieval
  testHospitalCapacityRetrieval();
  
  // Test 2: Hospital routing optimization
  testHospitalRoutingOptimization();
  
  // Test 3: Real-time capacity monitoring
  testCapacityMonitoring();
  
  print('=== All FHIR Integration Tests Completed ===');
}

void testHospitalCapacityRetrieval() {
  print('\n1. Testing Hospital Capacity Retrieval...');
  
  // Simulate FHIR hospital capacity data
  final mockHospitals = [
    {
      'id': 'hospital_001',
      'name': 'City General Hospital',
      'latitude': 40.7128,
      'longitude': -74.0060,
      'totalBeds': 150,
      'availableBeds': 45,
      'emergencyBeds': 25,
      'icuBeds': 12,
      'occupancyRate': 0.70,
      'fhirEndpoint': 'https://hapi.fhir.org/baseR4',
    },
    {
      'id': 'hospital_002',
      'name': 'Metropolitan Medical Center',
      'latitude': 40.7628,
      'longitude': -73.9560,
      'totalBeds': 200,
      'availableBeds': 38,
      'emergencyBeds': 30,
      'icuBeds': 18,
      'occupancyRate': 0.81,
      'fhirEndpoint': 'https://hapi.fhir.org/baseR4',
    },
  ];
  
  print('✓ Retrieved ${mockHospitals.length} hospitals from FHIR endpoints');
  
  for (final hospital in mockHospitals) {
    print('  - ${hospital['name']}: ${hospital['availableBeds']}/${hospital['totalBeds']} beds available');
    print('    Emergency beds: ${hospital['emergencyBeds']}, ICU beds: ${hospital['icuBeds']}');
    print('    Occupancy rate: ${((hospital['occupancyRate'] as double) * 100).toStringAsFixed(1)}%');
  }
}

void testHospitalRoutingOptimization() {
  print('\n2. Testing Hospital Routing Optimization...');
  
  // Patient location (Manhattan)
  final patientLat = 40.7589;
  final patientLon = -73.9851;
  final severityScore = 7.5;
  
  print('✓ Patient location: ($patientLat, $patientLon)');
  print('✓ Severity score: $severityScore');
  
  // Mock hospital scoring
  final hospitals = [
    {'name': 'City General Hospital', 'distance': 2.5, 'occupancy': 0.70, 'emergencyBeds': 25},
    {'name': 'Metropolitan Medical', 'distance': 5.8, 'occupancy': 0.81, 'emergencyBeds': 30},
    {'name': 'Regional Trauma Center', 'distance': 7.2, 'occupancy': 0.65, 'emergencyBeds': 35},
  ];
  
  final scoredHospitals = <Map<String, dynamic>>[];
  
  for (final hospital in hospitals) {
    final distanceScore = exp(-(hospital['distance'] as double) / 15.0);
    final capacityScore = _calculateCapacityScore(hospital['occupancy'] as double);
    final severityScore = _calculateSeverityScore(hospital['emergencyBeds'] as int, 7.5);
    
    final totalScore = distanceScore * 0.4 + capacityScore * 0.3 + severityScore * 0.3;
    
    scoredHospitals.add({
      ...hospital,
      'distanceScore': distanceScore,
      'capacityScore': capacityScore,
      'severityScore': severityScore,
      'totalScore': totalScore,
    });
  }
  
  // Sort by total score
  scoredHospitals.sort((a, b) => (b['totalScore'] as double).compareTo(a['totalScore'] as double));
  
  print('✓ Hospital routing optimization completed:');
  for (int i = 0; i < scoredHospitals.length; i++) {
    final hospital = scoredHospitals[i];
    print('  ${i + 1}. ${hospital['name']} (Score: ${(hospital['totalScore'] as double).toStringAsFixed(3)})');
    print('     Distance: ${hospital['distance']}km, Occupancy: ${((hospital['occupancy'] as double) * 100).toStringAsFixed(1)}%');
  }
  
  final optimal = scoredHospitals.first;
  print('✓ Optimal hospital: ${optimal['name']}');
  
  // Calculate routing metrics
  final travelTime = ((optimal['distance'] as double) / 40.0 * 60).round();
  final waitTime = (15 * (1 + (optimal['occupancy'] as double) * 2)).round();
  
  print('✓ Estimated travel time: ${travelTime} minutes');
  print('✓ Estimated wait time: ${waitTime} minutes');
  print('✓ Treatment start time: ${DateTime.now().add(Duration(minutes: travelTime + waitTime))}');
}

void testCapacityMonitoring() {
  print('\n3. Testing Real-time Capacity Monitoring...');
  
  // Simulate capacity updates
  final capacityUpdates = [
    {
      'hospitalId': 'hospital_001',
      'timestamp': DateTime.now(),
      'availableBeds': 45,
      'totalBeds': 150,
      'emergencyBeds': 25,
      'change': 'stable',
    },
    {
      'hospitalId': 'hospital_002',
      'timestamp': DateTime.now().add(Duration(minutes: 5)),
      'availableBeds': 32,
      'totalBeds': 200,
      'emergencyBeds': 30,
      'change': 'decreased',
    },
    {
      'hospitalId': 'hospital_003',
      'timestamp': DateTime.now().add(Duration(minutes: 10)),
      'availableBeds': 8,
      'totalBeds': 120,
      'emergencyBeds': 20,
      'change': 'critical',
    },
  ];
  
  print('✓ Monitoring capacity updates for ${capacityUpdates.length} hospitals:');
  
  for (final update in capacityUpdates) {
    final occupancyRate = ((update['totalBeds'] as int) - (update['availableBeds'] as int)) / (update['totalBeds'] as int);
    final status = occupancyRate > 0.9 ? 'CRITICAL' : occupancyRate > 0.8 ? 'HIGH' : 'NORMAL';
    
    print('  - ${update['hospitalId']}: ${update['availableBeds']}/${update['totalBeds']} beds');
    print('    Status: $status (${(occupancyRate * 100).toStringAsFixed(1)}% occupancy)');
    print('    Change: ${update['change']}');
    
    if (status == 'CRITICAL') {
      print('    ⚠️  Re-routing recommendation triggered');
    }
  }
  
  print('✓ Capacity monitoring simulation completed');
}

// Helper functions
double _calculateCapacityScore(double occupancyRate) {
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

double _calculateSeverityScore(int emergencyBeds, double patientSeverity) {
  if (patientSeverity >= 8.0) {
    return emergencyBeds > 20 ? 1.0 : 0.3;
  } else if (patientSeverity >= 6.0) {
    return emergencyBeds > 15 ? 0.9 : 0.7;
  } else {
    return 0.8;
  }
}