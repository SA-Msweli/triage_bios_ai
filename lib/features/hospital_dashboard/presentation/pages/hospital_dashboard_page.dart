import 'package:flutter/material.dart';
import '../widgets/live_capacity_monitor_widget.dart';
import '../widgets/patient_vitals_monitor_widget.dart';
import '../widgets/notification_overlay_widget.dart';
import '../widgets/real_time_stats_widget.dart';
import '../widgets/emergency_alerts_widget.dart';
import '../../../../shared/services/real_time_monitoring_service.dart';
import '../../../../shared/services/notification_service.dart';

/// Hospital dashboard for monitoring capacity and patient flow with real-time updates
class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  final RealTimeMonitoringService _monitoringService =
      RealTimeMonitoringService();
  final NotificationService _notificationService = NotificationService();

  List<dynamic> _patientQueue = [];
  Map<String, dynamic> _hospitalStats = {};
  bool _isLoading = true;
  bool _showRealTimeMonitoring = true;
  bool _showLegacyStats = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize real-time monitoring services
      await _notificationService.initialize();

      if (!_monitoringService.isMonitoring) {
        await _monitoringService.startMonitoring(monitorAllHospitals: true);
      }

      // Load mock data for demo (legacy support)
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _hospitalStats = {
          'totalBeds': 200,
          'availableBeds': 45,
          'emergencyBeds': 25,
          'icuBeds': 12,
          'occupancyRate': 0.775,
          'patientsInQueue': 8,
          'averageWaitTime': 25,
        };

        _patientQueue = [
          {
            'name': 'Sarah Johnson',
            'symptoms': 'Chest pain, difficulty breathing',
            'aiScore': 8.5,
            'urgency': 'CRITICAL',
            'color': Colors.red,
            'time': '5m ago',
            'vitals': 'HR: 115, SpO2: 94%',
          },
          {
            'name': 'Michael Chen',
            'symptoms': 'Severe headache, nausea',
            'aiScore': 6.2,
            'urgency': 'URGENT',
            'color': Colors.orange,
            'time': '12m ago',
            'vitals': 'HR: 88, BP: 160/95',
          },
          {
            'name': 'Emily Rodriguez',
            'symptoms': 'Abdominal pain, mild fever',
            'aiScore': 4.8,
            'urgency': 'STANDARD',
            'color': Colors.blue,
            'time': '28m ago',
            'vitals': 'Temp: 101.2°F',
          },
        ];

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading dashboard data: $e');

      // Show error notification
      _notificationService.showNotification(
        title: 'Dashboard Error',
        message: 'Failed to initialize real-time monitoring: ${e.toString()}',
        severity: AlertSeverity.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationOverlayWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hospital Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: Icon(
                _showRealTimeMonitoring
                    ? Icons.monitor
                    : Icons.monitor_outlined,
              ),
              onPressed: () {
                setState(() {
                  _showRealTimeMonitoring = !_showRealTimeMonitoring;
                });
              },
              tooltip: 'Toggle real-time monitoring',
            ),
            IconButton(
              icon: Icon(
                _showLegacyStats ? Icons.analytics : Icons.analytics_outlined,
              ),
              onPressed: () {
                setState(() {
                  _showLegacyStats = !_showLegacyStats;
                });
              },
              tooltip: 'Toggle legacy stats',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDashboardData,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'settings':
                    _showNotificationSettings();
                    break;
                  case 'test_alert':
                    _testAlert();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8),
                      Text('Notification Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'test_alert',
                  child: Row(
                    children: [
                      Icon(Icons.notification_add),
                      SizedBox(width: 8),
                      Text('Test Alert'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showRealTimeMonitoring) ...[
                      // Real-time monitoring overview
                      const RealTimeStatsWidget(showDetailedStats: true),
                      const SizedBox(height: 16),

                      // Real-time capacity monitoring
                      const LiveCapacityMonitorWidget(showAlerts: true),
                      const SizedBox(height: 16),

                      // Critical patient vitals monitoring
                      const PatientVitalsMonitorWidget(showCriticalOnly: true),
                      const SizedBox(height: 24),
                    ],

                    if (_showLegacyStats) ...[
                      // Legacy stats cards (for comparison)
                      _buildStatsSection(),
                      const SizedBox(height: 24),
                    ],

                    // Patient queue
                    _buildPatientQueue(),

                    const SizedBox(height: 24),

                    // Patient history section
                    _buildPatientHistorySection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hospital Status',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Available Beds',
              '${_hospitalStats['availableBeds']}/${_hospitalStats['totalBeds']}',
              Icons.bed,
              Colors.green,
            ),
            _buildStatCard(
              'Patients in Queue',
              '${_hospitalStats['patientsInQueue']}',
              Icons.queue,
              Colors.blue,
            ),
            _buildStatCard(
              'Emergency Beds',
              '${_hospitalStats['emergencyBeds']}',
              Icons.emergency,
              Colors.red,
            ),
            _buildStatCard(
              'Average Wait',
              '${_hospitalStats['averageWaitTime']}m',
              Icons.schedule,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient Queue',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _patientQueue.asMap().entries.map((entry) {
                final index = entry.key;
                final patient = entry.value;
                return Column(
                  children: [
                    if (index > 0) const Divider(),
                    _buildPatientItem(patient),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientItem(Map<String, dynamic> patient) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: patient['color'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              patient['aiScore'].toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      patient['name'],
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: patient['color'],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        patient['urgency'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  patient['symptoms'],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Vitals: ${patient['vitals']} • ${patient['time']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Capacity Alerts'),
              subtitle: const Text('Hospital capacity warnings'),
              value: _notificationService.settings.capacityAlertsEnabled,
              onChanged: (value) {
                _notificationService.setCapacityAlertsEnabled(value);
                setState(() {});
              },
            ),
            SwitchListTile(
              title: const Text('Vitals Alerts'),
              subtitle: const Text('Patient vitals warnings'),
              value: _notificationService.settings.vitalsAlertsEnabled,
              onChanged: (value) {
                _notificationService.setVitalsAlertsEnabled(value);
                setState(() {});
              },
            ),
            SwitchListTile(
              title: const Text('Sound Notifications'),
              subtitle: const Text('Audio alerts'),
              value: _notificationService.settings.soundEnabled,
              onChanged: (value) {
                _notificationService.setSoundEnabled(value);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AlertSeverity>(
              decoration: const InputDecoration(
                labelText: 'Minimum Alert Level',
                border: OutlineInputBorder(),
              ),
              value: _notificationService.settings.minimumSeverity,
              items: AlertSeverity.values.map((severity) {
                return DropdownMenuItem(
                  value: severity,
                  child: Text(severity.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _notificationService.setMinimumSeverity(value);
                  setState(() {});
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Patient History Access',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/patient-history');
              },
              icon: const Icon(Icons.history),
              label: const Text('View Full History'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Access patient triage history with real-time updates and advanced filtering',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showQuickPatientSearch();
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Quick Patient Search'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/patient-history');
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Browse History'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showQuickPatientSearch() {
    final TextEditingController patientIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Patient Search'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: patientIdController,
              decoration: const InputDecoration(
                hintText: 'Enter Patient ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Example patient IDs:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['patient_001', 'patient_002', 'patient_003']
                  .map(
                    (id) => ActionChip(
                      label: Text(id),
                      onPressed: () {
                        patientIdController.text = id;
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final patientId = patientIdController.text.trim();
              if (patientId.isNotEmpty) {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(
                  '/patient-history',
                  arguments: {'patientId': patientId},
                );
              }
            },
            child: const Text('View History'),
          ),
        ],
      ),
    );
  }

  void _testAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Alert'),
        content: const Text('Choose an alert type to test:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _notificationService.showNotification(
                title: 'Test Critical Alert',
                message: 'This is a test critical alert notification',
                severity: AlertSeverity.critical,
              );
            },
            child: const Text('Critical'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _notificationService.showNotification(
                title: 'Test Warning Alert',
                message: 'This is a test warning alert notification',
                severity: AlertSeverity.warning,
              );
            },
            child: const Text('Warning'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _notificationService.showNotification(
                title: 'Test Info Alert',
                message: 'This is a test info alert notification',
                severity: AlertSeverity.info,
              );
            },
            child: const Text('Info'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up monitoring service if needed
    super.dispose();
  }
}
