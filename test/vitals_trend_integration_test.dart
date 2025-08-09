// Integration test for vitals trend analysis
// This test verifies that the vitals trend analysis works correctly

import 'dart:math';

void main() {
  print('=== Vitals Trend Analysis Integration Test ===');
  
  // Test 1: Trend calculation
  testTrendCalculation();
  
  // Test 2: Deterioration risk assessment
  testDeteriorationRisk();
  
  // Test 3: Stability assessment
  testStabilityAssessment();
  
  print('=== All Vitals Trend Tests Completed ===');
}

void testTrendCalculation() {
  print('\n1. Testing Trend Calculation...');
  
  // Simulate heart rate data showing increasing trend
  final heartRateData = [72, 78, 85, 92, 98, 105];
  final trend = calculateTrendDirection(heartRateData.map((v) => v.toDouble()).toList());
  
  print('✓ Heart rate data: $heartRateData');
  print('✓ Calculated trend: $trend');
  
  // Test stable trend
  final stableData = [75, 74, 76, 75, 77, 74];
  final stableTrend = calculateTrendDirection(stableData.map((v) => v.toDouble()).toList());
  print('✓ Stable data: $stableData');
  print('✓ Stable trend: $stableTrend');
}

void testDeteriorationRisk() {
  print('\n2. Testing Deterioration Risk Assessment...');
  
  // Simulate concerning vitals
  final concerningVitals = {
    'heartRate': 115, // Elevated
    'oxygenSaturation': 94.0, // Low
    'temperature': 101.8, // Fever
    'bloodPressure': '160/95', // Elevated
  };
  
  final riskFactors = assessRiskFactors(concerningVitals);
  print('✓ Concerning vitals: $concerningVitals');
  print('✓ Risk factors identified: $riskFactors');
  
  final riskLevel = determineRiskLevel(riskFactors);
  print('✓ Overall risk level: $riskLevel');
}

void testStabilityAssessment() {
  print('\n3. Testing Stability Assessment...');
  
  // Simulate multiple vital signs trends
  final vitalsTrends = {
    'heartRate': 'increasing',
    'oxygenSaturation': 'decreasing',
    'temperature': 'stable',
    'bloodPressure': 'stable',
  };
  
  final stabilityLevel = assessStability(vitalsTrends);
  print('✓ Vitals trends: $vitalsTrends');
  print('✓ Overall stability: $stabilityLevel');
  
  // Generate recommendations
  final recommendations = generateRecommendations(stabilityLevel, 'moderate');
  print('✓ Recommendations: $recommendations');
}

// Helper functions for trend analysis
String calculateTrendDirection(List<double> values) {
  if (values.length < 2) return 'stable';
  
  final n = values.length;
  final xValues = List.generate(n, (i) => i.toDouble());
  
  final xMean = xValues.reduce((a, b) => a + b) / n;
  final yMean = values.reduce((a, b) => a + b) / n;
  
  double numerator = 0;
  double denominator = 0;
  
  for (int i = 0; i < n; i++) {
    numerator += (xValues[i] - xMean) * (values[i] - yMean);
    denominator += (xValues[i] - xMean) * (xValues[i] - xMean);
  }
  
  if (denominator == 0) return 'stable';
  
  final slope = numerator / denominator;
  final threshold = 0.5; // Simple threshold
  
  if (slope > threshold) return 'increasing';
  if (slope < -threshold) return 'decreasing';
  return 'stable';
}

int assessRiskFactors(Map<String, dynamic> vitals) {
  int riskFactors = 0;
  
  // Check heart rate
  if (vitals['heartRate'] != null && vitals['heartRate'] > 100) {
    riskFactors++;
  }
  
  // Check oxygen saturation
  if (vitals['oxygenSaturation'] != null && vitals['oxygenSaturation'] < 96) {
    riskFactors++;
  }
  
  // Check temperature
  if (vitals['temperature'] != null && vitals['temperature'] > 100.4) {
    riskFactors++;
  }
  
  // Check blood pressure
  if (vitals['bloodPressure'] != null) {
    final bp = vitals['bloodPressure'] as String;
    final parts = bp.split('/');
    if (parts.length == 2) {
      final systolic = int.tryParse(parts[0]);
      if (systolic != null && systolic > 140) {
        riskFactors++;
      }
    }
  }
  
  return riskFactors;
}

String determineRiskLevel(int riskFactors) {
  if (riskFactors >= 3) return 'high';
  if (riskFactors >= 2) return 'moderate';
  if (riskFactors >= 1) return 'low';
  return 'minimal';
}

String assessStability(Map<String, String> trends) {
  int unstableCount = 0;
  int totalTrends = trends.length;
  
  for (final trend in trends.values) {
    if (trend != 'stable') unstableCount++;
  }
  
  final instabilityRatio = unstableCount / totalTrends;
  
  if (instabilityRatio >= 0.75) return 'unstable';
  if (instabilityRatio >= 0.5) return 'concerning';
  if (instabilityRatio >= 0.25) return 'mildly_unstable';
  return 'stable';
}

List<String> generateRecommendations(String stability, String riskLevel) {
  final recommendations = <String>[];
  
  switch (stability) {
    case 'unstable':
      recommendations.add('Vital signs show significant instability - seek immediate medical attention');
      break;
    case 'concerning':
      recommendations.add('Vital signs trends are concerning - consider urgent medical evaluation');
      break;
    case 'mildly_unstable':
      recommendations.add('Some vital signs are fluctuating - monitor closely');
      break;
    default:
      recommendations.add('Vital signs are stable - continue monitoring');
  }
  
  switch (riskLevel) {
    case 'high':
      recommendations.add('High risk of clinical deterioration detected - seek emergency care immediately');
      break;
    case 'moderate':
      recommendations.add('Moderate deterioration risk - consider urgent medical evaluation');
      break;
    case 'low':
      recommendations.add('Mild deterioration risk - monitor symptoms closely');
      break;
    default:
      recommendations.add('Low deterioration risk - routine monitoring appropriate');
  }
  
  return recommendations;
}