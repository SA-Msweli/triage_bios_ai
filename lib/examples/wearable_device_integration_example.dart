import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../shared/services/wearable_device_service.dart';
import '../shared/services/multi_platform_health_service.dart';
import '../shared/services/device_sync_service.dart';
import '../features/triage/domain/entities/patient_vitals.dart';

/// Example demonstrating wearable device data integration with Firestore
class WearableDeviceIntegrationExample extends StatefulWidget {
  const WearableDeviceIntegrationExample({Key? key}) : super(key: key);

  @override
  State<WearableDeviceIntegrationExample> createState() =>
      _WearableDeviceIntegrationExampleState();
}

class _WearableDeviceIntegrationExampleState
    extends State<WearableDeviceIntegrationExample> {
  final Logger _logger = Logger();
  final WearableDeviceService _wearableService = WearableDeviceService();
  final MultiPlatformHealthService _healthService =
      MultiPlatformHealthService();
  final DeviceSyncService _syncService = DeviceSyncService();

  bool _isInitialized = false;
  String? _currentPatientId;
  Map<String, dynamic>? _syncStatus;
  List<Map<String, dynamic>> _deviceStatuses = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _logger.i('Initializing wearable device integration services...');

      // Initialize all services
      await _wearableService.initialize();
      await _healthService.initialize();
      await _syncService.initialize();

      // Set up a demo patient
      _currentPatientId = 'demo_patient_123';
      await _healthService.setCurrentPatient(_currentPatientId!);

      // Set up default vitals thresholds
      await _wearableService.setVitalsThresholds(
        patientId: _currentPatientId!,
        minHeartRate: 50.0,
        maxHeartRate: 120.0,
        minOxygenSaturation: 90.0,
        maxTemperature: 101.5,
        enableAutoTriage: true,
      );

      setState(() {
        _isInitialized = true;
      });

      _logger.i('Wearable device integration initialized successfully');

      // Start periodic status updates
      _startStatusUpdates();
    } catch (e) {
      _logger.e('Failed to initialize wearable device integration: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Initialization failed: $e')));
    }
  }

  void _startStatusUpdates() {
    // Update status every 10 seconds
    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        _updateStatus();
        _startStatusUpdates();
      }
    });
  }

  Future<void> _updateStatus() async {
    try {
      final syncStatus = await _healthService.getSyncStatus();
      setState(() {
        _syncStatus = syncStatus;
      });
    } catch (e) {
      _logger.e('Failed to update status: $e');
    }
  }

  Future<void> _syncVitalsNow() async {
    try {
      await _healthService.syncVitalsNow();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vitals synced successfully!')),
      );
      await _updateStatus();
    } catch (e) {
      _logger.e('Manual sync failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }

  Future<void> _forceSyncAll() async {
    try {
      await _healthService.forceSyncAll();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Force sync completed!')));
      await _updateStatus();
    } catch (e) {
      _logger.e('Force sync failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Force sync failed: $e')));
    }
  }

  Future<void> _simulateVitalsData() async {
    if (_currentPatientId == null) return;

    try {
      // Simulate vitals data from a wearable device
      final simulatedVitals = PatientVitals(
        heartRate: 75 + (DateTime.now().millisecond % 20) - 10, // 65-85 BPM
        oxygenSaturation:
            97.0 + (DateTime.now().millisecond % 30) / 10, // 97-100%
        temperature:
            98.6 + (DateTime.now().millisecond % 20) / 10 - 1, // 97.6-99.6°F
        bloodPressure: '120/80',
        respiratoryRate:
            16 + (DateTime.now().millisecond % 8) - 4, // 12-20 breaths/min
        timestamp: DateTime.now(),
        deviceSource: 'Simulated Apple Watch',
        deviceId: 'sim_apple_watch_1',
        dataQuality: 0.95,
      );

      await _wearableService.storeDeviceVitals(
        patientId: _currentPatientId!,
        vitals: simulatedVitals,
        deviceId: 'sim_apple_watch_1',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulated vitals data stored!')),
      );

      await _updateStatus();
    } catch (e) {
      _logger.e('Failed to simulate vitals data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Simulation failed: $e')));
    }
  }

  Future<void> _simulateCriticalVitals() async {
    if (_currentPatientId == null) return;

    try {
      // Simulate critical vitals that should trigger auto-triage
      final criticalVitals = PatientVitals(
        heartRate: 140, // Above threshold
        oxygenSaturation: 85.0, // Below threshold
        temperature: 103.2, // Above threshold
        bloodPressure: '190/130', // Above threshold
        respiratoryRate: 28, // Above normal
        timestamp: DateTime.now(),
        deviceSource: 'Simulated Emergency Device',
        deviceId: 'sim_emergency_1',
        dataQuality: 0.98,
      );

      await _wearableService.storeDeviceVitals(
        patientId: _currentPatientId!,
        vitals: criticalVitals,
        deviceId: 'sim_emergency_1',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Critical vitals simulated - Auto-triage should trigger!',
          ),
          backgroundColor: Colors.red,
        ),
      );

      await _updateStatus();
    } catch (e) {
      _logger.e('Failed to simulate critical vitals: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Critical simulation failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable Device Integration'),
        backgroundColor: Colors.blue,
      ),
      body: _isInitialized ? _buildContent() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing wearable device services...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientInfo(),
          const SizedBox(height: 20),
          _buildSyncStatus(),
          const SizedBox(height: 20),
          _buildActions(),
          const SizedBox(height: 20),
          _buildDeviceStatus(),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Patient',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Patient ID: ${_currentPatientId ?? 'None'}'),
            const Text('Auto-triage: Enabled'),
            const Text('Vitals monitoring: Active'),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_syncStatus != null) ...[
              Text('Online: ${_syncStatus!['isOnline'] ?? false}'),
              Text('Syncing: ${_syncStatus!['isSyncing'] ?? false}'),
              Text('Queued items: ${_syncStatus!['queuedItems'] ?? 0}'),
              if (_syncStatus!['lastSyncTime'] != null)
                Text('Last sync: ${_syncStatus!['lastSyncTime']}'),
              if (_syncStatus!['lastSyncResult'] != null) ...[
                const SizedBox(height: 8),
                const Text('Last sync result:'),
                Text(
                  '  Total: ${_syncStatus!['lastSyncResult']['totalItems']}',
                ),
                Text(
                  '  Success: ${_syncStatus!['lastSyncResult']['successfulItems']}',
                ),
                Text(
                  '  Failed: ${_syncStatus!['lastSyncResult']['failedItems']}',
                ),
              ],
            ] else
              const Text('Loading sync status...'),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _syncVitalsNow,
                  child: const Text('Sync Vitals Now'),
                ),
                ElevatedButton(
                  onPressed: _forceSyncAll,
                  child: const Text('Force Sync All'),
                ),
                ElevatedButton(
                  onPressed: _simulateVitalsData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Simulate Normal Vitals'),
                ),
                ElevatedButton(
                  onPressed: _simulateCriticalVitals,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Simulate Critical Vitals'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatus() {
    final platformStatus = _healthService.getPlatformStatus();
    final connectedDevices = _healthService.getConnectedDevices();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Platform Support:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ...platformStatus.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.check_circle : Icons.cancel,
                      color: entry.value ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(entry.key),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connected Devices: ${connectedDevices.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ...connectedDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${device.name} (${device.platform})'),
                    Text(
                      '  Battery: ${(device.batteryLevel * 100).toInt()}% | '
                      'Last sync: ${device.lastSync}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _healthService.dispose();
    _wearableService.dispose();
    _syncService.dispose();
    super.dispose();
  }
}

/// Example of how to use the wearable device integration in your app
void main() {
  runApp(
    MaterialApp(
      title: 'Wearable Device Integration Demo',
      home: const WearableDeviceIntegrationExample(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    ),
  );
}
