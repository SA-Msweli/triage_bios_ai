import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';

/// Service for tracking and analyzing vital signs trends over time
class VitalsTrendService {
  static final VitalsTrendService _instance = VitalsTrendService._internal();
  factory VitalsTrendService() => _instance;
  VitalsTrendService._internal();

  final Logger _logger = Logger();
  static const String _vitalsHistoryKey = 'vitals_history';
  static const int _maxHistoryEntries = 50; // Keep last 50 readings

  /// Store a new vitals reading
  Future<void> storeVitalsReading(PatientVitals vitals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_vitalsHistoryKey);

      List<Map<String, dynamic>> history = [];
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson) as List;
        history = decoded.cast<Map<String, dynamic>>();
      }

      // Add new reading
      history.add({
        'timestamp': vitals.timestamp.millisecondsSinceEpoch,
        'heartRate': vitals.heartRate,
        'bloodPressure': vitals.bloodPressure,
        'temperature': vitals.temperature,
        'oxygenSaturation': vitals.oxygenSaturation,
        'respiratoryRate': vitals.respiratoryRate,
        'heartRateVariability': vitals.heartRateVariability,
        'deviceSource': vitals.deviceSource,
        'dataQuality': vitals.dataQuality,
      });

      // Keep only recent entries
      if (history.length > _maxHistoryEntries) {
        history = history.sublist(history.length - _maxHistoryEntries);
      }

      // Sort by timestamp
      history.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );

      // Save back to storage
      await prefs.setString(_vitalsHistoryKey, jsonEncode(history));

      _logger.i(
        'Stored vitals reading: HR=${vitals.heartRate}, SpO2=${vitals.oxygenSaturation}',
      );
    } catch (e) {
      _logger.e('Failed to store vitals reading: $e');
    }
  }

  /// Get vitals history
  Future<List<PatientVitals>> getVitalsHistory({int? limitHours}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_vitalsHistoryKey);

      if (historyJson == null) return [];

      final decoded = jsonDecode(historyJson) as List;
      final history = decoded.cast<Map<String, dynamic>>();

      // Filter by time if specified
      List<Map<String, dynamic>> filteredHistory = history;
      if (limitHours != null) {
        final cutoffTime = DateTime.now().subtract(Duration(hours: limitHours));
        filteredHistory = history.where((entry) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            entry['timestamp'] as int,
          );
          return timestamp.isAfter(cutoffTime);
        }).toList();
      }

      // Convert to PatientVitals objects
      return filteredHistory
          .map(
            (entry) => PatientVitals(
              heartRate: entry['heartRate'] as int?,
              bloodPressure: entry['bloodPressure'] as String?,
              temperature: entry['temperature'] as double?,
              oxygenSaturation: entry['oxygenSaturation'] as double?,
              respiratoryRate: entry['respiratoryRate'] as int?,
              heartRateVariability: entry['heartRateVariability'] as double?,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                entry['timestamp'] as int,
              ),
              deviceSource: entry['deviceSource'] as String?,
              dataQuality: entry['dataQuality'] as double?,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get vitals history: $e');
      return [];
    }
  }

  /// Analyze trends in vital signs
  Future<VitalsTrendAnalysis> analyzeTrends({int hoursBack = 24}) async {
    final history = await getVitalsHistory(limitHours: hoursBack);

    if (history.length < 2) {
      return VitalsTrendAnalysis.noData();
    }

    _logger.i(
      'Analyzing trends for ${history.length} vitals readings over $hoursBack hours',
    );

    return VitalsTrendAnalysis(
      heartRateTrend: _analyzeHeartRateTrend(history),
      oxygenSaturationTrend: _analyzeOxygenTrend(history),
      temperatureTrend: _analyzeTemperatureTrend(history),
      bloodPressureTrend: _analyzeBloodPressureTrend(history),
      overallStability: _assessOverallStability(history),
      deteriorationRisk: _assessDeteriorationRisk(history),
      recommendations: _generateTrendRecommendations(history),
      dataPoints: history.length,
      timeSpanHours: hoursBack,
    );
  }

  /// Analyze heart rate trends
  TrendDirection _analyzeHeartRateTrend(List<PatientVitals> history) {
    final heartRates = history
        .where((v) => v.heartRate != null)
        .map((v) => v.heartRate!.toDouble())
        .toList();

    if (heartRates.length < 2) return TrendDirection.stable;

    return _calculateTrendDirection(heartRates);
  }

  /// Analyze oxygen saturation trends
  TrendDirection _analyzeOxygenTrend(List<PatientVitals> history) {
    final oxygenLevels = history
        .where((v) => v.oxygenSaturation != null)
        .map((v) => v.oxygenSaturation!)
        .toList();

    if (oxygenLevels.length < 2) return TrendDirection.stable;

    return _calculateTrendDirection(oxygenLevels);
  }

  /// Analyze temperature trends
  TrendDirection _analyzeTemperatureTrend(List<PatientVitals> history) {
    final temperatures = history
        .where((v) => v.temperature != null)
        .map((v) => v.temperature!)
        .toList();

    if (temperatures.length < 2) return TrendDirection.stable;

    return _calculateTrendDirection(temperatures);
  }

  /// Analyze blood pressure trends
  BloodPressureTrend _analyzeBloodPressureTrend(List<PatientVitals> history) {
    final systolicValues = <double>[];
    final diastolicValues = <double>[];

    for (final vitals in history) {
      if (vitals.bloodPressure != null) {
        final bp = _parseBloodPressure(vitals.bloodPressure!);
        if (bp != null) {
          systolicValues.add(bp['systolic']!.toDouble());
          diastolicValues.add(bp['diastolic']!.toDouble());
        }
      }
    }

    if (systolicValues.length < 2) {
      return BloodPressureTrend(
        systolicTrend: TrendDirection.stable,
        diastolicTrend: TrendDirection.stable,
      );
    }

    return BloodPressureTrend(
      systolicTrend: _calculateTrendDirection(systolicValues),
      diastolicTrend: _calculateTrendDirection(diastolicValues),
    );
  }

  /// Calculate trend direction using linear regression
  TrendDirection _calculateTrendDirection(List<double> values) {
    if (values.length < 2) return TrendDirection.stable;

    // Simple linear regression to determine trend
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

    if (denominator == 0) return TrendDirection.stable;

    final slope = numerator / denominator;

    // Determine trend based on slope and significance
    final slopeThreshold = _calculateSlopeThreshold(values);

    if (slope > slopeThreshold) return TrendDirection.increasing;
    if (slope < -slopeThreshold) return TrendDirection.decreasing;
    return TrendDirection.stable;
  }

  /// Calculate appropriate slope threshold based on data variability
  double _calculateSlopeThreshold(List<double> values) {
    if (values.isEmpty) return 0.1;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final standardDeviation = variance > 0 ? variance : 0.1;

    // Threshold is 10% of standard deviation
    return standardDeviation * 0.1;
  }

  /// Assess overall stability of vital signs
  StabilityLevel _assessOverallStability(List<PatientVitals> history) {
    if (history.length < 3) return StabilityLevel.unknown;

    int unstableCount = 0;
    int totalTrends = 0;

    // Check heart rate stability
    final hrTrend = _analyzeHeartRateTrend(history);
    if (hrTrend != TrendDirection.stable) unstableCount++;
    totalTrends++;

    // Check oxygen saturation stability
    final o2Trend = _analyzeOxygenTrend(history);
    if (o2Trend != TrendDirection.stable) unstableCount++;
    totalTrends++;

    // Check temperature stability
    final tempTrend = _analyzeTemperatureTrend(history);
    if (tempTrend != TrendDirection.stable) unstableCount++;
    totalTrends++;

    // Check blood pressure stability
    final bpTrend = _analyzeBloodPressureTrend(history);
    if (bpTrend.systolicTrend != TrendDirection.stable ||
        bpTrend.diastolicTrend != TrendDirection.stable)
      unstableCount++;
    totalTrends++;

    final instabilityRatio = unstableCount / totalTrends;

    if (instabilityRatio >= 0.75) return StabilityLevel.unstable;
    if (instabilityRatio >= 0.5) return StabilityLevel.concerning;
    if (instabilityRatio >= 0.25) return StabilityLevel.mildlyUnstable;
    return StabilityLevel.stable;
  }

  /// Assess risk of clinical deterioration
  DeteriorationRisk _assessDeteriorationRisk(List<PatientVitals> history) {
    if (history.length < 2) return DeteriorationRisk.unknown;

    final latest = history.last;
    int riskFactors = 0;

    // Check for concerning trends
    final hrTrend = _analyzeHeartRateTrend(history);
    final o2Trend = _analyzeOxygenTrend(history);
    final tempTrend = _analyzeTemperatureTrend(history);

    // Concerning heart rate trends
    if (hrTrend == TrendDirection.increasing &&
        latest.heartRate != null &&
        latest.heartRate! > 100) {
      riskFactors++;
    }

    // Concerning oxygen trends
    if (o2Trend == TrendDirection.decreasing &&
        latest.oxygenSaturation != null &&
        latest.oxygenSaturation! < 96) {
      riskFactors++;
    }

    // Concerning temperature trends
    if (tempTrend == TrendDirection.increasing &&
        latest.temperature != null &&
        latest.temperature! > 100.4) {
      riskFactors++;
    }

    // Check for rapid changes
    if (history.length >= 3) {
      final recent = history.sublist(history.length - 3);
      if (_hasRapidChanges(recent)) riskFactors++;
    }

    // Assess overall risk
    if (riskFactors >= 3) return DeteriorationRisk.high;
    if (riskFactors >= 2) return DeteriorationRisk.moderate;
    if (riskFactors >= 1) return DeteriorationRisk.low;
    return DeteriorationRisk.minimal;
  }

  /// Check for rapid changes in vital signs
  bool _hasRapidChanges(List<PatientVitals> recentReadings) {
    if (recentReadings.length < 3) return false;

    // Check for rapid heart rate changes (>20 bpm in short time)
    final heartRates = recentReadings
        .where((v) => v.heartRate != null)
        .map((v) => v.heartRate!)
        .toList();

    if (heartRates.length >= 2) {
      final hrChange = (heartRates.last - heartRates.first).abs();
      if (hrChange > 20) return true;
    }

    // Check for rapid oxygen saturation drops (>3% in short time)
    final oxygenLevels = recentReadings
        .where((v) => v.oxygenSaturation != null)
        .map((v) => v.oxygenSaturation!)
        .toList();

    if (oxygenLevels.length >= 2) {
      final o2Change = (oxygenLevels.last - oxygenLevels.first).abs();
      if (o2Change > 3.0) return true;
    }

    return false;
  }

  /// Generate recommendations based on trends
  List<String> _generateTrendRecommendations(List<PatientVitals> history) {
    final recommendations = <String>[];

    final stability = _assessOverallStability(history);
    final deteriorationRisk = _assessDeteriorationRisk(history);

    // Stability-based recommendations
    switch (stability) {
      case StabilityLevel.unstable:
        recommendations.add(
          'Vital signs show significant instability - seek immediate medical attention',
        );
        break;
      case StabilityLevel.concerning:
        recommendations.add(
          'Vital signs trends are concerning - consider urgent medical evaluation',
        );
        break;
      case StabilityLevel.mildlyUnstable:
        recommendations.add(
          'Some vital signs are fluctuating - monitor closely and consider medical consultation',
        );
        break;
      case StabilityLevel.stable:
        recommendations.add('Vital signs are stable - continue monitoring');
        break;
      case StabilityLevel.unknown:
        recommendations.add(
          'Insufficient data for trend analysis - continue collecting vitals',
        );
        break;
    }

    // Deterioration risk recommendations
    switch (deteriorationRisk) {
      case DeteriorationRisk.high:
        recommendations.add(
          'High risk of clinical deterioration detected - seek emergency care immediately',
        );
        break;
      case DeteriorationRisk.moderate:
        recommendations.add(
          'Moderate deterioration risk - consider urgent medical evaluation',
        );
        break;
      case DeteriorationRisk.low:
        recommendations.add(
          'Mild deterioration risk - monitor symptoms and vital signs closely',
        );
        break;
      case DeteriorationRisk.minimal:
        recommendations.add(
          'Low deterioration risk - routine monitoring appropriate',
        );
        break;
      case DeteriorationRisk.unknown:
        recommendations.add(
          'Unable to assess deterioration risk - continue monitoring',
        );
        break;
    }

    return recommendations;
  }

  /// Helper method to parse blood pressure
  Map<String, int>? _parseBloodPressure(String bp) {
    final parts = bp.split('/');
    if (parts.length != 2) return null;

    final systolic = int.tryParse(parts[0]);
    final diastolic = int.tryParse(parts[1]);

    if (systolic == null || diastolic == null) return null;

    return {'systolic': systolic, 'diastolic': diastolic};
  }

  /// Clear vitals history (for testing or privacy)
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_vitalsHistoryKey);
      _logger.i('Vitals history cleared');
    } catch (e) {
      _logger.e('Failed to clear vitals history: $e');
    }
  }
}

/// Comprehensive trend analysis result
class VitalsTrendAnalysis {
  final TrendDirection heartRateTrend;
  final TrendDirection oxygenSaturationTrend;
  final TrendDirection temperatureTrend;
  final BloodPressureTrend bloodPressureTrend;
  final StabilityLevel overallStability;
  final DeteriorationRisk deteriorationRisk;
  final List<String> recommendations;
  final int dataPoints;
  final int timeSpanHours;

  VitalsTrendAnalysis({
    required this.heartRateTrend,
    required this.oxygenSaturationTrend,
    required this.temperatureTrend,
    required this.bloodPressureTrend,
    required this.overallStability,
    required this.deteriorationRisk,
    required this.recommendations,
    required this.dataPoints,
    required this.timeSpanHours,
  });

  factory VitalsTrendAnalysis.noData() {
    return VitalsTrendAnalysis(
      heartRateTrend: TrendDirection.stable,
      oxygenSaturationTrend: TrendDirection.stable,
      temperatureTrend: TrendDirection.stable,
      bloodPressureTrend: BloodPressureTrend(
        systolicTrend: TrendDirection.stable,
        diastolicTrend: TrendDirection.stable,
      ),
      overallStability: StabilityLevel.unknown,
      deteriorationRisk: DeteriorationRisk.unknown,
      recommendations: ['Insufficient data for trend analysis'],
      dataPoints: 0,
      timeSpanHours: 0,
    );
  }
}

class BloodPressureTrend {
  final TrendDirection systolicTrend;
  final TrendDirection diastolicTrend;

  BloodPressureTrend({
    required this.systolicTrend,
    required this.diastolicTrend,
  });
}

enum TrendDirection { increasing, decreasing, stable }

enum StabilityLevel { stable, mildlyUnstable, concerning, unstable, unknown }

enum DeteriorationRisk { minimal, low, moderate, high, unknown }
