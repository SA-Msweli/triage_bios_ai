import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../shared/services/real_time_monitoring_service.dart';

/// Widget for displaying real-time monitoring statistics and system health
class RealTimeStatsWidget extends StatefulWidget {
  final bool showDetailedStats;
  final VoidCallback? onTap;

  const RealTimeStatsWidget({
    super.key,
    this.showDetailedStats = true,
    this.onTap,
  });

  @override
  State<RealTimeStatsWidget> createState() => _RealTimeStatsWidgetState();
}

class _RealTimeStatsWidgetState extends State<RealTimeStatsWidget>
    with TickerProviderStateMixin {
  final RealTimeMonitoringService _monitoringService =
      RealTimeMonitoringService();

  VitalsStatistics? _vitalsStats;
  MonitoringStatus? _monitoringStatus;
  bool _isLoading = true;
  String? _error;

  StreamSubscription<VitalsStatistics>? _vitalsStatsSubscription;
  Timer? _statusUpdateTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startStatsMonitoring();
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

  Future<void> _startStatsMonitoring() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Start monitoring if not already active
      if (!_monitoringService.isMonitoring) {
        await _monitoringService.startMonitoring();
      }

      // Subscribe to vitals statistics
      _vitalsStatsSubscription = _monitoringService
          .getVitalsStatistics(timeWindow: const Duration(hours: 1))
          .listen(
            (stats) {
              if (mounted) {
                setState(() {
                  _vitalsStats = stats;
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

      // Update monitoring status periodically
      _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          setState(() {
            _monitoringStatus = _monitoringService.monitoringStatus;
          });
        }
      });

      // Initial status update
      setState(() {
        _monitoringStatus = _monitoringService.monitoringStatus;
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
    _pulseController.dispose();
    _vitalsStatsSubscription?.cancel();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
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
                  color: _getSystemHealthColor(),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          'Real-Time Monitoring',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (_monitoringStatus != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getSystemHealthColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getSystemHealthText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                'Error loading stats',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (widget.showDetailedStats) ...[
          _buildVitalsOverview(),
          const SizedBox(height: 16),
        ],
        _buildMonitoringStatus(),
      ],
    );
  }

  Widget _buildVitalsOverview() {
    if (_vitalsStats == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Text('No vitals data available')),
      );
    }

    final stats = _vitalsStats!;
    final percentages = stats.percentages;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getVitalsOverallColor(
          stats.overallStatus,
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getVitalsOverallColor(
            stats.overallStatus,
          ).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getVitalsOverallIcon(stats.overallStatus),
                color: _getVitalsOverallColor(stats.overallStatus),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Patient Vitals Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getVitalsOverallColor(stats.overallStatus),
                ),
              ),
              const Spacer(),
              Text(
                '${stats.totalPatients} patients',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVitalsStatItem(
                  'Critical',
                  stats.criticalCount.toString(),
                  '${percentages['critical']!.toStringAsFixed(1)}%',
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildVitalsStatItem(
                  'Warning',
                  stats.warningCount.toString(),
                  '${percentages['warning']!.toStringAsFixed(1)}%',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildVitalsStatItem(
                  'Stable',
                  stats.stableCount.toString(),
                  '${percentages['stable']!.toStringAsFixed(1)}%',
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildVitalsStatItem(
                  'Avg Severity',
                  stats.averageSeverity.toStringAsFixed(1),
                  'score',
                  _getSeverityColor(stats.averageSeverity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: ${_formatTimestamp(stats.lastUpdated)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsStatItem(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringStatus() {
    if (_monitoringStatus == null) return const SizedBox.shrink();

    final status = _monitoringStatus!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                'System Status',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Hospitals',
                  status.hospitalCount.toString(),
                  Icons.local_hospital,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Capacity',
                  status.capacitySubscriptions.toString(),
                  Icons.bed,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Vitals',
                  status.vitalsSubscriptions.toString(),
                  Icons.favorite,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Total',
                  status.totalSubscriptions.toString(),
                  Icons.stream,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Color _getSystemHealthColor() {
    if (_monitoringStatus == null) return Colors.grey;

    switch (_monitoringStatus!.health) {
      case MonitoringHealth.healthy:
        return Colors.green;
      case MonitoringHealth.partial:
        return Colors.orange;
      case MonitoringHealth.noSubscriptions:
        return Colors.red;
      case MonitoringHealth.inactive:
        return Colors.grey;
    }
  }

  String _getSystemHealthText() {
    if (_monitoringStatus == null) return 'UNKNOWN';

    switch (_monitoringStatus!.health) {
      case MonitoringHealth.healthy:
        return 'HEALTHY';
      case MonitoringHealth.partial:
        return 'PARTIAL';
      case MonitoringHealth.noSubscriptions:
        return 'NO DATA';
      case MonitoringHealth.inactive:
        return 'INACTIVE';
    }
  }

  Color _getVitalsOverallColor(VitalsOverallStatus status) {
    switch (status) {
      case VitalsOverallStatus.critical:
        return Colors.red;
      case VitalsOverallStatus.warning:
        return Colors.orange;
      case VitalsOverallStatus.stable:
        return Colors.green;
      case VitalsOverallStatus.noData:
        return Colors.grey;
    }
  }

  IconData _getVitalsOverallIcon(VitalsOverallStatus status) {
    switch (status) {
      case VitalsOverallStatus.critical:
        return Icons.error;
      case VitalsOverallStatus.warning:
        return Icons.warning;
      case VitalsOverallStatus.stable:
        return Icons.check_circle;
      case VitalsOverallStatus.noData:
        return Icons.help_outline;
    }
  }

  Color _getSeverityColor(double severity) {
    if (severity >= 2.5) return Colors.red;
    if (severity >= 1.5) return Colors.orange;
    if (severity >= 1.0) return Colors.yellow.shade700;
    return Colors.green;
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
    } else {
      return '${difference.inHours}h ago';
    }
  }
}
