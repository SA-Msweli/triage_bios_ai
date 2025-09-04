import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../shared/services/real_time_monitoring_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/models/firestore/hospital_capacity_firestore.dart';

/// Widget for live hospital capacity monitoring with real-time updates
class LiveCapacityMonitorWidget extends StatefulWidget {
  final List<String>? hospitalIds;
  final bool showAlerts;
  final VoidCallback? onHospitalTap;

  const LiveCapacityMonitorWidget({
    super.key,
    this.hospitalIds,
    this.showAlerts = true,
    this.onHospitalTap,
  });

  @override
  State<LiveCapacityMonitorWidget> createState() =>
      _LiveCapacityMonitorWidgetState();
}

class _LiveCapacityMonitorWidgetState extends State<LiveCapacityMonitorWidget>
    with TickerProviderStateMixin {
  final RealTimeMonitoringService _monitoringService =
      RealTimeMonitoringService();
  final NotificationService _notificationService = NotificationService();

  List<HospitalCapacityFirestore> _capacities = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<HospitalCapacityFirestore>>? _capacitySubscription;
  StreamSubscription<CapacityAlert>? _alertSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startMonitoring();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
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
      await _monitoringService.startMonitoring(
        hospitalIds: widget.hospitalIds,
        monitorAllHospitals: widget.hospitalIds == null,
      );

      // Subscribe to capacity updates
      _capacitySubscription = _monitoringService.capacityUpdates.listen(
        (capacities) {
          if (mounted) {
            setState(() {
              _capacities = capacities;
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

      // Subscribe to alerts if enabled
      if (widget.showAlerts) {
        _alertSubscription = _monitoringService.capacityAlerts.listen((alert) {
          _notificationService.showCapacityAlert(alert);
        });
      }
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
    _pulseController.dispose();
    _capacitySubscription?.cancel();
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
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _monitoringService.isMonitoring
                      ? Colors.green
                      : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          'Live Capacity Monitor',
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
          Text(
            '${_capacities.length} hospitals',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                'Error loading capacity data',
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

    if (_capacities.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.local_hospital, size: 48),
              SizedBox(height: 16),
              Text('No hospital data available'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryStats(),
        const SizedBox(height: 16),
        _buildCapacityList(),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final totalBeds = _capacities.fold<int>(0, (sum, c) => sum + c.totalBeds);
    final availableBeds = _capacities.fold<int>(
      0,
      (sum, c) => sum + c.availableBeds,
    );
    final avgOccupancy = _capacities.isNotEmpty
        ? _capacities.fold<double>(0, (sum, c) => sum + c.occupancyRate) /
              _capacities.length
        : 0.0;
    final criticalHospitals = _capacities
        .where((c) => c.occupancyRate > 0.95)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'Total Beds',
              totalBeds.toString(),
              Icons.bed,
              Colors.blue,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              'Available',
              availableBeds.toString(),
              Icons.check_circle,
              availableBeds < totalBeds * 0.1 ? Colors.red : Colors.green,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              'Avg Occupancy',
              '${(avgOccupancy * 100).toStringAsFixed(1)}%',
              Icons.pie_chart,
              avgOccupancy > 0.85 ? Colors.red : Colors.orange,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              'Critical',
              criticalHospitals.toString(),
              Icons.warning,
              criticalHospitals > 0 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCapacityList() {
    // Sort by occupancy rate (highest first)
    final sortedCapacities = List<HospitalCapacityFirestore>.from(_capacities)
      ..sort((a, b) => b.occupancyRate.compareTo(a.occupancyRate));

    return Column(
      children: sortedCapacities
          .map((capacity) => _buildCapacityItem(capacity))
          .toList(),
    );
  }

  Widget _buildCapacityItem(HospitalCapacityFirestore capacity) {
    final occupancyColor = _getOccupancyColor(capacity.occupancyRate);
    final isStale = !capacity.isDataFresh;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: occupancyColor.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        color: occupancyColor.withValues(alpha: 0.05),
      ),
      child: InkWell(
        onTap: widget.onHospitalTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
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
                            'Hospital ${capacity.hospitalId}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (isStale)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'STALE',
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
                        'Last updated: ${_formatTimestamp(capacity.lastUpdated)}',
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
                    color: occupancyColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${(capacity.occupancyRate * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCapacityMetric(
                    'Total',
                    capacity.totalBeds.toString(),
                    Icons.bed,
                  ),
                ),
                Expanded(
                  child: _buildCapacityMetric(
                    'Available',
                    capacity.availableBeds.toString(),
                    Icons.check_circle,
                    color: capacity.availableBeds < 10 ? Colors.red : null,
                  ),
                ),
                Expanded(
                  child: _buildCapacityMetric(
                    'Emergency',
                    capacity.emergencyAvailable.toString(),
                    Icons.emergency,
                    color: capacity.emergencyAvailable <= 2 ? Colors.red : null,
                  ),
                ),
                Expanded(
                  child: _buildCapacityMetric(
                    'ICU',
                    capacity.icuAvailable.toString(),
                    Icons.local_hospital,
                    color: capacity.icuAvailable <= 1 ? Colors.red : null,
                  ),
                ),
                Expanded(
                  child: _buildCapacityMetric(
                    'Wait',
                    '${capacity.averageWaitTime.toStringAsFixed(0)}m',
                    Icons.access_time,
                    color: capacity.averageWaitTime > 60 ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityMetric(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        Icon(icon, size: 16, color: effectiveColor),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Color _getOccupancyColor(double occupancyRate) {
    if (occupancyRate > 0.95) return Colors.red;
    if (occupancyRate > 0.85) return Colors.orange;
    if (occupancyRate > 0.70) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
