import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/services/real_time_monitoring_service.dart';

/// Overlay widget for displaying real-time notifications and alerts
class NotificationOverlayWidget extends StatefulWidget {
  final Widget child;
  final bool enableSound;
  final Duration defaultDuration;

  const NotificationOverlayWidget({
    super.key,
    required this.child,
    this.enableSound = true,
    this.defaultDuration = const Duration(seconds: 5),
  });

  @override
  State<NotificationOverlayWidget> createState() =>
      _NotificationOverlayWidgetState();
}

class _NotificationOverlayWidgetState extends State<NotificationOverlayWidget>
    with TickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final List<_NotificationItem> _activeNotifications = [];
  StreamSubscription<AppNotification>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();

      _notificationSubscription = _notificationService.notifications.listen((
        notification,
      ) {
        _showNotification(notification);
      });
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  void _showNotification(AppNotification notification) {
    if (!mounted) return;

    // Create animation controller for this notification
    final animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOut),
    );

    final notificationItem = _NotificationItem(
      notification: notification,
      animationController: animationController,
      slideAnimation: slideAnimation,
      fadeAnimation: fadeAnimation,
    );

    setState(() {
      _activeNotifications.add(notificationItem);
    });

    // Start animation
    animationController.forward();

    // Auto-dismiss after duration
    Timer(notification.duration, () {
      _dismissNotification(notificationItem);
    });
  }

  void _dismissNotification(_NotificationItem item) {
    if (!mounted) return;

    // Animate out
    item.animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _activeNotifications.remove(item);
        });
        item.animationController.dispose();
      }
    });
  }

  void _dismissAllNotifications() {
    for (final item in List.from(_activeNotifications)) {
      _dismissNotification(item);
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    for (final item in _activeNotifications) {
      item.animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (_activeNotifications.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_activeNotifications.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton.icon(
                        onPressed: _dismissAllNotifications,
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ..._activeNotifications.map(
                    (item) => _buildNotificationCard(item),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    return AnimatedBuilder(
      animation: item.animationController,
      builder: (context, child) {
        return SlideTransition(
          position: item.slideAnimation,
          child: FadeTransition(
            opacity: item.fadeAnimation,
            child: Container(
              width: 350,
              margin: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 8,
                shadowColor: item.notification.color.withValues(alpha: 0.3),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.notification.color.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      item.notification.onTap?.call();
                      _dismissNotification(item);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: item.notification.color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  item.notification.icon ??
                                      _getDefaultIcon(
                                        item.notification.severity,
                                      ),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.notification.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: item.notification.color,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimestamp(
                                        item.notification.timestamp,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _dismissNotification(item),
                                icon: const Icon(Icons.close, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.notification.message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (item.notification.severity ==
                              AlertSeverity.critical) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.priority_high,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CRITICAL - Immediate attention required',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (item.notification.data != null &&
                              item.notification.data!.containsKey('type')) ...[
                            const SizedBox(height: 8),
                            _buildNotificationActions(item.notification),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationActions(AppNotification notification) {
    final data = notification.data!;
    final type = data['type'] as String;

    switch (type) {
      case 'capacity_alert':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to hospital details
                  debugPrint('Navigate to hospital: ${data['hospitalId']}');
                },
                icon: const Icon(Icons.local_hospital, size: 16),
                label: const Text('View Hospital'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Take action based on alert type
                  debugPrint('Handle capacity alert: ${data['alertType']}');
                },
                icon: const Icon(Icons.build, size: 16),
                label: const Text('Take Action'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: notification.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        );

      case 'vitals_alert':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to patient details
                  debugPrint('Navigate to patient: ${data['patientId']}');
                },
                icon: const Icon(Icons.person, size: 16),
                label: const Text('View Patient'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Escalate or respond to vitals alert
                  debugPrint('Escalate vitals alert: ${data['alertType']}');
                },
                icon: const Icon(Icons.emergency, size: 16),
                label: const Text('Escalate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: notification.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  IconData _getDefaultIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error;
      case AlertSeverity.warning:
        return Icons.warning;
      case AlertSeverity.info:
        return Icons.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 30) {
      return 'just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}

/// Internal class to hold notification with its animations
class _NotificationItem {
  final AppNotification notification;
  final AnimationController animationController;
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;

  _NotificationItem({
    required this.notification,
    required this.animationController,
    required this.slideAnimation,
    required this.fadeAnimation,
  });
}
