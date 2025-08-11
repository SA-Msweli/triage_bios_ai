import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../domain/entities/patient_queue_item.dart';
import '../../domain/entities/hospital_capacity.dart';
import '../widgets/patient_queue_widget.dart';
import '../widgets/capacity_overview_widget.dart';
import '../widgets/real_time_stats_widget.dart';
import '../widgets/emergency_alerts_widget.dart';

class HospitalDashboardPage extends StatefulWidget {
  const HospitalDashboardPage({super.key});

  @override
  State<HospitalDashboardPage> createState() => _HospitalDashboardPageState();
}

class _HospitalDashboardPageState extends State<HospitalDashboardPage> {
  List<PatientQueueItem> _patientQueue = [];
  HospitalCapacity _capacity = HospitalCapacity.initial();
  Timer? _updateTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeDemoData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _initializeDemoData() {
    // Initialize with some demo patients
    _patientQueue = [
      PatientQueueItem(
        id: 'P001',
        name: 'Sarah Johnson',
        age: 34,
        severityScore: 8.5,
        urgencyLevel: 'CRITICAL',
        symptoms: 'Chest pain, difficulty breathing',
        vitals: {
          'heartRate': 135,
          'bloodPressure': '160/95',
          'oxygenSaturation': 91.0,
          'temperature': 99.8,
        },
        arrivalTime: DateTime.now().subtract(const Duration(minutes: 5)),
        estimatedWaitTime: 0, // Critical - immediate
        triageNurse: 'Nurse Williams',
        deviceSource: 'Apple Watch Series 9',
      ),
      PatientQueueItem(
        id: 'P002',
        name: 'Michael Chen',
        age: 28,
        severityScore: 6.2,
        urgencyLevel: 'URGENT',
        symptoms: 'Severe headache, nausea, dizziness',
        vitals: {
          'heartRate': 95,
          'bloodPressure': '140/88',
          'oxygenSaturation': 97.0,
          'temperature': 101.2,
        },
        arrivalTime: DateTime.now().subtract(const Duration(minutes: 12)),
        estimatedWaitTime: 25,
        triageNurse: 'Nurse Davis',
        deviceSource: 'Samsung Galaxy Watch',
      ),
      PatientQueueItem(
        id: 'P003',
        name: 'Emily Rodriguez',
        age: 45,
        severityScore: 4.8,
        urgencyLevel: 'STANDARD',
        symptoms: 'Abdominal pain, mild fever',
        vitals: {
          'heartRate': 88,
          'bloodPressure': '125/82',
          'oxygenSaturation': 98.5,
          'temperature': 100.4,
        },
        arrivalTime: DateTime.now().subtract(const Duration(minutes: 28)),
        estimatedWaitTime: 45,
        triageNurse: 'Nurse Thompson',
        deviceSource: 'Fitbit Sense 2',
      ),
      PatientQueueItem(
        id: 'P004',
        name: 'Robert Kim',
        age: 52,
        severityScore: 3.1,
        urgencyLevel: 'NON_URGENT',
        symptoms: 'Minor cut on hand, requesting tetanus shot',
        vitals: {
          'heartRate': 72,
          'bloodPressure': '118/76',
          'oxygenSaturation': 99.0,
          'temperature': 98.6,
        },
        arrivalTime: DateTime.now().subtract(const Duration(minutes: 35)),
        estimatedWaitTime: 65,
        triageNurse: 'Nurse Johnson',
        deviceSource: 'Apple Watch SE',
      ),
    ];

    // Initialize capacity data
    _capacity = HospitalCapacity(
      totalBeds: 450,
      availableBeds: 23,
      icuBeds: 8,
      emergencyBeds: 12,
      staffOnDuty: 85,
      patientsInQueue: _patientQueue.length,
      averageWaitTime: 35.0,
      lastUpdated: DateTime.now(),
    );
  }

  void _startRealTimeUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() {
        _simulateRealTimeUpdates();
      });
    });
  }

  void _simulateRealTimeUpdates() {
    // Simulate new patient arrivals occasionally
    if (_random.nextDouble() < 0.3) {
      _addNewPatient();
    }

    // Update existing patient wait times
    for (int i = 0; i < _patientQueue.length; i++) {
      final patient = _patientQueue[i];
      if (patient.estimatedWaitTime > 0) {
        _patientQueue[i] = patient.copyWith(
          estimatedWaitTime: (patient.estimatedWaitTime - 1).clamp(0, 999),
        );
      }
    }

    // Simulate patient being called for treatment
    if (_random.nextDouble() < 0.2 && _patientQueue.isNotEmpty) {
      _patientQueue.removeAt(0);
    }

    // Update capacity
    _capacity = _capacity.copyWith(
      availableBeds: (_capacity.availableBeds + _random.nextInt(3) - 1).clamp(
        0,
        50,
      ),
      patientsInQueue: _patientQueue.length,
      averageWaitTime: _calculateAverageWaitTime(),
      lastUpdated: DateTime.now(),
    );
  }

  void _addNewPatient() {
    final names = [
      'Alex Thompson',
      'Maria Garcia',
      'David Wilson',
      'Lisa Chang',
      'James Brown',
    ];
    final symptoms = [
      'Fever and cough',
      'Ankle sprain from fall',
      'Allergic reaction',
      'Chest discomfort',
      'Severe headache',
    ];

    final severityScore = 2.0 + _random.nextDouble() * 6.0; // 2.0 to 8.0
    String urgencyLevel;
    if (severityScore >= 8.0) {
      urgencyLevel = 'CRITICAL';
    } else if (severityScore >= 6.0) {
      urgencyLevel = 'URGENT';
    } else if (severityScore >= 4.0) {
      urgencyLevel = 'STANDARD';
    } else {
      urgencyLevel = 'NON_URGENT';
    }

    final newPatient = PatientQueueItem(
      id: 'P${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      name: names[_random.nextInt(names.length)],
      age: 18 + _random.nextInt(65),
      severityScore: severityScore,
      urgencyLevel: urgencyLevel,
      symptoms: symptoms[_random.nextInt(symptoms.length)],
      vitals: {
        'heartRate': 60 + _random.nextInt(60),
        'bloodPressure':
            '${110 + _random.nextInt(40)}/${70 + _random.nextInt(30)}',
        'oxygenSaturation': 95.0 + _random.nextDouble() * 5.0,
        'temperature': 98.0 + _random.nextDouble() * 4.0,
      },
      arrivalTime: DateTime.now(),
      estimatedWaitTime: _random.nextInt(60) + 10,
      triageNurse:
          'Nurse ${['Smith', 'Johnson', 'Williams'][_random.nextInt(3)]}',
      deviceSource: [
        'Apple Watch',
        'Samsung Watch',
        'Fitbit',
      ][_random.nextInt(3)],
    );

    setState(() {
      _patientQueue.add(newPatient);
      _patientQueue.sort((a, b) => b.severityScore.compareTo(a.severityScore));
    });
  }

  double _calculateAverageWaitTime() {
    if (_patientQueue.isEmpty) return 0.0;
    final totalWaitTime = _patientQueue.fold<int>(
      0,
      (sum, patient) => sum + patient.estimatedWaitTime,
    );
    return totalWaitTime / _patientQueue.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.dashboard,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'City General Hospital',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Emergency Department Dashboard',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _simulateRealTimeUpdates();
              });
            },
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon')),
              );
            },
            tooltip: 'Settings',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 1000;

          if (isWideScreen) {
            return Row(
              children: [
                // Main content area
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Real-time stats bar
                      RealTimeStatsWidget(capacity: _capacity),

                      // Emergency alerts
                      EmergencyAlertsWidget(patientQueue: _patientQueue),

                      // Patient queue
                      Expanded(
                        child: PatientQueueWidget(
                          patientQueue: _patientQueue,
                          onPatientSelected: (patient) {
                            _showPatientDetails(patient);
                          },
                          onPatientCalled: (patient) {
                            setState(() {
                              _patientQueue.remove(patient);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${patient.name} called for treatment',
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Right sidebar
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Capacity overview
                      CapacityOverviewWidget(capacity: _capacity),

                      // Quick actions
                      _buildQuickActions(),

                      // Recent activity
                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // Mobile/tablet layout
            return Column(
              children: [
                // Real-time stats bar
                RealTimeStatsWidget(capacity: _capacity),

                // Emergency alerts
                EmergencyAlertsWidget(patientQueue: _patientQueue),

                // Patient queue
                Expanded(
                  child: PatientQueueWidget(
                    patientQueue: _patientQueue,
                    onPatientSelected: (patient) {
                      _showPatientDetails(patient);
                    },
                    onPatientCalled: (patient) {
                      setState(() {
                        _patientQueue.remove(patient);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${patient.name} called for treatment'),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewPatient,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
        tooltip: 'Simulate new patient arrival',
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency alert sent to all staff'),
                  ),
                );
              },
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Alert'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling additional staff')),
                );
              },
              icon: const Icon(Icons.people),
              label: const Text('Call Staff'),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bed management system opened')),
                );
              },
              icon: const Icon(Icons.bed),
              label: const Text('Manage Beds'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  _buildActivityItem(
                    Icons.person_add,
                    'New patient arrived',
                    'Sarah Johnson - Critical',
                    '5 min ago',
                    Colors.red,
                  ),
                  _buildActivityItem(
                    Icons.medical_services,
                    'Patient treated',
                    'John Doe discharged',
                    '12 min ago',
                    Colors.green,
                  ),
                  _buildActivityItem(
                    Icons.bed,
                    'Bed available',
                    'Room 204 - ICU',
                    '18 min ago',
                    Colors.blue,
                  ),
                  _buildActivityItem(
                    Icons.warning,
                    'Capacity alert',
                    'ER at 85% capacity',
                    '25 min ago',
                    Colors.orange,
                  ),
                  _buildActivityItem(
                    Icons.people,
                    'Staff update',
                    'Dr. Smith on duty',
                    '32 min ago',
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    String title,
    String subtitle,
    String time,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(PatientQueueItem patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Patient Details - ${patient.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Age', '${patient.age} years'),
              _buildDetailRow(
                'Severity Score',
                '${patient.severityScore.toStringAsFixed(1)}/10',
              ),
              _buildDetailRow('Urgency Level', patient.urgencyLevel),
              _buildDetailRow('Symptoms', patient.symptoms),
              _buildDetailRow(
                'Heart Rate',
                '${patient.vitals['heartRate']} bpm',
              ),
              _buildDetailRow(
                'Blood Pressure',
                patient.vitals['bloodPressure'].toString(),
              ),
              _buildDetailRow(
                'SpO2',
                '${patient.vitals['oxygenSaturation']?.toStringAsFixed(1)}%',
              ),
              _buildDetailRow(
                'Temperature',
                '${patient.vitals['temperature']?.toStringAsFixed(1)}°F',
              ),
              _buildDetailRow('Device Source', patient.deviceSource),
              _buildDetailRow('Triage Nurse', patient.triageNurse),
              _buildDetailRow('Arrival Time', _formatTime(patient.arrivalTime)),
              _buildDetailRow(
                'Est. Wait Time',
                '${patient.estimatedWaitTime} minutes',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _patientQueue.remove(patient);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${patient.name} called for treatment')),
              );
            },
            child: const Text('Call Patient'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
