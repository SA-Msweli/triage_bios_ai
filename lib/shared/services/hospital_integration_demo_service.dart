import 'package:logger/logger.dart';
import '../models/firestore/hospital_integration_config_firestore.dart';
import 'production_hospital_integration_service.dart';

/// Demo service showing how to use the Production Hospital Integration Framework
class HospitalIntegrationDemoService {
  static final HospitalIntegrationDemoService _instance =
      HospitalIntegrationDemoService._internal();
  factory HospitalIntegrationDemoService() => _instance;
  HospitalIntegrationDemoService._internal();

  final Logger _logger = Logger();
  final ProductionHospitalIntegrationService _integrationService =
      ProductionHospitalIntegrationService();

  /// Initialize and demonstrate the integration framework
  Future<void> runDemo() async {
    try {
      _logger.i('Starting Hospital Integration Framework Demo...');

      // Initialize the integration service
      await _integrationService.initialize();

      // Demo 1: Configure a hospital with custom API
      await _demoCustomAPIIntegration();

      // Demo 2: Configure a hospital with Firestore only
      await _demoFirestoreIntegration();

      // Demo 3: Switch data sources
      await _demoDataSourceSwitching();

      // Demo 4: Real-time monitoring
      await _demoRealTimeMonitoring();

      // Demo 5: Health monitoring
      await _demoHealthMonitoring();

      // Demo 6: Dashboard overview
      await _demoDashboard();

      _logger.i('Hospital Integration Framework Demo completed successfully');
    } catch (e) {
      _logger.e('Demo failed: $e');
      rethrow;
    }
  }

  /// Demo: Configure hospital with custom API integration
  Future<void> _demoCustomAPIIntegration() async {
    try {
      _logger.i('Demo 1: Configuring hospital with custom API integration');

      const hospitalId = 'demo-hospital-api';

      // Create API configuration
      final apiConfig = HospitalAPIConfig(
        baseUrl: 'https://api.demo-hospital.com/v1',
        authType: AuthenticationType.apiKey,
        credentials: {'apiKey': 'demo-api-key-12345'},
        headers: {'X-Client-Version': '1.0.0'},
        timeoutSeconds: 30,
        retryAttempts: 3,
      );

      // Configure the integration
      await _integrationService.configureHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: DataSourceType.customApi,
        apiConfig: apiConfig,
        fallbackToFirestore: true,
        realTimeEnabled: false,
        syncIntervalMinutes: 10,
      );

      _logger.i(
        '✅ Successfully configured custom API integration for $hospitalId',
      );
    } catch (e) {
      _logger.e('❌ Custom API integration demo failed: $e');
    }
  }

  /// Demo: Configure hospital with Firestore only
  Future<void> _demoFirestoreIntegration() async {
    try {
      _logger.i('Demo 2: Configuring hospital with Firestore integration');

      const hospitalId = 'demo-hospital-firestore';

      // Configure Firestore-only integration
      await _integrationService.configureHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: DataSourceType.firestore,
        fallbackToFirestore: true,
        realTimeEnabled: false,
      );

      _logger.i(
        '✅ Successfully configured Firestore integration for $hospitalId',
      );
    } catch (e) {
      _logger.e('❌ Firestore integration demo failed: $e');
    }
  }

  /// Demo: Switch data sources
  Future<void> _demoDataSourceSwitching() async {
    try {
      _logger.i('Demo 3: Switching data sources');

      const hospitalId = 'demo-hospital-switch';

      // Start with Firestore
      await _integrationService.configureHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: DataSourceType.firestore,
      );
      _logger.i('✅ Configured $hospitalId with Firestore');

      // Switch to custom API
      final apiConfig = HospitalAPIConfig(
        baseUrl: 'https://api.switched-hospital.com/v1',
        authType: AuthenticationType.bearerToken,
        credentials: {'token': 'bearer-token-67890'},
      );

      await _integrationService.switchHospitalDataSource(
        hospitalId: hospitalId,
        newDataSource: DataSourceType.customApi,
        apiConfig: apiConfig,
      );
      _logger.i('✅ Switched $hospitalId to custom API');

      // Switch back to Firestore
      await _integrationService.switchHospitalDataSource(
        hospitalId: hospitalId,
        newDataSource: DataSourceType.firestore,
      );
      _logger.i('✅ Switched $hospitalId back to Firestore');
    } catch (e) {
      _logger.e('❌ Data source switching demo failed: $e');
    }
  }

  /// Demo: Real-time monitoring
  Future<void> _demoRealTimeMonitoring() async {
    try {
      _logger.i('Demo 4: Real-time monitoring');

      const hospitalId = 'demo-hospital-realtime';

      // Configure with real-time monitoring
      final apiConfig = HospitalAPIConfig(
        baseUrl: 'https://api.realtime-hospital.com/v1',
        authType: AuthenticationType.oauth2,
        credentials: {
          'clientId': 'demo-client-id',
          'clientSecret': 'demo-client-secret',
          'tokenUrl': 'https://auth.realtime-hospital.com/oauth/token',
        },
      );

      await _integrationService.configureHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: DataSourceType.customApi,
        apiConfig: apiConfig,
        realTimeEnabled: true,
        syncIntervalMinutes: 5,
      );
      _logger.i('✅ Configured real-time monitoring for $hospitalId');

      // Toggle real-time monitoring
      await _integrationService.toggleRealTimeMonitoring(hospitalId, false);
      _logger.i('✅ Disabled real-time monitoring for $hospitalId');

      await _integrationService.toggleRealTimeMonitoring(hospitalId, true);
      _logger.i('✅ Re-enabled real-time monitoring for $hospitalId');
    } catch (e) {
      _logger.e('❌ Real-time monitoring demo failed: $e');
    }
  }

  /// Demo: Health monitoring
  Future<void> _demoHealthMonitoring() async {
    try {
      _logger.i('Demo 5: Health monitoring');

      const hospitalId = 'demo-hospital-health';

      // Configure a hospital
      await _integrationService.configureHospitalIntegration(
        hospitalId: hospitalId,
        dataSource: DataSourceType.firestore,
      );

      // Check integration health
      final healthReport = await _integrationService.checkIntegrationHealth(
        hospitalId,
      );

      _logger.i('Health Report for $hospitalId:');
      _logger.i('  - Has Configuration: ${healthReport.hasConfiguration}');
      _logger.i(
        '  - Configuration Active: ${healthReport.configurationActive}',
      );
      _logger.i(
        '  - Data Source Healthy: ${healthReport.dataSourceHealth.isHealthy}',
      );
      _logger.i('  - Overall Healthy: ${healthReport.overallHealthy}');

      // Perform manual sync
      final syncResult = await _integrationService.performManualSync(
        hospitalId,
      );
      _logger.i(
        'Manual sync result: ${syncResult.success ? 'Success' : 'Failed'}',
      );
      if (!syncResult.success && syncResult.errorMessage != null) {
        _logger.i('  Error: ${syncResult.errorMessage}');
      }

      _logger.i('✅ Health monitoring demo completed');
    } catch (e) {
      _logger.e('❌ Health monitoring demo failed: $e');
    }
  }

  /// Demo: Dashboard overview
  Future<void> _demoDashboard() async {
    try {
      _logger.i('Demo 6: Dashboard overview');

      // Get dashboard data
      final dashboard = await _integrationService.getIntegrationDashboard();

      _logger.i('Integration Dashboard:');
      _logger.i('  Data Sources:');
      _logger.i(
        '    - Total Hospitals: ${dashboard.dataSourceStatistics.totalHospitals}',
      );
      _logger.i(
        '    - Firestore: ${dashboard.dataSourceStatistics.firestoreCount}',
      );
      _logger.i(
        '    - Custom API: ${dashboard.dataSourceStatistics.customApiCount}',
      );
      _logger.i('    - HL7: ${dashboard.dataSourceStatistics.hl7Count}');
      _logger.i('    - FHIR: ${dashboard.dataSourceStatistics.fhirCount}');

      _logger.i('  Sync Health:');
      _logger.i('    - Total: ${dashboard.syncHealthStatus.totalHospitals}');
      _logger.i(
        '    - Healthy: ${dashboard.syncHealthStatus.healthyHospitals}',
      );
      _logger.i(
        '    - Unhealthy: ${dashboard.syncHealthStatus.unhealthyHospitals}',
      );
      _logger.i(
        '    - Health %: ${dashboard.syncHealthStatus.overallHealthPercentage.toStringAsFixed(1)}%',
      );

      // Get hospitals by data source
      final firestoreHospitals = await _integrationService
          .getHospitalsByDataSource(DataSourceType.firestore);
      final apiHospitals = await _integrationService.getHospitalsByDataSource(
        DataSourceType.customApi,
      );

      _logger.i('  Hospitals by Data Source:');
      _logger.i('    - Firestore: ${firestoreHospitals.length} hospitals');
      _logger.i('    - Custom API: ${apiHospitals.length} hospitals');

      // Get real-time enabled hospitals
      final realTimeHospitals = await _integrationService
          .getHospitalsWithRealTimeMonitoring();
      _logger.i(
        '    - Real-time enabled: ${realTimeHospitals.length} hospitals',
      );

      _logger.i('✅ Dashboard overview demo completed');
    } catch (e) {
      _logger.e('❌ Dashboard overview demo failed: $e');
    }
  }

  /// Demo: Data retrieval with fallback
  Future<void> _demoDataRetrieval() async {
    try {
      _logger.i('Demo 7: Data retrieval with automatic fallback');

      const hospitalId = 'demo-hospital-retrieval';

      // Get hospital data (will use configured data source with fallback)
      final hospitalData = await _integrationService.getHospitalData(
        hospitalId,
      );
      if (hospitalData != null) {
        _logger.i('✅ Retrieved hospital data: ${hospitalData.name}');
      } else {
        _logger.i('❌ No hospital data found for $hospitalId');
      }

      // Get hospital capacity
      final capacityData = await _integrationService.getHospitalCapacity(
        hospitalId,
      );
      if (capacityData != null) {
        _logger.i(
          '✅ Retrieved capacity data: ${capacityData.availableBeds} beds available',
        );
      } else {
        _logger.i('❌ No capacity data found for $hospitalId');
      }

      // Get multiple hospitals
      final hospitals = await _integrationService.getHospitals(limit: 5);
      _logger.i('✅ Retrieved ${hospitals.length} hospitals');

      _logger.i('✅ Data retrieval demo completed');
    } catch (e) {
      _logger.e('❌ Data retrieval demo failed: $e');
    }
  }

  /// Clean up demo data
  Future<void> cleanupDemo() async {
    try {
      _logger.i('Cleaning up demo data...');

      final demoHospitalIds = [
        'demo-hospital-api',
        'demo-hospital-firestore',
        'demo-hospital-switch',
        'demo-hospital-realtime',
        'demo-hospital-health',
        'demo-hospital-retrieval',
      ];

      for (final hospitalId in demoHospitalIds) {
        try {
          await _integrationService.removeHospitalIntegration(hospitalId);
          _logger.d('Removed integration for $hospitalId');
        } catch (e) {
          _logger.w('Failed to remove integration for $hospitalId: $e');
        }
      }

      _logger.i('✅ Demo cleanup completed');
    } catch (e) {
      _logger.e('❌ Demo cleanup failed: $e');
    }
  }
}
