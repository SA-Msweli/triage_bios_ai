import 'package:flutter/material.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/health_service.dart';
import '../../../../shared/services/vitals_trend_service.dart';
import '../../../../shared/services/multi_platform_health_service.dart';
import '../../../../shared/services/watsonx_service.dart';
import '../../../../features/triage/domain/entities/patient_vitals.dart';
import '../../../../features/auth/domain/entities/patient_consent.dart';

class PatientDashboardWidget extends StatefulWidget {
  const PatientDashboardWidget({super.key});

  @override
  State<PatientDashboardWidget> createState() => _PatientDashboardWidgetState();
}

class _PatientDashboardWidgetState extends State<PatientDashboardWidget> {
  final AuthService _authService = AuthService();
  final HealthService _healthService = HealthService();
  final VitalsTrendService _trendService = VitalsTrendService();
  final MultiPlatformHealthService _multiPlatformHealth =
      MultiPlatformHealthService();
  final WatsonxService _watsonxService = WatsonxService();

  PatientVitals? _latestVitals;
  VitalsTrendAnalysis? _trendAnalysis;
  List<String> _connectedDevices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize WatsonX service for health insights (Milestone 1 & 2 requirement)
      _watsonxService.initialize(
        apiKey: 'demo_api_key',
        projectId: 'demo_project_id',
      );

      // Load latest vitals from multiple platforms (Milestone 2 requirement)
      _latestVitals = await _multiPlatformHealth.getLatestVitals();

      // Store vitals for trend analysis
      if (_latestVitals != null) {
        await _trendService.storeVitalsReading(_latestVitals!);
      }

      // Load trend analysis (Milestone 2 requirement)
      _trendAnalysis = await _trendService.analyzeTrends(hoursBack: 24);

      // Get connected devices status (Milestone 2 requirement)
      final devices = await _multiPlatformHealth.getConnectedDevices();
      _connectedDevices = devices.map((device) => device.name).toList();
    } catch (e) {
      // Handle error silently for demo
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${user.name.split(' ').first}!',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Your health dashboard is ready',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (user.isGuest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Guest Mode',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  'Start Triage',
                  'Get AI-powered health assessment',
                  Icons.medical_services,
                  Theme.of(context).colorScheme.primary,
                  () => _navigateToTriage(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  'Find Hospitals',
                  'Locate nearby emergency facilities',
                  Icons.local_hospital,
                  Theme.of(context).colorScheme.secondary,
                  () => _navigateToHospitals(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  'Voice Triage',
                  'Use AI voice input for symptoms',
                  Icons.mic,
                  Colors.purple,
                  () => _startVoiceTriage(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Main content grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Current vitals card
                    _buildVitalsCard(),
                    const SizedBox(height: 16),
                    // Recent assessments card
                    _buildRecentAssessmentsCard(),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right column
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Health trends card
                    _buildHealthTrendsCard(),
                    const SizedBox(height: 16),
                    // Quick tips card
                    _buildQuickTipsCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                  'Current Vitals',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_latestVitals != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildVitalItem(
                      'Heart Rate',
                      '${_latestVitals!.heartRate ?? '--'} bpm',
                      Icons.favorite,
                      _isVitalNormal(
                        'heartRate',
                        _latestVitals!.heartRate?.toDouble(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildVitalItem(
                      'SpO2',
                      '${_latestVitals!.oxygenSaturation?.toStringAsFixed(1) ?? '--'}%',
                      Icons.air,
                      _isVitalNormal(
                        'oxygenSaturation',
                        _latestVitals!.oxygenSaturation,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildVitalItem(
                      'Blood Pressure',
                      _latestVitals!.bloodPressure ?? '--',
                      Icons.monitor_heart,
                      _isBloodPressureNormal(_latestVitals!.bloodPressure),
                    ),
                  ),
                  Expanded(
                    child: _buildVitalItem(
                      'Temperature',
                      '${_latestVitals!.temperature?.toStringAsFixed(1) ?? '--'}°F',
                      Icons.thermostat,
                      _isVitalNormal('temperature', _latestVitals!.temperature),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.watch,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'From ${_latestVitals!.deviceSource ?? 'Health App'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimestamp(_latestVitals!.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.devices, color: Colors.green.shade700, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_connectedDevices.length} devices connected (Milestone 2)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.watch,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No vitals data available',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect your wearable device to track vitals',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildVitalItem(
    String label,
    String value,
    IconData icon,
    bool isNormal,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNormal
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: isNormal
            ? null
            : Border.all(color: Theme.of(context).colorScheme.error, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isNormal
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isNormal ? null : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAssessmentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Assessments',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 16),

            // Placeholder for recent assessments
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent assessments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start your first triage assessment to see results here',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTrendsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Health Trends',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_trendAnalysis != null && _trendAnalysis!.dataPoints > 0) ...[
              _buildTrendItem(
                'Overall Stability',
                _getStabilityText(_trendAnalysis!.overallStability),
                _getStabilityColor(_trendAnalysis!.overallStability),
              ),
              const SizedBox(height: 8),
              _buildTrendItem(
                'Deterioration Risk',
                _getDeteriorationText(_trendAnalysis!.deteriorationRisk),
                _getDeteriorationColor(_trendAnalysis!.deteriorationRisk),
              ),
              const SizedBox(height: 12),
              Text(
                '${_trendAnalysis!.dataPoints} readings over ${_trendAnalysis!.timeSpanHours}h',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No trend data yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Continue monitoring to see trends',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildTrendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTipsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Health Tips',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTipItem(
              'Monitor your vitals regularly for better health insights',
            ),
            _buildTipItem('Keep emergency contacts updated in your profile'),
            _buildTipItem('Use voice input for faster symptom reporting'),
            _buildTipItem(
              'Connect multiple wearable devices for comprehensive tracking',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tip, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _isVitalNormal(String type, double? value) {
    if (value == null) return true;

    switch (type) {
      case 'heartRate':
        return value >= 60 && value <= 100;
      case 'oxygenSaturation':
        return value >= 95;
      case 'temperature':
        return value >= 97.0 && value <= 99.5;
      default:
        return true;
    }
  }

  bool _isBloodPressureNormal(String? bp) {
    if (bp == null) return true;

    final parts = bp.split('/');
    if (parts.length != 2) return true;

    final systolic = int.tryParse(parts[0]);
    final diastolic = int.tryParse(parts[1]);

    if (systolic == null || diastolic == null) return true;

    return systolic < 140 &&
        diastolic < 90 &&
        systolic >= 90 &&
        diastolic >= 60;
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

  String _getStabilityText(StabilityLevel stability) {
    switch (stability) {
      case StabilityLevel.stable:
        return 'Stable';
      case StabilityLevel.mildlyUnstable:
        return 'Mild Variation';
      case StabilityLevel.concerning:
        return 'Concerning';
      case StabilityLevel.unstable:
        return 'Unstable';
      case StabilityLevel.unknown:
        return 'Unknown';
    }
  }

  Color _getStabilityColor(StabilityLevel stability) {
    switch (stability) {
      case StabilityLevel.stable:
        return Colors.green;
      case StabilityLevel.mildlyUnstable:
        return Colors.orange;
      case StabilityLevel.concerning:
        return Colors.deepOrange;
      case StabilityLevel.unstable:
        return Colors.red;
      case StabilityLevel.unknown:
        return Colors.grey;
    }
  }

  String _getDeteriorationText(DeteriorationRisk risk) {
    switch (risk) {
      case DeteriorationRisk.minimal:
        return 'Minimal';
      case DeteriorationRisk.low:
        return 'Low';
      case DeteriorationRisk.moderate:
        return 'Moderate';
      case DeteriorationRisk.high:
        return 'High';
      case DeteriorationRisk.unknown:
        return 'Unknown';
    }
  }

  Color _getDeteriorationColor(DeteriorationRisk risk) {
    switch (risk) {
      case DeteriorationRisk.minimal:
        return Colors.green;
      case DeteriorationRisk.low:
        return Colors.blue;
      case DeteriorationRisk.moderate:
        return Colors.orange;
      case DeteriorationRisk.high:
        return Colors.red;
      case DeteriorationRisk.unknown:
        return Colors.grey;
    }
  }

  void _navigateToTriage() {
    // Navigate to triage assessment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to triage assessment...')),
    );
  }

  void _navigateToHospitals() {
    // Navigate to hospitals view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to hospitals view...')),
    );
  }

  void _startVoiceTriage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.purple.shade600),
            const SizedBox(width: 8),
            const Text('AI Voice Triage'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Multimodal AI input is ready (Milestone 2 feature):'),
            const SizedBox(height: 12),
            const Text('• Voice symptom description'),
            const Text('• Image analysis for visual symptoms'),
            const Text('• WatsonX.ai natural language processing'),
            const Text('• Real-time vitals integration'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.purple.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected devices: ${_connectedDevices.length} wearables',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/triage-portal');
            },
            child: const Text('Start Triage'),
          ),
        ],
      ),
    );
  }

  void _showConsentManagement() {
    final user = _authService.currentUser!;
    final consents = _authService.getPatientConsents(user.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Consent Management'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You have full control over your medical data. Manage which healthcare providers can access your information:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (consents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No active consents. You can grant access to healthcare providers when needed.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...consents.map((consent) => _buildConsentItem(consent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showGrantConsentDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Grant New Consent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentItem(PatientConsent consent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Provider ID: ${consent.providerId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: consent.isActive && !consent.isExpired
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  consent.isActive && !consent.isExpired ? 'Active' : 'Expired',
                  style: TextStyle(
                    fontSize: 10,
                    color: consent.isActive && !consent.isExpired
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Data Access: ${consent.dataScopes.join(', ')}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Granted: ${consent.grantedAt.toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (consent.expiresAt != null)
            Text(
              'Expires: ${consent.expiresAt!.toString().split(' ')[0]}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _revokeConsent(consent.consentId),
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Revoke'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGrantConsentDialog() {
    final providerController = TextEditingController();
    final selectedScopes = <String>{'vitals', 'assessments'};
    DateTime? expiryDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Grant Healthcare Provider Access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: providerController,
                decoration: const InputDecoration(
                  labelText: 'Provider Email or ID',
                  hintText: 'doctor@hospital.com',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Data Access Permissions:'),
              const SizedBox(height: 8),
              ...[
                'vitals',
                'assessments',
                'history',
                'imaging',
                'triage_results',
              ].map(
                (scope) => CheckboxListTile(
                  title: Text(scope.replaceAll('_', ' ').toUpperCase()),
                  value: selectedScopes.contains(scope),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedScopes.add(scope);
                      } else {
                        selectedScopes.remove(scope);
                      }
                    });
                  },
                  dense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Expiry Date (optional): '),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 30),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          expiryDate = date;
                        });
                      }
                    },
                    child: Text(
                      expiryDate?.toString().split(' ')[0] ?? 'Select Date',
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (providerController.text.isNotEmpty &&
                    selectedScopes.isNotEmpty) {
                  await _grantConsent(
                    providerController.text,
                    selectedScopes.toList(),
                    expiryDate,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _showConsentManagement(); // Refresh the consent list
                  }
                }
              },
              child: const Text('Grant Access'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _grantConsent(
    String providerId,
    List<String> dataScopes,
    DateTime? expiryDate,
  ) async {
    final user = _authService.currentUser!;
    try {
      await _authService.grantPatientConsent(
        user.id,
        providerId,
        dataScopes,
        expiryDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access granted to $providerId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to grant consent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeConsent(String consentId) async {
    final user = _authService.currentUser!;
    try {
      await _authService.revokePatientConsent(user.id, consentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consent revoked successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(); // Close the dialog
        _showConsentManagement(); // Reopen with updated data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke consent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
