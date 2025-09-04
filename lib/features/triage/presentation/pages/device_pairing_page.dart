import 'package:flutter/material.dart';
import '../../../../shared/services/multi_platform_health_service.dart';

/// Page for discovering and pairing wearable devices
class DevicePairingPage extends StatefulWidget {
  const DevicePairingPage({super.key});

  @override
  State<DevicePairingPage> createState() => _DevicePairingPageState();
}

class _DevicePairingPageState extends State<DevicePairingPage> {
  final MultiPlatformHealthService _healthService = MultiPlatformHealthService();
  List<WearableDevice> _connectedDevices = [];
  Map<String, bool> _platformStatus = {};
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeHealthService();
  }

  Future<void> _initializeHealthService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _healthService.initialize();
      await _refreshDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing health service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDevices() async {
    try {
      final devices = _healthService.getConnectedDevices();
      final status = _healthService.getPlatformStatus();
      
      setState(() {
        _connectedDevices = devices;
        _platformStatus = status;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
    });

    try {
      await _healthService.requestPermissions();
      await _refreshDevices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device scan completed. Found ${_connectedDevices.length} devices.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning for devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable Devices'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDeviceList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _scanForDevices,
        icon: _isScanning 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.search),
        label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  Widget _buildDeviceList() {
    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlatformStatus(),
          const SizedBox(height: 24),
          _buildConnectedDevices(),
          const SizedBox(height: 24),
          _buildSupportedPlatforms(),
        ],
      ),
    );
  }

  Widget _buildPlatformStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Platform Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._platformStatus.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.cancel,
                    color: entry.value ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(entry.key),
                  const Spacer(),
                  Text(
                    entry.value ? 'Available' : 'Not Available',
                    style: TextStyle(
                      color: entry.value ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected Devices (${_connectedDevices.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_connectedDevices.isEmpty)
          _buildEmptyDeviceState()
        else
          ..._connectedDevices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  Widget _buildEmptyDeviceState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.watch_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Devices Connected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Scan for Devices" to discover wearables',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(WearableDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getDeviceIcon(device.platform),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        device.platform,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildConnectionStatus(device.isConnected),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.battery_std, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${(device.batteryLevel * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(Icons.sync, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatLastSync(device.lastSync),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Supported Data:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: device.supportedDataTypes.map((dataType) => Chip(
                label: Text(
                  _formatDataType(dataType),
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: Colors.blue.shade50,
                side: BorderSide(color: Colors.blue.shade200),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getDeviceIcon(String platform) {
    IconData iconData;
    Color color;
    
    switch (platform.toLowerCase()) {
      case 'apple health':
        iconData = Icons.watch;
        color = Colors.black;
        break;
      case 'google health connect':
        iconData = Icons.watch_outlined;
        color = Colors.blue;
        break;
      case 'samsung health':
        iconData = Icons.watch_later_outlined;
        color = Colors.indigo;
        break;
      case 'fitbit':
        iconData = Icons.fitness_center;
        color = Colors.green;
        break;
      default:
        iconData = Icons.device_unknown;
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildConnectionStatus(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isConnected ? 'Connected' : 'Disconnected',
        style: TextStyle(
          color: isConnected ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSupportedPlatforms() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supported Platforms',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPlatformInfo(
              'Apple Health',
              'Apple Watch, iPhone Health app',
              Icons.watch,
              Colors.black,
            ),
            _buildPlatformInfo(
              'Google Health Connect',
              'Pixel Watch, Wear OS devices',
              Icons.watch_outlined,
              Colors.blue,
            ),
            _buildPlatformInfo(
              'Samsung Health',
              'Galaxy Watch, Samsung Health app',
              Icons.watch_later_outlined,
              Colors.indigo,
            ),
            _buildPlatformInfo(
              'Fitbit',
              'Fitbit Sense, Versa, Charge series',
              Icons.fitness_center,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformInfo(String name, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDataType(String dataType) {
    switch (dataType.toLowerCase()) {
      case 'heart_rate':
        return 'Heart Rate';
      case 'blood_pressure':
        return 'Blood Pressure';
      case 'blood_oxygen':
        return 'Blood Oxygen';
      case 'temperature':
        return 'Temperature';
      case 'respiratory_rate':
        return 'Respiratory Rate';
      case 'heart_rate_variability':
        return 'HRV';
      default:
        return dataType.replaceAll('_', ' ').toUpperCase();
    }
  }
}