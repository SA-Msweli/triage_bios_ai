import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';
import 'patient_dashboard_widget.dart';
import 'provider_dashboard_widget.dart';
import 'caregiver_dashboard_widget.dart';

class RoleBasedDashboard extends StatelessWidget {
  const RoleBasedDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.displayRole} Dashboard'),
        backgroundColor: _getAppBarColor(user.role),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showUserProfile(context, user),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _buildDashboardContent(user.role),
    );
  }

  Widget _buildDashboardContent(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return const PatientDashboardWidget();
      case UserRole.healthcareProvider:
        return const ProviderDashboardWidget();
      case UserRole.caregiver:
        return const CaregiverDashboardWidget();
      case UserRole.admin:
        return const AdminDashboardWidget();
    }
  }

  Color _getAppBarColor(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return Colors.blue;
      case UserRole.healthcareProvider:
        return Colors.green;
      case UserRole.caregiver:
        return Colors.orange;
      case UserRole.admin:
        return Colors.purple;
    }
  }

  void _showUserProfile(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.name}'),
            Text('Email: ${user.email}'),
            Text('Role: ${user.displayRole}'),
            if (user.phoneNumber != null) Text('Phone: ${user.phoneNumber}'),
            if (user.age != null) Text('Age: ${user.age}'),
            Text('Member since: ${user.createdAt.toString().split(' ')[0]}'),
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

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authService = AuthService();
              await authService.logout();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardWidget extends StatelessWidget {
  const AdminDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Administration',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildAdminCard(
                  'User Management',
                  'Manage users and roles',
                  Icons.people,
                  Colors.blue,
                  () {},
                ),
                _buildAdminCard(
                  'System Monitoring',
                  'Monitor system health',
                  Icons.monitor_heart,
                  Colors.green,
                  () {},
                ),
                _buildAdminCard(
                  'Audit Logs',
                  'View security audit logs',
                  Icons.security,
                  Colors.orange,
                  () {},
                ),
                _buildAdminCard(
                  'Configuration',
                  'System configuration',
                  Icons.settings,
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

  Widget _buildAdminCard(
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
