import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/patient_vitals.dart';
import '../bloc/triage_bloc.dart';
import '../bloc/triage_event.dart';
import '../bloc/triage_state.dart';

class VitalsDisplayWidget extends StatelessWidget {
  const VitalsDisplayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TriageBloc, TriageState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Wearable Vitals Data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (state is VitalsLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          context.read<TriageBloc>().add(
                            const LoadVitalsEvent(),
                          );
                        },
                        tooltip: 'Refresh Vitals',
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (state is VitalsLoaded)
                  _buildVitalsData(context, state.vitals)
                else if (state is VitalsError)
                  _buildVitalsError(
                    context,
                    state.message,
                    state.hasPermissions,
                  )
                else if (state is VitalsLoading)
                  _buildVitalsLoading(context)
                else if (state is HealthPermissionsState)
                  _buildPermissionsState(context, state)
                else
                  _buildVitalsInitial(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVitalsData(BuildContext context, PatientVitals vitals) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Connected to ${vitals.deviceSource ?? 'Health App'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (vitals.dataQuality != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getQualityColor(context, vitals.dataQuality!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Quality: ${(vitals.dataQuality! * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Vitals grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            if (vitals.heartRate != null)
              _VitalCard(
                icon: Icons.favorite,
                label: 'Heart Rate',
                value: '${vitals.heartRate} bpm',
                isAbnormal: vitals.heartRate! > 100 || vitals.heartRate! < 60,
              ),
            if (vitals.oxygenSaturation != null)
              _VitalCard(
                icon: Icons.air,
                label: 'SpO2',
                value: '${vitals.oxygenSaturation?.toStringAsFixed(1)}%',
                isAbnormal: vitals.oxygenSaturation! < 95,
              ),
            if (vitals.bloodPressure != null)
              _VitalCard(
                icon: Icons.monitor_heart,
                label: 'Blood Pressure',
                value: vitals.bloodPressure!,
                isAbnormal: _isBloodPressureAbnormal(vitals.bloodPressure!),
              ),
            if (vitals.temperature != null)
              _VitalCard(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: '${vitals.temperature?.toStringAsFixed(1)}°F',
                isAbnormal: vitals.temperature! > 99.5,
              ),
          ],
        ),

        if (vitals.hasCriticalVitals) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Critical vitals detected - this will increase your severity score',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Text(
          'Last updated: ${_formatTimestamp(vitals.timestamp)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsError(
    BuildContext context,
    String message,
    bool hasPermissions,
  ) {
    return Column(
      children: [
        Icon(
          hasPermissions ? Icons.error_outline : Icons.security,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          hasPermissions
              ? 'No Vitals Data Available'
              : 'Health Access Required',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (!hasPermissions)
          FilledButton.icon(
            onPressed: () {
              context.read<TriageBloc>().add(
                const RequestHealthPermissionsEvent(),
              );
            },
            icon: const Icon(Icons.security),
            label: const Text('Grant Health Access'),
          )
        else
          OutlinedButton.icon(
            onPressed: () {
              context.read<TriageBloc>().add(const LoadVitalsEvent());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
      ],
    );
  }

  Widget _buildVitalsLoading(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 8),
        Text('Loading vitals from wearable devices...'),
      ],
    );
  }

  Widget _buildPermissionsState(
    BuildContext context,
    HealthPermissionsState state,
  ) {
    if (state.isRequesting) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text('Requesting health data permissions...'),
        ],
      );
    }

    return Column(
      children: [
        Icon(
          state.hasPermissions ? Icons.check_circle : Icons.security,
          color: state.hasPermissions
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          state.hasPermissions
              ? 'Health Access Granted'
              : 'Health Access Required',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        if (state.hasPermissions)
          FilledButton.icon(
            onPressed: () {
              context.read<TriageBloc>().add(const LoadVitalsEvent());
            },
            icon: const Icon(Icons.favorite),
            label: const Text('Load Vitals Data'),
          )
        else
          FilledButton.icon(
            onPressed: () {
              context.read<TriageBloc>().add(
                const RequestHealthPermissionsEvent(),
              );
            },
            icon: const Icon(Icons.security),
            label: const Text('Grant Health Access'),
          ),
      ],
    );
  }

  Widget _buildVitalsInitial(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.watch,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          'Connect Wearable Device',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Connect your Apple Watch, Fitbit, or other health device to enhance triage accuracy',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            context.read<TriageBloc>().add(const CheckHealthPermissionsEvent());
          },
          icon: const Icon(Icons.link),
          label: const Text('Connect Device'),
        ),
      ],
    );
  }

  Color _getQualityColor(BuildContext context, double quality) {
    if (quality >= 0.8) return Colors.green;
    if (quality >= 0.6) return Colors.orange;
    return Colors.red;
  }

  bool _isBloodPressureAbnormal(String bp) {
    final parts = bp.split('/');
    if (parts.length != 2) return false;

    final systolic = int.tryParse(parts[0]);
    final diastolic = int.tryParse(parts[1]);

    if (systolic == null || diastolic == null) return false;

    return systolic > 140 || diastolic > 90 || systolic < 90 || diastolic < 60;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isAbnormal;

  const _VitalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isAbnormal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isAbnormal
            ? Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.3)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: isAbnormal
            ? Border.all(color: Theme.of(context).colorScheme.error, width: 1)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isAbnormal
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isAbnormal ? Theme.of(context).colorScheme.error : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
