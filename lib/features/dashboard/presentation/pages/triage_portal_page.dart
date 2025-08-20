import 'package:flutter/material.dart';
import '../widgets/triage_form_widget.dart';
import '../widgets/vitals_display_widget.dart';
import '../../../hospital_routing/presentation/widgets/hospital_map_widget.dart';
import '../widgets/consent_panel_widget.dart';

import '../../../../shared/services/hospital_routing_service.dart';
import '../../../../shared/services/consent_service.dart';
import '../../../../shared/services/watsonx_service.dart';
import '../../../../shared/services/medical_algorithm_service.dart';
import '../../../../config/app_config.dart';
import '../../../../shared/services/multimodal_input_service.dart';
import '../../../../shared/services/vitals_trend_service.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/responsive_widget.dart';
import '../../../../shared/models/hospital_capacity.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/widgets/responsive_layouts.dart';
import '../../../../shared/utils/overflow_detection.dart';

/// Responsive triage portal for patient assessment and hospital routing
class TriagePortalPage extends StatefulWidget {
  final String? patientId;

  const TriagePortalPage({super.key, this.patientId});

  @override
  State<TriagePortalPage> createState() => _TriagePortalPageState();
}

class _TriagePortalPageState extends State<TriagePortalPage> {
  final HospitalRoutingService _routingService = HospitalRoutingService();
  final ConsentService _consentService = ConsentService();
  final WatsonxService _watsonxService = WatsonxService();
  final MedicalAlgorithmService _medicalService = MedicalAlgorithmService();
  final MultiModalInputService _multiModalService = MultiModalInputService();
  final VitalsTrendService _trendService = VitalsTrendService();

  String _currentStep = 'symptoms'; // symptoms, vitals, routing, consent
  final Map<String, dynamic> _triageData = {};
  List<HospitalCapacity> _nearbyHospitals = [];
  HospitalRoutingResult? _routingResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePortal();
  }

  Future<void> _initializePortal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize WatsonX AI service for symptom analysis
      _watsonxService.initialize(
        apiKey: AppConfig.instance.watsonxApiKey,
        projectId: AppConfig.instance.watsonxProjectId,
      );

      // Initialize multimodal input service for voice/image input
      await _multiModalService.initialize();

      // Load nearby hospitals for map display
      await _loadNearbyHospitals();

      _showInfo('AI Triage Engine initialized with WatsonX.ai');
    } catch (e) {
      _showError('Failed to initialize portal: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyHospitals() async {
    try {
      // Use the existing _routingService instance
      final hospitals = await _routingService.getNearbyHospitals( 
        latitude: 40.7128, // Default to NYC
        longitude: -74.0060,
        radiusKm: 25.0,
      );

      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _nearbyHospitals = hospitals;
        });
      }
    } catch (e) {
      _showError('Failed to load nearby hospitals: $e'); // It's better to show an error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildResponsiveLayout(),
    );
  }

  Widget _buildResponsiveLayout() {
    return ResponsiveBuilder(
      mobile: (context) => _buildMobileLayout(),
      tablet: (context) => _buildTabletLayout(),
      desktop: (context) => _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: ResponsiveThreeColumnLayout(
        leftChild: ConstrainedResponsiveContainer(
          minWidth: 280,
          maxWidth: 320,
          child: Container(
            color: Colors.blue.shade50,
            child: Column(
              children: [
                // Desktop sidebar header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_hospital, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Triage-BIOS.ai',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sidebar content
                Expanded(child: _buildSidebar()),
              ],
            ),
          ),
        ),
        centerChild: ConstrainedResponsiveContainer(
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Desktop main header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStepTitle(),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _getProgressValue(),
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      _buildStepIndicator(),
                    ],
                  ),
                ),
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: _buildMainContent().withOverflowDetection(
                      debugName: 'Desktop Main Content',
                    ),
                  ),
                ),
                // Desktop navigation buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: _buildStepNavigationButtons(),
                ),
              ],
            ),
          ),
        ),
        rightChild: ConstrainedResponsiveContainer(
          minWidth: 300,
          maxWidth: 420,
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Right panel header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Text(
                    'Hospital Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Right panel content
                Expanded(
                  child: _buildRightPanel().withOverflowDetection(
                    debugName: 'Desktop Right Panel',
                  ),
                ),
              ],
            ),
          ),
        ),
        leftFlex: 1.0,
        centerFlex: 2.0,
        rightFlex: 1.2,
        spacing: 0,
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        elevation: 1,
        title: Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.blue.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Triage-BIOS.ai',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: _buildStepIndicator(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _getProgressValue(),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
        ),
      ),
      body: ResponsiveTwoColumnLayout(
        leftChild: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: ResponsiveBreakpoints.getResponsivePadding(context),
                  child: _buildMainContent().withOverflowDetection(
                    debugName: 'Tablet Main Content',
                  ),
                ),
              ),
              // Tablet navigation buttons
              Container(
                padding: ResponsiveBreakpoints.getResponsivePadding(context),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: _buildStepNavigationButtons(),
              ),
            ],
          ),
        ),
        rightChild: Container(
          color: Colors.grey.shade50,
          child: Column(
            children: [
              // Right panel header
              Container(
                width: double.infinity,
                padding: ResponsiveBreakpoints.getResponsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Text(
                  'Hospital Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Right panel content
              Expanded(
                child: _buildRightPanel().withOverflowDetection(
                  debugName: 'Tablet Right Panel',
                ),
              ),
            ],
          ),
        ),
        leftFlex: 2.0,
        rightFlex: 1.2,
        spacing: 0,
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Handle keyboard properly
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Triage-BIOS.ai',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _getStepTitle(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: ConstrainedResponsiveContainer(
            minHeight: 6,
            maxHeight: 8,
            child: LinearProgressIndicator(
              value: _getProgressValue(),
              backgroundColor: Colors.blue.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Emergency banner for mobile
            if (_currentStep == 'symptoms') _buildMobileEmergencyBanner(),

            // Main content with overflow protection
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: ResponsiveBreakpoints.getResponsivePadding(context),
                child: _buildMainContent().withOverflowDetection(
                  debugName: 'Mobile Main Content',
                ),
              ),
            ),

            // Mobile navigation buttons
            _buildMobileNavigationButtons(),
          ],
        ),
      ),
      // Mobile drawer for additional options
      drawer: _buildMobileDrawer(),
    );
  }

  Widget _buildSidebar() {
    return SingleChildScrollView(
      child: Padding(
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo and title with text overflow protection
            ConstrainedResponsiveContainer(
              child: Row(
                children: [
                  Icon(
                    Icons.local_hospital,
                    color: Colors.blue.shade700,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Triage-BIOS.ai',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Progress steps
            _buildProgressSteps(),

            const SizedBox(height: 32),

            // Emergency contact info with constraints
            ConstrainedResponsiveContainer.card(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
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
                        Expanded(
                          child: Text(
                            'Emergency',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If this is a life-threatening emergency, call 911 immediately.',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = [
      {'key': 'symptoms', 'title': 'Symptoms', 'icon': Icons.assignment},
      {'key': 'vitals', 'title': 'Vitals', 'icon': Icons.favorite},
      {'key': 'routing', 'title': 'Hospital', 'icon': Icons.local_hospital},
      {'key': 'consent', 'title': 'Consent', 'icon': Icons.security},
    ];

    return Column(
      children: steps.map((step) {
        final isActive = step['key'] == _currentStep;
        final isCompleted = _isStepCompleted(step['key'] as String);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.blue.shade600
                      : isCompleted
                      ? Colors.green.shade600
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isCompleted ? Icons.check : step['icon'] as IconData,
                  color: isActive || isCompleted
                      ? Colors.white
                      : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                step['title'] as String,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? Colors.blue.shade700
                      : isCompleted
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileEmergencyBanner() {
    return ConstrainedResponsiveContainer.card(
      margin: ResponsiveBreakpoints.getResponsiveMargin(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Emergency? Call 911 immediately',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ConstrainedResponsiveContainer.button(
              child: TextButton(
                onPressed: () => _showEmergencyDialog(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(44, 32),
                ),
                child: const Text('Call', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavigationButtons() {
    return Container(
      padding: ResponsiveBreakpoints.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(top: false, child: _buildStepNavigationButtons()),
    );
  }

  Widget _buildStepNavigationButtons() {
    return ResponsiveGrid(
      mobileColumns: _canGoBack() && _canGoNext() ? 2 : 1,
      tabletColumns: 2,
      desktopColumns: 2,
      spacing: 12,
      children: [
        if (_canGoBack())
          ConstrainedResponsiveContainer.button(
            child: OutlinedButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        if (_canGoNext())
          ConstrainedResponsiveContainer.button(
            child: ElevatedButton.icon(
              onPressed: _goNext,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(_getNextButtonText()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_hospital,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Triage-BIOS.ai',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-Powered Emergency Triage',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Progress steps
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProgressSteps(),

                    const Spacer(),

                    // Emergency contact in drawer
                    ConstrainedResponsiveContainer.card(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
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
                                Expanded(
                                  child: Text(
                                    'Emergency',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'If this is a life-threatening emergency, call 911 immediately.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedResponsiveContainer.button(
                              child: ElevatedButton.icon(
                                onPressed: () => _showEmergencyDialog(),
                                icon: const Icon(Icons.phone, size: 18),
                                label: const Text('Call 911'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['symptoms', 'vitals', 'routing', 'consent'];
    final currentIndex = steps.indexOf(_currentStep);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final isActive = index == currentIndex;
        final isCompleted = index < currentIndex;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.blue.shade600
                : isCompleted
                ? Colors.green.shade600
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: ResponsiveBreakpoints.getResponsivePadding(context),
      child: _buildCurrentStepContent(),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 'symptoms':
        return TriageFormWidget(
          onDataChanged: (data) {
            setState(() {
              _triageData.addAll(data);
            });
          },
          onNext: () => _goToStep('vitals'),
        );
      case 'vitals':
        return VitalsDisplayWidget(
          onDataChanged: (data) {
            setState(() {
              _triageData.addAll(data);
            });
          },
          onNext: () => _processTriageAndRoute(),
          onBack: () => _goToStep('symptoms'),
        );
      case 'routing':
        return _buildRoutingResults();
      case 'consent':
        return ConsentPanelWidget(
          patientId: widget.patientId ?? 'web_patient',
          hospitalId: _routingResult?.recommendedHospital.id ?? '',
          hospitalName: _routingResult?.recommendedHospital.name ?? '',
          onConsentDecision: _handleConsentDecision,
        );
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  Widget _buildRightPanel() {
    return SingleChildScrollView(
      child: Padding(
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title with text overflow protection
            ConstrainedResponsiveContainer(
              child: Text(
                'Nearby Hospitals',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),

            // Hospital map with size constraints
            ConstrainedResponsiveContainer.hospitalMap(
              child: HospitalMapWidget(
                severityScore: _triageData['severity_score'] as double?,
                onHospitalSelected: (hospital) {
                  // Handle hospital selection
                  setState(() {
                    // Update routing result with selected hospital
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Hospital list
            if (_nearbyHospitals.isNotEmpty) ...[
              Text(
                'Hospital Status',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              ConstrainedResponsiveContainer(
                maxHeight: 300, // Prevent excessive height
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _nearbyHospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = _nearbyHospitals[index];
                    return _buildHospitalCard(hospital);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalCard(HospitalCapacity hospital) {
    final isRecommended = _routingResult?.recommendedHospital.id == hospital.id;

    return ConstrainedResponsiveContainer.card(
      margin: ResponsiveBreakpoints.getResponsiveMargin(
        context,
      ).copyWith(top: 0),
      child: Card(
        color: isRecommended ? Colors.blue.shade50 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRecommended ? Colors.blue.shade700 : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (isRecommended)
                    Icon(Icons.star, color: Colors.blue.shade700, size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${hospital.availableBeds}/${hospital.totalBeds} beds available',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (hospital.distanceKm != null)
                Text(
                  '${hospital.distanceKm!.toStringAsFixed(1)} km away',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutingResults() {
    if (_routingResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Hospital',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 24),

          ConstrainedResponsiveContainer.card(
            child: Card(
              child: Padding(
                padding: ResponsiveBreakpoints.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital,
                          color: Colors.blue.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _routingResult!.recommendedHospital.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              Text(
                                '${_routingResult!.routingMetrics.distanceKm.toStringAsFixed(1)} km away',
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Responsive grid for metrics
                    ResponsiveGrid(
                      mobileColumns: 1,
                      tabletColumns: 2,
                      desktopColumns: 2,
                      spacing: 16,
                      children: [
                        _buildMetricCard(
                          'Travel Time',
                          '${_routingResult!.routingMetrics.travelTimeMinutes} min',
                          Icons.directions_car,
                          Colors.blue,
                        ),
                        _buildMetricCard(
                          'Wait Time',
                          '${_routingResult!.routingMetrics.estimatedWaitTimeMinutes} min',
                          Icons.schedule,
                          Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Responsive button layout
                    ResponsiveGrid(
                      mobileColumns: 1,
                      tabletColumns: 2,
                      desktopColumns: 2,
                      spacing: 16,
                      children: [
                        ConstrainedResponsiveContainer.button(
                          child: ElevatedButton(
                            onPressed: () => _goToStep('consent'),
                            child: const Text('Proceed to Hospital'),
                          ),
                        ),
                        ConstrainedResponsiveContainer.button(
                          child: OutlinedButton(
                            onPressed: () => _goToStep('vitals'),
                            child: const Text('Back'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ConstrainedResponsiveContainer(
      minWidth: 120,
      maxWidth: 200,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods

  void _goToStep(String step) {
    setState(() {
      _currentStep = step;
    });
  }

  bool _isStepCompleted(String step) {
    switch (step) {
      case 'symptoms':
        return _triageData.containsKey('symptoms');
      case 'vitals':
        return _triageData.containsKey('vitals');
      case 'routing':
        return _routingResult != null;
      case 'consent':
        return _triageData.containsKey('consent');
      default:
        return false;
    }
  }

  double _getProgressValue() {
    final steps = ['symptoms', 'vitals', 'routing', 'consent'];
    final currentIndex = steps.indexOf(_currentStep);
    return (currentIndex + 1) / steps.length;
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 'symptoms':
        return 'Describe Symptoms';
      case 'vitals':
        return 'Check Vitals';
      case 'routing':
        return 'Hospital Selection';
      case 'consent':
        return 'Data Consent';
      default:
        return 'Triage';
    }
  }

  bool _canGoBack() {
    switch (_currentStep) {
      case 'symptoms':
        return false;
      case 'vitals':
        return true;
      case 'routing':
        return true;
      case 'consent':
        return true;
      default:
        return false;
    }
  }

  bool _canGoNext() {
    switch (_currentStep) {
      case 'symptoms':
        return _triageData.containsKey('symptoms');
      case 'vitals':
        return _triageData.containsKey('vitals');
      case 'routing':
        return _routingResult != null;
      case 'consent':
        return false; // Consent is the final step
      default:
        return false;
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 'symptoms':
        return 'Check Vitals';
      case 'vitals':
        return 'Find Hospital';
      case 'routing':
        return 'Continue';
      default:
        return 'Next';
    }
  }

  void _goBack() {
    switch (_currentStep) {
      case 'vitals':
        _goToStep('symptoms');
        break;
      case 'routing':
        _goToStep('vitals');
        break;
      case 'consent':
        _goToStep('routing');
        break;
    }
  }

  void _goNext() {
    switch (_currentStep) {
      case 'symptoms':
        _goToStep('vitals');
        break;
      case 'vitals':
        _processTriageAndRoute();
        break;
      case 'routing':
        _goToStep('consent');
        break;
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Emergency'),
          ],
        ),
        content: const Text(
          'This will open your phone\'s dialer to call 911. '
          'Only use this for life-threatening emergencies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // In a real app, this would use url_launcher to call 911
              _showInfo('Emergency services would be contacted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call 911'),
          ),
        ],
      ),
    );
  }

  Future<void> _processTriageAndRoute() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _showInfo('Analyzing symptoms with WatsonX.ai...');

      // Step 1: Use WatsonX AI for symptom analysis (Milestone 1 & 2 requirement)
      final aiTriageResult = await _watsonxService.assessSymptoms(
        symptoms: _triageData['symptoms'] ?? '',
        vitals: _triageData['vitals'],
        demographics: {
          'age': 35, // Would get from user profile
          'gender': 'unknown',
        },
      );

      // Step 2: Use Medical Algorithm Service for clinical assessment (Milestone 2 requirement)
      final medicalAssessment = await _medicalService.analyzePatient(
        symptoms: _triageData['symptoms'] ?? '',
        vitals: _triageData['vitals'],
        aiResult: {
          'severityScore': aiTriageResult.severityScore,
          'urgencyLevel': aiTriageResult.urgencyLevelString,
          'explanation': aiTriageResult.explanation,
          'keySymptoms': aiTriageResult.keySymptoms,
        },
      );

      // Step 3: Store vitals for trend analysis (Milestone 2 requirement)
      if (_triageData['vitals'] != null) {
        await _trendService.storeVitalsReading(_triageData['vitals']);

        // Get trend analysis for enhanced severity scoring
        final trendAnalysis = await _trendService.analyzeTrends(hoursBack: 24);
        _triageData['trendAnalysis'] = trendAnalysis;
      }

      // Step 4: Calculate enhanced severity score combining AI + Medical algorithms
      final enhancedSeverityScore = _calculateEnhancedSeverity(
        aiResult: aiTriageResult,
        medicalAssessment: medicalAssessment,
        vitalsSeverityBoost: _triageData['vitalsSeverityBoost'] ?? 0.0,
      );

      _triageData['aiTriageResult'] = aiTriageResult;
      _triageData['medicalAssessment'] = medicalAssessment;
      _triageData['enhancedSeverityScore'] = enhancedSeverityScore;

      _showSuccess(
        'AI analysis complete - Severity: ${enhancedSeverityScore.toStringAsFixed(1)}/10',
      );

      // Step 5: Find optimal hospital using enhanced scoring
      final result = await _routingService.findOptimalHospital(
        patientLatitude: 40.7128, // Would get from user location
        patientLongitude: -74.0060,
        severityScore: enhancedSeverityScore,
        specializations:
            [], // Would extract from AI result in real implementation
      );

      setState(() {
        _routingResult = result;
        _currentStep = 'routing';
      });
    } catch (e) {
      _showError('Failed to process triage: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateEnhancedSeverity({
    required dynamic aiResult,
    required dynamic medicalAssessment,
    required double vitalsSeverityBoost,
  }) {
    // Combine AI assessment, medical algorithms, and vitals boost
    double baseSeverity = _triageData['severityScore'] ?? 5.0;

    // Add AI enhancement (up to +2 points)
    if (aiResult != null) {
      baseSeverity += (aiResult.confidence ?? 0.5) * 2.0;
    }

    // Add medical algorithm enhancement (up to +1.5 points)
    if (medicalAssessment != null) {
      baseSeverity += (medicalAssessment.riskLevel ?? 0.3) * 1.5;
    }

    // Add vitals-based boost
    baseSeverity += vitalsSeverityBoost;

    // Ensure score stays within 0-10 range
    return baseSeverity.clamp(0.0, 10.0);
  }

  Future<void> _handleConsentDecision(bool granted) async {
    setState(() {
      _triageData['consent'] = granted;
    });

    try {
      // Record consent decision using the consent service
      await _consentService.recordConsent(
        patientId: widget.patientId ?? 'web_patient',
        hospitalId: _routingResult?.recommendedHospital.id ?? '',
        consentGranted: granted,
        dataScope: granted ? ['vitals', 'symptoms'] : [],
      );

      if (granted) {
        _showSuccess(
          'Consent granted. Your data will be shared securely with the hospital.',
        );
      } else {
        _showInfo('You can still receive care without data sharing.');
      }
    } catch (e) {
      _showError('Failed to record consent: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }
}
