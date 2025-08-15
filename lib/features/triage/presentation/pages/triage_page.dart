import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/triage_bloc.dart';
import '../bloc/triage_event.dart';
import '../bloc/triage_state.dart';
import '../widgets/symptom_input_widget.dart';
import '../../../dashboard/presentation/widgets/vitals_display_widget.dart';
import '../widgets/triage_result_widget.dart';
import '../widgets/trend_analysis_widget.dart';

class TriagePage extends StatelessWidget {
  const TriagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Triage Assessment'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TriageBloc>().add(const ResetTriageEvent());
            },
            tooltip: 'Reset Assessment',
          ),
        ],
      ),
      body: BlocBuilder<TriageBloc, TriageState>(
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 800;
              final padding = isWideScreen ? 24.0 : 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: isWideScreen
                    ? _buildWideScreenLayout(context, state)
                    : _buildNarrowScreenLayout(context, state),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWideScreenLayout(BuildContext context, TriageState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Header and input
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Emergency Triage Assessment',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-powered severity assessment with wearable data integration',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Symptom Input Section
              const SymptomInputWidget(),
            ],
          ),
        ),

        const SizedBox(width: 24),

        // Right column - Vitals and results
        Expanded(
          flex: 1,
          child: Column(
            children: [
              // Vitals Section
              const VitalsDisplayWidget(),

              const SizedBox(height: 16),

              // Trend Analysis Section
              const TrendAnalysisWidget(),

              const SizedBox(height: 16),

              // Results Section
              _buildResultsSection(context, state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowScreenLayout(BuildContext context, TriageState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(
                  Icons.medical_services,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Emergency Triage Assessment',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'AI-powered severity assessment with wearable data integration',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Vitals Section
        const VitalsDisplayWidget(),

        const SizedBox(height: 16),

        // Trend Analysis Section
        const TrendAnalysisWidget(),

        const SizedBox(height: 16),

        // Symptom Input Section
        const SymptomInputWidget(),

        const SizedBox(height: 16),

        // Results Section
        _buildResultsSection(context, state),

        const SizedBox(height: 24),

        // Disclaimer
        _buildDisclaimer(context),
      ],
    );
  }

  Widget _buildResultsSection(BuildContext context, TriageState state) {
    if (state is TriageLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing symptoms with AI...'),
              SizedBox(height: 8),
              Text(
                'Integrating wearable data for enhanced accuracy',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    } else if (state is TriageAssessmentComplete) {
      return TriageResultWidget(result: state.result);
    } else if (state is TriageError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                'Assessment Error',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  context.read<TriageBloc>().add(const ResetTriageEvent());
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This AI assessment is for informational purposes only and does not replace professional medical advice. In case of emergency, call 911 immediately.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
