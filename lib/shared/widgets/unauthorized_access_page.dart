import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/enterprise_auth_service.dart';
import '../middleware/auth_middleware.dart';

/// Enhanced unauthorized access error page with clear messaging and recovery options
class UnauthorizedAccessPage extends StatelessWidget {
  final String? requiredPermission;
  final String? requiredRole;
  final String? resourceName;
  final String? customMessage;

  const UnauthorizedAccessPage({
    super.key,
    this.requiredPermission,
    this.requiredRole,
    this.resourceName,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final authService = EnterpriseAuthService();
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade600, Colors.red.shade50],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.lock, size: 64, color: Colors.red.shade600),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Access Denied',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Error Message
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getErrorMessage(),
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (currentUser != null) ...[
                        const SizedBox(height: 16),
                        _buildUserInfo(context, currentUser),
                      ],
                      if (requiredPermission != null ||
                          requiredRole != null) ...[
                        const SizedBox(height: 16),
                        _buildRequirements(context),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                _buildActionButtons(context),

                const SizedBox(height: 24),

                // Help Text
                Text(
                  'If you believe this is an error, please contact your system administrator.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getErrorMessage() {
    if (customMessage != null) return customMessage!;

    if (resourceName != null) {
      return 'You do not have permission to access "$resourceName".';
    }

    if (requiredPermission != null) {
      return 'This action requires the "$requiredPermission" permission.';
    }

    if (requiredRole != null) {
      return 'This feature is only available to users with the "$requiredRole" role.';
    }

    return 'You do not have permission to access this resource.';
  }

  Widget _buildUserInfo(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _getRoleColor(user.role),
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Role: ${user.displayRole}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirements(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Requirements:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (requiredRole != null)
            Text(
              '• Role: $requiredRole',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          if (requiredPermission != null)
            Text(
              '• Permission: $requiredPermission',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Primary Action - Go to Dashboard
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToDashboard(context),
            icon: const Icon(Icons.dashboard),
            label: const Text('Go to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showHelpDialog(context),
                icon: const Icon(Icons.help_outline),
                label: const Text('Get Help'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToDashboard(BuildContext context) {
    final authService = EnterpriseAuthService();
    if (authService.isAuthenticated) {
      AuthMiddleware.navigateToRoleDashboard(context);
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Need Help?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('If you need access to this resource, you can:'),
            const SizedBox(height: 12),
            const Text('• Contact your system administrator'),
            const Text('• Request role or permission changes'),
            const Text('• Check if you\'re logged in with the correct account'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'support@triage-bios.ai',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
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

  Color _getRoleColor(UserRole role) {
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
}

/// Widget that wraps content and shows unauthorized page when permissions are insufficient
class PermissionGuard extends StatelessWidget {
  final Widget child;
  final String? requiredPermission;
  final String? requiredRole;
  final String? resourceName;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.child,
    this.requiredPermission,
    this.requiredRole,
    this.resourceName,
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
          UnauthorizedAccessPage(
            requiredPermission: requiredPermission,
            resourceName: resourceName,
          );
    }

    // Check role
    if (requiredRole != null && !authService.hasRole(requiredRole!)) {
      return fallback ??
          UnauthorizedAccessPage(
            requiredRole: requiredRole,
            resourceName: resourceName,
          );
    }

    return child;
  }
}
