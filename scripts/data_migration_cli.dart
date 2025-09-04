#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';

// Note: This is a standalone CLI script for data migration operations
// To use this script, run: dart run scripts/data_migration_cli.dart [options]

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show this help message')
    ..addFlag('setup', help: 'Setup complete development data')
    ..addFlag('quick', help: 'Quick test setup (minimal data)')
    ..addFlag('full', help: 'Full development setup (comprehensive data)')
    ..addFlag('hospitals-only', help: 'Seed hospitals only')
    ..addFlag('patients-only', help: 'Generate patient data only')
    ..addFlag('migrate', help: 'Migrate mock data to Firestore')
    ..addFlag('validate', help: 'Validate data integrity')
    ..addFlag('stats', help: 'Show data statistics')
    ..addFlag('reset', help: 'Reset all data (destructive)')
    ..addOption(
      'patient-count',
      help: 'Number of patients to generate',
      defaultsTo: '10',
    )
    ..addOption(
      'vitals-per-patient',
      help: 'Vitals records per patient',
      defaultsTo: '5',
    )
    ..addOption(
      'triage-per-patient',
      help: 'Triage results per patient',
      defaultsTo: '2',
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _showHelp(parser);
      return;
    }

    // Print banner
    _printBanner();

    // Parse options
    final patientCount = int.parse(results['patient-count'] as String);
    final vitalsPerPatient = int.parse(results['vitals-per-patient'] as String);
    final triagePerPatient = int.parse(results['triage-per-patient'] as String);

    // Execute commands
    if (results['setup'] as bool) {
      await _setupDevelopmentData(
        patientCount,
        vitalsPerPatient,
        triagePerPatient,
      );
    } else if (results['quick'] as bool) {
      await _quickSetup();
    } else if (results['full'] as bool) {
      await _fullSetup();
    } else if (results['hospitals-only'] as bool) {
      await _seedHospitalsOnly();
    } else if (results['patients-only'] as bool) {
      await _generatePatientsOnly(
        patientCount,
        vitalsPerPatient,
        triagePerPatient,
      );
    } else if (results['migrate'] as bool) {
      await _migrateMockData();
    } else if (results['validate'] as bool) {
      await _validateData();
    } else if (results['stats'] as bool) {
      await _showStatistics();
    } else if (results['reset'] as bool) {
      await _resetData();
    } else {
      print('No command specified. Use --help for available options.');
      _showHelp(parser);
    }
  } catch (e) {
    print('Error: $e');
    _showHelp(parser);
    exit(1);
  }
}

void _printBanner() {
  print('');
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║                 Triage-BIOS.ai Data Migration CLI           ║');
  print('║                     Firebase Data Management                 ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
}

void _showHelp(ArgParser parser) {
  print('Triage-BIOS.ai Data Migration CLI');
  print('');
  print('Usage: dart run scripts/data_migration_cli.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart run scripts/data_migration_cli.dart --quick');
  print(
    '  dart run scripts/data_migration_cli.dart --setup --patient-count 20',
  );
  print('  dart run scripts/data_migration_cli.dart --hospitals-only');
  print('  dart run scripts/data_migration_cli.dart --validate');
  print('  dart run scripts/data_migration_cli.dart --stats');
  print('');
}

Future<void> _setupDevelopmentData(
  int patientCount,
  int vitalsPerPatient,
  int triagePerPatient,
) async {
  print('🚀 Setting up complete development data...');
  print('   - Patient count: $patientCount');
  print('   - Vitals per patient: $vitalsPerPatient');
  print('   - Triage results per patient: $triagePerPatient');
  print('');

  // Note: In a real implementation, you would import and use DataMigrationUtils here
  print('⚠️  This is a CLI template. To use this script:');
  print('   1. Import the DataMigrationUtils class');
  print('   2. Initialize Firebase in the script');
  print('   3. Call DataMigrationUtils.setupDevelopmentData()');
  print('');
  print('Example implementation:');
  print('   await DataMigrationUtils.setupDevelopmentData(');
  print('     includePatientData: true,');
  print('     patientCount: $patientCount,');
  print('     vitalsPerPatient: $vitalsPerPatient,');
  print('     triageResultsPerPatient: $triagePerPatient,');
  print('   );');
}

Future<void> _quickSetup() async {
  print('⚡ Running quick test setup...');
  print('   - 3 patients, 2 vitals each, 1 triage result each');
  print('');
  print('⚠️  Call: await DataMigrationUtils.quickTestSetup();');
}

Future<void> _fullSetup() async {
  print('🏗️  Running full development setup...');
  print('   - 25 patients, 10 vitals each, 5 triage results each');
  print('');
  print('⚠️  Call: await DataMigrationUtils.fullDevelopmentSetup();');
}

Future<void> _seedHospitalsOnly() async {
  print('🏥 Seeding hospitals only...');
  print('');
  print('⚠️  Call: await DataMigrationUtils.seedHospitalsOnly();');
}

Future<void> _generatePatientsOnly(
  int patientCount,
  int vitalsPerPatient,
  int triagePerPatient,
) async {
  print('👥 Generating patient data only...');
  print('   - Patient count: $patientCount');
  print('   - Vitals per patient: $vitalsPerPatient');
  print('   - Triage results per patient: $triagePerPatient');
  print('');
  print('⚠️  Call: await DataMigrationUtils.generatePatientDataOnly(');
  print('     patientCount: $patientCount,');
  print('     vitalsPerPatient: $vitalsPerPatient,');
  print('     triageResultsPerPatient: $triagePerPatient,');
  print('   );');
}

Future<void> _migrateMockData() async {
  print('📦 Migrating mock data to Firestore...');
  print('');
  print('⚠️  Call: await DataMigrationUtils.migrateMockData();');
}

Future<void> _validateData() async {
  print('✅ Validating data integrity...');
  print('');
  print('⚠️  Call: await DataMigrationUtils.validateData();');
}

Future<void> _showStatistics() async {
  print('📊 Showing data statistics...');
  print('');
  print('⚠️  Call: await DataMigrationUtils.getStatistics();');
}

Future<void> _resetData() async {
  print('🗑️  Resetting all data...');
  print('');
  print('⚠️  WARNING: This is a destructive operation!');
  print('⚠️  Call: await DataMigrationUtils.resetAllData();');
}
