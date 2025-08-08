import 'package:flutter/material.dart';
import '../../domain/entities/triage_result.dart';

class TriageResultWidget extends StatelessWidget {
  final TriageResult result;

  const TriageResultWidget({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with severity score
            Row(
              children: [
                Icon(
                  _getSeverityIcon(),
                  color: _getSeverityColor(context),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Triage Assessment Complete',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Severity Score: ${result.severityScore.toStringAsFixed(1)}/10',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getSeverityColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    result.urgencyLevelString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Confidence interval
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Confidence: ${result.confidenceLower.toStringAsFixed(1)} - ${result.confidenceUpper.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // AI Explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI Analysis',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.explanation,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Vitals contribution (if available)
            if (result.vitals != null && result.vitalsContribution != null && result.vitalsContribution! > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Wearable Data Impact (+${result.vitalsContribution!.toStringAsFixed(1)} points)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.vitalsExplanation,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Key symptoms
            if (result.keySymptoms.isNotEmpty) ...[
              _buildSection(
                context,
                'Key Symptoms',
                Icons.medical_information,
                result.keySymptoms,
              ),
              const SizedBox(height: 12),
            ],
            
            // Concerning findings
            if (result.concerningFindings.isNotEmpty) ...[
              _buildSection(
                context,
                'Concerning Findings',
                Icons.warning,
                result.concerningFindings,
                isWarning: true,
              ),
              const SizedBox(height: 12),
            ],
            
            // Recommended actions
            _buildSection(
              context,
              'Recommended Actions',
              Icons.checklist,
              result.recommendedActions,
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            if (result.isCritical) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: Implement emergency call
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Emergency services integration coming soon'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  icon: const Icon(Icons.emergency),
                  label: const Text('Call 911 Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement hospital routing
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hospital routing coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.local_hospital),
                label: const Text('Find Nearby Hospitals'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Footer info
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Assessment ID: ${result.assessmentId} • Model: ${result.aiModelVersion}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items, {
    bool isWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isWarning 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isWarning ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isWarning ? Theme.of(context).colorScheme.error : null,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isWarning ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  IconData _getSeverityIcon() {
    switch (result.urgencyLevel) {
      case UrgencyLevel.critical:
        return Icons.emergency;
      case UrgencyLevel.urgent:
        return Icons.priority_high;
      case UrgencyLevel.standard:
        return Icons.medical_services;
      case UrgencyLevel.nonUrgent:
        return Icons.health_and_safety;
    }
  }

  Color _getSeverityColor(BuildContext context) {
    switch (result.urgencyLevel) {
      case UrgencyLevel.critical:
        return Colors.red;
      case UrgencyLevel.urgent:
        return Colors.orange;
      case UrgencyLevel.standard:
        return Theme.of(context).colorScheme.primary;
      case UrgencyLevel.nonUrgent:
        return Colors.green;
    }
  }
}