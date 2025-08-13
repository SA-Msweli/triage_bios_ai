import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';

class SessionManagementPage extends StatefulWidget {
  const SessionManagementPage({super.key});

  @override
  State<SessionManagementPage> createState() => _SessionManagementPageState();
}

class _SessionManagementPageState extends State<SessionManagementPage> {
  final _authService = AuthService();
  List<UserSession> _activeSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
  }

  Future<void> _loadActiveSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real implementation, this would load from the auth service
      // For demo purposes, we'll create mock sessions
      await Future.delayed(const Duration(seconds: 1));

      _activeSessions = [
        UserSession(
          sessionId: 'session_1',
          userId: _authService.currentUser?.id ?? 'user_1',
          deviceId: 'web_browser_chrome',
          ipAddress: '192.168.1.100',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          lastAccessAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 6)),
          isActive: true,
          deviceInfo: 'Chrome on Windows 11',
          location: 'New York, NY',
          isCurrent: true,
        ),
        UserSession(
          sessionId: 'session_2',
          userId: _authService.currentUser?.id ?? 'user_1',
          deviceId: 'mobile_app_android',
          ipAddress: '192.168.1.101',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          lastAccessAt: DateTime.now().subtract(const Duration(hours: 3)),
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
          isActive: true,
          deviceInfo: 'Android App on Samsung Galaxy S23',
          location: 'New York, NY',
          isCurrent: false,
        ),
        UserSession(
          sessionId: 'session_3',
          userId: _authService.currentUser?.id ?? 'user_1',
          deviceId: 'mobile_app_ios',
          ipAddress: '10.0.0.50',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          lastAccessAt: DateTime.now().subtract(const Duration(days: 1)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          isActive: false,
          deviceInfo: 'iOS App on iPhone 15 Pro',
          location: 'Brooklyn, NY',
          isCurrent: false,
        ),
      ];
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Management'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Active Sessions',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your active sessions across all devices',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Session statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Active Sessions',
                          '${_activeSessions.where((s) => s.isActive).length}',
                          Icons.devices,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Expired Sessions',
                          '${_activeSessions.where((s) => !s.isActive).length}',
                          Icons.schedule,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Sessions',
                          '${_activeSessions.length}',
                          Icons.history,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Sessions list
                  ..._activeSessions.map(
                    (session) => Column(
                      children: [
                        _buildSessionCard(session),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Bulk actions
                  if (_activeSessions
                      .where((s) => s.isActive && !s.isCurrent)
                      .isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _terminateAllOtherSessions,
                        icon: const Icon(Icons.logout),
                        label: const Text('Terminate All Other Sessions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Security tips
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Security Tips',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildTipItem(
                            'Regularly review your active sessions',
                          ),
                          _buildTipItem(
                            'Terminate sessions on devices you no longer use',
                          ),
                          _buildTipItem(
                            'Report any suspicious activity immediately',
                          ),
                          _buildTipItem(
                            'Use strong, unique passwords for your account',
                          ),
                          _buildTipItem(
                            'Enable two-factor authentication for extra security',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(UserSession session) {
    final isExpired =
        !session.isActive || session.expiresAt.isBefore(DateTime.now());
    final timeAgo = _getTimeAgo(session.lastAccessAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getDeviceColor(
                      session.deviceId,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDeviceIcon(session.deviceId),
                    color: _getDeviceColor(session.deviceId),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            session.deviceInfo ?? 'Unknown Device',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (session.isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last active: $timeAgo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired ? 'EXPIRED' : 'ACTIVE',
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Session details
            Row(
              children: [
                Expanded(
                  child: _buildSessionDetail(
                    'IP Address',
                    session.ipAddress,
                    Icons.public,
                  ),
                ),
                Expanded(
                  child: _buildSessionDetail(
                    'Location',
                    session.location ?? 'Unknown',
                    Icons.location_on,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildSessionDetail(
                    'Created',
                    _formatDate(session.createdAt),
                    Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildSessionDetail(
                    'Expires',
                    _formatDate(session.expiresAt),
                    Icons.timer,
                  ),
                ),
              ],
            ),

            if (!session.isCurrent && session.isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _terminateSession(session),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Terminate Session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionDetail(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tip, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceId) {
    if (deviceId.contains('mobile') ||
        deviceId.contains('android') ||
        deviceId.contains('ios')) {
      return Icons.smartphone;
    } else if (deviceId.contains('web') || deviceId.contains('browser')) {
      return Icons.computer;
    } else if (deviceId.contains('tablet')) {
      return Icons.tablet;
    }
    return Icons.device_unknown;
  }

  Color _getDeviceColor(String deviceId) {
    if (deviceId.contains('mobile') || deviceId.contains('android')) {
      return Colors.green;
    } else if (deviceId.contains('ios')) {
      return Colors.blue;
    } else if (deviceId.contains('web') || deviceId.contains('browser')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _terminateSession(UserSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Session'),
        content: Text(
          'Are you sure you want to terminate the session on ${session.deviceInfo}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        session.isActive = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session terminated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _terminateAllOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate All Other Sessions'),
        content: const Text(
          'Are you sure you want to terminate all other active sessions? This will log you out of all other devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Terminate All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        for (final session in _activeSessions) {
          if (!session.isCurrent) {
            session.isActive = false;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All other sessions terminated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

// User session model (should be moved to a proper model file)
class UserSession {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastAccessAt;
  final DateTime expiresAt;
  bool isActive;
  final String? deviceInfo;
  final String? location;
  final bool isCurrent;

  UserSession({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.ipAddress,
    required this.createdAt,
    required this.lastAccessAt,
    required this.expiresAt,
    required this.isActive,
    this.deviceInfo,
    this.location,
    this.isCurrent = false,
  });
}
