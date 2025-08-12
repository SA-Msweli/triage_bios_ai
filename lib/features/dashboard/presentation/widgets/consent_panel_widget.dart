import 'package:flutter/material.dart';

/// Responsive consent management panel widget
class ConsentPanelWidget extends StatefulWidget {
  final String patientId;
  final String hospitalId;
  final String hospitalName;
  final Function(bool) onConsentDecision;

  const ConsentPanelWidget({
    super.key,
    required this.patientId,
    required this.hospitalId,
    required this.hospitalName,
    required this.onConsentDecision,
  });

  @override
  State<ConsentPanelWidget> createState() => _ConsentPanelWidgetState();
}

class _ConsentPanelWidgetState extends State<ConsentPanelWidget> {
  bool? _consentGranted;
  final List<String> _selectedDataTypes = [];
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _dataTypes = [
    {
      'key': 'vitals',
      'title': 'Vital Signs',
      'description':
          'Heart rate, blood pressure, temperature, oxygen saturation',
      'icon': Icons.favorite,
      'required': true,
    },
    {
      'key': 'symptoms',
      'title': 'Reported Symptoms',
      'description': 'Your symptom description and severity assessment',
      'icon': Icons.assignment,
      'required': true,
    },
    {
      'key': 'medical_history',
      'title': 'Medical History',
      'description': 'Previous conditions, medications, and allergies',
      'icon': Icons.history,
      'required': false,
    },
    {
      'key': 'emergency_contacts',
      'title': 'Emergency Contacts',
      'description': 'Contact information for family or caregivers',
      'icon': Icons.contact_phone,
      'required': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select required data types
    _selectedDataTypes.addAll(
      _dataTypes
          .where((dt) => dt['required'] == true)
          .map((dt) => dt['key'] as String),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Sharing Consent',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what information to share with ${widget.hospitalName} for your care.',
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
                          _buildHospitalInfo(),
                          const SizedBox(height: 24),
                          _buildDataSharingOptions(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildPrivacyInfo(),
                          const SizedBox(height: 24),
                          _buildConsentDecision(),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Narrow screen layout
                _buildHospitalInfo(),
                const SizedBox(height: 24),
                _buildDataSharingOptions(),
                const SizedBox(height: 24),
                _buildPrivacyInfo(),
                const SizedBox(height: 24),
                _buildConsentDecision(),
              ],

              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHospitalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.local_hospital,
                color: Colors.blue.shade700,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.hospitalName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Requesting access to your medical data for emergency care',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSharingOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data to Share',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ..._dataTypes.map((dataType) => _buildDataTypeOption(dataType)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTypeOption(Map<String, dynamic> dataType) {
    final isSelected = _selectedDataTypes.contains(dataType['key']);
    final isRequired = dataType['required'] as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.shade50 : null,
        ),
        child: CheckboxListTile(
          value: isSelected,
          onChanged: isRequired
              ? null
              : (value) {
                  setState(() {
                    if (value == true) {
                      _selectedDataTypes.add(dataType['key']);
                    } else {
                      _selectedDataTypes.remove(dataType['key']);
                    }
                  });
                },
          title: Row(
            children: [
              Icon(
                dataType['icon'] as IconData,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dataType['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue.shade700 : null,
                  ),
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(left: 28, top: 4),
            child: Text(
              dataType['description'] as String,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          activeColor: Colors.blue.shade600,
          controlAffinity: ListTileControlAffinity.trailing,
        ),
      ),
    );
  }

  Widget _buildPrivacyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Privacy is Protected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            '• Your consent is recorded securely on blockchain',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            '• You can revoke consent at any time',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            '• Only selected data is shared with the hospital',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            '• All data access is logged for audit purposes',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            '• Data is encrypted during transmission and storage',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentDecision() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Decision',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            RadioListTile<bool>(
              title: const Text('Grant Consent'),
              subtitle: const Text(
                'Share selected data with the hospital for better care',
              ),
              value: true,
              groupValue: _consentGranted,
              onChanged: (value) {
                setState(() {
                  _consentGranted = value;
                });
              },
              activeColor: Colors.green.shade600,
            ),

            RadioListTile<bool>(
              title: const Text('Deny Consent'),
              subtitle: const Text(
                'Do not share data (you can still receive care)',
              ),
              value: false,
              groupValue: _consentGranted,
              onChanged: (value) {
                setState(() {
                  _consentGranted = value;
                });
              },
              activeColor: Colors.red.shade600,
            ),

            if (_consentGranted == false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Without data sharing, hospital staff will need to collect this information manually, which may delay your care.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            // Go back to hospital selection
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _canProceed() && !_isProcessing ? _handleSubmit : null,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isProcessing ? 'Processing...' : 'Complete Triage'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            backgroundColor: _consentGranted == true
                ? Colors.green.shade600
                : null,
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    return _consentGranted != null;
  }

  Future<void> _handleSubmit() async {
    if (_consentGranted == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Simulate processing time
      await Future.delayed(const Duration(seconds: 2));

      // Call the callback with the consent decision
      widget.onConsentDecision(_consentGranted!);

      // Show completion dialog
      if (mounted) {
        _showCompletionDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing consent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Triage Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _consentGranted == true
                  ? 'Your consent has been recorded and your data will be shared securely with ${widget.hospitalName}.'
                  : 'Your decision has been recorded. You can still receive excellent care without data sharing.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Proceed to ${widget.hospitalName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '• Present this triage summary at reception',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    '• Your priority level has been communicated',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Could navigate to a summary page or close the portal
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}
