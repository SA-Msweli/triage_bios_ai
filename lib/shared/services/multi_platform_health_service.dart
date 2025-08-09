import 'dart:io';
import 'package:logger/logger.dart';
import '../../features/triage/domain/entities/patient_vitals.dart';

/// Multi-platform health service supporting various wearable devices
class MultiPlatformHealthService {
  static final MultiPlatformHealthService _instance = MultiPlatformHealthService._internal();
  factory MultiPlatformHealthService() => _instance;
  MultiPlatformHealthService._internal();

  final Logger _logger = Logger();
  
  // Platform-specific health services
  AppleHealthService? _appleHealth;
  GoogleHealthService? _googleHealth;
  SamsungHealthService? _samsungHealth;
  FitbitService? _fitbitService;
  
  List<WearableDevice> _connectedDevices = [];
  bool _isInitialized = false;

  /// Initialize all available health platforms
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _logger.i('Initializing multi-platform health service...');
      
      // Initialize platform-specific services
      if (Platform.isIOS) {
        _appleHealth = AppleHealthService();
        await _appleHealth!.initialize();
      }
      
      if (Platform.isAndroid) {
        _googleHealth = GoogleHealthService();
        await _googleHealth!.initialize();
        
        // Samsung Health is available on Android
        _samsungHealth = SamsungHealthService();
        await _samsungHealth!.initialize();
      }
      
      // Fitbit works on both platforms via Web API
      _fitbitService = FitbitService();
      await _fitbitService!.initialize();
      
      // Discover available devices
      await _discoverDevices();
      
      _isInitialized = true;
      _logger.i('Multi-platform health service initialized with ${_connectedDevices.length} devices');
      return true;
      
    } catch (e) {
      _logger.e('Failed to initialize multi-platform health service: $e');
      return false;
    }
  }

  /// Discover and pair available wearable devices
  Future<void> _discoverDevices() async {
    _connectedDevices.clear();
    
    // Check Apple devices (iOS only)
    if (_appleHealth != null) {
      final appleDevices = await _appleHealth!.getConnectedDevices();
      _connectedDevices.addAll(appleDevices);
    }
    
    // Check Google Health Connect devices (Android only)
    if (_googleHealth != null) {
      final googleDevices = await _googleHealth!.getConnectedDevices();
      _connectedDevices.addAll(googleDevices);
    }
    
    // Check Samsung Health devices (Android only)
    if (_samsungHealth != null) {
      final samsungDevices = await _samsungHealth!.getConnectedDevices();
      _connectedDevices.addAll(samsungDevices);
    }
    
    // Check Fitbit devices (both platforms)
    if (_fitbitService != null) {
      final fitbitDevices = await _fitbitService!.getConnectedDevices();
      _connectedDevices.addAll(fitbitDevices);
    }
    
    _logger.i('Discovered ${_connectedDevices.length} wearable devices');
  }

  /// Get latest vitals from all connected devices
  Future<PatientVitals?> getLatestVitals() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final List<PatientVitals> allVitals = [];
      
      // Collect vitals from all platforms
      if (_appleHealth != null) {
        final appleVitals = await _appleHealth!.getLatestVitals();
        if (appleVitals != null) allVitals.add(appleVitals);
      }
      
      if (_googleHealth != null) {
        final googleVitals = await _googleHealth!.getLatestVitals();
        if (googleVitals != null) allVitals.add(googleVitals);
      }
      
      if (_samsungHealth != null) {
        final samsungVitals = await _samsungHealth!.getLatestVitals();
        if (samsungVitals != null) allVitals.add(samsungVitals);
      }
      
      if (_fitbitService != null) {
        final fitbitVitals = await _fitbitService!.getLatestVitals();
        if (fitbitVitals != null) allVitals.add(fitbitVitals);
      }
      
      if (allVitals.isEmpty) {
        _logger.w('No vitals data available from any platform');
        return null;
      }
      
      // Merge vitals from multiple sources
      return _mergeVitalsData(allVitals);
      
    } catch (e) {
      _logger.e('Failed to get latest vitals: $e');
      return null;
    }
  }

  /// Merge vitals data from multiple sources, prioritizing most recent and reliable data
  PatientVitals _mergeVitalsData(List<PatientVitals> vitalsList) {
    // Sort by timestamp (most recent first) and data quality
    vitalsList.sort((a, b) {
      final timeComparison = b.timestamp.compareTo(a.timestamp);
      if (timeComparison != 0) return timeComparison;
      return (b.dataQuality ?? 0.0).compareTo(a.dataQuality ?? 0.0);
    });
    
    // Use the most recent timestamp as base
    final latestVitals = vitalsList.first;
    
    // Merge data, preferring higher quality readings
    int? bestHeartRate;
    String? bestBloodPressure;
    double? bestTemperature;
    double? bestOxygenSaturation;
    int? bestRespiratoryRate;
    double? bestHeartRateVariability;
    String deviceSources = '';
    double totalQuality = 0.0;
    int qualityCount = 0;
    
    for (final vitals in vitalsList) {
      final quality = vitals.dataQuality ?? 0.5;
      
      // Heart rate - prefer higher quality or more recent
      if (vitals.heartRate != null && 
          (bestHeartRate == null || quality > (vitalsList.firstWhere((v) => v.heartRate == bestHeartRate, orElse: () => vitals).dataQuality ?? 0.0))) {
        bestHeartRate = vitals.heartRate;
      }
      
      // Blood pressure
      if (vitals.bloodPressure != null && 
          (bestBloodPressure == null || quality > (vitalsList.firstWhere((v) => v.bloodPressure == bestBloodPressure, orElse: () => vitals).dataQuality ?? 0.0))) {
        bestBloodPressure = vitals.bloodPressure;
      }
      
      // Temperature
      if (vitals.temperature != null && 
          (bestTemperature == null || quality > (vitalsList.firstWhere((v) => v.temperature == bestTemperature, orElse: () => vitals).dataQuality ?? 0.0))) {
        bestTemperature = vitals.temperature;
      }
      
      // Oxygen saturation
      if (vitals.oxygenSaturation != null && 
          (bestOxygenSaturation == null || quality > (vitalsList.firstWhere((v) => v.oxygenSaturation == bestOxygenSaturation, orElse: () => vitals).dataQuality ?? 0.0))) {
        bestOxygenSaturation = vitals.oxygenSaturation;
      }
      
      // Respiratory rate
      if (vitals.respiratoryRate != null && 
          (bestRespiratoryRate == null || quality > (vitalsList.firstWhere((v) => v.respiratoryRate == bestRespiratoryRate, orElse: () => vitals).dataQuality ?? 0.0))) {
        bestRespiratoryRate = vitals.respiratoryRate;
      }
      
      // Heart rate variability
      if (vitals.heartRateVariability != null && 
          (bestHeartRateVariability == null || quality > (vitalsList.firstWhere((v) => v.heartRateVariability == bestHeartRateVariability, orElse: () => vitals).dataQuality ?? 0.0))) {
        bestHeartRateVariability = vitals.heartRateVariability;
      }
      
      // Collect device sources
      if (vitals.deviceSource != null && !deviceSources.contains(vitals.deviceSource!)) {
        if (deviceSources.isNotEmpty) deviceSources += ', ';
        deviceSources += vitals.deviceSource!;
      }
      
      totalQuality += quality;
      qualityCount++;
    }
    
    final averageQuality = qualityCount > 0 ? totalQuality / qualityCount : 0.5;
    
    _logger.i('Merged vitals from ${vitalsList.length} sources: $deviceSources');
    
    return PatientVitals(
      heartRate: bestHeartRate,
      bloodPressure: bestBloodPressure,
      temperature: bestTemperature,
      oxygenSaturation: bestOxygenSaturation,
      respiratoryRate: bestRespiratoryRate,
      heartRateVariability: bestHeartRateVariability,
      timestamp: latestVitals.timestamp,
      deviceSource: deviceSources.isNotEmpty ? deviceSources : 'Multi-platform',
      dataQuality: averageQuality,
    );
  }

  /// Get list of connected wearable devices
  List<WearableDevice> getConnectedDevices() {
    return List.unmodifiable(_connectedDevices);
  }

  /// Check if any health platforms have permissions
  Future<bool> hasHealthPermissions() async {
    if (!_isInitialized) await initialize();
    
    bool hasAnyPermissions = false;
    
    if (_appleHealth != null) {
      hasAnyPermissions |= await _appleHealth!.hasPermissions();
    }
    
    if (_googleHealth != null) {
      hasAnyPermissions |= await _googleHealth!.hasPermissions();
    }
    
    if (_samsungHealth != null) {
      hasAnyPermissions |= await _samsungHealth!.hasPermissions();
    }
    
    if (_fitbitService != null) {
      hasAnyPermissions |= await _fitbitService!.hasPermissions();
    }
    
    return hasAnyPermissions;
  }

  /// Request permissions from all available platforms
  Future<void> requestPermissions() async {
    if (!_isInitialized) await initialize();
    
    final futures = <Future<void>>[];
    
    if (_appleHealth != null) {
      futures.add(_appleHealth!.requestPermissions());
    }
    
    if (_googleHealth != null) {
      futures.add(_googleHealth!.requestPermissions());
    }
    
    if (_samsungHealth != null) {
      futures.add(_samsungHealth!.requestPermissions());
    }
    
    if (_fitbitService != null) {
      futures.add(_fitbitService!.requestPermissions());
    }
    
    await Future.wait(futures);
    
    // Refresh device list after permissions
    await _discoverDevices();
  }

  /// Get platform-specific health service status
  Map<String, bool> getPlatformStatus() {
    return {
      'Apple Health': _appleHealth != null,
      'Google Health Connect': _googleHealth != null,
      'Samsung Health': _samsungHealth != null,
      'Fitbit': _fitbitService != null,
    };
  }
}

/// Represents a connected wearable device
class WearableDevice {
  final String id;
  final String name;
  final String platform;
  final List<String> supportedDataTypes;
  final bool isConnected;
  final DateTime lastSync;
  final double batteryLevel;

  WearableDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.supportedDataTypes,
    required this.isConnected,
    required this.lastSync,
    this.batteryLevel = 0.0,
  });
}

/// Apple Health service implementation
class AppleHealthService {
  final Logger _logger = Logger();

  Future<bool> initialize() async {
    try {
      // Initialize Apple HealthKit
      _logger.i('Initializing Apple Health service');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize Apple Health: $e');
      return false;
    }
  }

  Future<List<WearableDevice>> getConnectedDevices() async {
    // Mock Apple devices for now
    return [
      WearableDevice(
        id: 'apple_watch_1',
        name: 'Apple Watch Series 9',
        platform: 'Apple Health',
        supportedDataTypes: ['heart_rate', 'blood_oxygen', 'temperature', 'blood_pressure'],
        isConnected: true,
        lastSync: DateTime.now().subtract(Duration(minutes: 5)),
        batteryLevel: 0.85,
      ),
    ];
  }

  Future<PatientVitals?> getLatestVitals() async {
    // Mock Apple Health data
    return PatientVitals(
      heartRate: 72,
      oxygenSaturation: 98.5,
      temperature: 98.6,
      timestamp: DateTime.now().subtract(Duration(minutes: 2)),
      deviceSource: 'Apple Watch',
      dataQuality: 0.95,
    );
  }

  Future<bool> hasPermissions() async => true;
  Future<void> requestPermissions() async {}
}

/// Google Health Connect service implementation
class GoogleHealthService {
  final Logger _logger = Logger();

  Future<bool> initialize() async {
    try {
      _logger.i('Initializing Google Health Connect service');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize Google Health Connect: $e');
      return false;
    }
  }

  Future<List<WearableDevice>> getConnectedDevices() async {
    return [
      WearableDevice(
        id: 'pixel_watch_1',
        name: 'Pixel Watch 2',
        platform: 'Google Health Connect',
        supportedDataTypes: ['heart_rate', 'blood_oxygen', 'respiratory_rate'],
        isConnected: true,
        lastSync: DateTime.now().subtract(Duration(minutes: 3)),
        batteryLevel: 0.72,
      ),
    ];
  }

  Future<PatientVitals?> getLatestVitals() async {
    return PatientVitals(
      heartRate: 75,
      respiratoryRate: 16,
      timestamp: DateTime.now().subtract(Duration(minutes: 1)),
      deviceSource: 'Pixel Watch',
      dataQuality: 0.88,
    );
  }

  Future<bool> hasPermissions() async => true;
  Future<void> requestPermissions() async {}
}

/// Samsung Health service implementation
class SamsungHealthService {
  final Logger _logger = Logger();

  Future<bool> initialize() async {
    try {
      _logger.i('Initializing Samsung Health service');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize Samsung Health: $e');
      return false;
    }
  }

  Future<List<WearableDevice>> getConnectedDevices() async {
    return [
      WearableDevice(
        id: 'galaxy_watch_1',
        name: 'Galaxy Watch6',
        platform: 'Samsung Health',
        supportedDataTypes: ['heart_rate', 'blood_pressure', 'blood_oxygen', 'temperature'],
        isConnected: true,
        lastSync: DateTime.now().subtract(Duration(minutes: 4)),
        batteryLevel: 0.91,
      ),
    ];
  }

  Future<PatientVitals?> getLatestVitals() async {
    return PatientVitals(
      heartRate: 78,
      bloodPressure: '120/80',
      oxygenSaturation: 97.8,
      timestamp: DateTime.now().subtract(Duration(minutes: 3)),
      deviceSource: 'Galaxy Watch',
      dataQuality: 0.92,
    );
  }

  Future<bool> hasPermissions() async => true;
  Future<void> requestPermissions() async {}
}

/// Fitbit service implementation
class FitbitService {
  final Logger _logger = Logger();

  Future<bool> initialize() async {
    try {
      _logger.i('Initializing Fitbit service');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize Fitbit: $e');
      return false;
    }
  }

  Future<List<WearableDevice>> getConnectedDevices() async {
    return [
      WearableDevice(
        id: 'fitbit_sense_1',
        name: 'Fitbit Sense 2',
        platform: 'Fitbit',
        supportedDataTypes: ['heart_rate', 'heart_rate_variability', 'temperature', 'blood_oxygen'],
        isConnected: true,
        lastSync: DateTime.now().subtract(Duration(minutes: 8)),
        batteryLevel: 0.68,
      ),
    ];
  }

  Future<PatientVitals?> getLatestVitals() async {
    return PatientVitals(
      heartRate: 74,
      heartRateVariability: 45.2,
      temperature: 98.4,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
      deviceSource: 'Fitbit Sense',
      dataQuality: 0.85,
    );
  }

  Future<bool> hasPermissions() async => true;
  Future<void> requestPermissions() async {}
}