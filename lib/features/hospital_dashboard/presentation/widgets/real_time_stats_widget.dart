import 'package:flutter/material.dart';
import '../../domain/entities/hospital_capacity.dart';

class RealTimeStatsWidget extends StatelessWidget {
  final HospitalCapacity capacity;

  const RealTimeStatsWidget({super.key, required this.capacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Stats
          Expanded(
            child: Row(
              children: [
                _buildStatItem(
                  context,
                  'Total Beds',
                  '${capacity.totalBeds}',
                  Icons.bed,
                ),

                const SizedBox(width: 32),

                _buildStatItem(
                  context,
                  'Available',
                  '${capacity.availableBeds}',
                  Icons.check_circle,
                  color: capacity.availableBeds < 10
                      ? Colors.red
                      : Colors.green,
                ),

                const SizedBox(width: 32),

                _buildStatItem(
                  context,
                  'Occupancy',
                  '${capacity.capacityPercentage.toStringAsFixed(0)}%',
                  Icons.pie_chart,
                  color: capacity.capacityColor,
                ),

                const SizedBox(width: 32),

                _buildStatItem(
                  context,
                  'Queue',
                  '${capacity.patientsInQueue}',
                  Icons.queue,
                  color: capacity.patientsInQueue > 10 ? Colors.red : null,
                ),

                const SizedBox(width: 32),

                _buildStatItem(
                  context,
                  'Avg Wait',
                  '${capacity.averageWaitTime.toStringAsFixed(0)}m',
                  Icons.access_time,
                  color: capacity.averageWaitTime > 60
                      ? Colors.red
                      : capacity.averageWaitTime > 30
                      ? Colors.orange
                      : null,
                ),

                const SizedBox(width: 32),

                _buildStatItem(
                  context,
                  'Staff',
                  '${capacity.staffOnDuty}',
                  Icons.people,
                ),
              ],
            ),
          ),

          // System status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: capacity.isDataFresh ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  capacity.isDataFresh ? Icons.check : Icons.warning,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  capacity.isDataFresh ? 'System Online' : 'Data Stale',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
