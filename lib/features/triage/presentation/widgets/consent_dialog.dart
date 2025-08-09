import 'package:flutter/material.dart';
import '../../../../shared/services/consent_service.dart';

/// Dialog for requesting patient consent for data sharing
class ConsentDialog extends StatefulWidget {
  final String patientId;
  final String hospitalId;
  final String hospitalName;
  final List<String> requestedData;
  final Function(bool consentGranted) onConsentDecision;

  const ConsentDialog({
    super.key,
    required this.patientId,
    required this.hospitalId,
    required this.hospitalName,
    required this.requestedData,
    required this.onConsentDecision,
  });

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  final ConsentService _consentService = ConsentService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.security, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Data Sharing Consent'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.hospitalName} is requesting access to your medical data to provide better care.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Requested Data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...widget.requestedData.map((dataType) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(_formatDataType(dataType)),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
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
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy Protection',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Your consent is recorded securely\n'
                    '• You can revoke consent at any time\n'
                    '• Only minimum necessary data is shared\n'
                    '• All access is logged for audit purposes',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => _handleConsentDecision(false),
          child: const Text('Deny'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : () => _handleConsentDecision(true),
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Grant Consent'),
        ),
      ],
    );
  }

  Future<void> _handleConsentDecision(bool consentGranted) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _consentService.recordConsent(
        patientId: widget.patientId,
        hospitalId: widget.hospitalId,
        dataScope: widget.requestedData,
        consentGranted: consentGranted,
        reason: consentGranted 
            ? 'Patient granted consent for emergency care'
            : 'Patient denied consent',
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onConsentDecision(consentGranted);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              consentGranted 
                  ? 'Consent granted. Your data will be shared securely.'
                  : 'Consent denied. You can still receive care without data sharing.',
            ),
            backgroundColor: consentGranted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording consent: $e'),
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

  String _formatDataType(String dataType) {
    switch (dataType.toLowerCase()) {
      case 'vitals':
        return 'Vital Signs (Heart Rate, Blood Pressure, etc.)';
      case 'symptoms':
        return 'Reported Symptoms';
      case 'medical_history':
        return 'Medical History';
      case 'medications':
        return 'Current Medications';
      case 'allergies':
        return 'Known Allergies';
      case 'emergency_contacts':
        return 'Emergency Contact Information';
      default:
        return dataType.replaceAll('_', ' ').toUpperCase();
    }
  }
}

/// Helper function to show consent dialog
Future<bool?> showConsentDialog({
  required BuildContext context,
  required String patientId,
  required String hospitalId,
  required String hospitalName,
  required List<String> requestedData,
}) async {
  bool? consentGranted;
  
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConsentDialog(
      patientId: patientId,
      hospitalId: hospitalId,
      hospitalName: hospitalName,
      requestedData: requestedData,
      onConsentDecision: (granted) {
        consentGranted = granted;
      },
    ),
  );
  
  return consentGranted;
}