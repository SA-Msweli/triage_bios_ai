import 'package:flutter/material.dart';
import '../../domain/entities/patient_queue_item.dart';

class EmergencyAlertsWidget extends StatelessWidget {
  final List<PatientQueueItem> patientQueue;

  const EmergencyAlertsWidget({super.key, required this.patientQueue});

  @override
  Widget build(BuildContext context) {
    final criticalPatients = patientQueue.where((p) => p.isCritical).toList();
    final urgentPatients = patientQueue
        .where((p) => p.isUrgent && !p.isCritical)
        .toList();

    if (criticalPatients.isEmpty && urgentPatients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Critical alerts
          if (criticalPatients.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emergency,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CRITICAL PATIENTS (${criticalPatients.length})',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'IMMEDIATE ATTENTION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: criticalPatients
                        .map(
                          (patient) =>
                              _buildPatientChip(context, patient, Colors.red),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

          if (criticalPatients.isNotEmpty && urgentPatients.isNotEmpty)
            const SizedBox(height: 8),

          // Urgent alerts
          if (urgentPatients.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'URGENT PATIENTS (${urgentPatients.length})',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'PRIORITY CARE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: urgentPatients
                        .map(
                          (patient) => _buildPatientChip(
                            context,
                            patient,
                            Colors.orange,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientChip(
    BuildContext context,
    PatientQueueItem patient,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            patient.name,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${patient.severityScore.toStringAsFixed(1)})',
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
          ),
          if (patient.hasAbnormalVitals) ...[
            const SizedBox(width: 4),
            Icon(Icons.favorite, color: color.withValues(alpha: 0.8), size: 12),
          ],
        ],
      ),
    );
  }
}
