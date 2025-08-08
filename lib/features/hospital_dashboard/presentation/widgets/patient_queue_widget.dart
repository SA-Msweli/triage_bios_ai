import 'package:flutter/material.dart';
import '../../domain/entities/patient_queue_item.dart';

class PatientQueueWidget extends StatelessWidget {
  final List<PatientQueueItem> patientQueue;
  final Function(PatientQueueItem) onPatientSelected;
  final Function(PatientQueueItem) onPatientCalled;

  const PatientQueueWidget({
    super.key,
    required this.patientQueue,
    required this.onPatientSelected,
    required this.onPatientCalled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Patient Queue (${patientQueue.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Last updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Queue header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40), // Priority indicator space
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Patient',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Symptoms',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Vitals',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Wait Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 100), // Actions space
              ],
            ),
          ),

          // Patient list
          Expanded(
            child: patientQueue.isEmpty
                ? _buildEmptyQueue(context)
                : ListView.builder(
                    itemCount: patientQueue.length,
                    itemBuilder: (context, index) {
                      final patient = patientQueue[index];
                      return _buildPatientRow(context, patient, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQueue(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Patients in Queue',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All patients have been seen or the queue is empty',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientRow(
    BuildContext context,
    PatientQueueItem patient,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: InkWell(
        onTap: () => onPatientSelected(patient),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Priority indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: patient.urgencyColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Patient info
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: patient.urgencyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            patient.urgencyLevel,
                            style: TextStyle(
                              color: patient.urgencyColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Age ${patient.age} • Score: ${patient.severityScore.toStringAsFixed(1)}/10',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Arrived: ${patient.arrivalTimeDisplay}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Symptoms
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.symptoms,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.watch,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patient.deviceSource,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Vitals
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVitalSign(
                      context,
                      'HR: ${patient.vitals['heartRate']} bpm',
                      patient.vitals['heartRate'] > 100 ||
                          patient.vitals['heartRate'] < 60,
                    ),
                    _buildVitalSign(
                      context,
                      'SpO2: ${patient.vitals['oxygenSaturation']?.toStringAsFixed(1)}%',
                      (patient.vitals['oxygenSaturation'] as double?) != null &&
                          patient.vitals['oxygenSaturation'] < 95.0,
                    ),
                    _buildVitalSign(
                      context,
                      'BP: ${patient.vitals['bloodPressure']}',
                      false, // Simplified for demo
                    ),
                  ],
                ),
              ),

              // Wait time
              Expanded(
                child: Column(
                  children: [
                    Text(
                      patient.waitTimeDisplay,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: patient.estimatedWaitTime == 0
                            ? Colors.red
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (patient.estimatedWaitTime == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Actions
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => onPatientSelected(patient),
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'View Details',
                      iconSize: 20,
                    ),
                    IconButton(
                      onPressed: () => onPatientCalled(patient),
                      icon: const Icon(Icons.call),
                      tooltip: 'Call Patient',
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalSign(BuildContext context, String text, bool isAbnormal) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isAbnormal
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isAbnormal ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
