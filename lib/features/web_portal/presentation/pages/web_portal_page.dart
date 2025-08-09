import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../widgets/patient_dashboard_widget.dart';
import '../widgets/caregiver_dashboard_widget.dart';
import '../widgets/provider_dashboard_widget.dart';
import '../widgets/admin_dashboard_widget.dart';

class WebPortalPage extends StatefulWidget {
  const WebPortalPage({super.key});

  @override
  State<WebPortalPage> createState() => _WebPortalPageState();
}

class _WebPortalPageState extends State<WebPortalPage> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() {
    if (!_authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            destinations: _getNavigationDestinations(user.role),
            leading: Column(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  user.displayRole,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _showProfileDialog,
                        icon: const Icon(Icons.settings),
                        tooltip: 'Settings',
                      ),
                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Vertical divider
          const VerticalDivider(thickness: 1, width: 1),

          // Main content
          Expanded(
            child: Column(
              children: [
                // App bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Web Portal',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (user.isGuest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Guest Mode',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 16),
                      Text(
                        _getCurrentDateTime(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Expanded(
                  child: _buildContent(user.role),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _getNavigationDestinations(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return const [
          NavigationRailDestination(
            icon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.medical_services),
            label: Text('Triage'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.local_hospital),
            label: Text('Hospitals'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history),
            label: Text('History'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.favorite),
            label: Text('Vitals'),
          ),
        ];
      case UserRole.caregiver:
        return const [
          NavigationRailDestination(
            icon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.people),
            label: Text('Patients'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.notifications),
            label: Text('Alerts'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.local_hospital),
            label: Text('Hospitals'),
          ),
        ];
      case UserRole.healthcare_provider:
        return const [
          NavigationRailDestination(
            icon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.queue),
            label: Text('Patient Queue'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.analytics),
            label: Text('Analytics'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bed),
            label: Text('Capacity'),
          ),
        ];
      case UserRole.admin:
        return const [
          NavigationRailDestination(
            icon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.people),
            label: Text('Users'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.analytics),
            label: Text('Analytics'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings),
            label: Text('System'),
          ),
        ];
    }
  }

  Widget _buildContent(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return _buildPatientContent();
      case UserRole.caregiver:
        return _buildCaregiverContent();
      case UserRole.healthcare_provider:
        return _buildProviderContent();
      case UserRole.admin:
        return _buildAdminContent();
    }
  }

  Widget _buildPatientContent() {
    switch (_selectedIndex) {
      case 0:
        return const PatientDashboardWidget();
      case 1:
        return _buildTriageSection();
      case 2:
        return _buildHospitalsSection();
      case 3:
        return _buildHistorySection();
      case 4:
        return _buildVitalsSection();
      default:
        return const PatientDashboardWidget();
    }
  }

  Widget _buildCaregiverContent() {
    switch (_selectedIndex) {
      case 0:
        return const CaregiverDashboardWidget();
      case 1:
        return _buildPatientsSection();
      case 2:
        return _buildAlertsSection();
      case 3:
        return _buildHospitalsSection();
      default:
        return const CaregiverDashboardWidget();
    }
  }

  Widget _buildProviderContent() {
    switch (_selectedIndex) {
      case 0:
        return const ProviderDashboardWidget();
      case 1:
        return _buildPatientQueueSection();
      case 2:
        return _buildAnalyticsSection();
      case 3:
        return _buildCapacitySection();
      default:
        return const ProviderDashboardWidget();
    }
  }

  Widget _buildAdminContent() {
    switch (_selectedIndex) {
      case 0:
        return const AdminDashboardWidget();
      case 1:
        return _buildUsersSection();
      case 2:
        return _buildAnalyticsSection();
      case 3:
        return _buildSystemSection();
      default:
        return const AdminDashboardWidget();
    }
  }

  // Placeholder sections - these would be implemented as separate widgets
  Widget _buildTriageSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services, size: 64),
          SizedBox(height: 16),
          Text('Triage Assessment'),
          SizedBox(height: 8),
          Text('Start a new triage assessment or view recent results'),
        ],
      ),
    );
  }

  Widget _buildHospitalsSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital, size: 64),
          SizedBox(height: 16),
          Text('Nearby Hospitals'),
          SizedBox(height: 8),
          Text('View hospital locations, capacity, and wait times'),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64),
          SizedBox(height: 16),
          Text('Assessment History'),
          SizedBox(height: 8),
          Text('View your previous triage assessments and outcomes'),
        ],
      ),
    );
  }

  Widget _buildVitalsSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, size: 64),
          SizedBox(height: 16),
          Text('Vitals Monitoring'),
          SizedBox(height: 8),
          Text('Track your vital signs and health trends'),
        ],
      ),
    );
  }

  Widget _buildPatientsSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64),
          SizedBox(height: 16),
          Text('Patients Under Care'),
          SizedBox(height: 8),
          Text('Monitor patients you are caring for'),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications, size: 64),
          SizedBox(height: 16),
          Text('Health Alerts'),
          SizedBox(height: 8),
          Text('Important notifications and alerts'),
        ],
      ),
    );
  }

  Widget _buildPatientQueueSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue, size: 64),
          SizedBox(height: 16),
          Text('Patient Queue'),
          SizedBox(height: 8),
          Text('Manage incoming patients and triage priorities'),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64),
          SizedBox(height: 16),
          Text('Analytics & Reports'),
          SizedBox(height: 8),
          Text('View system analytics and performance metrics'),
        ],
      ),
    );
  }

  Widget _buildCapacitySection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bed, size: 64),
          SizedBox(height: 16),
          Text('Capacity Management'),
          SizedBox(height: 8),
          Text('Monitor and manage hospital capacity'),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64),
          SizedBox(height: 16),
          Text('User Management'),
          SizedBox(height: 8),
          Text('Manage system users and permissions'),
        ],
      ),
    );
  }

  Widget _buildSystemSection() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64),
          SizedBox(height: 16),
          Text('System Settings'),
          SizedBox(height: 8),
          Text('Configure system settings and preferences'),
        ],
      ),
    );
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showProfileDialog() {
    final user = _authService.currentUser!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.name}'),
            Text('Email: ${user.email}'),
            Text('Role: ${user.displayRole}'),
            if (user.phoneNumber != null) Text('Phone: ${user.phoneNumber}'),
            if (user.age != null) Text('Age: ${user.age}'),
            Text('Member since: ${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'),
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

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}