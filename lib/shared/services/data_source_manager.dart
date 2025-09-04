import 'package:logger/logger.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/hospital_integration_config_firestore.dart';
import 'firestore_data_service.dart';
import 'hospital_api_integration_service.dart';
import 'hospital_integration_config_service.dart';

/// Configurable data source manager supporting Firestore and custom APIs
class DataSourceManager {
  static final DataSourceManager _instance = DataSourceManager._internal();
  factory DataSourceManager() => _instance;
  DataSourceManager._internal();

  final Logger _logger = Logger();
  final FirestoreDataService _firestoreService = FirestoreDataService();
  final HospitalAPIIntegrationService _apiService =
      HospitalAPIIntegrationService();
  final HospitalIntegrationConfigService _configService =
      HospitalIntegrationConfigService();

  // Cache for integration configurations
  final Map<String, HospitalIntegrationConfigFirestore> _configCache = {};
  DateTime? _lastConfigRefresh;
  static const Duration _configCacheTimeout = Duration(minutes: 5);

  /// Initialize the data source manager
  Future<void> initialize() async {
    try {
      await _refreshConfigCache();
      _logger.i('DataSourceManager initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize DataSourceManager: $e');
      rethrow;
    }
  }

  /// Get hospital data using the configured data source with fallback
  Future<HospitalFirestore?> getHospitalData(String hospitalId) async {
    try {
      final config = await _getHospitalConfig(hospitalId);

      // Try primary data source first
      if (config != null && config.isActive) {
        switch (config.dataSource) {
          case DataSourceType.customApi:
          case DataSourceType.hl7:
          case DataSourceType.fhir:
            try {
              final hospitalData = await _apiService.getHospitalData(
                hospitalId,
                config,
              );
              if (hospitalData != null) {
                _logger.d('Retrieved hospital data from API for: $hospitalId');
                return hospitalData;
              }
            } catch (apiError) {
              _logger.w('API failed for hospital $hospitalId: $apiError');
              if (!config.fallbackToFirestore) {
                rethrow;
              }
            }
            break;
          case DataSourceType.firestore:
            // Use Firestore directly
            break;
        }
      }

      // Fallback to Firestore
      final firestoreData = await _firestoreService.getHospitalById(hospitalId);
      if (firestoreData != null) {
        _logger.d('Retrieved hospital data from Firestore for: $hospitalId');
      }
      return firestoreData;
    } catch (e) {
      _logger.e('Failed to get hospital data for $hospitalId: $e');
      return null;
    }
  }

  /// Get hospital capacity using the configured data source with fallback
  Future<HospitalCapacityFirestore?> getHospitalCapacity(
    String hospitalId,
  ) async {
    try {
      final config = await _getHospitalConfig(hospitalId);

      // Try primary data source first
      if (config != null && config.isActive) {
        switch (config.dataSource) {
          case DataSourceType.customApi:
          case DataSourceType.hl7:
          case DataSourceType.fhir:
            try {
              final capacityData = await _apiService.getHospitalCapacity(
                hospitalId,
                config,
              );
              if (capacityData != null) {
                _logger.d(
                  'Retrieved hospital capacity from API for: $hospitalId',
                );

                // Update Firestore cache if successful
                if (config.fallbackToFirestore) {
                  await _firestoreService.updateHospitalCapacity(capacityData);
                }

                return capacityData;
              }
            } catch (apiError) {
              _logger.w(
                'API failed for hospital capacity $hospitalId: $apiError',
              );
              if (!config.fallbackToFirestore) {
                rethrow;
              }
            }
            break;
          case DataSourceType.firestore:
            // Use Firestore directly
            break;
        }
      }

      // Fallback to Firestore
      final firestoreData = await _firestoreService.getHospitalCapacity(
        hospitalId,
      );
      if (firestoreData != null) {
        _logger.d(
          'Retrieved hospital capacity from Firestore for: $hospitalId',
        );
      }
      return firestoreData;
    } catch (e) {
      _logger.e('Failed to get hospital capacity for $hospitalId: $e');
      return null;
    }
  }

  /// Get multiple hospitals with mixed data sources
  Future<List<HospitalFirestore>> getHospitals({
    List<String>? hospitalIds,
    List<String>? specializations,
    int? minTraumaLevel,
    bool? isActive,
    int limit = 50,
  }) async {
    try {
      final hospitals = <HospitalFirestore>[];

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        // Get specific hospitals by ID
        for (final hospitalId in hospitalIds) {
          final hospital = await getHospitalData(hospitalId);
          if (hospital != null) {
            hospitals.add(hospital);
          }
        }
      } else {
        // Get hospitals from Firestore with filters
        final firestoreHospitals = await _firestoreService.getHospitals(
          specializations: specializations,
          minTraumaLevel: minTraumaLevel,
          isActive: isActive,
          limit: limit,
        );
        hospitals.addAll(firestoreHospitals);
      }

      return hospitals;
    } catch (e) {
      _logger.e('Failed to get hospitals: $e');
      return [];
    }
  }

  /// Get multiple hospital capacities with mixed data sources
  Future<List<HospitalCapacityFirestore>> getHospitalCapacities(
    List<String> hospitalIds,
  ) async {
    try {
      final capacities = <HospitalCapacityFirestore>[];

      for (final hospitalId in hospitalIds) {
        final capacity = await getHospitalCapacity(hospitalId);
        if (capacity != null) {
          capacities.add(capacity);
        }
      }

      return capacities;
    } catch (e) {
      _logger.e('Failed to get hospital capacities: $e');
      return [];
    }
  }

  /// Check data source health for a hospital
  Future<DataSourceHealthStatus> checkDataSourceHealth(
    String hospitalId,
  ) async {
    try {
      final config = await _getHospitalConfig(hospitalId);

      if (config == null || !config.isActive) {
        return DataSourceHealthStatus(
          hospitalId: hospitalId,
          dataSource: DataSourceType.firestore,
          isHealthy: true,
          lastChecked: DateTime.now(),
          responseTimeMs: 0,
          errorMessage: null,
        );
      }

      switch (config.dataSource) {
        case DataSourceType.customApi:
        case DataSourceType.hl7:
        case DataSourceType.fhir:
          return await _apiService.checkAPIHealth(hospitalId, config);
        case DataSourceType.firestore:
          return await _checkFirestoreHealth(hospitalId);
      }
    } catch (e) {
      _logger.e('Failed to check data source health for $hospitalId: $e');
      return DataSourceHealthStatus(
        hospitalId: hospitalId,
        dataSource: DataSourceType.firestore,
        isHealthy: false,
        lastChecked: DateTime.now(),
        responseTimeMs: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get data source statistics
  Future<DataSourceStatistics> getDataSourceStatistics() async {
    try {
      await _refreshConfigCache();

      final stats = DataSourceStatistics(
        totalHospitals: _configCache.length,
        firestoreCount: _configCache.values
            .where((c) => c.dataSource == DataSourceType.firestore)
            .length,
        customApiCount: _configCache.values
            .where((c) => c.dataSource == DataSourceType.customApi)
            .length,
        hl7Count: _configCache.values
            .where((c) => c.dataSource == DataSourceType.hl7)
            .length,
        fhirCount: _configCache.values
            .where((c) => c.dataSource == DataSourceType.fhir)
            .length,
        activeIntegrations: _configCache.values.where((c) => c.isActive).length,
        realTimeEnabled: _configCache.values
            .where((c) => c.realTimeEnabled)
            .length,
        lastUpdated: DateTime.now(),
      );

      return stats;
    } catch (e) {
      _logger.e('Failed to get data source statistics: $e');
      return DataSourceStatistics.empty();
    }
  }

  /// Switch hospital data source
  Future<void> switchHospitalDataSource({
    required String hospitalId,
    required DataSourceType newDataSource,
    HospitalAPIConfig? apiConfig,
  }) async {
    try {
      await _configService.updateHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: newDataSource,
        apiConfig: apiConfig,
      );

      // Clear cache to force refresh
      _configCache.remove(hospitalId);

      _logger.i(
        'Switched data source for hospital $hospitalId to $newDataSource',
      );
    } catch (e) {
      _logger.e('Failed to switch data source for hospital $hospitalId: $e');
      rethrow;
    }
  }

  /// Enable/disable real-time monitoring for a hospital
  Future<void> toggleRealTimeMonitoring(String hospitalId, bool enabled) async {
    try {
      await _configService.updateRealTimeMonitoring(hospitalId, enabled);

      // Clear cache to force refresh
      _configCache.remove(hospitalId);

      _logger.i(
        '${enabled ? 'Enabled' : 'Disabled'} real-time monitoring for hospital $hospitalId',
      );
    } catch (e) {
      _logger.e(
        'Failed to toggle real-time monitoring for hospital $hospitalId: $e',
      );
      rethrow;
    }
  }

  /// Get hospital configuration with caching
  Future<HospitalIntegrationConfigFirestore?> _getHospitalConfig(
    String hospitalId,
  ) async {
    // Check cache first
    if (_configCache.containsKey(hospitalId) && _isCacheValid()) {
      return _configCache[hospitalId];
    }

    // Refresh cache if needed
    if (!_isCacheValid()) {
      await _refreshConfigCache();
    }

    return _configCache[hospitalId];
  }

  /// Refresh configuration cache
  Future<void> _refreshConfigCache() async {
    try {
      final configs = await _configService.getAllHospitalIntegrations();
      _configCache.clear();

      for (final config in configs) {
        _configCache[config.hospitalId] = config;
      }

      _lastConfigRefresh = DateTime.now();
      _logger.d('Refreshed configuration cache with ${configs.length} entries');
    } catch (e) {
      _logger.e('Failed to refresh configuration cache: $e');
      rethrow;
    }
  }

  /// Check if configuration cache is valid
  bool _isCacheValid() {
    return _lastConfigRefresh != null &&
        DateTime.now().difference(_lastConfigRefresh!) < _configCacheTimeout;
  }

  /// Check Firestore health
  Future<DataSourceHealthStatus> _checkFirestoreHealth(
    String hospitalId,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      await _firestoreService.getHospitalById(hospitalId);
      stopwatch.stop();

      return DataSourceHealthStatus(
        hospitalId: hospitalId,
        dataSource: DataSourceType.firestore,
        isHealthy: true,
        lastChecked: DateTime.now(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: null,
      );
    } catch (e) {
      stopwatch.stop();

      return DataSourceHealthStatus(
        hospitalId: hospitalId,
        dataSource: DataSourceType.firestore,
        isHealthy: false,
        lastChecked: DateTime.now(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Data source health status
class DataSourceHealthStatus {
  final String hospitalId;
  final DataSourceType dataSource;
  final bool isHealthy;
  final DateTime lastChecked;
  final int responseTimeMs;
  final String? errorMessage;

  const DataSourceHealthStatus({
    required this.hospitalId,
    required this.dataSource,
    required this.isHealthy,
    required this.lastChecked,
    required this.responseTimeMs,
    this.errorMessage,
  });
}

/// Data source statistics
class DataSourceStatistics {
  final int totalHospitals;
  final int firestoreCount;
  final int customApiCount;
  final int hl7Count;
  final int fhirCount;
  final int activeIntegrations;
  final int realTimeEnabled;
  final DateTime lastUpdated;

  const DataSourceStatistics({
    required this.totalHospitals,
    required this.firestoreCount,
    required this.customApiCount,
    required this.hl7Count,
    required this.fhirCount,
    required this.activeIntegrations,
    required this.realTimeEnabled,
    required this.lastUpdated,
  });

  factory DataSourceStatistics.empty() {
    return DataSourceStatistics(
      totalHospitals: 0,
      firestoreCount: 0,
      customApiCount: 0,
      hl7Count: 0,
      fhirCount: 0,
      activeIntegrations: 0,
      realTimeEnabled: 0,
      lastUpdated: DateTime.now(),
    );
  }
}
