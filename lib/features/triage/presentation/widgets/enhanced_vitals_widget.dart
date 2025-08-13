import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../shared/services/multi_platform_health_service.dart';
import '../../../../shared/services/vitals_trend_service.dart';
import '../../../../features/triage/domain/entities/patient_vitals.dart';

/// Enhanced vitals widget with real-time monitoring and trend analysis
class EnhancedVitalsWidget extends StatefulWidget {
  final Function(PatientVitals?) onVitalsChanged;
  final bool enableRealTimeMonitoring;

  const EnhancedVitalsWidget({
    super.key,
    required this.onVitalsChanged,
    this.enableRealTimeMonitoring = true,
  });

  @override
  State<EnhancedVitalsWidget> createState() => _EnhancedVitalsWidgetState();
}

class _EnhancedVitalsWidgetState extends State<EnhancedVitalsWidget>
    with TickerProviderStateMixin {
  final MultiPlatformHealthService _healthService =
      MultiPlatformHealthService();
  final VitalsTrendService _trendService = VitalsTrendService();

  PatientVitals? _currentVitals;
  VitalsTrendAnalysis? _trendAnalysis;
  List<WearableDevice> _connectedDevices = [];
  Timer? _monitoringTimer;
  bool _isLoading = true;
  bool _hasPermissions = false;

  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeVitalsMonitoring();
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    _heartbeatController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeVitalsMonitoring() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize health service
      await _healthService.initialize();

      // Check permissions
      _hasPermissions = await _healthService.hasHealthPermissions();

      if (_hasPermissions) {
        // Load connected devices
        _connectedDevices = _healthService.getConnectedDevices();

        // Load initial vitals
        await _loadVitals();

        // Start real-time monitoring if enabled
        if (widget.enableRealTimeMonitoring) {
          _startRealTimeMonitoring();
        }
      }
    } catch (e) {
      _showError('Failed to initialize vitals monitoring: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVitals() async {
    try {
      final vitals = await _healthService.getLatestVitals();

      if (vitals != null) {
        setState(() {
          _currentVitals = vitals;
        });

        // Store for trend analysis
        await _trendService.storeVitalsReading(vitals);

        // Load trend analysis
        final trends = await _trendService.analyzeTrends(hoursBack: 24);
        setState(() {
          _trendAnalysis = trends;
        });

        // Start heartbeat animation if heart rate is available
        if (vitals.heartRate != null) {
          _startHeartbeatAnimation(vitals.heartRate!);
        }

        // Notify parent
        widget.onVitalsChanged(vitals);
      }
    } catch (e) {
      _showError('Failed to load vitals: $e');
    }
  }

  void _startRealTimeMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadVitals();
    });
  }

  void _startHeartbeatAnimation(int heartRate) {
    // Calculate animation speed based on heart rate
    final duration = Duration(milliseconds: (60000 / heartRate).round());
    _heartbeatController.duration = duration;
    _heartbeatController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                AnimatedBuilder(
                  animation: _heartbeatAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _currentVitals?.heartRate != null
                          ? _heartbeatAnimation.value
                          : 1.0,
                      child: Icon(
                        Icons.favorite,
                        color: _currentVitals?.heartRate != null
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Real-Time Vitals',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.enableRealTimeMonitoring)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            if (_isLoading) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading vitals data...'),
                  ],
                ),
              ),
            ] else if (!_hasPermissions) ...[
              _buildPermissionRequest(),
            ] else if (_currentVitals == null) ...[
              _buildNoDataState(),
            ] else ...[
              // Connected devices
              _buildConnectedDevices(),
              const SizedBox(height: 16),

              // Vitals grid
              _buildVitalsGrid(),
              const SizedBox(height: 16),

              // Trend analysis
              if (_trendAnalysis != null) ...[
                _buildTrendAnalysis(),
                const SizedBox(height: 16),
              ],

              // Data quality and timestamp
              _buildDataInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.health_and_safety,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Health Data Access Required',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'To provide accurate triage assessment, we need access to your health data from connected wearable devices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await _healthService.requestPermissions();
              await _initializeVitalsMonitoring();
            },
            icon: const Icon(Icons.security),
            label: const Text('Grant Health Access'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.watch,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Vitals Data Available',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect a wearable device or manually enter vitals to enhance your triage assessment.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadVitals,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showManualEntry,
                  icon: const Icon(Icons.edit),
                  label: const Text('Manual Entry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDevices() {
    if (_connectedDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No wearable devices connected. Connect devices for enhanced monitoring.',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected Devices (${_connectedDevices.length})',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _connectedDevices.length,
            itemBuilder: (context, index) {
              final device = _connectedDevices[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: device.isConnected
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: device.isConnected
                        ? Colors.green.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getDeviceIcon(device.platform),
                      color: device.isConnected
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: device.isConnected
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          device.isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 10,
                            color: device.isConnected
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildVitalCard(
          'Heart Rate',
          _currentVitals!.heartRate?.toString() ?? '--',
          'bpm',
          Icons.favorite,
          Colors.red,
          _isVitalNormal('heartRate', _currentVitals!.heartRate?.toDouble()),
        ),
        _buildVitalCard(
          'SpO2',
          _currentVitals!.oxygenSaturation?.toStringAsFixed(1) ?? '--',
          '%',
          Icons.air,
          Colors.blue,
          _isVitalNormal('oxygenSaturation', _currentVitals!.oxygenSaturation),
        ),
        _buildVitalCard(
          'Temperature',
          _currentVitals!.temperature?.toStringAsFixed(1) ?? '--',
          '°F',
          Icons.thermostat,
          Colors.orange,
          _isVitalNormal('temperature', _currentVitals!.temperature),
        ),
        _buildVitalCard(
          'Blood Pressure',
          _currentVitals!.bloodPressure ?? '--',
          '',
          Icons.monitor_heart,
          Colors.purple,
          _isBloodPressureNormal(_currentVitals!.bloodPressure),
        ),
      ],
    );
  }

  Widget _buildVitalCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
    bool isNormal,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNormal ? color.withValues(alpha: 0.1) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNormal ? color.withValues(alpha: 0.3) : Colors.red.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isNormal ? color : Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isNormal ? color : Colors.red,
                  ),
                ),
              ),
              if (!isNormal) Icon(Icons.warning, color: Colors.red, size: 16),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isNormal ? color : Colors.red,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: isNormal ? color : Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Trend Analysis (24h)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTrendItem(
                  'Stability',
                  _getStabilityText(_trendAnalysis!.overallStability),
                  _getStabilityColor(_trendAnalysis!.overallStability),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTrendItem(
                  'Risk Level',
                  _getDeteriorationText(_trendAnalysis!.deteriorationRisk),
                  _getDeteriorationColor(_trendAnalysis!.deteriorationRisk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_trendAnalysis!.dataPoints} readings analyzed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Quality: ${(_currentVitals!.dataQuality! * 100).toStringAsFixed(0)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Last updated: ${_formatTimestamp(_currentVitals!.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadVitals,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh vitals',
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getDeviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'apple health':
        return Icons.watch;
      case 'google health connect':
        return Icons.android;
      case 'samsung health':
        return Icons.watch;
      case 'fitbit':
        return Icons.fitness_center;
      default:
        return Icons.device_unknown;
    }
  }

  bool _isVitalNormal(String type, double? value) {
    if (value == null) return true;

    switch (type) {
      case 'heartRate':
        return value >= 60 && value <= 100;
      case 'oxygenSaturation':
        return value >= 95;
      case 'temperature':
        return value >= 97.0 && value <= 99.5;
      default:
        return true;
    }
  }

  bool _isBloodPressureNormal(String? bp) {
    if (bp == null) return true;

    final parts = bp.split('/');
    if (parts.length != 2) return true;

    final systolic = int.tryParse(parts[0]);
    final diastolic = int.tryParse(parts[1]);

    if (systolic == null || diastolic == null) return true;

    return systolic < 140 &&
        diastolic < 90 &&
        systolic >= 90 &&
        diastolic >= 60;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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

  String _getStabilityText(StabilityLevel stability) {
    switch (stability) {
      case StabilityLevel.stable:
        return 'Stable';
      case StabilityLevel.mildlyUnstable:
        return 'Mild Variation';
      case StabilityLevel.concerning:
        return 'Concerning';
      case StabilityLevel.unstable:
        return 'Unstable';
      case StabilityLevel.unknown:
        return 'Unknown';
    }
  }

  Color _getStabilityColor(StabilityLevel stability) {
    switch (stability) {
      case StabilityLevel.stable:
        return Colors.green;
      case StabilityLevel.mildlyUnstable:
        return Colors.orange;
      case StabilityLevel.concerning:
        return Colors.deepOrange;
      case StabilityLevel.unstable:
        return Colors.red;
      case StabilityLevel.unknown:
        return Colors.grey;
    }
  }

  String _getDeteriorationText(DeteriorationRisk risk) {
    switch (risk) {
      case DeteriorationRisk.minimal:
        return 'Minimal';
      case DeteriorationRisk.low:
        return 'Low';
      case DeteriorationRisk.moderate:
        return 'Moderate';
      case DeteriorationRisk.high:
        return 'High';
      case DeteriorationRisk.unknown:
        return 'Unknown';
    }
  }

  Color _getDeteriorationColor(DeteriorationRisk risk) {
    switch (risk) {
      case DeteriorationRisk.minimal:
        return Colors.green;
      case DeteriorationRisk.low:
        return Colors.blue;
      case DeteriorationRisk.moderate:
        return Colors.orange;
      case DeteriorationRisk.high:
        return Colors.red;
      case DeteriorationRisk.unknown:
        return Colors.grey;
    }
  }

  void _showManualEntry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Vitals Entry'),
        content: const Text(
          'Manual vitals entry feature will be available in the next update. For now, please connect a wearable device for automatic monitoring.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
