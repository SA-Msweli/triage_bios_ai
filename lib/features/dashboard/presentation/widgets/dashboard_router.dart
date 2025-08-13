import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';
// Removed unused import
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
  final AuthService _authService = AuthService();
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
      appBar: _buildAppBar(user),
      body: _buildBody(user),
      drawer: _buildDrawer(user),
      bottomNavigationBar: _buildBottomNavigation(user),
    );
  }

  PreferredSizeWidget _buildAppBar(User user) {
    return AppBar(
      title: Text('${user.displayRole} Dashboard'),
      backgroundColor: _getAppBarColor(user.role),
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        // Notifications
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications),
              if (_hasNotifications(user))
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => _showNotifications(context),
        ),

        // Profile menu
        PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getAppBarColor(user.role),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          onSelected: (value) => _handleProfileMenuAction(context, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 8),
                  const Text('Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sessions',
              child: Row(
                children: [
                  const Icon(Icons.devices, size: 20),
                  const SizedBox(width: 8),
                  const Text('Sessions'),
                ],
              ),
            ),
            if (user.role == UserRole.patient)
              PopupMenuItem(
                value: 'consent',
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 20),
                    const SizedBox(width: 8),
                    const Text('Consent Management'),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
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

  Widget? _buildDrawer(User user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user.name),
            accountEmail: Text(user.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _getAppBarColor(user.role),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            decoration: BoxDecoration(color: _getAppBarColor(user.role)),
          ),

          // Role-specific navigation items
          ..._buildDrawerItems(user),

          const Divider(),

          // Common items
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              _navigateToSettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              _showHelpDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDrawerItems(User user) {
    switch (user.role) {
      case UserRole.patient:
        return [
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () => _selectPage(0),
          ),
          ListTile(
            leading: const Icon(Icons.medical_services),
            title: const Text('Start Triage'),
            selected: _selectedIndex == 1,
            onTap: () => _selectPage(1),
          ),
          ListTile(
            leading: const Icon(Icons.local_hospital),
            title: const Text('Find Hospitals'),
            selected: _selectedIndex == 2,
            onTap: () => _selectPage(2),
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Health Data'),
            selected: _selectedIndex == 3,
            onTap: () => _selectPage(3),
          ),
        ];

      case UserRole.healthcareProvider:
        return [
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () => _selectPage(0),
          ),
          ListTile(
            leading: const Icon(Icons.queue),
            title: const Text('Patient Queue'),
            selected: _selectedIndex == 1,
            onTap: () => _selectPage(1),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            selected: _selectedIndex == 2,
            onTap: () => _selectPage(2),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            selected: _selectedIndex == 3,
            onTap: () => _selectPage(3),
          ),
        ];

      case UserRole.caregiver:
        return [
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () => _selectPage(0),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('My Patients'),
            selected: _selectedIndex == 1,
            onTap: () => _selectPage(1),
          ),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Alerts'),
            selected: _selectedIndex == 2,
            onTap: () => _selectPage(2),
          ),
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Resources'),
            selected: _selectedIndex == 3,
            onTap: () => _selectPage(3),
          ),
        ];

      case UserRole.admin:
        return [
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () => _selectPage(0),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('User Management'),
            selected: _selectedIndex == 1,
            onTap: () => _selectPage(1),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart),
            title: const Text('System Monitoring'),
            selected: _selectedIndex == 2,
            onTap: () => _selectPage(2),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Audit Logs'),
            selected: _selectedIndex == 3,
            onTap: () => _selectPage(3),
          ),
        ];
    }
  }

  Widget? _buildBottomNavigation(User user) {
    final items = _getBottomNavItems(user);
    if (items.isEmpty) return null;

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _selectPage,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _getAppBarColor(user.role),
      items: items,
    );
  }

  List<BottomNavigationBarItem> _getBottomNavItems(User user) {
    switch (user.role) {
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
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Health'),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ];

      case UserRole.caregiver:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Resources',
          ),
        ];

      case UserRole.admin:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'Audit'),
        ];
    }
  }

  // Helper methods
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

  bool _hasNotifications(User user) {
    // In a real implementation, this would check for actual notifications
    return true;
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close drawer if open
  }

  void _handleProfileMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'profile':
        Navigator.of(context).pushNamed('/profile');
        break;
      case 'sessions':
        Navigator.of(context).pushNamed('/sessions');
        break;
      case 'consent':
        _showConsentManagement();
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationItem(
              'New triage assessment completed',
              '5 minutes ago',
              Icons.medical_services,
              Colors.blue,
            ),
            _buildNotificationItem(
              'Vitals data updated',
              '15 minutes ago',
              Icons.favorite,
              Colors.red,
            ),
            _buildNotificationItem(
              'Hospital capacity alert',
              '1 hour ago',
              Icons.local_hospital,
              Colors.orange,
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

  Widget _buildNotificationItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(time, style: const TextStyle(fontSize: 12)),
      dense: true,
    );
  }

  void _showConsentManagement() {
    // Implementation for consent management
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consent Management'),
        content: const Text(
          'Consent management features are available in the full implementation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _logout() {
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
              await _authService.logout();
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

  void _navigateToSettings() {
    // Implementation for settings navigation
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For help and support, please contact our team at support@triage-bios.ai',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Triage-BIOS.ai',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.local_hospital, size: 48),
      children: [
        const Text('AI-Powered Emergency Triage System'),
        const SizedBox(height: 8),
        const Text('Vital Intelligence for Critical Decisions'),
      ],
    );
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
