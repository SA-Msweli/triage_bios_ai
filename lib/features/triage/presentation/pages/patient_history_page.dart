import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/patient_history_widget.dart';
import '../../domain/repositories/triage_repository.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';

/// Page for viewing patient triage history with filtering and search capabilities
class PatientHistoryPage extends StatefulWidget {
  final String? patientId;

  const PatientHistoryPage({super.key, this.patientId});

  @override
  State<PatientHistoryPage> createState() => _PatientHistoryPageState();
}

class _PatientHistoryPageState extends State<PatientHistoryPage> {
  final TextEditingController _patientIdController = TextEditingController();
  String? _currentPatientId;

  @override
  void initState() {
    super.initState();
    _currentPatientId = widget.patientId;
    if (_currentPatientId != null) {
      _patientIdController.text = _currentPatientId!;
    }
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final triageRepository = context.read<TriageRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient History'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showPatientSearch,
            tooltip: 'Search Patient',
          ),
        ],
      ),
      body: Padding(
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        child: Column(
          children: [
            // Patient ID input section
            if (_currentPatientId == null) ...[
              _buildPatientIdInput(context, isMobile),
              const SizedBox(height: 16),
            ] else ...[
              _buildCurrentPatientHeader(context, isMobile),
              const SizedBox(height: 16),
            ],

            // History widget
            if (_currentPatientId != null)
              Expanded(
                child: PatientHistoryWidget(
                  patientId: _currentPatientId!,
                  triageRepository: triageRepository,
                  showRealTimeUpdates: true,
                ),
              )
            else
              Expanded(child: _buildEmptyState(context, isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientIdInput(BuildContext context, bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Patient ID',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _patientIdController,
                    decoration: const InputDecoration(
                      hintText: 'Patient ID (e.g., patient_123)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onSubmitted: (value) => _loadPatientHistory(value),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      _loadPatientHistory(_patientIdController.text),
                  icon: const Icon(Icons.search),
                  label: Text(isMobile ? 'Load' : 'Load History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPatientHeader(BuildContext context, bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
              size: isMobile ? 20 : 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Patient ID: $_currentPatientId',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentPatientId = null;
                  _patientIdController.clear();
                });
              },
              icon: const Icon(Icons.change_circle),
              label: Text(isMobile ? 'Change' : 'Change Patient'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: isMobile ? 64 : 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Patient History',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a patient ID to view their triage history',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showPatientSearch,
            icon: const Icon(Icons.search),
            label: const Text('Search Patient'),
          ),
        ],
      ),
    );
  }

  void _loadPatientHistory(String patientId) {
    if (patientId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid patient ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _currentPatientId = patientId.trim();
    });
  }

  void _showPatientSearch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _patientIdController,
              decoration: const InputDecoration(
                hintText: 'Enter Patient ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
              autofocus: true,
              onSubmitted: (value) {
                Navigator.of(context).pop();
                _loadPatientHistory(value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Example patient IDs for testing:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['patient_001', 'patient_002', 'patient_003']
                  .map(
                    (id) => ActionChip(
                      label: Text(id),
                      onPressed: () {
                        _patientIdController.text = id;
                        Navigator.of(context).pop();
                        _loadPatientHistory(id);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadPatientHistory(_patientIdController.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}
