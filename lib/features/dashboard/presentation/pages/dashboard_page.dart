import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../widgets/patient_dashboard_widget.dart';
import '../widgets/caregiver_dashboard_widget.dart';
import '../widgets/provider_dashboard_widget.dart';
import '../widgets/admin_dashboard_widget.dart';
import '../../../triage/presentation/pages/patient_history_page.dart';
import '../../../triage/presentation/pages/device_pairing_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800;

          if (isWideScreen) {
            return _buildDesktopLayout(user);
          } else {
            return _buildMobileLayout(user);
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(User user) {
    return Row(
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
              _buildAppBar(user),
              // Content area
              Expanded(child: _buildContent(user.role)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(User user) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
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
      body: _buildContent(user.role),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: _getBottomNavigationItems(user.role),
      ),
    );
  }

  Widget _buildAppBar(User user) {
    return Container(
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
              'Dashboard',
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
      case UserRole.healthcareProvider:
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

  List<BottomNavigationBarItem> _getBottomNavigationItems(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Triage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Hospitals',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Vitals'),
        ];
      case UserRole.caregiver:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Hospitals',
          ),
        ];
      case UserRole.healthcareProvider:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.queue), label: 'Queue'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bed), label: 'Capacity'),
        ];
      case UserRole.admin:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'System'),
        ];
    }
  }

  Widget _buildContent(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return _buildPatientContent();
      case UserRole.caregiver:
        return _buildCaregiverContent();
      case UserRole.healthcareProvider:
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.medical_services, size: 64),
          const SizedBox(height: 16),
          const Text('Triage Assessment'),
          const SizedBox(height: 8),
          const Text('Start a new triage assessment or view recent results'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/enhanced-triage'),
            icon: const Icon(Icons.medical_services),
            label: const Text('Start Triage Assessment'),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalsSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_hospital, size: 64),
          const SizedBox(height: 16),
          const Text('Nearby Hospitals'),
          const SizedBox(height: 8),
          const Text('View hospital locations, capacity, and wait times'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/hospitals'),
            icon: const Icon(Icons.local_hospital),
            label: const Text('Find Hospitals'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64),
          const SizedBox(height: 16),
          const Text('Assessment History'),
          const SizedBox(height: 8),
          const Text('View your previous triage assessments and outcomes'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to patient history page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientHistoryPage(),
                ),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('View History'),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, size: 64),
          const SizedBox(height: 16),
          const Text('Vitals Monitoring'),
          const SizedBox(height: 8),
          const Text('Track your vital signs and health trends'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to device pairing page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DevicePairingPage(),
                ),
              );
            },
            icon: const Icon(Icons.favorite),
            label: const Text('Connect Devices'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64),
          const SizedBox(height: 16),
          const Text('Patients Under Care'),
          const SizedBox(height: 8),
          const Text('Monitor patients you are caring for'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to patient management page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientHistoryPage(),
                ),
              );
            },
            icon: const Icon(Icons.people),
            label: const Text('Manage Patients'),
          ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.queue, size: 64),
          const SizedBox(height: 16),
          const Text('Patient Queue'),
          const SizedBox(height: 8),
          const Text('Manage incoming patients and triage priorities'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/hospital-dashboard'),
            icon: const Icon(Icons.queue),
            label: const Text('View Patient Queue'),
          ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64),
          const SizedBox(height: 16),
          const Text('User Management'),
          const SizedBox(height: 8),
          const Text('Manage system users and permissions'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/sessions'),
            icon: const Icon(Icons.people),
            label: const Text('Manage Users'),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings, size: 64),
          const SizedBox(height: 16),
          const Text('System Settings'),
          const SizedBox(height: 8),
          const Text('Configure system settings and preferences'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/identity-providers'),
            icon: const Icon(Icons.settings),
            label: const Text('System Settings'),
          ),
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
            Text(
              'Member since: ${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
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
