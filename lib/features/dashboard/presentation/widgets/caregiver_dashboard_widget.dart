import 'package:flutter/material.dart';

/// Caregiver dashboard widget showing patient management and alerts
class CaregiverDashboardWidget extends StatelessWidget {
  const CaregiverDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Caregiver Dashboard',
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
                  'My Patients',
                  'Manage patients under care',
                  Icons.people,
                  Colors.blue,
                  () {},
                ),
                _buildDashboardCard(
                  'Alerts',
                  'View patient alerts',
                  Icons.warning,
                  Colors.red,
                  () {},
                ),
                _buildDashboardCard(
                  'Resources',
                  'Access care resources',
                  Icons.library_books,
                  Colors.green,
                  () {},
                ),
                _buildDashboardCard(
                  'Communication',
                  'Contact healthcare team',
                  Icons.message,
                  Colors.purple,
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
