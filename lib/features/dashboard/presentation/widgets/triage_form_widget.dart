import 'package:flutter/material.dart';

/// Responsive triage form widget for symptom input
class TriageFormWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;
  final VoidCallback onNext;

  const TriageFormWidget({
    super.key,
    required this.onDataChanged,
    required this.onNext,
  });

  @override
  State<TriageFormWidget> createState() => _TriageFormWidgetState();
}

class _TriageFormWidgetState extends State<TriageFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _durationController = TextEditingController();

  String _selectedSeverity = 'moderate';
  final List<String> _selectedSymptoms = [];

  final List<String> _commonSymptoms = [
    'Chest pain',
    'Shortness of breath',
    'Severe headache',
    'Abdominal pain',
    'Nausea/Vomiting',
    'Fever',
    'Dizziness',
    'Fatigue',
    'Cough',
    'Back pain',
  ];

  @override
  void dispose() {
    _symptomsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Describe Your Symptoms',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please provide detailed information about your current symptoms.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                if (isWideScreen) ...[
                  // Wide screen layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildQuickSymptomSelection(),
                            const SizedBox(height: 24),
                            _buildSymptomDescription(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildSymptomDuration(),
                            const SizedBox(height: 24),
                            _buildSeverityAssessment(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Narrow screen layout
                  _buildQuickSymptomSelection(),
                  const SizedBox(height: 24),
                  _buildSymptomDescription(),
                  const SizedBox(height: 24),
                  _buildSymptomDuration(),
                  const SizedBox(height: 24),
                  _buildSeverityAssessment(),
                ],

                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickSymptomSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Symptoms',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Select any symptoms you are experiencing:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _commonSymptoms.map((symptom) {
            final isSelected = _selectedSymptoms.contains(symptom);
            return FilterChip(
              label: Text(symptom),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSymptoms.add(symptom);
                  } else {
                    _selectedSymptoms.remove(symptom);
                  }
                });
                _updateData();
              },
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue.shade700,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSymptomDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Description',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _symptomsController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Please describe your symptoms in detail, including when they started, what makes them better or worse, and any other relevant information...',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if ((value?.isEmpty ?? true) && _selectedSymptoms.isEmpty) {
              return 'Please describe your symptoms or select from common symptoms above';
            }
            return null;
          },
          onChanged: (_) => _updateData(),
        ),
      ],
    );
  }

  Widget _buildSymptomDuration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How long have you been experiencing these symptoms?',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _durationController,
          decoration: const InputDecoration(
            hintText: 'e.g., 2 hours, 3 days, 1 week',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.schedule),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please specify how long you have had these symptoms';
            }
            return null;
          },
          onChanged: (_) => _updateData(),
        ),
      ],
    );
  }

  Widget _buildSeverityAssessment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you rate your current pain/discomfort level?',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Severity scale
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mild', style: TextStyle(color: Colors.green.shade700)),
                  Text(
                    'Moderate',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  Text('Severe', style: TextStyle(color: Colors.red.shade700)),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Mild'),
                    subtitle: const Text('1-3/10'),
                    value: 'mild',
                    groupValue: _selectedSeverity,
                    onChanged: (value) {
                      setState(() {
                        _selectedSeverity = value!;
                      });
                      _updateData();
                    },
                    activeColor: Colors.green.shade600,
                  ),
                  RadioListTile<String>(
                    title: const Text('Moderate'),
                    subtitle: const Text('4-6/10'),
                    value: 'moderate',
                    groupValue: _selectedSeverity,
                    onChanged: (value) {
                      setState(() {
                        _selectedSeverity = value!;
                      });
                      _updateData();
                    },
                    activeColor: Colors.orange.shade600,
                  ),
                  RadioListTile<String>(
                    title: const Text('Severe'),
                    subtitle: const Text('7-10/10'),
                    value: 'severe',
                    groupValue: _selectedSeverity,
                    onChanged: (value) {
                      setState(() {
                        _selectedSeverity = value!;
                      });
                      _updateData();
                    },
                    activeColor: Colors.red.shade600,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Emergency warning
        if (_selectedSeverity == 'severe') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Severe Symptoms Detected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'If this is a life-threatening emergency, please call 911 immediately.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _canProceed() ? widget.onNext : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue to Vitals'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    return _selectedSymptoms.isNotEmpty || _symptomsController.text.isNotEmpty;
  }

  void _updateData() {
    final severityScore = _getSeverityScore();

    widget.onDataChanged({
      'symptoms': _symptomsController.text,
      'selectedSymptoms': _selectedSymptoms,
      'duration': _durationController.text,
      'severity': _selectedSeverity,
      'severityScore': severityScore,
    });
  }

  double _getSeverityScore() {
    switch (_selectedSeverity) {
      case 'mild':
        return 2.0 + (_selectedSymptoms.length * 0.5);
      case 'moderate':
        return 5.0 + (_selectedSymptoms.length * 0.5);
      case 'severe':
        return 8.0 + (_selectedSymptoms.length * 0.3);
      default:
        return 5.0;
    }
  }
}
