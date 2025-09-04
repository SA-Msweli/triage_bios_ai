import 'package:flutter_test/flutter_test.dart';

// Unit Tests
import 'unit/services/firestore_data_service_unit_test.dart' as firestore_unit;
import 'unit/services/enhanced_firestore_data_service_unit_test.dart'
    as enhanced_unit;
import 'unit/services/data_migration_service_unit_test.dart' as migration_unit;

// Integration Tests
import 'integration/firestore_integration_test.dart' as firestore_integration;

// Performance Tests
import 'performance/firestore_performance_test.dart' as firestore_performance;

// Validation Tests
import 'validation/data_integrity_validation_test.dart' as data_integrity;

// Existing Tests
import 'services/enhanced_firestore_data_service_test.dart'
    as existing_enhanced;
import 'services/data_migration_service_test.dart' as existing_migration;
import 'patient_data_persistence_test.dart' as patient_persistence;
import 'offline_support_test.dart' as offline_support;
import 'security_compliance_test.dart' as security_compliance;

void main() {
  group('Firebase Data Integration - Comprehensive Test Suite', () {
    group('Unit Tests', () {
      group('Firestore Data Service Unit Tests', firestore_unit.main);
      group('Enhanced Firestore Data Service Unit Tests', enhanced_unit.main);
      group('Data Migration Service Unit Tests', migration_unit.main);
    });

    group('Integration Tests', () {
      group('Firestore Integration Tests', firestore_integration.main);
    });

    group('Performance Tests', () {
      group('Firestore Performance Tests', firestore_performance.main);
    });

    group('Data Integrity Validation Tests', () {
      group('Data Integrity Validation', data_integrity.main);
    });

    group('Existing Test Suite', () {
      group('Enhanced Firestore Service Tests', existing_enhanced.main);
      group('Data Migration Service Tests', existing_migration.main);
      group('Patient Data Persistence Tests', patient_persistence.main);
      group('Offline Support Tests', offline_support.main);
      group('Security Compliance Tests', security_compliance.main);
    });
  });
}
