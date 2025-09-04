import 'package:logger/logger.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/hospital_integration_config_firestore.dart';
import 'data_source_manager.dart';
import 'hospital_integration_config_service.dart';
import 'hospital_data_sync_service.dart';
import 'hospital_api_integration_service.dart';

/// Production hospital integration service that orchestrates all integration components
class ProductionHospitalIntegrationService {
  static final ProductionHospitalIntegrationService _instance =
      ProductionHospitalIntegrationService._internal();
  factory ProductionHospitalIntegrationService() => _instance;
  ProductionHospitalIntegrationService._internal();

  final Logger _logger = Logger();
  final DataSourceManager _dataSourceManager = DataSourceManager();
  final HospitalIntegrationConfigService _configService =
      HospitalIntegrationConfigService();
  final HospitalDataSyncService _syncService = HospitalDataSyncService();
  final HospitalAPIIntegrationService _apiService =
      HospitalAPIIntegrationService();

  bool _isInitialized = false;

  /// Initialize the production hospital integration service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing Production Hospital Integration Service...');

      // Initialize all components
      await _dataSourceManager.initialize();
      await _syncService.initialize();

      _isInitialized = true;
      _logger.i(
        'Production Hospital Integration Service initialized successfully',
      );
    } catch (e) {
      _logger.e(
        'Failed to initialize Production Hospital Integration Service: $e',
      );
      rethrow;
    }
  }

  /// Configure hospital integration
  Future<void> configureHospitalIntegration({
    required String hospitalId,
    required DataSourceType dataSource,
    HospitalAPIConfig? apiConfig,
    bool fallbackToFirestore = true,
    bool realTimeEnabled = false,
    int syncIntervalMinutes = 15,
  }) async {
    try {
      _logger.i(
        'Configuring integration for hospital $hospitalId with data source $dataSource',
      );

      // Validate API configuration if provided
      if (apiConfig != null) {
        final isValid = await _configService.validateAPIConfiguration(
          apiConfig,
        );
        if (!isValid) {
          throw Exception('Invalid API configuration for hospital $hospitalId');
        }
      }

      // Create or update configuration
      await _configService.createOrUpdateHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: dataSource,
        apiConfig: apiConfig,
        fallbackToFirestore: fallbackToFirestore,
        realTimeEnabled: realTimeEnabled,
        syncIntervalMinutes: syncIntervalMinutes,
      );

      // Start synchronization if not using Firestore
      if (dataSource != DataSourceType.firestore) {
        await _syncService.startHospitalSync(hospitalId);
      }

      _logger.i('Successfully configured integration for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to configure integration for hospital $hospitalId: $e');
      rethrow;
    }
  }

  /// Get hospital data with automatic fallback
  Future<HospitalFirestore?> getHospitalData(String hospitalId) async {
    try {
      return await _dataSourceManager.getHospitalData(hospitalId);
    } catch (e) {
      _logger.e('Failed to get hospital data for $hospitalId: $e');
      return null;
    }
  }

  /// Get hospital capacity with automatic fallback
  Future<HospitalCapacityFirestore?> getHospitalCapacity(
    String hospitalId,
  ) async {
    try {
      return await _dataSourceManager.getHospitalCapacity(hospitalId);
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
      return await _dataSourceManager.getHospitals(
        hospitalIds: hospitalIds,
        specializations: specializations,
        minTraumaLevel: minTraumaLevel,
        isActive: isActive,
        limit: limit,
      );
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
      return await _dataSourceManager.getHospitalCapacities(hospitalIds);
    } catch (e) {
      _logger.e('Failed to get hospital capacities: $e');
      return [];
    }
  }

  /// Switch hospital data source
  Future<void> switchHospitalDataSource({
    required String hospitalId,
    required DataSourceType newDataSource,
    HospitalAPIConfig? apiConfig,
  }) async {
    try {
      _logger.i(
        'Switching data source for hospital $hospitalId to $newDataSource',
      );

      // Validate API configuration if switching to API-based source
      if (newDataSource != DataSourceType.firestore && apiConfig != null) {
        final isValid = await _configService.validateAPIConfiguration(
          apiConfig,
        );
        if (!isValid) {
          throw Exception('Invalid API configuration for hospital $hospitalId');
        }
      }

      // Stop existing sync
      await _syncService.stopHospitalSync(hospitalId);

      // Update configuration
      await _dataSourceManager.switchHospitalDataSource(
        hospitalId: hospitalId,
        newDataSource: newDataSource,
        apiConfig: apiConfig,
      );

      // Start new sync if needed
      if (newDataSource != DataSourceType.firestore) {
        await _syncService.startHospitalSync(hospitalId);
      }

      _logger.i('Successfully switched data source for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to switch data source for hospital $hospitalId: $e');
      rethrow;
    }
  }

  /// Enable/disable real-time monitoring
  Future<void> toggleRealTimeMonitoring(String hospitalId, bool enabled) async {
    try {
      await _dataSourceManager.toggleRealTimeMonitoring(hospitalId, enabled);
      await _syncService.restartHospitalSync(hospitalId);

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

  /// Perform manual sync for a hospital
  Future<SyncResult> performManualSync(String hospitalId) async {
    try {
      return await _syncService.performManualSync(hospitalId);
    } catch (e) {
      _logger.e('Manual sync failed for hospital $hospitalId: $e');
      return SyncResult(
        hospitalId: hospitalId,
        success: false,
        timestamp: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  /// Check integration health for a hospital
  Future<IntegrationHealthReport> checkIntegrationHealth(
    String hospitalId,
  ) async {
    try {
      final config = await _configService.getHospitalIntegration(hospitalId);
      final dataSourceHealth = await _dataSourceManager.checkDataSourceHealth(
        hospitalId,
      );
      final syncStats = _syncService.getSyncStatistics(hospitalId);

      return IntegrationHealthReport(
        hospitalId: hospitalId,
        hasConfiguration: config != null,
        configurationActive: config?.isActive ?? false,
        dataSourceHealth: dataSourceHealth,
        syncStatistics: syncStats,
        overallHealthy: _calculateOverallHealth(
          config,
          dataSourceHealth,
          syncStats,
        ),
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      _logger.e(
        'Failed to check integration health for hospital $hospitalId: $e',
      );
      return IntegrationHealthReport(
        hospitalId: hospitalId,
        hasConfiguration: false,
        configurationActive: false,
        dataSourceHealth: DataSourceHealthStatus(
          hospitalId: hospitalId,
          dataSource: DataSourceType.firestore,
          isHealthy: false,
          lastChecked: DateTime.now(),
          responseTimeMs: 0,
          errorMessage: e.toString(),
        ),
        syncStatistics: null,
        overallHealthy: false,
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Get integration dashboard data
  Future<IntegrationDashboard> getIntegrationDashboard() async {
    try {
      final dataSourceStats = await _dataSourceManager
          .getDataSourceStatistics();
      final configStats = await _configService.getConfigurationStatistics();
      final syncHealth = _syncService.getSyncHealthStatus();
      final allSyncStats = _syncService.getAllSyncStatistics();

      return IntegrationDashboard(
        dataSourceStatistics: dataSourceStats,
        configurationStatistics: configStats,
        syncHealthStatus: syncHealth,
        syncStatistics: allSyncStats,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Failed to get integration dashboard data: $e');
      return IntegrationDashboard.empty();
    }
  }

  /// Get hospitals by data source type
  Future<List<HospitalIntegrationConfigFirestore>> getHospitalsByDataSource(
    DataSourceType dataSource,
  ) async {
    try {
      return await _configService.getHospitalsByDataSource(dataSource);
    } catch (e) {
      _logger.e('Failed to get hospitals by data source $dataSource: $e');
      return [];
    }
  }

  /// Get hospitals with real-time monitoring
  Future<List<HospitalIntegrationConfigFirestore>>
  getHospitalsWithRealTimeMonitoring() async {
    try {
      return await _configService.getHospitalsWithRealTimeMonitoring();
    } catch (e) {
      _logger.e('Failed to get hospitals with real-time monitoring: $e');
      return [];
    }
  }

  /// Restart all integrations
  Future<void> restartAllIntegrations() async {
    try {
      _logger.i('Restarting all hospital integrations...');

      await _syncService.restartAllSyncs();

      _logger.i('Successfully restarted all hospital integrations');
    } catch (e) {
      _logger.e('Failed to restart all integrations: $e');
      rethrow;
    }
  }

  /// Remove hospital integration
  Future<void> removeHospitalIntegration(String hospitalId) async {
    try {
      _logger.i('Removing integration for hospital $hospitalId');

      // Stop sync
      await _syncService.stopHospitalSync(hospitalId);

      // Delete configuration
      await _configService.deleteHospitalIntegration(hospitalId);

      _logger.i('Successfully removed integration for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to remove integration for hospital $hospitalId: $e');
      rethrow;
    }
  }

  /// Calculate overall health status
  bool _calculateOverallHealth(
    HospitalIntegrationConfigFirestore? config,
    DataSourceHealthStatus dataSourceHealth,
    SyncStatistics? syncStats,
  ) {
    if (config == null || !config.isActive) return false;
    if (!dataSourceHealth.isHealthy) return false;
    if (config.dataSource != DataSourceType.firestore &&
        syncStats != null &&
        !syncStats.isHealthy) {
      return false;
    }
    return true;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    try {
      await _syncService.dispose();
      _apiService.dispose();
      _isInitialized = false;
      _logger.i('Production Hospital Integration Service disposed');
    } catch (e) {
      _logger.e('Error disposing Production Hospital Integration Service: $e');
    }
  }
}

/// Integration health report model
class IntegrationHealthReport {
  final String hospitalId;
  final bool hasConfiguration;
  final bool configurationActive;
  final DataSourceHealthStatus dataSourceHealth;
  final SyncStatistics? syncStatistics;
  final bool overallHealthy;
  final DateTime lastChecked;

  const IntegrationHealthReport({
    required this.hospitalId,
    required this.hasConfiguration,
    required this.configurationActive,
    required this.dataSourceHealth,
    this.syncStatistics,
    required this.overallHealthy,
    required this.lastChecked,
  });
}

/// Integration dashboard model
class IntegrationDashboard {
  final DataSourceStatistics dataSourceStatistics;
  final Map<String, dynamic> configurationStatistics;
  final SyncHealthStatus syncHealthStatus;
  final Map<String, SyncStatistics> syncStatistics;
  final DateTime lastUpdated;

  const IntegrationDashboard({
    required this.dataSourceStatistics,
    required this.configurationStatistics,
    required this.syncHealthStatus,
    required this.syncStatistics,
    required this.lastUpdated,
  });

  factory IntegrationDashboard.empty() {
    return IntegrationDashboard(
      dataSourceStatistics: DataSourceStatistics.empty(),
      configurationStatistics: {},
      syncHealthStatus: SyncHealthStatus(
        totalHospitals: 0,
        healthyHospitals: 0,
        unhealthyHospitals: 0,
        overallHealthPercentage: 0.0,
        lastChecked: DateTime.now(),
      ),
      syncStatistics: {},
      lastUpdated: DateTime.now(),
    );
  }
}
