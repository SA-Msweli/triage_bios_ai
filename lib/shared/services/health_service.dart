import 'package:health/health.dart';
import 'package:logger/logger.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Logger _logger = Logger();
  Health? _health;

  // Health data types we want to access
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
  ];

  Future<bool> initialize() async {
    try {
      _health = Health();
      
      // Request permissions
      final permissions = _dataTypes.map((type) => 
          HealthDataAccess.READ).toList();
      
      final authorized = await _health!.requestAuthorization(
        _dataTypes,
        permissions: permissions,
      );

      if (authorized) {
        _logger.i('Health permissions granted');
        return true;
      } else {
        _logger.w('Health permissions denied');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to initialize health service: $e');
      return false;
    }
  }

  Future<PatientVitals?> getLatestVitals() async {
    if (_health == null) {
      await initialize();
    }

    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Get health data from the last 24 hours
      final healthData = await _health!.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: yesterday,
        endTime: now,
      );

      if (healthData.isEmpty) {
        _logger.w('No health data available');
        return null;
      }

      // Process the health data to extract latest vitals
      int? heartRate;
      String? bloodPressure;
      double? temperature;
      double? oxygenSaturation;
      int? respiratoryRate;
      double? heartRateVariability;
      DateTime? latestTimestamp;
      String deviceSource = 'Unknown';

      // Sort by date to get most recent values
      healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));

      for (final data in healthData) {
        switch (data.type) {
          case HealthDataType.HEART_RATE:
            if (heartRate == null) {
              heartRate = (data.value as NumericHealthValue).numericValue.toInt();
              latestTimestamp ??= data.dateTo;
              deviceSource = data.sourceName;
            }
            break;
          case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
            // We need both systolic and diastolic
            final systolic = (data.value as NumericHealthValue).numericValue.toInt();
            final diastolicData = healthData
                .where((d) => d.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC)
                .where((d) => d.dateTo.isAtSameMomentAs(data.dateTo))
                .firstOrNull;
            if (diastolicData != null && bloodPressure == null) {
              final diastolic = (diastolicData.value as NumericHealthValue).numericValue.toInt();
              bloodPressure = '$systolic/$diastolic';
              latestTimestamp ??= data.dateTo;
            }
            break;
          case HealthDataType.BODY_TEMPERATURE:
            if (temperature == null) {
              // Convert Celsius to Fahrenheit if needed
              double temp = (data.value as NumericHealthValue).numericValue.toDouble();
              if (temp < 50) { // Assume Celsius if less than 50
                temp = (temp * 9/5) + 32;
              }
              temperature = temp;
              latestTimestamp ??= data.dateTo;
            }
            break;
          case HealthDataType.BLOOD_OXYGEN:
            if (oxygenSaturation == null) {
              oxygenSaturation = (data.value as NumericHealthValue).numericValue.toDouble();
              latestTimestamp ??= data.dateTo;
            }
            break;
          case HealthDataType.RESPIRATORY_RATE:
            if (respiratoryRate == null) {
              respiratoryRate = (data.value as NumericHealthValue).numericValue.toInt();
              latestTimestamp ??= data.dateTo;
            }
            break;
          default:
            break;
        }
      }

      if (latestTimestamp == null) {
        _logger.w('No valid health data found');
        return null;
      }

      // Calculate data quality based on how recent and complete the data is
      final dataAge = now.difference(latestTimestamp).inMinutes;
      double dataQuality = 1.0;
      if (dataAge > 60) dataQuality *= 0.8; // Reduce quality for old data
      if (dataAge > 180) dataQuality *= 0.6;
      if (dataAge > 360) dataQuality *= 0.4;

      // Boost quality if we have multiple vital signs
      int vitalCount = 0;
      if (heartRate != null) vitalCount++;
      if (bloodPressure != null) vitalCount++;
      if (temperature != null) vitalCount++;
      if (oxygenSaturation != null) vitalCount++;
      if (respiratoryRate != null) vitalCount++;

      dataQuality *= (vitalCount / 5.0).clamp(0.3, 1.0);

      final vitals = PatientVitals(
        heartRate: heartRate,
        bloodPressure: bloodPressure,
        temperature: temperature,
        oxygenSaturation: oxygenSaturation,
        respiratoryRate: respiratoryRate,
        heartRateVariability: heartRateVariability,
        timestamp: latestTimestamp,
        deviceSource: deviceSource,
        dataQuality: dataQuality,
      );

      _logger.i('Retrieved vitals: HR=$heartRate, BP=$bloodPressure, Temp=$temperature, SpO2=$oxygenSaturation');
      return vitals;

    } catch (e) {
      _logger.e('Failed to get health data: $e');
      return null;
    }
  }

  Future<bool> hasHealthPermissions() async {
    try {
      if (_health == null) return false;
      
      // Check if we have permission for at least heart rate
      final hasPermission = await _health!.hasPermissions(_dataTypes);
      return hasPermission ?? false;
    } catch (e) {
      _logger.e('Failed to check health permissions: $e');
      return false;
    }
  }

  Future<void> requestPermissions() async {
    try {
      await initialize();
    } catch (e) {
      _logger.e('Failed to request health permissions: $e');
    }
  }
}