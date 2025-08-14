import 'package:flutter/material.dart';

/// Healthcare provider dashboard widget showing patient queue and analytics
class ProviderDashboardWidget extends StatelessWidget {
  const ProviderDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Provider Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildDashboardCard(
                  'Patient Queue',
                  'Manage triage queue',
                  Icons.queue,
                  Colors.orange,
                  () {},
                ),
                _buildDashboardCard(
                  'Analytics',
                  'View system metrics',
                  Icons.analytics,
                  Colors.purple,
                  () {},
                ),
                _buildDashboardCard(
                  'Assessments',
                  'Review AI assessments',
                  Icons.medical_services,
                  Colors.blue,
                  () {},
                ),
                _buildDashboardCard(
                  'Settings',
                  'Configure preferences',
                  Icons.settings,
                  Colors.grey,
                  () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
