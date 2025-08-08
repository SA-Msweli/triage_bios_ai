import 'package:flutter/material.dart';
import '../../domain/entities/hospital_capacity.dart';

class CapacityOverviewWidget extends StatelessWidget {
  final HospitalCapacity capacity;

  const CapacityOverviewWidget({super.key, required this.capacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Capacity Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Overall capacity indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: capacity.capacityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: capacity.capacityColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      capacity.isAtCapacity
                          ? Icons.warning
                          : capacity.isNearCapacity
                          ? Icons.info
                          : Icons.check_circle,
                      color: capacity.capacityColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      capacity.capacityStatus,
                      style: TextStyle(
                        color: capacity.capacityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Capacity bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bed Occupancy',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${capacity.capacityPercentage.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: capacity.occupancyRate,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        capacity.capacityColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Capacity metrics grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _buildMetricCard(
                context,
                'Available Beds',
                '${capacity.availableBeds}',
                '/ ${capacity.totalBeds}',
                Icons.bed,
                capacity.availableBeds < 10 ? Colors.red : Colors.green,
              ),
              _buildMetricCard(
                context,
                'ICU Beds',
                '${capacity.icuBeds}',
                'available',
                Icons.local_hospital,
                capacity.icuBeds < 5 ? Colors.orange : Colors.blue,
              ),
              _buildMetricCard(
                context,
                'ER Beds',
                '${capacity.emergencyBeds}',
                'available',
                Icons.emergency,
                capacity.emergencyBeds < 5 ? Colors.red : Colors.green,
              ),
              _buildMetricCard(
                context,
                'Staff on Duty',
                '${capacity.staffOnDuty}',
                'active',
                Icons.people,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Queue metrics
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patients in Queue',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${capacity.patientsInQueue}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: capacity.patientsInQueue > 10
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Average Wait Time',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${capacity.averageWaitTime.toStringAsFixed(0)} min',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: capacity.averageWaitTime > 60
                            ? Colors.red
                            : capacity.averageWaitTime > 30
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Last updated
          Row(
            children: [
              Icon(
                Icons.update,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Updated ${_formatLastUpdated(capacity.lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (!capacity.isDataFresh) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning, size: 14, color: Colors.orange),
                const SizedBox(width: 2),
                Text(
                  'Stale',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatLastUpdated(DateTime lastUpdated) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}';
    }
  }
}
