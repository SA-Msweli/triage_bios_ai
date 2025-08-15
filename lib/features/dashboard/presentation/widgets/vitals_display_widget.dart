import 'package:flutter/material.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/widgets/responsive_layouts.dart';
import '../../../../shared/utils/overflow_detection.dart';

/// Vital reading data model
class VitalReading {
  final String value;
  final String unit;
  final VitalStatus status;
  final DateTime timestamp;
  final IconData icon;
  final String normalRange;
  final String? trend; // 'up', 'down', 'stable'

  VitalReading({
    required this.value,
    required this.unit,
    required this.status,
    required this.timestamp,
    required this.icon,
    required this.normalRange,
    this.trend,
  });
}

/// Vital status enumeration
enum VitalStatus { critical, abnormal, normal, unknown }

/// Widget for displaying and managing patient vitals data
class VitalsDisplayWidget extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataChanged;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const VitalsDisplayWidget({
    super.key,
    this.onDataChanged,
    this.onNext,
    this.onBack,
  });

  @override
  State<VitalsDisplayWidget> createState() => _VitalsDisplayWidgetState();
}

class _VitalsDisplayWidgetState extends State<VitalsDisplayWidget> {
  bool _hasWearableDevice = false;
  bool _isConnecting = false;
  bool _hasManualVitals = false;

  // Sample vitals data - in real app would come from health services
  final Map<String, VitalReading> _vitalsData = {
    'heartRate': VitalReading(
      value: '72',
      unit: 'bpm',
      status: VitalStatus.normal,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      icon: Icons.favorite,
      normalRange: '60-100',
    ),
    'bloodPressure': VitalReading(
      value: '120/80',
      unit: 'mmHg',
      status: VitalStatus.normal,
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      icon: Icons.monitor_heart,
      normalRange: '<140/90',
    ),
    'oxygenSaturation': VitalReading(
      value: '98',
      unit: '%',
      status: VitalStatus.normal,
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      icon: Icons.air,
      normalRange: '>95',
    ),
    'temperature': VitalReading(
      value: '98.6',
      unit: '°F',
      status: VitalStatus.normal,
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      icon: Icons.thermostat,
      normalRange: '97-99',
    ),
    'respiratoryRate': VitalReading(
      value: '16',
      unit: '/min',
      status: VitalStatus.normal,
      timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
      icon: Icons.air,
      normalRange: '12-20',
    ),
    'bloodGlucose': VitalReading(
      value: '95',
      unit: 'mg/dL',
      status: VitalStatus.normal,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      icon: Icons.water_drop,
      normalRange: '70-140',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          _buildVitalsHeader(),
          SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 16 : 24),

          // Wearable device connection
          _buildWearableConnection(),
          SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 16 : 24),

          // Vitals grid - main feature
          if (_hasWearableDevice || _hasManualVitals) ...[
            _buildVitalsGrid(),
            SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 16 : 24),

            // Vitals summary and trends
            _buildVitalsSummary(),
            SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 16 : 24),
          ],

          // Manual entry section
          _buildManualVitalsInput(),
          SizedBox(height: ResponsiveBreakpoints.isMobile(context) ? 16 : 24),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    ).withOverflowDetection(debugName: 'Vitals Display Widget');
  }

  Widget _buildVitalsHeader() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Container(
        width: double.infinity,
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vital Signs Monitor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: isMobile ? 20 : 24,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'Real-time health monitoring for accurate triage',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue.shade600,
                          fontSize: isMobile ? 14 : 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getOverallHealthColor().withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getOverallHealthColor()),
                    ),
                    child: Text(
                      _getOverallHealthStatus(),
                      style: TextStyle(
                        color: _getOverallHealthColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isMobile) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getOverallHealthColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getOverallHealthColor()),
                ),
                child: Text(
                  _getOverallHealthStatus(),
                  style: TextStyle(
                    color: _getOverallHealthColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsGrid() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Current Vitals',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 18 : 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ConstrainedResponsiveContainer.button(
                child: OutlinedButton.icon(
                  onPressed: _refreshVitals,
                  icon: Icon(Icons.refresh, size: isMobile ? 16 : 18),
                  label: Text(
                    'Refresh',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(isMobile ? 80 : 100, isMobile ? 36 : 40),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 6 : 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // Responsive vitals grid with proper constraints (150-250px width per card)
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          spacing: isMobile ? 12 : 16,
          runSpacing: isMobile ? 12 : 16,
          children: _vitalsData.entries.map((entry) {
            return ConstrainedResponsiveContainer.vitalsCard(
              child: _buildVitalCard(entry.key, entry.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVitalCard(String key, VitalReading vital) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final statusColor = _getStatusColor(vital.status);

    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: vital.status != VitalStatus.normal
              ? Border.all(color: statusColor, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and status
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    vital.icon,
                    color: statusColor,
                    size: isMobile ? 18 : 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getVitalDisplayName(key),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (vital.trend != null)
                  Icon(
                    vital.trend == 'up'
                        ? Icons.trending_up
                        : vital.trend == 'down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                    color: vital.trend == 'up'
                        ? Colors.red
                        : vital.trend == 'down'
                        ? Colors.blue
                        : Colors.grey,
                    size: isMobile ? 16 : 18,
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 12),

            // Value display
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  vital.value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: isMobile ? 24 : 28,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(width: 4),
                Text(
                  vital.unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 10 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),

            // Status and normal range
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(vital.status),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: isMobile ? 10 : 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: isMobile ? 4 : 6),

            // Normal range and timestamp
            Text(
              'Normal: ${vital.normalRange}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontSize: isMobile ? 9 : 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _formatTimestamp(vital.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: isMobile ? 9 : 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSummary() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final abnormalVitals = _vitalsData.values
        .where((vital) => vital.status != VitalStatus.normal)
        .length;

    return ConstrainedResponsiveContainer.card(
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: Colors.blue.shade700,
                    size: isMobile ? 20 : 24,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      'Vitals Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 16 : 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),

              ResponsiveGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 3,
                spacing: isMobile ? 8 : 12,
                children: [
                  _buildSummaryItem(
                    'Total Vitals',
                    '${_vitalsData.length}',
                    Icons.favorite,
                    Colors.blue,
                  ),
                  _buildSummaryItem(
                    'Normal',
                    '${_vitalsData.length - abnormalVitals}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildSummaryItem(
                    'Abnormal',
                    '$abnormalVitals',
                    Icons.warning,
                    abnormalVitals > 0 ? Colors.orange : Colors.grey,
                  ),
                ],
              ),

              if (abnormalVitals > 0) ...[
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: isMobile ? 18 : 20,
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          'Some vitals are outside normal ranges. This information will be included in your triage assessment.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 16 : 18),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ResponsiveGrid(
      mobileColumns: widget.onBack != null && widget.onNext != null ? 2 : 1,
      tabletColumns: 2,
      desktopColumns: 2,
      spacing: isMobile ? 12 : 16,
      children: [
        if (widget.onBack != null)
          ConstrainedResponsiveContainer.button(
            child: OutlinedButton.icon(
              onPressed: widget.onBack,
              icon: Icon(Icons.arrow_back, size: isMobile ? 18 : 20),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 16,
                  vertical: isMobile ? 14 : 12,
                ),
              ),
            ),
          ),
        if (widget.onNext != null)
          ConstrainedResponsiveContainer.button(
            child: ElevatedButton.icon(
              onPressed: widget.onNext,
              icon: Icon(Icons.arrow_forward, size: isMobile ? 18 : 20),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 16,
                  vertical: isMobile ? 14 : 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWearableConnection() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: _hasWearableDevice
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.watch,
                      color: _hasWearableDevice
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wearable Device',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 16 : 18,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          _hasWearableDevice
                              ? 'Connected & Syncing'
                              : 'Not Connected',
                          style: TextStyle(
                            color: _hasWearableDevice
                                ? Colors.green.shade600
                                : Colors.grey.shade600,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),

              Text(
                'Connect your smartwatch or fitness tracker for automatic vital signs monitoring and enhanced triage accuracy.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 14 : 16),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              SizedBox(height: isMobile ? 12 : 16),

              // Device connection status and controls
              ResponsiveGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: 12,
                children: [
                  // Connection status
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: _hasWearableDevice
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hasWearableDevice
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasWearableDevice
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _hasWearableDevice
                              ? Colors.green
                              : Colors.grey,
                          size: isMobile ? 18 : 20,
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(
                          child: Text(
                            _hasWearableDevice
                                ? 'Apple Watch Connected'
                                : 'No Device Connected',
                            style: TextStyle(
                              color: _hasWearableDevice
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: isMobile ? 12 : 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Connection button
                  ConstrainedResponsiveContainer.button(
                    child: _isConnecting
                        ? Container(
                            height: isMobile ? 44 : 48,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Connecting...',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _connectWearableDevice,
                            icon: Icon(
                              _hasWearableDevice ? Icons.link_off : Icons.link,
                              size: isMobile ? 18 : 20,
                            ),
                            label: Text(
                              _hasWearableDevice
                                  ? 'Disconnect'
                                  : 'Connect Device',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(
                                double.infinity,
                                isMobile ? 44 : 48,
                              ),
                              backgroundColor: _hasWearableDevice
                                  ? Colors.red.shade600
                                  : null,
                              foregroundColor: _hasWearableDevice
                                  ? Colors.white
                                  : null,
                            ),
                          ),
                  ),
                ],
              ),

              if (_hasWearableDevice) ...[
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync,
                        color: Colors.green.shade700,
                        size: isMobile ? 18 : 20,
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Real-time Monitoring Active',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                            Text(
                              'Vitals are being automatically updated from your device every 30 seconds.',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.green.shade600,
                              ),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualVitalsInput() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.orange.shade700,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  Expanded(
                    child: Text(
                      'Manual Entry',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 16 : 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),

              Text(
                'Enter your vital signs manually if you don\'t have a connected device or want to add additional measurements.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 14 : 16),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              SizedBox(height: isMobile ? 12 : 16),

              ResponsiveGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: 12,
                children: [
                  ConstrainedResponsiveContainer.button(
                    child: ElevatedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: Icon(Icons.add, size: isMobile ? 18 : 20),
                      label: Text(
                        'Enter Vitals Manually',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, isMobile ? 44 : 48),
                      ),
                    ),
                  ),
                  if (_hasManualVitals)
                    ConstrainedResponsiveContainer.button(
                      child: OutlinedButton.icon(
                        onPressed: _clearManualVitals,
                        icon: Icon(Icons.clear, size: isMobile ? 18 : 20),
                        label: Text(
                          'Clear Manual Data',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(
                            double.infinity,
                            isMobile ? 44 : 48,
                          ),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _connectWearableDevice() {
    setState(() {
      _isConnecting = true;
    });

    // Simulate connection process
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _hasWearableDevice = !_hasWearableDevice;
        });

        // Notify parent of data change
        widget.onDataChanged?.call({
          'vitals': _hasWearableDevice ? _vitalsData : null,
          'hasWearableDevice': _hasWearableDevice,
          'vitalsSeverityBoost': _calculateVitalsSeverityBoost(),
        });
      }
    });
  }

  void _refreshVitals() {
    // Simulate refreshing vitals data
    setState(() {
      // Update timestamps to show fresh data
      _vitalsData.forEach((key, vital) {
        _vitalsData[key] = VitalReading(
          value: vital.value,
          unit: vital.unit,
          status: vital.status,
          timestamp: DateTime.now().subtract(
            Duration(minutes: (key.hashCode % 10)),
          ),
          icon: vital.icon,
          normalRange: vital.normalRange,
          trend: vital.trend,
        );
      });
    });
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.orange),
            SizedBox(width: 8),
            Text('Manual Vitals Entry'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your current vital signs. This information will be used to enhance your triage assessment.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Available measurements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._getManualEntryOptions().map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(option['name'] as String),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _simulateManualEntry();
            },
            child: const Text('Add Sample Data'),
          ),
        ],
      ),
    );
  }

  void _simulateManualEntry() {
    setState(() {
      _hasManualVitals = true;
      // Add some sample manual data
      _vitalsData['manualHeartRate'] = VitalReading(
        value: '85',
        unit: 'bpm',
        status: VitalStatus.normal,
        timestamp: DateTime.now(),
        icon: Icons.favorite,
        normalRange: '60-100',
        trend: 'stable',
      );
    });

    widget.onDataChanged?.call({
      'vitals': _vitalsData,
      'hasManualVitals': _hasManualVitals,
      'vitalsSeverityBoost': _calculateVitalsSeverityBoost(),
    });
  }

  void _clearManualVitals() {
    setState(() {
      _hasManualVitals = false;
      _vitalsData.removeWhere((key, value) => key.startsWith('manual'));
    });

    widget.onDataChanged?.call({
      'vitals': _vitalsData,
      'hasManualVitals': _hasManualVitals,
      'vitalsSeverityBoost': _calculateVitalsSeverityBoost(),
    });
  }

  // Helper methods
  Color _getStatusColor(VitalStatus status) {
    switch (status) {
      case VitalStatus.critical:
        return Colors.red;
      case VitalStatus.abnormal:
        return Colors.orange;
      case VitalStatus.normal:
        return Colors.green;
      case VitalStatus.unknown:
        return Colors.grey;
    }
  }

  String _getStatusText(VitalStatus status) {
    switch (status) {
      case VitalStatus.critical:
        return 'Critical';
      case VitalStatus.abnormal:
        return 'Abnormal';
      case VitalStatus.normal:
        return 'Normal';
      case VitalStatus.unknown:
        return 'Unknown';
    }
  }

  String _getVitalDisplayName(String key) {
    switch (key) {
      case 'heartRate':
        return 'Heart Rate';
      case 'bloodPressure':
        return 'Blood Pressure';
      case 'oxygenSaturation':
        return 'Oxygen Sat';
      case 'temperature':
        return 'Temperature';
      case 'respiratoryRate':
        return 'Respiratory';
      case 'bloodGlucose':
        return 'Blood Glucose';
      case 'manualHeartRate':
        return 'Heart Rate (Manual)';
      default:
        return key;
    }
  }

  Color _getOverallHealthColor() {
    final abnormalCount = _vitalsData.values
        .where((vital) => vital.status != VitalStatus.normal)
        .length;

    if (abnormalCount == 0) return Colors.green;
    if (abnormalCount <= 2) return Colors.orange;
    return Colors.red;
  }

  String _getOverallHealthStatus() {
    final abnormalCount = _vitalsData.values
        .where((vital) => vital.status != VitalStatus.normal)
        .length;

    if (abnormalCount == 0) return 'All Normal';
    if (abnormalCount <= 2) return 'Some Concerns';
    return 'Multiple Issues';
  }

  double _calculateVitalsSeverityBoost() {
    double boost = 0.0;

    for (final vital in _vitalsData.values) {
      switch (vital.status) {
        case VitalStatus.critical:
          boost += 3.0;
          break;
        case VitalStatus.abnormal:
          boost += 1.5;
          break;
        case VitalStatus.normal:
          break;
        case VitalStatus.unknown:
          break;
      }
    }

    return boost.clamp(0.0, 5.0); // Cap at 5.0 points
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

  List<Map<String, dynamic>> _getManualEntryOptions() {
    return [
      {'name': 'Heart Rate', 'icon': Icons.favorite},
      {'name': 'Blood Pressure', 'icon': Icons.monitor_heart},
      {'name': 'Temperature', 'icon': Icons.thermostat},
      {'name': 'Oxygen Saturation', 'icon': Icons.air},
      {'name': 'Respiratory Rate', 'icon': Icons.air},
      {'name': 'Blood Glucose', 'icon': Icons.water_drop},
    ];
  }
}
