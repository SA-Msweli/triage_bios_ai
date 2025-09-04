import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../shared/services/real_time_monitoring_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/models/firestore/patient_vitals_firestore.dart';

/// Widget for monitoring critical patient vitals in real-time
class PatientVitalsMonitorWidget extends StatefulWidget {
  final String? patientId;
  final bool showCriticalOnly;
  final VoidCallback? onPatientTap;

  const PatientVitalsMonitorWidget({
    super.key,
    this.patientId,
    this.showCriticalOnly = true,
    this.onPatientTap,
  });

  @override
  State<PatientVitalsMonitorWidget> createState() =>
      _PatientVitalsMonitorWidgetState();
}

class _PatientVitalsMonitorWidgetState extends State<PatientVitalsMonitorWidget>
    with TickerProviderStateMixin {
  final RealTimeMonitoringService _monitoringService =
      RealTimeMonitoringService();
  final NotificationService _notificationService = NotificationService();

  List<PatientVitalsFirestore> _vitals = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<PatientVitalsFirestore>>? _vitalsSubscription;
  StreamSubscription<VitalsAlert>? _alertSubscription;

  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startMonitoring();
  }

  void _initializeAnimations() {
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );
    _heartbeatController.repeat(reverse: true);
  }

  Future<void> _startMonitoring() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Initialize notification service
      await _notificationService.initialize();

      // Start monitoring
      if (!_monitoringService.isMonitoring) {
        await _monitoringService.startMonitoring();
      }

      // Subscribe to vitals updates
      if (widget.patientId != null) {
        // Monitor specific patient
        _vitalsSubscription = _monitoringService
            .listenToPatientVitals(widget.patientId!)
            .listen(
              (vitals) {
                if (mounted) {
                  setState(() {
                    _vitals = vitals;
                    _isLoading = false;
                    _error = null;
                  });
                }
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _error = error.toString();
                    _isLoading = false;
                  });
                }
              },
            );
      } else {
        // Monitor critical vitals across all patients
        _vitalsSubscription = _monitoringService.criticalVitals.listen(
          (vitals) {
            if (mounted) {
              setState(() {
                _vitals = widget.showCriticalOnly
                    ? vitals.where((v) => v.vitalsSeverityScore >= 1.5).toList()
                    : vitals;
                _isLoading = false;
                _error = null;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = error.toString();
                _isLoading = false;
              });
            }
          },
        );
      }

      // Subscribe to vitals alerts
      _alertSubscription = _monitoringService.vitalsAlerts.listen((alert) {
        _notificationService.showVitalsAlert(alert);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _vitalsSubscription?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _heartbeatAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _heartbeatAnimation.value,
              child: Icon(
                Icons.favorite,
                color: _vitals.any((v) => v.vitalsSeverityScore >= 2.0)
                    ? Colors.red
                    : Colors.pink,
                size: 20,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          widget.patientId != null
              ? 'Patient Vitals Monitor'
              : 'Critical Vitals Monitor',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (_isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getCriticalityColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getCriticalityText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _startMonitoring,
          tooltip: 'Refresh monitoring',
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading vitals data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startMonitoring,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.health_and_safety, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                widget.showCriticalOnly
                    ? 'No critical vitals detected'
                    : 'No vitals data available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'All patients appear stable',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.green),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _vitals.map((vitals) => _buildVitalsItem(vitals)).toList(),
    );
  }

  Widget _buildVitalsItem(PatientVitalsFirestore vitals) {
    final severityColor = _getSeverityColor(vitals.vitalsSeverityScore);
    final isRecent = DateTime.now().difference(vitals.timestamp).inMinutes < 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: severityColor.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: severityColor.withValues(alpha: 0.05),
      ),
      child: InkWell(
        onTap: widget.onPatientTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Patient ${vitals.patientId}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (isRecent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Source: ${_getSourceDisplay(vitals.source)} • ${_formatTimestamp(vitals.timestamp)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Severity: ${vitals.vitalsSeverityScore.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildVitalsGrid(vitals),
            if (vitals.hasAbnormalVitals) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Abnormal vitals detected - requires attention',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsGrid(PatientVitalsFirestore vitals) {
    final vitalsData = <Map<String, dynamic>>[];

    if (vitals.heartRate != null) {
      vitalsData.add({
        'label': 'Heart Rate',
        'value': '${vitals.heartRate!.toStringAsFixed(0)} bpm',
        'icon': Icons.favorite,
        'isAbnormal': vitals.heartRate! < 60 || vitals.heartRate! > 100,
        'isCritical': vitals.heartRate! < 50 || vitals.heartRate! > 120,
      });
    }

    if (vitals.oxygenSaturation != null) {
      vitalsData.add({
        'label': 'SpO2',
        'value': '${vitals.oxygenSaturation!.toStringAsFixed(1)}%',
        'icon': Icons.air,
        'isAbnormal': vitals.oxygenSaturation! < 95,
        'isCritical': vitals.oxygenSaturation! < 90,
      });
    }

    if (vitals.temperature != null) {
      vitalsData.add({
        'label': 'Temperature',
        'value': '${vitals.temperature!.toStringAsFixed(1)}°F',
        'icon': Icons.thermostat,
        'isAbnormal': vitals.temperature! < 97 || vitals.temperature! > 99.5,
        'isCritical': vitals.temperature! < 95 || vitals.temperature! > 101.5,
      });
    }

    if (vitals.bloodPressureSystolic != null &&
        vitals.bloodPressureDiastolic != null) {
      vitalsData.add({
        'label': 'Blood Pressure',
        'value':
            '${vitals.bloodPressureSystolic!.toStringAsFixed(0)}/${vitals.bloodPressureDiastolic!.toStringAsFixed(0)}',
        'icon': Icons.monitor_heart,
        'isAbnormal':
            vitals.bloodPressureSystolic! > 140 ||
            vitals.bloodPressureDiastolic! > 90,
        'isCritical':
            vitals.bloodPressureSystolic! > 180 ||
            vitals.bloodPressureDiastolic! > 120,
      });
    }

    if (vitals.respiratoryRate != null) {
      vitalsData.add({
        'label': 'Respiratory Rate',
        'value': '${vitals.respiratoryRate!.toStringAsFixed(0)} /min',
        'icon': Icons.waves,
        'isAbnormal':
            vitals.respiratoryRate! < 12 || vitals.respiratoryRate! > 20,
        'isCritical':
            vitals.respiratoryRate! < 8 || vitals.respiratoryRate! > 30,
      });
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: vitalsData.map((data) => _buildVitalChip(data)).toList(),
    );
  }

  Widget _buildVitalChip(Map<String, dynamic> data) {
    Color color = Theme.of(context).colorScheme.primary;
    if (data['isCritical'] == true) {
      color = Colors.red;
    } else if (data['isAbnormal'] == true) {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data['icon'], size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['value'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                data['label'],
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(double severity) {
    if (severity >= 2.5) return Colors.red;
    if (severity >= 1.5) return Colors.orange;
    if (severity >= 1.0) return Colors.yellow.shade700;
    return Colors.green;
  }

  Color _getCriticalityColor() {
    final criticalCount = _vitals
        .where((v) => v.vitalsSeverityScore >= 2.5)
        .length;
    final warningCount = _vitals
        .where((v) => v.vitalsSeverityScore >= 1.5)
        .length;

    if (criticalCount > 0) return Colors.red;
    if (warningCount > 0) return Colors.orange;
    return Colors.green;
  }

  String _getCriticalityText() {
    final criticalCount = _vitals
        .where((v) => v.vitalsSeverityScore >= 2.5)
        .length;
    final warningCount = _vitals
        .where((v) => v.vitalsSeverityScore >= 1.5)
        .length;

    if (criticalCount > 0) return '$criticalCount CRITICAL';
    if (warningCount > 0) return '$warningCount WARNING';
    return 'ALL STABLE';
  }

  String _getSourceDisplay(VitalsSource source) {
    switch (source) {
      case VitalsSource.appleHealth:
        return 'Apple Health';
      case VitalsSource.googleFit:
        return 'Google Fit';
      case VitalsSource.manual:
        return 'Manual Entry';
      case VitalsSource.device:
        return 'Medical Device';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 30) {
      return 'just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
