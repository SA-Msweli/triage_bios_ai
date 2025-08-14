import 'package:flutter/material.dart';

/// Patient dashboard widget showing health data and triage options
class PatientDashboardWidget extends StatelessWidget {
  const PatientDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Your Health Dashboard',
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
                  'AI Triage',
                  'Start health assessment',
                  Icons.psychology,
                  Colors.blue,
                  () {},
                ),
                _buildDashboardCard(
                  'Find Hospitals',
                  'Locate nearby facilities',
                  Icons.local_hospital,
                  Colors.green,
                  () {},
                ),
                _buildDashboardCard(
                  'Health Data',
                  'View your vitals',
                  Icons.favorite,
                  Colors.red,
                  () {},
                ),
                _buildDashboardCard(
                  'Consent Management',
                  'Manage data sharing',
                  Icons.security,
                  Colors.orange,
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
