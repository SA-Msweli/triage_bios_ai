import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triage_bios_ai/shared/services/real_time_monitoring_service.dart';
import 'package:triage_bios_ai/shared/services/notification_service.dart';
import 'package:triage_bios_ai/shared/models/firestore/hospital_capacity_firestore.dart';
import 'package:triage_bios_ai/shared/models/firestore/patient_vitals_firestore.dart';

void main() {
  group('Real-Time Monitoring Service Tests', () {
    late RealTimeMonitoringService monitoringService;

    setUp(() {
      monitoringService = RealTimeMonitoringService();
    });

    tearDown(() {
      monitoringService.dispose();
    });

    test('should initialize monitoring service correctly', () {
      expect(monitoringService.isMonitoring, false);
      expect(monitoringService.monitoredHospitalIds, isEmpty);
    });

    test('should provide monitoring status information', () {
      final status = monitoringService.monitoringStatus;

      expect(status.isActive, false); // Not started yet
      expect(status.totalSubscriptions, 0);
      expect(status.health, MonitoringHealth.inactive);
    });

    test('should create capacity alerts correctly', () {
      final criticalCapacity = HospitalCapacityFirestore(
        id: 'test-capacity-1',
        hospitalId: 'hospital-1',
        totalBeds: 100,
        availableBeds: 2,
        icuBeds: 20,
        icuAvailable: 1,
        emergencyBeds: 15,
        emergencyAvailable: 0,
        staffOnDuty: 50,
        patientsInQueue: 25,
        averageWaitTime: 180,
        lastUpdated: DateTime.now(),
        dataSource: DataSource.firestore,
        isRealTime: true,
      );

      // Test capacity calculations
      expect(criticalCapacity.occupancyRate, greaterThan(0.95));
      expect(criticalCapacity.isAtCapacity, true);
      expect(criticalCapacity.emergencyAvailable, 0);
      expect(criticalCapacity.icuAvailable, 1);
      expect(criticalCapacity.averageWaitTime, greaterThan(120));
    });

    test('should create vitals alerts for critical patient vitals', () {
      final criticalVitals = PatientVitalsFirestore(
        id: 'test-vitals-1',
        patientId: 'patient-1',
        heartRate: 45, // Critical low heart rate
        oxygenSaturation: 85, // Critical low oxygen
        temperature: 103.5, // Critical high temperature
        bloodPressureSystolic: 200, // Critical high BP
        bloodPressureDiastolic: 130,
        source: VitalsSource.device,
        accuracy: 0.95,
        timestamp: DateTime.now(),
        isValidated: true,
      );

      // Test vitals calculations
      expect(criticalVitals.hasAbnormalVitals, true);
      expect(criticalVitals.vitalsSeverityScore, greaterThan(2.0));
    });

    test('should calculate vitals statistics correctly', () {
      final vitals1 = PatientVitalsFirestore(
        id: 'vitals-1',
        patientId: 'patient-1',
        heartRate: 120, // Abnormal
        oxygenSaturation: 98, // Normal
        source: VitalsSource.device,
        accuracy: 0.95,
        timestamp: DateTime.now(),
        isValidated: true,
      );

      final vitals2 = PatientVitalsFirestore(
        id: 'vitals-2',
        patientId: 'patient-2',
        heartRate: 45, // Critical
        oxygenSaturation: 85, // Critical
        source: VitalsSource.device,
        accuracy: 0.95,
        timestamp: DateTime.now(),
        isValidated: true,
      );

      final vitals3 = PatientVitalsFirestore(
        id: 'vitals-3',
        patientId: 'patient-3',
        heartRate: 75, // Normal
        oxygenSaturation: 99, // Normal
        source: VitalsSource.device,
        accuracy: 0.95,
        timestamp: DateTime.now(),
        isValidated: true,
      );

      // Test individual vitals severity
      expect(
        vitals1.vitalsSeverityScore,
        greaterThan(0.5),
      ); // Should be warning
      expect(
        vitals2.vitalsSeverityScore,
        greaterThan(2.0),
      ); // Should be critical
      expect(vitals3.vitalsSeverityScore, lessThan(1.0)); // Should be stable

      // Test abnormal vitals detection
      expect(vitals1.hasAbnormalVitals, true);
      expect(vitals2.hasAbnormalVitals, true);
      expect(vitals3.hasAbnormalVitals, false);
    });
  });

  group('Notification Service Tests', () {
    late NotificationService notificationService;

    setUp(() {
      notificationService = NotificationService();
    });

    tearDown(() {
      notificationService.dispose();
    });

    test('should initialize with default settings', () {
      final settings = notificationService.settings;
      expect(settings.capacityAlertsEnabled, true);
      expect(settings.vitalsAlertsEnabled, true);
      expect(settings.soundEnabled, true);
      expect(settings.minimumSeverity, AlertSeverity.warning);
    });

    test('should update notification settings', () {
      notificationService.setCapacityAlertsEnabled(false);
      notificationService.setVitalsAlertsEnabled(false);
      notificationService.setSoundEnabled(false);
      notificationService.setMinimumSeverity(AlertSeverity.critical);

      final settings = notificationService.settings;
      expect(settings.capacityAlertsEnabled, false);
      expect(settings.vitalsAlertsEnabled, false);
      expect(settings.soundEnabled, false);
      expect(settings.minimumSeverity, AlertSeverity.critical);
    });

    test('should create app notifications with correct properties', () {
      final notification = AppNotification(
        id: 'test-1',
        title: 'Test Notification',
        message: 'This is a test message',
        severity: AlertSeverity.warning,
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 5),
      );

      expect(notification.title, 'Test Notification');
      expect(notification.severity, AlertSeverity.warning);
      expect(notification.color, Colors.orange);
    });
  });

  group('Alert Model Tests', () {
    test('should create capacity alerts correctly', () {
      final capacity = HospitalCapacityFirestore(
        id: 'test-capacity',
        hospitalId: 'test-hospital',
        totalBeds: 100,
        availableBeds: 2,
        icuBeds: 20,
        icuAvailable: 1,
        emergencyBeds: 15,
        emergencyAvailable: 0,
        staffOnDuty: 50,
        patientsInQueue: 25,
        averageWaitTime: 180,
        lastUpdated: DateTime.now(),
        dataSource: DataSource.firestore,
        isRealTime: true,
      );

      final alert = CapacityAlert(
        hospitalId: 'test-hospital',
        type: CapacityAlertType.criticalCapacity,
        message: 'Test critical capacity alert',
        severity: AlertSeverity.critical,
        timestamp: DateTime.now(),
        data: capacity,
      );

      expect(alert.hospitalId, 'test-hospital');
      expect(alert.type, CapacityAlertType.criticalCapacity);
      expect(alert.severity, AlertSeverity.critical);
      expect(alert.data.occupancyRate, greaterThan(0.95));
    });

    test('should create vitals alerts correctly', () {
      final vitals = PatientVitalsFirestore(
        id: 'test-vitals',
        patientId: 'test-patient',
        heartRate: 45,
        oxygenSaturation: 85,
        source: VitalsSource.device,
        accuracy: 0.95,
        timestamp: DateTime.now(),
        isValidated: true,
      );

      final alert = VitalsAlert(
        patientId: 'test-patient',
        type: VitalsAlertType.criticalVitals,
        message: 'Test critical vitals alert',
        severity: AlertSeverity.critical,
        timestamp: DateTime.now(),
        data: vitals,
      );

      expect(alert.patientId, 'test-patient');
      expect(alert.type, VitalsAlertType.criticalVitals);
      expect(alert.severity, AlertSeverity.critical);
      expect(alert.data.hasAbnormalVitals, true);
    });
  });

  group('Statistics Model Tests', () {
    test('should create vitals statistics correctly', () {
      final stats = VitalsStatistics(
        totalPatients: 10,
        criticalCount: 2,
        warningCount: 3,
        stableCount: 5,
        averageSeverity: 1.5,
        timeWindow: const Duration(hours: 1),
        lastUpdated: DateTime.now(),
        latestVitalsPerPatient: [],
      );

      expect(stats.totalPatients, 10);
      expect(
        stats.overallStatus,
        VitalsOverallStatus.critical,
      ); // 2 critical patients makes overall status critical

      final percentages = stats.percentages;
      expect(percentages['critical'], 20.0);
      expect(percentages['warning'], 30.0);
      expect(percentages['stable'], 50.0);
    });

    test('should handle empty vitals statistics', () {
      final stats = VitalsStatistics.empty();

      expect(stats.totalPatients, 0);
      expect(stats.overallStatus, VitalsOverallStatus.noData);

      final percentages = stats.percentages;
      expect(percentages['critical'], 0.0);
      expect(percentages['warning'], 0.0);
      expect(percentages['stable'], 0.0);
    });

    test('should create monitoring status correctly', () {
      final status = MonitoringStatus(
        isActive: true,
        hospitalCount: 5,
        capacitySubscriptions: 2,
        vitalsSubscriptions: 3,
        triageSubscriptions: 1,
        totalSubscriptions: 6,
      );

      expect(status.isActive, true);
      expect(status.health, MonitoringHealth.healthy);
    });

    test('should detect monitoring health issues', () {
      final inactiveStatus = MonitoringStatus(
        isActive: false,
        hospitalCount: 0,
        capacitySubscriptions: 0,
        vitalsSubscriptions: 0,
        triageSubscriptions: 0,
        totalSubscriptions: 0,
      );

      expect(inactiveStatus.health, MonitoringHealth.inactive);

      final noSubscriptionsStatus = MonitoringStatus(
        isActive: true,
        hospitalCount: 5,
        capacitySubscriptions: 0,
        vitalsSubscriptions: 0,
        triageSubscriptions: 0,
        totalSubscriptions: 0,
      );

      expect(noSubscriptionsStatus.health, MonitoringHealth.noSubscriptions);

      final partialStatus = MonitoringStatus(
        isActive: true,
        hospitalCount: 5,
        capacitySubscriptions: 2,
        vitalsSubscriptions: 0,
        triageSubscriptions: 0,
        totalSubscriptions: 2,
      );

      expect(partialStatus.health, MonitoringHealth.partial);
    });
  });
}
