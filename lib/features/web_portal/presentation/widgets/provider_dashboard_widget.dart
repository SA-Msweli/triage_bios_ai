import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';

class ProviderDashboardWidget extends StatelessWidget {
  const ProviderDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Text(
            'Healthcare Provider Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Monitor patient queue and hospital capacity',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),

          // Hospital stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Patients in Queue',
                  '12',
                  Icons.queue,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Available Beds',
                  '23',
                  Icons.bed,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Critical Cases',
                  '3',
                  Icons.emergency,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Avg Wait Time',
                  '35m',
                  Icons.access_time,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient queue
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Queue',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildQueueItem(
                          context,
                          'Sarah Johnson',
                          'Chest pain, difficulty breathing',
                          '8.5',
                          'CRITICAL',
                          Colors.red,
                          '5m ago',
                        ),
                        const Divider(),
                        _buildQueueItem(
                          context,
                          'Michael Chen',
                          'Severe headache, nausea',
                          '6.2',
                          'URGENT',
                          Colors.orange,
                          '12m ago',
                        ),
                        const Divider(),
                        _buildQueueItem(
                          context,
                          'Emily Rodriguez',
                          'Abdominal pain, mild fever',
                          '4.8',
                          'STANDARD',
                          Theme.of(context).colorScheme.primary,
                          '28m ago',
                        ),
                        const Divider(),
                        _buildQueueItem(
                          context,
                          'Robert Kim',
                          'Minor cut on hand',
                          '3.1',
                          'NON_URGENT',
                          Colors.green,
                          '35m ago',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Capacity overview
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capacity Overview',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            _buildCapacityItem('Emergency Beds', 12, 15, Colors.green),
                            const SizedBox(height: 8),
                            _buildCapacityItem('ICU Beds', 6, 8, Colors.orange),
                            const SizedBox(height: 8),
                            _buildCapacityItem('General Beds', 145, 200, Colors.blue),
                            const SizedBox(height: 8),
                            _buildCapacityItem('Staff on Duty', 85, 100, Colors.purple),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Activity',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            _buildActivityItem(
                              context,
                              'New patient arrived',
                              'Sarah Johnson - Critical',
                              '5 min ago',
                              Icons.person_add,
                              Colors.red,
                            ),
                            _buildActivityItem(
                              context,
                              'Patient discharged',
                              'John Doe - Recovered',
                              '12 min ago',
                              Icons.check_circle,
                              Colors.green,
                            ),
                            _buildActivityItem(
                              context,
                              'Bed available',
                              'Room 204 - ICU',
                              '18 min ago',
                              Icons.bed,
                              Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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

  Widget _buildQueueItem(
    BuildContext context,
    String name,
    String symptoms,
    String score,
    String urgency,
    Color urgencyColor,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: urgencyColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        urgency,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  symptoms,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityItem(String label, int current, int total, Color color) {
    final percentage = current / total;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '$current/$total',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}