import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/enterprise_auth_service.dart';
import '../../../../shared/widgets/role_based_ui_components.dart';
import '../../../../shared/widgets/role_based_navigation.dart';
import 'patient_dashboard_widget.dart';
import 'provider_dashboard_widget.dart';
import 'caregiver_dashboard_widget.dart';

/// Central dashboard router that handles role-based navigation and UI rendering
class DashboardRouter extends StatefulWidget {
  const DashboardRouter({super.key});

  @override
  State<DashboardRouter> createState() => _DashboardRouterState();
}

class _DashboardRouterState extends State<DashboardRouter> {
  final EnterpriseAuthService _authService = EnterpriseAuthService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null || !_authService.isAuthenticated) {
      // Redirect to login if not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: RoleBasedAppBar(
        title: '${user.displayRole} Dashboard',
        user: user,
        notificationCount: _getNotificationCount(user),
      ),
      body: _buildBody(user),
      drawer: RoleBasedDrawer(
        user: user,
        selectedIndex: _selectedIndex,
        onItemTapped: _selectPage,
        notificationCounts: _getNotificationCounts(user),
      ),
      bottomNavigationBar: RoleBasedNavigation(
        userRole: user.role,
        selectedIndex: _selectedIndex,
        onItemTapped: _selectPage,
        showBadges: true,
        notificationCounts: _getNotificationCounts(user),
      ),
    );
  }

  Widget _buildBody(User user) {
    switch (user.role) {
      case UserRole.patient:
        return _buildPatientBody();
      case UserRole.healthcareProvider:
        return _buildProviderBody();
      case UserRole.caregiver:
        return _buildCaregiverBody();
      case UserRole.admin:
        return _buildAdminBody();
    }
  }

  Widget _buildPatientBody() {
    final pages = [
      const PatientDashboardWidget(),
      _buildTriagePage(),
      _buildHospitalsPage(),
      _buildHealthDataPage(),
    ];
    return pages[_selectedIndex];
  }

  Widget _buildProviderBody() {
    final pages = [
      const ProviderDashboardWidget(),
      _buildPatientQueuePage(),
      _buildAnalyticsPage(),
      _buildSettingsPage(),
    ];
    return pages[_selectedIndex];
  }

  Widget _buildCaregiverBody() {
    final pages = [
      const CaregiverDashboardWidget(),
      _buildPatientsPage(),
      _buildAlertsPage(),
      _buildResourcesPage(),
    ];
    return pages[_selectedIndex];
  }

  Widget _buildAdminBody() {
    final pages = [
      const AdminDashboardWidget(),
      _buildUserManagementPage(),
      _buildSystemMonitoringPage(),
      _buildAuditLogsPage(),
    ];
    return pages[_selectedIndex];
  }

  // Helper methods
  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Embedded pages for dashboard sections
  Widget _buildTriagePage() {
    // For patient dashboard, show triage launch page
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.medical_services, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'AI Triage Assessment',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Start your AI-powered health assessment'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToTriage,
            icon: const Icon(Icons.psychology),
            label: const Text('Start AI Triage'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalsPage() {
    // For patient dashboard, show hospital finder launch page
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_hospital, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Find Hospitals',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Locate nearby emergency facilities'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToHospitals,
            icon: const Icon(Icons.search),
            label: const Text('Find Nearby Hospitals'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDataPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Health Data',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('View your health metrics and trends'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
            icon: const Icon(Icons.person),
            label: const Text('View Profile & Health Data'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientQueuePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.queue, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Patient Queue',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Manage patient queue and priorities'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToTriagePortal,
            icon: const Icon(Icons.medical_services),
            label: const Text('Open Triage Portal'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, size: 64, color: Colors.purple),
          const SizedBox(height: 16),
          const Text(
            'Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('View system analytics and reports'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed('/hospital-dashboard'),
            icon: const Icon(Icons.local_hospital),
            label: const Text('Hospital Analytics'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Configure system settings'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
            icon: const Icon(Icons.person),
            label: const Text('User Settings'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            'My Patients',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Manage patients under your care'),
        ],
      ),
    );
  }

  Widget _buildAlertsPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Alerts',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('View patient alerts and notifications'),
        ],
      ),
    );
  }

  Widget _buildResourcesPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Resources',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Access care resources and guides'),
        ],
      ),
    );
  }

  Widget _buildUserManagementPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            'User Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Manage system users and roles'),
        ],
      ),
    );
  }

  Widget _buildSystemMonitoringPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_heart, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'System Monitoring',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Monitor system health and performance'),
        ],
      ),
    );
  }

  Widget _buildAuditLogsPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Audit Logs',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('View security audit logs'),
        ],
      ),
    );
  }

  // Navigation methods for different sections
  void _navigateToTriage() {
    Navigator.of(context).pushNamed('/triage');
  }

  void _navigateToHospitals() {
    Navigator.of(context).pushNamed('/hospitals');
  }

  void _navigateToTriagePortal() {
    Navigator.of(context).pushNamed('/triage-portal');
  }

  // Helper methods for notifications
  int _getNotificationCount(User user) {
    switch (user.role) {
      case UserRole.patient:
        return 2;
      case UserRole.healthcareProvider:
        return 5;
      case UserRole.caregiver:
        return 1;
      case UserRole.admin:
        return 3;
    }
  }

  Map<String, int> _getNotificationCounts(User user) {
    switch (user.role) {
      case UserRole.patient:
        return {
          '/patient-dashboard': 0,
          '/triage': 1,
          '/hospitals': 0,
          '/profile': 1,
        };
      case UserRole.healthcareProvider:
        return {
          '/provider-dashboard': 2,
          '/triage-portal': 3,
          '/hospital-dashboard': 0,
          '/profile': 0,
        };
      case UserRole.caregiver:
        return {
          '/caregiver-dashboard': 1,
          '/triage': 0,
          '/hospitals': 0,
          '/profile': 0,
        };
      case UserRole.admin:
        return {'/admin-dashboard': 1, '/hospital-dashboard': 2, '/profile': 0};
    }
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
                  'LDAP Configuration',
                  'Configure LDAP/AD integration',
                  Icons.settings,
                  Colors.purple,
                  () => Navigator.of(context).pushNamed('/ldap-config'),
                ),
                _buildAdminCard(
                  'SSO Configuration',
                  'Configure SAML/OAuth2 SSO',
                  Icons.login,
                  Colors.indigo,
                  () => Navigator.of(context).pushNamed('/sso-config'),
                ),
                _buildAdminCard(
                  'Identity Providers',
                  'Manage all identity providers',
                  Icons.dns,
                  Colors.deepPurple,
                  () => Navigator.of(context).pushNamed('/identity-providers'),
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
