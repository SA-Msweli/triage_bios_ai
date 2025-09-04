import 'package:logger/logger.dart';
import '../services/data_migration_service.dart';

/// Utility class for running data migration and seeding operations
class DataMigrationUtils {
  static final Logger _logger = Logger();
  static final DataMigrationService _migrationService = DataMigrationService();

  /// Run complete data setup (reset + seed + validate)
  static Future<void> setupDevelopmentData({
    bool includePatientData = true,
    int patientCount = 10,
    int vitalsPerPatient = 5,
    int triageResultsPerPatient = 2,
  }) async {
    try {
      _logger.i('Starting complete development data setup...');

      // Step 1: Reset existing data
      _logger.i('Step 1: Resetting existing data...');
      await _migrationService.resetDevelopmentData();

      // Step 2: Seed hospital data
      _logger.i('Step 2: Seeding hospital data...');
      await _migrationService.seedHospitalData();

      // Step 3: Generate sample patient data (optional)
      if (includePatientData) {
        _logger.i('Step 3: Generating sample patient data...');
        await _migrationService.generateSamplePatientData(
          patientCount: patientCount,
          vitalsPerPatient: vitalsPerPatient,
          triageResultsPerPatient: triageResultsPerPatient,
        );
      }

      // Step 4: Validate data integrity
      _logger.i('Step 4: Validating data integrity...');
      final validation = await _migrationService.validateDataIntegrity();

      if (validation.isValid) {
        _logger.i('✅ Development data setup completed successfully!');
        _logger.i(
          'Overall validation score: ${(validation.overallScore * 100).toStringAsFixed(1)}%',
        );
      } else {
        _logger.w('⚠️ Data setup completed with warnings');
        _logger.w(
          'Overall validation score: ${(validation.overallScore * 100).toStringAsFixed(1)}%',
        );
        if (validation.error != null) {
          _logger.e('Validation error: ${validation.error}');
        }
      }

      // Step 5: Show statistics
      final stats = await _migrationService.getDataStatistics();
      _logger.i('Data Statistics:');
      _logger.i(stats.toString());
    } catch (e) {
      _logger.e('Failed to setup development data: $e');
      rethrow;
    }
  }

  /// Seed only hospital data (without resetting)
  static Future<void> seedHospitalsOnly() async {
    try {
      _logger.i('Seeding hospital data only...');
      await _migrationService.seedHospitalData();

      final validation = await _migrationService.validateDataIntegrity();
      _logger.i(
        'Hospital seeding completed with ${(validation.hospitalValidationScore * 100).toStringAsFixed(1)}% validation score',
      );
    } catch (e) {
      _logger.e('Failed to seed hospital data: $e');
      rethrow;
    }
  }

  /// Generate only patient data (requires existing hospitals)
  static Future<void> generatePatientDataOnly({
    int patientCount = 10,
    int vitalsPerPatient = 5,
    int triageResultsPerPatient = 2,
  }) async {
    try {
      _logger.i('Generating patient data only...');
      await _migrationService.generateSamplePatientData(
        patientCount: patientCount,
        vitalsPerPatient: vitalsPerPatient,
        triageResultsPerPatient: triageResultsPerPatient,
      );

      final stats = await _migrationService.getDataStatistics();
      _logger.i('Patient data generation completed');
      _logger.i(
        'Generated: ${stats.totalVitalsRecords} vitals, ${stats.totalTriageResults} triage results, ${stats.totalConsentRecords} consents',
      );
    } catch (e) {
      _logger.e('Failed to generate patient data: $e');
      rethrow;
    }
  }

  /// Migrate existing mock data to Firestore
  static Future<void> migrateMockData() async {
    try {
      _logger.i('Migrating mock data to Firestore...');
      await _migrationService.migrateFromMockData();

      final validation = await _migrationService.validateDataIntegrity();
      _logger.i(
        'Mock data migration completed with ${(validation.overallScore * 100).toStringAsFixed(1)}% validation score',
      );
    } catch (e) {
      _logger.e('Failed to migrate mock data: $e');
      rethrow;
    }
  }

  /// Validate current data integrity
  static Future<ValidationResult> validateData() async {
    try {
      _logger.i('Validating data integrity...');
      final validation = await _migrationService.validateDataIntegrity();

      _logger.i('Validation Results:');
      _logger.i(
        '- Hospitals: ${validation.hospitalsValid}/${validation.hospitalCount} valid (${(validation.hospitalValidationScore * 100).toStringAsFixed(1)}%)',
      );
      _logger.i(
        '- Capacities: ${validation.capacitiesValid}/${validation.capacityCount} valid (${(validation.capacityValidationScore * 100).toStringAsFixed(1)}%)',
      );
      _logger.i(
        '- Overall Score: ${(validation.overallScore * 100).toStringAsFixed(1)}%',
      );

      if (validation.hasWarnings) {
        _logger.w('Warnings:');
        if (validation.orphanedCapacities > 0) {
          _logger.w(
            '- ${validation.orphanedCapacities} orphaned capacity records',
          );
        }
        if (validation.staleCapacities > 0) {
          _logger.w('- ${validation.staleCapacities} stale capacity records');
        }
      }

      return validation;
    } catch (e) {
      _logger.e('Failed to validate data: $e');
      rethrow;
    }
  }

  /// Get current data statistics
  static Future<DataStatistics> getStatistics() async {
    try {
      _logger.i('Retrieving data statistics...');
      final stats = await _migrationService.getDataStatistics();

      _logger.i('Current Data Statistics:');
      _logger.i(stats.toString());

      return stats;
    } catch (e) {
      _logger.e('Failed to get statistics: $e');
      rethrow;
    }
  }

  /// Reset all development data (destructive operation)
  static Future<void> resetAllData() async {
    try {
      _logger.w('⚠️ DESTRUCTIVE OPERATION: Resetting all development data...');
      await _migrationService.resetDevelopmentData();
      _logger.i('All development data has been reset');
    } catch (e) {
      _logger.e('Failed to reset data: $e');
      rethrow;
    }
  }

  /// Quick setup for testing (minimal data)
  static Future<void> quickTestSetup() async {
    await setupDevelopmentData(
      includePatientData: true,
      patientCount: 3,
      vitalsPerPatient: 2,
      triageResultsPerPatient: 1,
    );
  }

  /// Full setup for development (comprehensive data)
  static Future<void> fullDevelopmentSetup() async {
    await setupDevelopmentData(
      includePatientData: true,
      patientCount: 25,
      vitalsPerPatient: 10,
      triageResultsPerPatient: 5,
    );
  }

  /// Production-ready hospital data only (no patient data)
  static Future<void> productionHospitalSetup() async {
    await setupDevelopmentData(includePatientData: false);
  }
}

/// Extension methods for easier access to migration utilities
extension DataMigrationExtensions on DataMigrationService {
  /// Quick access to setup development data
  Future<void> quickSetup() => DataMigrationUtils.quickTestSetup();

  /// Quick access to full development setup
  Future<void> fullSetup() => DataMigrationUtils.fullDevelopmentSetup();

  /// Quick access to validation
  Future<ValidationResult> validate() => DataMigrationUtils.validateData();

  /// Quick access to statistics
  Future<DataStatistics> stats() => DataMigrationUtils.getStatistics();
}
