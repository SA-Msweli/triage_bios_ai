import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../services/firebase_service.dart';
import 'data_migration_utils.dart';

/// Runner class for executing data migration operations in Flutter app
class DataMigrationRunner {
  static final Logger _logger = Logger();
  static final FirebaseService _firebaseService = FirebaseService();

  /// Initialize Firebase and run data migration operations
  static Future<void> initializeAndRun({
    required DataMigrationOperation operation,
    Map<String, dynamic>? options,
  }) async {
    try {
      // Ensure Firebase is initialized
      if (!_firebaseService.isInitialized) {
        _logger.i('Initializing Firebase...');
        await _firebaseService.initialize();
      }

      // Execute the requested operation
      await _executeOperation(operation, options ?? {});
    } catch (e) {
      _logger.e('Failed to run data migration operation: $e');
      rethrow;
    }
  }

  /// Execute specific migration operation
  static Future<void> _executeOperation(
    DataMigrationOperation operation,
    Map<String, dynamic> options,
  ) async {
    switch (operation) {
      case DataMigrationOperation.quickSetup:
        await DataMigrationUtils.quickTestSetup();
        break;

      case DataMigrationOperation.fullSetup:
        await DataMigrationUtils.fullDevelopmentSetup();
        break;

      case DataMigrationOperation.customSetup:
        await DataMigrationUtils.setupDevelopmentData(
          includePatientData: options['includePatientData'] ?? true,
          patientCount: options['patientCount'] ?? 10,
          vitalsPerPatient: options['vitalsPerPatient'] ?? 5,
          triageResultsPerPatient: options['triageResultsPerPatient'] ?? 2,
        );
        break;

      case DataMigrationOperation.hospitalsOnly:
        await DataMigrationUtils.seedHospitalsOnly();
        break;

      case DataMigrationOperation.patientsOnly:
        await DataMigrationUtils.generatePatientDataOnly(
          patientCount: options['patientCount'] ?? 10,
          vitalsPerPatient: options['vitalsPerPatient'] ?? 5,
          triageResultsPerPatient: options['triageResultsPerPatient'] ?? 2,
        );
        break;

      case DataMigrationOperation.migrateMock:
        await DataMigrationUtils.migrateMockData();
        break;

      case DataMigrationOperation.validate:
        await DataMigrationUtils.validateData();
        break;

      case DataMigrationOperation.statistics:
        await DataMigrationUtils.getStatistics();
        break;

      case DataMigrationOperation.reset:
        await DataMigrationUtils.resetAllData();
        break;

      case DataMigrationOperation.productionSetup:
        await DataMigrationUtils.productionHospitalSetup();
        break;
    }
  }

  /// Run migration with UI feedback (for Flutter apps)
  static Future<void> runWithProgress({
    required DataMigrationOperation operation,
    Map<String, dynamic>? options,
    Function(String)? onProgress,
    Function(String)? onComplete,
    Function(String)? onError,
  }) async {
    try {
      onProgress?.call('Initializing Firebase...');

      if (!_firebaseService.isInitialized) {
        await _firebaseService.initialize();
      }

      onProgress?.call('Starting ${operation.displayName}...');

      await _executeOperation(operation, options ?? {});

      onComplete?.call('${operation.displayName} completed successfully!');
    } catch (e) {
      final errorMessage = 'Failed to complete ${operation.displayName}: $e';
      _logger.e(errorMessage);
      onError?.call(errorMessage);
      rethrow;
    }
  }

  /// Check if Firebase is ready for migration operations
  static Future<bool> isReady() async {
    try {
      return _firebaseService.isInitialized;
    } catch (e) {
      _logger.w('Firebase readiness check failed: $e');
      return false;
    }
  }

  /// Get available operations for UI
  static List<DataMigrationOperation> getAvailableOperations() {
    return DataMigrationOperation.values;
  }

  /// Run development setup based on environment
  static Future<void> runEnvironmentSetup() async {
    if (kDebugMode) {
      _logger.i('Running development environment setup...');
      await initializeAndRun(operation: DataMigrationOperation.quickSetup);
    } else {
      _logger.i('Running production environment setup...');
      await initializeAndRun(operation: DataMigrationOperation.productionSetup);
    }
  }
}

/// Available data migration operations
enum DataMigrationOperation {
  quickSetup,
  fullSetup,
  customSetup,
  hospitalsOnly,
  patientsOnly,
  migrateMock,
  validate,
  statistics,
  reset,
  productionSetup;

  String get displayName {
    switch (this) {
      case DataMigrationOperation.quickSetup:
        return 'Quick Test Setup';
      case DataMigrationOperation.fullSetup:
        return 'Full Development Setup';
      case DataMigrationOperation.customSetup:
        return 'Custom Setup';
      case DataMigrationOperation.hospitalsOnly:
        return 'Seed Hospitals Only';
      case DataMigrationOperation.patientsOnly:
        return 'Generate Patient Data Only';
      case DataMigrationOperation.migrateMock:
        return 'Migrate Mock Data';
      case DataMigrationOperation.validate:
        return 'Validate Data Integrity';
      case DataMigrationOperation.statistics:
        return 'Show Statistics';
      case DataMigrationOperation.reset:
        return 'Reset All Data';
      case DataMigrationOperation.productionSetup:
        return 'Production Hospital Setup';
    }
  }

  String get description {
    switch (this) {
      case DataMigrationOperation.quickSetup:
        return 'Quick setup with minimal test data (3 patients, 2 vitals each)';
      case DataMigrationOperation.fullSetup:
        return 'Comprehensive setup with full test data (25 patients, 10 vitals each)';
      case DataMigrationOperation.customSetup:
        return 'Custom setup with configurable parameters';
      case DataMigrationOperation.hospitalsOnly:
        return 'Seed realistic hospital data for major cities';
      case DataMigrationOperation.patientsOnly:
        return 'Generate sample patient vitals and triage data';
      case DataMigrationOperation.migrateMock:
        return 'Migrate existing mock data from code to Firestore';
      case DataMigrationOperation.validate:
        return 'Validate data integrity and show validation report';
      case DataMigrationOperation.statistics:
        return 'Display current data statistics and counts';
      case DataMigrationOperation.reset:
        return 'Reset all development data (destructive operation)';
      case DataMigrationOperation.productionSetup:
        return 'Setup production-ready hospital data without patient data';
    }
  }

  bool get isDestructive {
    return this == DataMigrationOperation.reset ||
        this == DataMigrationOperation.quickSetup ||
        this == DataMigrationOperation.fullSetup ||
        this == DataMigrationOperation.customSetup;
  }
}

/// Configuration class for migration operations
class MigrationConfig {
  final bool includePatientData;
  final int patientCount;
  final int vitalsPerPatient;
  final int triageResultsPerPatient;
  final bool resetExistingData;

  const MigrationConfig({
    this.includePatientData = true,
    this.patientCount = 10,
    this.vitalsPerPatient = 5,
    this.triageResultsPerPatient = 2,
    this.resetExistingData = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'includePatientData': includePatientData,
      'patientCount': patientCount,
      'vitalsPerPatient': vitalsPerPatient,
      'triageResultsPerPatient': triageResultsPerPatient,
      'resetExistingData': resetExistingData,
    };
  }

  static const MigrationConfig quick = MigrationConfig(
    includePatientData: true,
    patientCount: 3,
    vitalsPerPatient: 2,
    triageResultsPerPatient: 1,
    resetExistingData: true,
  );

  static const MigrationConfig full = MigrationConfig(
    includePatientData: true,
    patientCount: 25,
    vitalsPerPatient: 10,
    triageResultsPerPatient: 5,
    resetExistingData: true,
  );

  static const MigrationConfig production = MigrationConfig(
    includePatientData: false,
    patientCount: 0,
    vitalsPerPatient: 0,
    triageResultsPerPatient: 0,
    resetExistingData: true,
  );
}
