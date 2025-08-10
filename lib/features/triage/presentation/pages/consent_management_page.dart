import 'package:flutter/material.dart';
import '../../../../shared/services/consent_service.dart';

/// Page for managing patient consent preferences and viewing history
class ConsentManagementPage extends StatefulWidget {
  final String patientId;

  const ConsentManagementPage({
    super.key,
    required this.patientId,
  });

  @override
  State<ConsentManagementPage> createState() => _ConsentManagementPageState();
}

class _ConsentManagementPageState extends State<ConsentManagementPage> {
  final ConsentService _consentService = ConsentService();
  List<ConsentRecord> _consentHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsentHistory();
  }

  Future<void> _loadConsentHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _consentService.getPatientConsentHistory(widget.patientId);
      setState(() {
        _consentHistory = history..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading consent history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consent Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConsentHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildConsentHistory(),
    );
  }

  Widget _buildConsentHistory() {
    if (_consentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Consent Records',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your consent decisions will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConsentHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPrivacyOverview(),
          const SizedBox(height: 24),
          Text(
            'Consent History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._consentHistory.map((record) => _buildConsentCard(record)),
        ],
      ),
    );
  }

  Widget _buildPrivacyOverview() {
    final activeConsents = _consentHistory
        .where((record) => record.consentGranted && DateTime.now().isBefore(record.expirationTime))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Privacy Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Active Consents',
                    activeConsents.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total Records',
                    _consentHistory.length.toString(),
                    Colors.blue,
                    Icons.history,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard(ConsentRecord record) {
    final isActive = record.consentGranted && DateTime.now().isBefore(record.expirationTime);
    final statusColor = record.consentGranted 
        ? (isActive ? Colors.green : Colors.orange)
        : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    record.consentGranted 
                        ? (isActive ? 'ACTIVE' : 'EXPIRED')
                        : 'DENIED',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(record.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Hospital ID: ${record.hospitalId}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (record.reason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${record.reason}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (record.dataScope.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Data Scope:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: record.dataScope.map((scope) => Chip(
                  label: Text(
                    scope.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                )).toList(),
              ),
            ],
            if (record.consentGranted && isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Expires: ${_formatDateTime(record.expirationTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _revokeConsent(record),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _revokeConsent(ConsentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Consent'),
        content: Text(
          'Are you sure you want to revoke consent for data sharing with ${record.hospitalId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _consentService.revokeConsent(
          patientId: widget.patientId,
          hospitalId: record.hospitalId,
          reason: 'Patient manually revoked consent',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Consent revoked successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConsentHistory();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error revoking consent: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}