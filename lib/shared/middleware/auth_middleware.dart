import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/enterprise_auth_service.dart';

class AuthMiddleware {
  static final EnterpriseAuthService _authService = EnterpriseAuthService();

  /// Check if user is authenticated and redirect to login if not
  static Future<bool> requireAuth(BuildContext context) async {
    if (!_authService.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
      return false;
    }
    return true;
  }

  /// Check if user has required permission
  static bool requirePermission(String permission) {
    return _authService.hasPermission(permission);
  }

  /// Check if user has required role
  static bool requireRole(String role) {
    return _authService.hasRole(role);
  }

  /// Check if user can access patient data
  static bool canAccessPatientData(String patientId) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;

    // Patient can always access their own data
    if (currentUser.id == patientId) return true;

    // Check if provider has consent
    return _authService.canAccessPatientData(currentUser.id, patientId);
  }

  /// Redirect based on user role after login
  static String getDefaultRoute() {
    final user = _authService.currentUser;
    if (user == null) return '/login';

    switch (user.role) {
      case UserRole.patient:
        return '/patient-dashboard';
      case UserRole.caregiver:
        return '/caregiver-dashboard';
      case UserRole.healthcareProvider:
        return '/provider-dashboard';
      case UserRole.admin:
        return '/admin-dashboard';
    }
  }

  /// Navigate to appropriate dashboard based on user role
  static void navigateToRoleDashboard(BuildContext context) {
    final route = getDefaultRoute();
    if (route != '/login') {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  /// Enhanced post-login routing with intended route handling
  static String getPostLoginRoute({String? intendedRoute}) {
    final user = _authService.currentUser;
    if (user == null) return '/login';

    // If user tried to access a specific route before login, validate permissions
    if (intendedRoute != null &&
        intendedRoute != '/login' &&
        intendedRoute != '/') {
      if (canAccessRoute(intendedRoute)) {
        return intendedRoute;
      } else {
        // User doesn't have permission for intended route, redirect to default
        return getDefaultRoute();
      }
    }

    // Default role-based redirect
    return getDefaultRoute();
  }

  /// Navigate to post-login route with enhanced logic
  static void navigatePostLogin(BuildContext context, {String? intendedRoute}) {
    final route = getPostLoginRoute(intendedRoute: intendedRoute);
    Navigator.of(context).pushReplacementNamed(route);
  }

  /// Check if user has access to specific route
  static bool canAccessRoute(String route) {
    final user = _authService.currentUser;
    if (user == null) return false;

    // Define route permissions based on user roles
    final routePermissions = {
      '/patient-dashboard': [UserRole.patient],
      '/provider-dashboard': [UserRole.healthcareProvider],
      '/caregiver-dashboard': [UserRole.caregiver],
      '/admin-dashboard': [UserRole.admin],
      '/triage': [UserRole.patient, UserRole.caregiver],
      '/triage-portal': [UserRole.healthcareProvider, UserRole.admin],
      '/hospitals': [
        UserRole.patient,
        UserRole.caregiver,
        UserRole.healthcareProvider,
      ],
      '/hospital-dashboard': [UserRole.healthcareProvider, UserRole.admin],
      '/profile': [
        UserRole.patient,
        UserRole.caregiver,
        UserRole.healthcareProvider,
        UserRole.admin,
      ],
      '/sessions': [
        UserRole.patient,
        UserRole.caregiver,
        UserRole.healthcareProvider,
        UserRole.admin,
      ],
    };

    final allowedRoles = routePermissions[route];
    if (allowedRoles == null) return true; // Allow access to unspecified routes

    return allowedRoles.contains(user.role);
  }

  /// Get navigation items based on user role
  static List<NavigationItem> getNavigationItems(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/patient-dashboard',
            permission: 'read_own_data',
          ),
          NavigationItem(
            icon: Icons.medical_services,
            label: 'Start Triage',
            route: '/triage',
            permission: 'view_triage',
          ),
          NavigationItem(
            icon: Icons.local_hospital,
            label: 'Find Hospitals',
            route: '/hospitals',
            permission: 'view_hospitals',
          ),
          NavigationItem(
            icon: Icons.favorite,
            label: 'Health Data',
            route: '/profile',
            permission: 'read_own_data',
          ),
          NavigationItem(
            icon: Icons.security,
            label: 'Consent Management',
            route: '/profile',
            permission: 'manage_consent',
          ),
        ];

      case UserRole.healthcareProvider:
        return [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/provider-dashboard',
            permission: 'read_assigned_patient_data',
          ),
          NavigationItem(
            icon: Icons.queue,
            label: 'Patient Queue',
            route: '/triage-portal',
            permission: 'manage_queue',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Analytics',
            route: '/hospital-dashboard',
            permission: 'view_analytics',
          ),
          NavigationItem(
            icon: Icons.local_hospital,
            label: 'Hospital Capacity',
            route: '/hospitals',
            permission: 'view_capacity',
          ),
        ];

      case UserRole.caregiver:
        return [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/caregiver-dashboard',
            permission: 'read_assigned_patient_data',
          ),
          NavigationItem(
            icon: Icons.people,
            label: 'My Patients',
            route: '/caregiver-dashboard',
            permission: 'read_assigned_patient_data',
          ),
          NavigationItem(
            icon: Icons.medical_services,
            label: 'Start Triage',
            route: '/triage',
            permission: 'view_triage',
          ),
          NavigationItem(
            icon: Icons.local_hospital,
            label: 'Find Hospitals',
            route: '/hospitals',
            permission: 'view_hospitals',
          ),
        ];

      case UserRole.admin:
        return [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/admin-dashboard',
            permission: 'admin_access',
          ),
          NavigationItem(
            icon: Icons.people,
            label: 'User Management',
            route: '/admin-dashboard',
            permission: 'manage_users',
          ),
          NavigationItem(
            icon: Icons.monitor_heart,
            label: 'System Monitoring',
            route: '/admin-dashboard',
            permission: 'system_monitoring',
          ),
          NavigationItem(
            icon: Icons.security,
            label: 'Audit Logs',
            route: '/admin-dashboard',
            permission: 'view_audit_logs',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Analytics',
            route: '/hospital-dashboard',
            permission: 'view_analytics',
          ),
        ];
    }
  }

  /// Get role-specific dashboard layout configuration
  static DashboardLayout getDashboardLayout(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return DashboardLayout(
          primaryColor: Colors.blue,
          title: 'Patient Dashboard',
          features: [
            DashboardFeature.vitalsMonitoring,
            DashboardFeature.triageAssessment,
            DashboardFeature.hospitalFinder,
            DashboardFeature.consentManagement,
          ],
        );

      case UserRole.healthcareProvider:
        return DashboardLayout(
          primaryColor: Colors.green,
          title: 'Provider Dashboard',
          features: [
            DashboardFeature.patientQueue,
            DashboardFeature.hospitalCapacity,
            DashboardFeature.analytics,
            DashboardFeature.triagePortal,
          ],
        );

      case UserRole.caregiver:
        return DashboardLayout(
          primaryColor: Colors.orange,
          title: 'Caregiver Dashboard',
          features: [
            DashboardFeature.patientList,
            DashboardFeature.alerts,
            DashboardFeature.triageAssessment,
            DashboardFeature.resources,
          ],
        );

      case UserRole.admin:
        return DashboardLayout(
          primaryColor: Colors.purple,
          title: 'Admin Dashboard',
          features: [
            DashboardFeature.userManagement,
            DashboardFeature.systemMonitoring,
            DashboardFeature.auditLogs,
            DashboardFeature.analytics,
          ],
        );
    }
  }
}

/// Navigation item model
class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final String permission;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.permission,
  });
}

/// Dashboard layout configuration
class DashboardLayout {
  final Color primaryColor;
  final String title;
  final List<DashboardFeature> features;

  DashboardLayout({
    required this.primaryColor,
    required this.title,
    required this.features,
  });
}

/// Dashboard features enum
enum DashboardFeature {
  vitalsMonitoring,
  triageAssessment,
  hospitalFinder,
  consentManagement,
  patientQueue,
  hospitalCapacity,
  analytics,
  triagePortal,
  patientList,
  alerts,
  resources,
  userManagement,
  systemMonitoring,
  auditLogs,
}

/// Widget that requires authentication
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? requiredPermission;
  final String? requiredRole;
  final Widget? fallback;

  const AuthGuard({
    super.key,
    required this.child,
    this.requiredPermission,
    this.requiredRole,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authService = EnterpriseAuthService();

    // Check authentication
    if (!authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Check permission
    if (requiredPermission != null &&
        !authService.hasPermission(requiredPermission!)) {
      return fallback ??
          UnauthorizedWidget(requiredPermission: requiredPermission);
    }

    // Check role
    if (requiredRole != null && !authService.hasRole(requiredRole!)) {
      return fallback ?? UnauthorizedWidget(requiredRole: requiredRole);
    }

    return child;
  }
}

/// Widget shown when user lacks permissions
class UnauthorizedWidget extends StatelessWidget {
  final String? requiredPermission;
  final String? requiredRole;

  const UnauthorizedWidget({
    super.key,
    this.requiredPermission,
    this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getErrorMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _navigateToAppropriateLocation(context),
                icon: const Icon(Icons.dashboard),
                label: const Text('Go to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getErrorMessage() {
    if (requiredPermission != null) {
      return 'This action requires the "$requiredPermission" permission.';
    }
    if (requiredRole != null) {
      return 'This feature is only available to users with the "$requiredRole" role.';
    }
    return 'You do not have permission to access this resource.';
  }

  void _navigateToAppropriateLocation(BuildContext context) {
    final authService = AuthService();
    if (authService.isAuthenticated) {
      AuthMiddleware.navigateToRoleDashboard(context);
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
