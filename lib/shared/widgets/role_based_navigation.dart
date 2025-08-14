import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/enterprise_auth_service.dart';
import '../middleware/auth_middleware.dart';

/// Enhanced role-based navigation widget that shows/hides features based on permissions
class RoleBasedNavigation extends StatelessWidget {
  final UserRole userRole;
  final int selectedIndex;
  final Function(int) onItemTapped;
  final bool isDrawer;
  final bool showBadges;
  final Map<String, int>? notificationCounts;

  const RoleBasedNavigation({
    super.key,
    required this.userRole,
    required this.selectedIndex,
    required this.onItemTapped,
    this.isDrawer = false,
    this.showBadges = true,
    this.notificationCounts,
  });

  @override
  Widget build(BuildContext context) {
    final navigationItems = AuthMiddleware.getNavigationItems(userRole);
    final authService = EnterpriseAuthService();

    // Filter items based on permissions
    final filteredItems = navigationItems.where((item) {
      return authService.hasPermission(item.permission);
    }).toList();

    if (isDrawer) {
      return _buildDrawerNavigation(context, filteredItems);
    } else {
      return _buildBottomNavigation(context, filteredItems);
    }
  }

  Widget _buildDrawerNavigation(
    BuildContext context,
    List<NavigationItem> items,
  ) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final notificationCount = notificationCounts?[item.route] ?? 0;

        return ListTile(
          leading: Icon(
            item.icon,
            color: selectedIndex == index ? _getRoleColor(userRole) : null,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              fontWeight: selectedIndex == index
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: selectedIndex == index ? _getRoleColor(userRole) : null,
            ),
          ),
          trailing: showBadges && notificationCount > 0
              ? _buildNotificationBadge(notificationCount)
              : null,
          selected: selectedIndex == index,
          selectedTileColor: _getRoleColor(userRole).withValues(alpha: 0.1),
          onTap: () => onItemTapped(index),
        );
      },
    );
  }

  Widget _buildBottomNavigation(
    BuildContext context,
    List<NavigationItem> items,
  ) {
    if (items.length <= 1) return const SizedBox.shrink();

    return BottomNavigationBar(
      currentIndex: selectedIndex.clamp(0, items.length - 1),
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _getRoleColor(userRole),
      items: items.asMap().entries.map((entry) {
        final item = entry.value;
        final notificationCount = notificationCounts?[item.route] ?? 0;

        return BottomNavigationBarItem(
          icon: showBadges && notificationCount > 0
              ? Badge(
                  label: Text(notificationCount.toString()),
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  child: Icon(item.icon),
                )
              : Icon(item.icon),
          label: item.label,
        );
      }).toList(),
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

/// Permission-based widget that shows/hides content based on user permissions
class PermissionBasedWidget extends StatelessWidget {
  final String requiredPermission;
  final Widget child;
  final Widget? fallback;

  const PermissionBasedWidget({
    super.key,
    required this.requiredPermission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authService = EnterpriseAuthService();

    if (authService.hasPermission(requiredPermission)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// Role indicator widget that displays user role and permissions
class RoleIndicator extends StatelessWidget {
  final User user;
  final bool showPermissions;

  const RoleIndicator({
    super.key,
    required this.user,
    this.showPermissions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getRoleColor(user.role).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getRoleColor(user.role)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getRoleIcon(user.role),
            size: 16,
            color: _getRoleColor(user.role),
          ),
          const SizedBox(width: 6),
          Text(
            user.displayRole,
            style: TextStyle(
              color: _getRoleColor(user.role),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (showPermissions) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.info_outline,
                size: 16,
                color: _getRoleColor(user.role),
              ),
              itemBuilder: (context) => _getPermissionsList(user.role)
                  .map(
                    (permission) => PopupMenuItem(
                      value: permission,
                      child: Text(
                        permission,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
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

  List<String> _getPermissionsList(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return [
          'read_own_data',
          'manage_consent',
          'view_triage',
          'grant_consent',
          'revoke_consent',
        ];
      case UserRole.healthcareProvider:
        return [
          'read_assigned_patient_data',
          'write_assessments',
          'manage_queue',
          'view_analytics',
        ];
      case UserRole.caregiver:
        return ['read_assigned_patient_data', 'view_queue'];
      case UserRole.admin:
        return ['All permissions'];
    }
  }
}
