# Data Migration Service Guide

## Overview

The Data Migration Service provides comprehensive functionality for migrating from mock data to Firebase/Firestore as the primary data source for the Triage-BIOS.ai application. This service handles hospital data seeding, patient data generation, data validation, and development utilities.

## Features

### ✅ Completed Features

- **Hospital Data Seeding**: Generate realistic hospital data for major metropolitan areas
- **Mock Data Migration**: Migrate existing hardcoded hospital data to Firestore
- **Patient Data Generation**: Create sample patient vitals, triage results, and consent records
- **Data Validation**: Comprehensive validation of data integrity with detailed reporting
- **Development Utilities**: Reset, reseed, and manage development data
- **Statistics Reporting**: Get detailed statistics about current data state

## Quick Start

### 1. Basic Usage

```dart
import 'package:your_app/shared/services/data_migration_service.dart';

final migrationService = DataMigrationService();

// Seed hospital data
await migrationService.seedHospitalData();

// Generate sample patient data
await migrationService.generateSamplePatientData(
  patientCount: 10,
  vitalsPerPatient: 5,
  triageResultsPerPatient: 2,
);

// Validate data integrity
final validation = await migrationService.validateDataIntegrity();
print('Validation score: ${(validation.overallScore * 100).toStringAsFixed(1)}%');
```

### 2. Using Utility Classes

```dart
import 'package:your_app/shared/utils/data_migration_utils.dart';

// Quick test setup
await DataMigrationUtils.quickTestSetup();

// Full development setup
await DataMigrationUtils.fullDevelopmentSetup();

// Production hospital setup (no patient data)
await DataMigrationUtils.productionHospitalSetup();
```

### 3. Using the Runner for Flutter Apps

```dart
import 'package:your_app/shared/utils/data_migration_runner.dart';

// Run with progress callbacks
await DataMigrationRunner.runWithProgress(
  operation: DataMigrationOperation.quickSetup,
  onProgress: (message) => print('Progress: $message'),
  onComplete: (message) => print('Complete: $message'),
  onError: (error) => print('Error: $error'),
);

// Environment-based setup
await DataMigrationRunner.runEnvironmentSetup();
```

## Available Operations

### Hospital Data Operations

#### Seed Hospital Data
```dart
await migrationService.seedHospitalData();
```
- Creates realistic hospital data for major cities (NYC, LA, Chicago, Houston, Miami)
- Includes trauma levels, specializations, contact information
- Generates corresponding capacity data

#### Migrate Mock Data
```dart
await migrationService.migrateFromMockData();
```
- Converts existing hardcoded hospital data to Firestore format
- Preserves existing hospital IDs and relationships

### Patient Data Operations

#### Generate Sample Patient Data
```dart
await migrationService.generateSamplePatientData(
  patientCount: 10,
  vitalsPerPatient: 5,
  triageResultsPerPatient: 2,
);
```
- Creates realistic patient vitals with normal and abnormal values
- Generates triage results with AI reasoning and confidence scores
- Creates consent records with blockchain transaction IDs

### Validation and Statistics

#### Validate Data Integrity
```dart
final validation = await migrationService.validateDataIntegrity();

if (validation.isValid) {
  print('✅ All data is valid');
} else {
  print('⚠️ Validation issues found:');
  print('- Hospital validation: ${(validation.hospitalValidationScore * 100).toStringAsFixed(1)}%');
  print('- Capacity validation: ${(validation.capacityValidationScore * 100).toStringAsFixed(1)}%');
}
```

#### Get Statistics
```dart
final stats = await migrationService.getDataStatistics();
print(stats.toString());
```

### Development Utilities

#### Reset All Data (Destructive)
```dart
await migrationService.resetDevelopmentData();
```
⚠️ **Warning**: This permanently deletes all development data!

#### Reseed All Data
```dart
await migrationService.reseedAllData();
```
Combines reset + seed + validation in one operation.

## Data Models

### Hospital Data Structure
```dart
HospitalFirestore(
  id: 'unique_id',
  name: 'Hospital Name',
  address: HospitalAddress(...),
  location: HospitalLocation(latitude: 40.7589, longitude: -73.9851),
  contact: HospitalContact(...),
  traumaLevel: 1, // 1-4
  specializations: ['emergency', 'cardiology', 'trauma'],
  certifications: ['Joint Commission', 'Magnet'],
  operatingHours: HospitalOperatingHours(...),
  isActive: true,
)
```

### Capacity Data Structure
```dart
HospitalCapacityFirestore(
  hospitalId: 'hospital_id',
  totalBeds: 450,
  availableBeds: 23,
  icuBeds: 45,
  icuAvailable: 8,
  emergencyBeds: 67,
  emergencyAvailable: 12,
  staffOnDuty: 85,
  patientsInQueue: 5,
  averageWaitTime: 30.0,
  dataSource: DataSource.firestore,
  isRealTime: false,
)
```

### Patient Vitals Structure
```dart
PatientVitalsFirestore(
  patientId: 'patient_id',
  heartRate: 75.0,
  bloodPressureSystolic: 120.0,
  bloodPressureDiastolic: 80.0,
  oxygenSaturation: 98.0,
  temperature: 98.6,
  source: VitalsSource.manual,
  accuracy: 0.95,
  timestamp: DateTime.now(),
  isValidated: true,
)
```

## Configuration Options

### Migration Configuration
```dart
const config = MigrationConfig(
  includePatientData: true,
  patientCount: 25,
  vitalsPerPatient: 10,
  triageResultsPerPatient: 5,
  resetExistingData: true,
);

await DataMigrationRunner.initializeAndRun(
  operation: DataMigrationOperation.customSetup,
  options: config.toMap(),
);
```

### Predefined Configurations
- `MigrationConfig.quick`: 3 patients, minimal data
- `MigrationConfig.full`: 25 patients, comprehensive data
- `MigrationConfig.production`: Hospitals only, no patient data

## CLI Usage

Use the provided CLI script for command-line operations:

```bash
# Quick setup
dart run scripts/data_migration_cli.dart --quick

# Custom setup
dart run scripts/data_migration_cli.dart --setup --patient-count 20

# Hospitals only
dart run scripts/data_migration_cli.dart --hospitals-only

# Validate data
dart run scripts/data_migration_cli.dart --validate

# Show statistics
dart run scripts/data_migration_cli.dart --stats
```

## Testing

Run the comprehensive test suite:

```bash
flutter test test/services/data_migration_service_test.dart
```

The tests cover:
- Data validation logic
- Sample data generation
- Enum handling
- Statistics calculation
- Validation results

## Best Practices

### Development Environment
1. Use `quickTestSetup()` for rapid development
2. Use `fullDevelopmentSetup()` for comprehensive testing
3. Regularly validate data integrity during development

### Production Environment
1. Use `productionHospitalSetup()` for production deployments
2. Never include sample patient data in production
3. Implement proper data source configuration for hospital APIs

### Data Management
1. Always validate data after migration operations
2. Monitor data statistics regularly
3. Use the reset functionality only in development environments

## Troubleshooting

### Common Issues

#### Firebase Not Initialized
```dart
// Ensure Firebase is initialized before using migration service
await Firebase.initializeApp();
```

#### Validation Failures
- Check hospital data completeness (name, address, contact info)
- Verify capacity data consistency (available ≤ total beds)
- Ensure location coordinates are valid (-90 to 90 lat, -180 to 180 lng)

#### Performance Issues
- Use batch operations for large datasets
- Implement pagination for large queries
- Monitor Firestore usage and costs

### Error Handling
```dart
try {
  await migrationService.seedHospitalData();
} catch (e) {
  logger.error('Migration failed: $e');
  // Implement appropriate error handling
}
```

## Requirements Satisfied

This implementation satisfies the following requirements from the specification:

- **7.1**: ✅ Seed Firestore with realistic hospital data for major metropolitan areas
- **7.2**: ✅ Migrate existing mock data to Firestore collections
- **7.3**: ✅ Create hospitals with varied capacity, specializations, and performance metrics
- **7.4**: ✅ Provide utilities to reset and reseed Firestore collections

## Next Steps

After completing the data migration setup:

1. **Task 4**: Refactor HospitalService to use FirestoreDataService
2. **Task 5**: Implement patient data persistence
3. **Task 6**: Add real-time updates and monitoring
4. **Task 7**: Integrate wearable device data

## Support

For issues or questions about the Data Migration Service:
1. Check the test files for usage examples
2. Review the validation results for data integrity issues
3. Use the statistics functionality to monitor data state
4. Refer to the Firebase/Firestore documentation for underlying service issues