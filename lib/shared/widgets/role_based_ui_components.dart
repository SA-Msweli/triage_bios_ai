import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/enterprise_auth_service.dart';
import '../middleware/auth_middleware.dart';
import 'unauthorized_access_page.dart';

/// Enhanced role-based app bar with user context and permissions
class RoleBasedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final User user;
  final List<Widget>? actions;
  final bool showRoleIndicator;
  final bool showNotifications;
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const RoleBasedAppBar({
    super.key,
    required this.title,
    required this.user,
    this.actions,
    this.showRoleIndicator = true,
    this.showNotifications = true,
    this.notificationCount = 0,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (showRoleIndicator) ...[
            const SizedBox(width: 8),
            _buildRoleChip(),
          ],
        ],
      ),
      backgroundColor: _getRoleColor(user.role),
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        // Notifications
        if (showNotifications)
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (notificationCount > 0)
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
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        notificationCount > 99
                            ? '99+'
                            : notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: onNotificationTap ?? () => _showNotifications(context),
          ),

        // User profile menu
        PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getRoleColor(user.role),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          onSelected: (value) => _handleProfileMenuAction(context, value),
          itemBuilder: (context) => _buildProfileMenuItems(),
        ),

        // Additional actions
        if (actions != null) ...actions!,
      ],
    );
  }

  Widget _buildRoleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getRoleIcon(user.role), size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            user.displayRole,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildProfileMenuItems() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'profile',
        child: Row(
          children: [
            Icon(Icons.person, size: 20),
            SizedBox(width: 8),
            Text('Profile'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'sessions',
        child: Row(
          children: [
            Icon(Icons.devices, size: 20),
            SizedBox(width: 8),
            Text('Sessions'),
          ],
        ),
      ),
    ];

    // Add role-specific menu items
    switch (user.role) {
      case UserRole.patient:
        items.add(
          const PopupMenuItem(
            value: 'consent',
            child: Row(
              children: [
                Icon(Icons.security, size: 20),
                SizedBox(width: 8),
                Text('Consent Management'),
              ],
            ),
          ),
        );
        break;
      case UserRole.healthcareProvider:
        items.add(
          const PopupMenuItem(
            value: 'patients',
            child: Row(
              children: [
                Icon(Icons.people, size: 20),
                SizedBox(width: 8),
                Text('My Patients'),
              ],
            ),
          ),
        );
        break;
      case UserRole.admin:
        items.add(
          const PopupMenuItem(
            value: 'admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 20),
                SizedBox(width: 8),
                Text('Admin Panel'),
              ],
            ),
          ),
        );
        break;
      case UserRole.caregiver:
        // No additional items for caregiver
        break;
    }

    items.addAll([
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'logout',
        child: Row(
          children: [
            Icon(Icons.logout, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ]);

    return items;
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildNotificationItems(),
          ),
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

  List<Widget> _buildNotificationItems() {
    // Mock notifications based on user role
    switch (user.role) {
      case UserRole.patient:
        return [
          _buildNotificationItem(
            'Triage assessment completed',
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
        ];
      case UserRole.healthcareProvider:
        return [
          _buildNotificationItem(
            'New patient in queue',
            '2 minutes ago',
            Icons.person_add,
            Colors.green,
          ),
          _buildNotificationItem(
            'Critical patient alert',
            '10 minutes ago',
            Icons.warning,
            Colors.red,
          ),
        ];
      case UserRole.caregiver:
        return [
          _buildNotificationItem(
            'Patient vitals alert',
            '8 minutes ago',
            Icons.monitor_heart,
            Colors.orange,
          ),
        ];
      case UserRole.admin:
        return [
          _buildNotificationItem(
            'System maintenance scheduled',
            '1 hour ago',
            Icons.build,
            Colors.purple,
          ),
          _buildNotificationItem(
            'New user registration',
            '2 hours ago',
            Icons.person_add,
            Colors.blue,
          ),
        ];
    }
  }

  Widget _buildNotificationItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(time, style: const TextStyle(fontSize: 12)),
      dense: true,
    );
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
        Navigator.of(
          context,
        ).pushNamed('/profile'); // Consent is part of profile
        break;
      case 'patients':
        Navigator.of(context).pushNamed('/provider-dashboard');
        break;
      case 'admin':
        Navigator.of(context).pushNamed('/admin-dashboard');
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  void _showLogoutDialog(BuildContext context) {
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
              final authService = EnterpriseAuthService();
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

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return Icons.person;
      case UserRole.healthcareProvider:
        return Icons.medical_services;
      case UserRole.caregiver:
        return Icons.family_restroom;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Role-based drawer with enhanced navigation and user context
class RoleBasedDrawer extends StatelessWidget {
  final User user;
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Map<String, int>? notificationCounts;

  const RoleBasedDrawer({
    super.key,
    required this.user,
    required this.selectedIndex,
    required this.onItemTapped,
    this.notificationCounts,
  });

  @override
  Widget build(BuildContext context) {
    final navigationItems = AuthMiddleware.getNavigationItems(user.role);
    final authService = EnterpriseAuthService();

    // Filter items based on permissions
    final filteredItems = navigationItems.where((item) {
      return authService.hasPermission(item.permission);
    }).toList();

    return Drawer(
      child: Column(
        children: [
          // Enhanced drawer header
          UserAccountsDrawerHeader(
            accountName: Text(user.name),
            accountEmail: Text(user.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _getRoleColor(user.role),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            decoration: BoxDecoration(
              color: _getRoleColor(user.role),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getRoleColor(user.role),
                  _getRoleColor(user.role).withValues(alpha: 0.8),
                ],
              ),
            ),
            otherAccountsPictures: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.displayRole,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final notificationCount = notificationCounts?[item.route] ?? 0;

                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: selectedIndex == index
                        ? _getRoleColor(user.role)
                        : null,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: selectedIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selectedIndex == index
                          ? _getRoleColor(user.role)
                          : null,
                    ),
                  ),
                  trailing: notificationCount > 0
                      ? _buildNotificationBadge(notificationCount)
                      : null,
                  selected: selectedIndex == index,
                  selectedTileColor: _getRoleColor(
                    user.role,
                  ).withValues(alpha: 0.1),
                  onTap: () {
                    onItemTapped(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),

          const Divider(),

          // Common items
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              _showHelpDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
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

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Triage-BIOS.ai',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.local_hospital, size: 48),
      children: const [
        Text('AI-Powered Emergency Triage System'),
        SizedBox(height: 8),
        Text('Vital Intelligence for Critical Decisions'),
      ],
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

/// Enhanced permission-based widget with loading and error states
class EnhancedPermissionWidget extends StatelessWidget {
  final String requiredPermission;
  final Widget child;
  final Widget? fallback;
  final Widget? loadingWidget;
  final bool showUnauthorizedPage;
  final String? resourceName;

  const EnhancedPermissionWidget({
    super.key,
    required this.requiredPermission,
    required this.child,
    this.fallback,
    this.loadingWidget,
    this.showUnauthorizedPage = false,
    this.resourceName,
  });

  @override
  Widget build(BuildContext context) {
    final authService = EnterpriseAuthService();

    // Check authentication first
    if (!authService.isAuthenticated) {
      return loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    // Check permission
    if (authService.hasPermission(requiredPermission)) {
      return child;
    }

    // Show unauthorized page or fallback
    if (showUnauthorizedPage) {
      return UnauthorizedAccessPage(
        requiredPermission: requiredPermission,
        resourceName: resourceName,
      );
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// Role-based feature card that adapts to user permissions
class RoleBasedFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String requiredPermission;
  final VoidCallback? onTap;
  final Color? color;

  const RoleBasedFeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredPermission,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final authService = EnterpriseAuthService();
    final hasPermission = authService.hasPermission(requiredPermission);
    final cardColor = color ?? Theme.of(context).primaryColor;

    return Card(
      elevation: hasPermission ? 4 : 1,
      child: InkWell(
        onTap: hasPermission ? onTap : () => _showPermissionDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hasPermission ? null : Colors.grey.shade100,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: hasPermission ? cardColor : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasPermission ? null : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: hasPermission ? Colors.grey.shade600 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              if (!hasPermission) ...[
                const SizedBox(height: 8),
                Icon(Icons.lock, size: 16, color: Colors.grey.shade400),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permission Required'),
          ],
        ),
        content: Text(
          'You need the "$requiredPermission" permission to access this feature.',
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
}
