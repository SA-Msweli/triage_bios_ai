import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthMiddleware {
  static final AuthService _authService = AuthService();

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

  /// Redirect based on user role
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
    final authService = AuthService();

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
      return fallback ?? const UnauthorizedWidget();
    }

    // Check role
    if (requiredRole != null && !authService.hasRole(requiredRole!)) {
      return fallback ?? const UnauthorizedWidget();
    }

    return child;
  }
}

/// Widget shown when user lacks permissions
class UnauthorizedWidget extends StatelessWidget {
  const UnauthorizedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You do not have permission to access this resource.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
