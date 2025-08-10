import 'package:flutter/material.dart';
import '../widgets/web_triage_form.dart';
import '../widgets/web_vitals_display.dart';
import '../widgets/web_hospital_map.dart';
import '../widgets/web_consent_panel.dart';
import '../../../../shared/services/fhir_service.dart';
import '../../../../shared/services/hospital_routing_service.dart';
import '../../../../shared/services/consent_service.dart';

/// Responsive web portal for patient triage and hospital routing
class PatientWebPortalPage extends StatefulWidget {
  final String? patientId;

  const PatientWebPortalPage({
    super.key,
    this.patientId,
  });

  @override
  State<PatientWebPortalPage> createState() => _PatientWebPortalPageState();
}

class _PatientWebPortalPageState extends State<PatientWebPortalPage> {
  final HospitalRoutingService _routingService = HospitalRoutingService();
  final ConsentService _consentService = ConsentService(); // TODO: Implement consent functionality
  
  String _currentStep = 'symptoms'; // symptoms, vitals, routing, consent
  Map<String, dynamic> _triageData = {};
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
      // Initialize services
      FhirService().initialize();
      
      // Load nearby hospitals for map display
      await _loadNearbyHospitals();
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
      final hospitals = await FhirService().getHospitalCapacities(
        latitude: 40.7128, // Default to NYC
        longitude: -74.0060,
        radiusKm: 25.0,
      );
      
      setState(() {
        _nearbyHospitals = hospitals;
      });
    } catch (e) {
      print('Error loading hospitals: $e');
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return _buildDesktopLayout();
    } else if (screenWidth > 800) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar - Navigation and progress
        Container(
          width: 300,
          color: Colors.blue.shade50,
          child: _buildSidebar(),
        ),
        // Main content area
        Expanded(
          flex: 2,
          child: _buildMainContent(),
        ),
        // Right panel - Hospital map and info
        Container(
          width: 400,
          color: Colors.grey.shade50,
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        // Top navigation
        Container(
          height: 80,
          color: Colors.blue.shade50,
          child: _buildTopNavigation(),
        ),
        // Main content
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildMainContent(),
              ),
              Expanded(
                flex: 1,
                child: _buildRightPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile header
        Container(
          height: 60,
          color: Colors.blue.shade700,
          child: _buildMobileHeader(),
        ),
        // Progress indicator
        Container(
          height: 8,
          child: LinearProgressIndicator(
            value: _getProgressValue(),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
        ),
        // Main content
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo and title
          Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.blue.shade700, size: 32),
              const SizedBox(width: 12),
              Text(
                'Triage-BIOS.ai',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Progress steps
          _buildProgressSteps(),
          
          const Spacer(),
          
          // Emergency contact info
          Container(
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
                    Icon(Icons.emergency, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Emergency',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'If this is a life-threatening emergency, call 911 immediately.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
                  color: isActive || isCompleted ? Colors.white : Colors.grey.shade600,
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

  Widget _buildTopNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.local_hospital, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Text(
            'Triage-BIOS.ai',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const Spacer(),
          _buildStepIndicator(),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.local_hospital, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(
            'Triage-BIOS.ai',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            _getStepTitle(),
            style: const TextStyle(color: Colors.white),
          ),
        ],
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
      padding: const EdgeInsets.all(24),
      child: _buildCurrentStepContent(),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 'symptoms':
        return WebTriageForm(
          onDataChanged: (data) {
            setState(() {
              _triageData.addAll(data);
            });
          },
          onNext: () => _goToStep('vitals'),
        );
      case 'vitals':
        return WebVitalsDisplay(
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
        return WebConsentPanel(
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nearby Hospitals',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Hospital map
          Expanded(
            flex: 2,
            child: WebHospitalMap(
              hospitals: _nearbyHospitals,
              selectedHospital: _routingResult?.recommendedHospital,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Hospital list
          if (_nearbyHospitals.isNotEmpty) ...[
            Text(
              'Hospital Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 1,
              child: ListView.builder(
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
    );
  }

  Widget _buildHospitalCard(HospitalCapacity hospital) {
    final isRecommended = _routingResult?.recommendedHospital.id == hospital.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
            ),
            if (hospital.distanceKm != null)
              Text(
                '${hospital.distanceKm!.toStringAsFixed(1)} km away',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingResults() {
    if (_routingResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Hospital',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_hospital, color: Colors.blue.shade700, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _routingResult!.recommendedHospital.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_routingResult!.routingMetrics.distanceKm.toStringAsFixed(1)} km away',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Travel Time',
                        '${_routingResult!.routingMetrics.travelTimeMinutes} min',
                        Icons.directions_car,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Wait Time',
                        '${_routingResult!.routingMetrics.estimatedWaitTimeMinutes} min',
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _goToStep('consent'),
                        child: const Text('Proceed to Hospital'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => _goToStep('vitals'),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
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
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
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

  Future<void> _processTriageAndRoute() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Process triage data and find optimal hospital
      final result = await _routingService.findOptimalHospital(
        patientLatitude: 40.7128, // Would get from user location
        patientLongitude: -74.0060,
        severityScore: _triageData['severityScore'] ?? 5.0,
        specializations: [],
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

  void _handleConsentDecision(bool granted) {
    setState(() {
      _triageData['consent'] = granted;
    });

    if (granted) {
      _showSuccess('Consent granted. Your data will be shared securely with the hospital.');
    } else {
      _showInfo('You can still receive care without data sharing.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}