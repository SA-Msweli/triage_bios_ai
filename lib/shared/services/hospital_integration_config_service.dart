import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/firestore/hospital_integration_config_firestore.dart';
import 'firebase_service.dart';

/// Configuration management service for per-hospital integration settings and credentials
class HospitalIntegrationConfigService {
  static final HospitalIntegrationConfigService _instance =
      HospitalIntegrationConfigService._internal();
  factory HospitalIntegrationConfigService() => _instance;
  HospitalIntegrationConfigService._internal();

  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  // Collection name
  static const String _configCollection = 'hospital_integration_configs';

  /// Get hospital integration configuration by hospital ID
  Future<HospitalIntegrationConfigFirestore?> getHospitalIntegration(
    String hospitalId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_configCollection)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return HospitalIntegrationConfigFirestore.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    } catch (e) {
      _logger.e(
        'Failed to get hospital integration config for $hospitalId: $e',
      );
      return null;
    }
  }

  /// Get all hospital integration configurations
  Future<List<HospitalIntegrationConfigFirestore>> getAllHospitalIntegrations({
    bool? isActive,
    DataSourceType? dataSource,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(_configCollection);

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      if (dataSource != null) {
        query = query.where('dataSource', isEqualTo: dataSource.name);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => HospitalIntegrationConfigFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get all hospital integration configs: $e');
      return [];
    }
  }

  /// Create or update hospital integration configuration
  Future<String> createOrUpdateHospitalIntegration({
    required String hospitalId,
    required DataSourceType dataSource,
    HospitalAPIConfig? apiConfig,
    bool fallbackToFirestore = true,
    bool realTimeEnabled = false,
    int syncIntervalMinutes = 15,
    bool isActive = true,
  }) async {
    try {
      // Check if configuration already exists
      final existingConfig = await getHospitalIntegration(hospitalId);

      if (existingConfig != null) {
        // Update existing configuration
        final updatedConfig = existingConfig.copyWith(
          dataSource: dataSource,
          apiConfig: apiConfig,
          fallbackToFirestore: fallbackToFirestore,
          realTimeEnabled: realTimeEnabled,
          syncIntervalMinutes: syncIntervalMinutes,
          isActive: isActive,
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection(_configCollection)
            .doc(existingConfig.id)
            .update(updatedConfig.toFirestore());

        _logger.i('Updated hospital integration config for $hospitalId');
        return existingConfig.id;
      } else {
        // Create new configuration
        final newConfig = HospitalIntegrationConfigFirestore(
          id: '', // Will be set by Firestore
          hospitalId: hospitalId,
          dataSource: dataSource,
          apiConfig: apiConfig,
          fallbackToFirestore: fallbackToFirestore,
          realTimeEnabled: realTimeEnabled,
          syncIntervalMinutes: syncIntervalMinutes,
          isActive: isActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final docRef = await _firestore
            .collection(_configCollection)
            .add(newConfig.toFirestore());

        _logger.i('Created hospital integration config for $hospitalId');
        return docRef.id;
      }
    } catch (e) {
      _logger.e(
        'Failed to create/update hospital integration config for $hospitalId: $e',
      );
      rethrow;
    }
  }

  /// Update hospital integration data source
  Future<void> updateHospitalIntegration({
    required String hospitalId,
    DataSourceType? dataSource,
    HospitalAPIConfig? apiConfig,
    bool? fallbackToFirestore,
    bool? realTimeEnabled,
    int? syncIntervalMinutes,
    bool? isActive,
  }) async {
    try {
      final existingConfig = await getHospitalIntegration(hospitalId);

      if (existingConfig == null) {
        throw Exception(
          'Hospital integration config not found for $hospitalId',
        );
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (dataSource != null) {
        updates['dataSource'] = dataSource.name;
      }

      if (apiConfig != null) {
        updates['apiConfig'] = apiConfig.toMap();
      }

      if (fallbackToFirestore != null) {
        updates['fallbackToFirestore'] = fallbackToFirestore;
      }

      if (realTimeEnabled != null) {
        updates['realTimeEnabled'] = realTimeEnabled;
      }

      if (syncIntervalMinutes != null) {
        updates['syncIntervalMinutes'] = syncIntervalMinutes;
      }

      if (isActive != null) {
        updates['isActive'] = isActive;
      }

      await _firestore
          .collection(_configCollection)
          .doc(existingConfig.id)
          .update(updates);

      _logger.i('Updated hospital integration config for $hospitalId');
    } catch (e) {
      _logger.e(
        'Failed to update hospital integration config for $hospitalId: $e',
      );
      rethrow;
    }
  }

  /// Enable/disable real-time monitoring for a hospital
  Future<void> updateRealTimeMonitoring(String hospitalId, bool enabled) async {
    try {
      await updateHospitalIntegration(
        hospitalId: hospitalId,
        realTimeEnabled: enabled,
      );

      _logger.i(
        '${enabled ? 'Enabled' : 'Disabled'} real-time monitoring for $hospitalId',
      );
    } catch (e) {
      _logger.e('Failed to update real-time monitoring for $hospitalId: $e');
      rethrow;
    }
  }

  /// Update sync interval for a hospital
  Future<void> updateSyncInterval(
    String hospitalId,
    int intervalMinutes,
  ) async {
    try {
      await updateHospitalIntegration(
        hospitalId: hospitalId,
        syncIntervalMinutes: intervalMinutes,
      );

      _logger.i(
        'Updated sync interval for $hospitalId to $intervalMinutes minutes',
      );
    } catch (e) {
      _logger.e('Failed to update sync interval for $hospitalId: $e');
      rethrow;
    }
  }

  /// Delete hospital integration configuration
  Future<void> deleteHospitalIntegration(String hospitalId) async {
    try {
      final existingConfig = await getHospitalIntegration(hospitalId);

      if (existingConfig == null) {
        _logger.w('Hospital integration config not found for $hospitalId');
        return;
      }

      await _firestore
          .collection(_configCollection)
          .doc(existingConfig.id)
          .delete();

      _logger.i('Deleted hospital integration config for $hospitalId');
    } catch (e) {
      _logger.e(
        'Failed to delete hospital integration config for $hospitalId: $e',
      );
      rethrow;
    }
  }

  /// Batch create hospital integration configurations
  Future<void> batchCreateHospitalIntegrations(
    List<HospitalIntegrationConfigFirestore> configs,
  ) async {
    if (configs.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final config in configs) {
        final docRef = _firestore.collection(_configCollection).doc();
        batch.set(docRef, config.toFirestore());
      }

      await batch.commit();
      _logger.i('Batch created ${configs.length} hospital integration configs');
    } catch (e) {
      _logger.e('Failed to batch create hospital integration configs: $e');
      rethrow;
    }
  }

  /// Get hospitals by data source type
  Future<List<HospitalIntegrationConfigFirestore>> getHospitalsByDataSource(
    DataSourceType dataSource,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_configCollection)
          .where('dataSource', isEqualTo: dataSource.name)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => HospitalIntegrationConfigFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get hospitals by data source $dataSource: $e');
      return [];
    }
  }

  /// Get hospitals with real-time monitoring enabled
  Future<List<HospitalIntegrationConfigFirestore>>
  getHospitalsWithRealTimeMonitoring() async {
    try {
      final querySnapshot = await _firestore
          .collection(_configCollection)
          .where('realTimeEnabled', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => HospitalIntegrationConfigFirestore.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get hospitals with real-time monitoring: $e');
      return [];
    }
  }

  /// Listen to configuration changes
  Stream<List<HospitalIntegrationConfigFirestore>>
  listenToConfigurationChanges({
    String? hospitalId,
    DataSourceType? dataSource,
  }) {
    Query query = _firestore
        .collection(_configCollection)
        .where('isActive', isEqualTo: true);

    if (hospitalId != null) {
      query = query.where('hospitalId', isEqualTo: hospitalId);
    }

    if (dataSource != null) {
      query = query.where('dataSource', isEqualTo: dataSource.name);
    }

    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => HospitalIntegrationConfigFirestore.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Validate API configuration
  Future<bool> validateAPIConfiguration(HospitalAPIConfig apiConfig) async {
    try {
      // Basic validation
      if (apiConfig.baseUrl.isEmpty) {
        _logger.w('API base URL is empty');
        return false;
      }

      if (!Uri.tryParse(apiConfig.baseUrl)?.hasAbsolutePath ?? true) {
        _logger.w('Invalid API base URL: ${apiConfig.baseUrl}');
        return false;
      }

      // Validate authentication credentials
      switch (apiConfig.authType) {
        case AuthenticationType.apiKey:
          if (!apiConfig.credentials.containsKey('apiKey') ||
              apiConfig.credentials['apiKey']?.isEmpty == true) {
            _logger.w('API key is missing or empty');
            return false;
          }
          break;

        case AuthenticationType.basicAuth:
          if (!apiConfig.credentials.containsKey('username') ||
              !apiConfig.credentials.containsKey('password') ||
              apiConfig.credentials['username']?.isEmpty == true ||
              apiConfig.credentials['password']?.isEmpty == true) {
            _logger.w('Basic auth credentials are missing or empty');
            return false;
          }
          break;

        case AuthenticationType.oauth2:
          if (!apiConfig.credentials.containsKey('clientId') ||
              !apiConfig.credentials.containsKey('clientSecret') ||
              !apiConfig.credentials.containsKey('tokenUrl') ||
              apiConfig.credentials['clientId']?.isEmpty == true ||
              apiConfig.credentials['clientSecret']?.isEmpty == true ||
              apiConfig.credentials['tokenUrl']?.isEmpty == true) {
            _logger.w('OAuth2 credentials are missing or empty');
            return false;
          }
          break;

        case AuthenticationType.bearerToken:
          if (!apiConfig.credentials.containsKey('token') ||
              apiConfig.credentials['token']?.isEmpty == true) {
            _logger.w('Bearer token is missing or empty');
            return false;
          }
          break;

        case AuthenticationType.certificate:
        case AuthenticationType.custom:
          // Custom validation can be added here
          break;
      }

      _logger.i('API configuration validation passed');
      return true;
    } catch (e) {
      _logger.e('API configuration validation failed: $e');
      return false;
    }
  }

  /// Get configuration statistics
  Future<Map<String, dynamic>> getConfigurationStatistics() async {
    try {
      final allConfigs = await getAllHospitalIntegrations();

      final stats = <String, dynamic>{
        'totalConfigurations': allConfigs.length,
        'activeConfigurations': allConfigs.where((c) => c.isActive).length,
        'dataSourceBreakdown': <String, int>{},
        'realTimeEnabled': allConfigs.where((c) => c.realTimeEnabled).length,
        'averageSyncInterval': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Calculate data source breakdown
      for (final config in allConfigs) {
        final dataSource = config.dataSource.name;
        stats['dataSourceBreakdown'][dataSource] =
            (stats['dataSourceBreakdown'][dataSource] as int? ?? 0) + 1;
      }

      // Calculate average sync interval
      if (allConfigs.isNotEmpty) {
        final totalInterval = allConfigs
            .map((c) => c.syncIntervalMinutes)
            .reduce((a, b) => a + b);
        stats['averageSyncInterval'] = totalInterval / allConfigs.length;
      }

      return stats;
    } catch (e) {
      _logger.e('Failed to get configuration statistics: $e');
      return {
        'totalConfigurations': 0,
        'activeConfigurations': 0,
        'dataSourceBreakdown': <String, int>{},
        'realTimeEnabled': 0,
        'averageSyncInterval': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }
}
