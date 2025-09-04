import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/offline_support_service.dart';

/// Widget that displays sync status and provides manual sync controls
class SyncStatusWidget extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onManualSync;

  const SyncStatusWidget({
    super.key,
    this.showDetails = false,
    this.onManualSync,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final OfflineSupportService _offlineService = OfflineSupportService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatusInfo>(
      stream: _offlineService.syncStatusStream,
      initialData: _offlineService.currentSyncStatus,
      builder: (context, snapshot) {
        final syncStatus = snapshot.data ?? _offlineService.currentSyncStatus;

        if (widget.showDetails) {
          return _buildDetailedStatus(context, syncStatus);
        } else {
          return _buildCompactStatus(context, syncStatus);
        }
      },
    );
  }

  Widget _buildCompactStatus(BuildContext context, SyncStatusInfo syncStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(syncStatus.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(syncStatus.status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(syncStatus.status),
            size: 16,
            color: _getStatusColor(syncStatus.status),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(syncStatus.status),
            style: TextStyle(
              fontSize: 12,
              color: _getStatusColor(syncStatus.status),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (syncStatus.pendingOperations > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _getStatusColor(syncStatus.status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${syncStatus.pendingOperations}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedStatus(BuildContext context, SyncStatusInfo syncStatus) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(syncStatus.status),
                  color: _getStatusColor(syncStatus.status),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sync Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (syncStatus.status != SyncStatus.syncing)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _offlineService.manualSync();
                      widget.onManualSync?.call();
                    },
                    tooltip: 'Manual Sync',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(syncStatus.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(syncStatus.status).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(syncStatus.status),
                    size: 20,
                    color: _getStatusColor(syncStatus.status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusText(syncStatus.status),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(syncStatus.status),
                          ),
                        ),
                        if (syncStatus.errorMessage != null)
                          Text(
                            syncStatus.errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sync details
            _buildSyncDetails(context, syncStatus),

            // Connectivity status
            const SizedBox(height: 16),
            _buildConnectivityStatus(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDetails(BuildContext context, SyncStatusInfo syncStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _buildDetailRow(
          'Last Sync',
          _formatDateTime(syncStatus.lastSyncTime),
          Icons.schedule,
        ),

        if (syncStatus.pendingOperations > 0)
          _buildDetailRow(
            'Pending Operations',
            '${syncStatus.pendingOperations}',
            Icons.pending_actions,
            color: Colors.orange,
          ),

        if (syncStatus.conflictCount > 0)
          _buildDetailRow(
            'Conflicts',
            '${syncStatus.conflictCount}',
            Icons.warning,
            color: Colors.red,
          ),

        _buildDetailRow('Cache Status', _getCacheStatusText(), Icons.storage),
      ],
    );
  }

  Widget _buildConnectivityStatus(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _offlineService.connectivityStream,
      initialData: _offlineService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOnline
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOnline
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
              if (!isOnline)
                Text(
                  'Using cached data',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.grey.shade800,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.offline:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.conflictResolution:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icons.check_circle;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.offline:
        return Icons.cloud_off;
      case SyncStatus.error:
        return Icons.error;
      case SyncStatus.conflictResolution:
        return Icons.merge_type;
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.error:
        return 'Error';
      case SyncStatus.conflictResolution:
        return 'Resolving Conflicts';
    }
  }

  String _formatDateTime(DateTime dateTime) {
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

  String _getCacheStatusText() {
    final stats = _offlineService.getCacheStats();
    final totalEntries = stats['totalEntries'] as int;
    final criticalEntries = stats['criticalEntries'] as int;

    if (totalEntries == 0) {
      return 'Empty';
    } else {
      return '$totalEntries items ($criticalEntries critical)';
    }
  }
}

/// Floating sync status indicator for minimal UI impact
class FloatingSyncStatus extends StatelessWidget {
  final VoidCallback? onTap;

  const FloatingSyncStatus({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final offlineService = OfflineSupportService();

    return StreamBuilder<SyncStatusInfo>(
      stream: offlineService.syncStatusStream,
      initialData: offlineService.currentSyncStatus,
      builder: (context, snapshot) {
        final syncStatus = snapshot.data ?? offlineService.currentSyncStatus;

        // Only show if there are issues or pending operations
        if (syncStatus.status == SyncStatus.synced &&
            syncStatus.pendingOperations == 0) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 16,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: _getStatusColor(syncStatus.status).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(syncStatus.status),
                    size: 16,
                    color: _getStatusColor(syncStatus.status),
                  ),
                  if (syncStatus.pendingOperations > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(syncStatus.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${syncStatus.pendingOperations}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.offline:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.conflictResolution:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icons.check_circle;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.offline:
        return Icons.cloud_off;
      case SyncStatus.error:
        return Icons.error;
      case SyncStatus.conflictResolution:
        return Icons.merge_type;
    }
  }
}

/// Bottom sheet for detailed sync status and controls
class SyncStatusBottomSheet extends StatelessWidget {
  const SyncStatusBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SyncStatusBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offlineService = OfflineSupportService();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          const Padding(
            padding: EdgeInsets.all(16),
            child: SyncStatusWidget(showDetails: true),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      offlineService.clearCache();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Cache'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      offlineService.manualSync();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                  ),
                ),
              ],
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
