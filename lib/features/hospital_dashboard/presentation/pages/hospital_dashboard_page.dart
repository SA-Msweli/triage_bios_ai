import 'package:flutter/material.dart';
import '../../../../config/app_config.dart';

/// Hospital dashboard for monitoring capacity and patient flow
class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  List<dynamic> _patientQueue = [];
  Map<String, dynamic> _hospitalStats = {};
  bool _isLoading = true;

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
      // Initialize services
      // WatsonxService initialization removed

      // Load mock data for demo
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
      // Consider logging the error or showing a user-friendly message
      // print('Error loading dashboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
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
                  // Stats cards
                  _buildStatsSection(),
                  const SizedBox(height: 24),

                  // Patient queue
                  _buildPatientQueue(),
                ],
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
}
