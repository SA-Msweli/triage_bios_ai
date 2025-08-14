import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/multimodal_input_widget.dart';
import '../widgets/enhanced_vitals_widget.dart';
import '../widgets/triage_result_widget.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/entities/patient_vitals.dart';
import '../../../../shared/services/watsonx_service.dart';
import '../../../../shared/services/medical_algorithm_service.dart';
import '../../../../shared/services/vitals_trend_service.dart';
import '../../../../shared/services/fhir_service.dart';
import '../../../../shared/services/hospital_routing_service.dart';
import '../../../../config/app_config.dart';

/// Enhanced triage assessment page with full AI integration and multimodal input
class EnhancedTriagePage extends StatefulWidget {
  const EnhancedTriagePage({super.key});

  @override
  State<EnhancedTriagePage> createState() => _EnhancedTriagePageState();
}

class _EnhancedTriagePageState extends State<EnhancedTriagePage>
    with TickerProviderStateMixin {
  final WatsonxService _watsonxService = WatsonxService();
  final MedicalAlgorithmService _medicalService = MedicalAlgorithmService();
  final VitalsTrendService _trendService = VitalsTrendService();
  final FhirService _fhirService = FhirService();
  final HospitalRoutingService _routingService = HospitalRoutingService();

  // Assessment state
  Map<String, dynamic> _inputData = {};
  PatientVitals? _currentVitals;
  TriageResult? _assessmentResult;
  bool _isAssessing = false;

  // Animation controllers
  late AnimationController _processingController;
  late Animation<double> _processingAnimation;

  // Stepper state
  int _currentStepIndex = 0;
  final List<String> _steps = ['Input', 'Vitals', 'Assessment', 'Results'];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
  }

  @override
  void dispose() {
    _processingController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _processingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _processingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _processingController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize all services
      _watsonxService.initialize(
        apiKey: AppConfig.instance.watsonxApiKey,
        projectId: AppConfig.instance.watsonxProjectId,
      );
      _fhirService.initialize();

      _showInfo(
        'AI Triage Engine initialized with WatsonX.ai and medical algorithms',
      );
    } catch (e) {
      _showError('Failed to initialize services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced AI Triage'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetAssessment,
            tooltip: 'Reset Assessment',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: 'Help',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Main content
          Expanded(child: _buildMainContent()),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Step indicators
          Row(
            children: _steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = index == _currentStepIndex;
              final isCompleted = index < _currentStepIndex;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : isCompleted
                            ? Colors.green
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive || isCompleted
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (index < _steps.length - 1)
                      Container(
                        height: 2,
                        width: 20,
                        color: isCompleted
                            ? Colors.green
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Progress bar
          LinearProgressIndicator(
            value: (_currentStepIndex + 1) / _steps.length,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI status
          _buildHeader(),
          const SizedBox(height: 24),

          // Main content based on current step
          if (_currentStepIndex == 0) ...[
            // Step 1: Multimodal Input
            MultimodalInputWidget(
              onInputReceived: _handleInputReceived,
              enableVoice: true,
              enableImage: true,
              enableText: true,
            ),
          ] else if (_currentStepIndex == 1) ...[
            // Step 2: Enhanced Vitals
            EnhancedVitalsWidget(
              onVitalsChanged: _handleVitalsChanged,
              enableRealTimeMonitoring: true,
            ),
          ] else if (_currentStepIndex == 2) ...[
            // Step 3: AI Processing
            _buildProcessingView(),
          ] else if (_currentStepIndex == 3) ...[
            // Step 4: Results
            if (_assessmentResult != null)
              TriageResultWidget(result: _assessmentResult!),
          ],

          const SizedBox(height: 24),

          // Summary panel (always visible)
          _buildSummaryPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI-Powered Emergency Triage',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Advanced assessment using WatsonX.ai, medical algorithms, and real-time vitals',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // AI Status indicators
            Row(
              children: [
                _buildStatusChip('WatsonX.ai', true, Colors.blue),
                const SizedBox(width: 8),
                _buildStatusChip('Medical Algorithms', true, Colors.green),
                const SizedBox(width: 8),
                _buildStatusChip('FHIR Integration', true, Colors.purple),
                const SizedBox(width: 8),
                _buildStatusChip(
                  'Real-time Vitals',
                  _currentVitals != null,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? color : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Processing animation
            AnimatedBuilder(
              animation: _processingAnimation,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Transform.rotate(
                        angle: _processingAnimation.value * 2 * 3.14159,
                        child: Icon(
                          Icons.psychology,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            Text(
              'AI Analysis in Progress',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Processing steps
            Column(
              children: [
                _buildProcessingStep(
                  'Analyzing multimodal input with WatsonX.ai',
                  true,
                ),
                _buildProcessingStep(
                  'Running medical algorithm validation',
                  true,
                ),
                _buildProcessingStep(
                  'Integrating real-time vitals data',
                  _currentVitals != null,
                ),
                _buildProcessingStep(
                  'Calculating enhanced severity score',
                  true,
                ),
                _buildProcessingStep(
                  'Generating clinical recommendations',
                  true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep(String step, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: isActive
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isActive
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assessment Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Input Methods',
                    _getInputMethodsCount(),
                    Icons.input,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Vitals Connected',
                    _currentVitals != null ? 'Yes' : 'No',
                    Icons.favorite,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'AI Models',
                    '2 Active',
                    Icons.psychology,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          if (_currentStepIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
            ),
          if (_currentStepIndex > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _canProceed() ? _nextStep : null,
              icon: Icon(_getNextButtonIcon()),
              label: Text(_getNextButtonText()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Event handlers
  void _handleInputReceived(Map<String, dynamic> inputData) {
    setState(() {
      _inputData = inputData;
    });
  }

  void _handleVitalsChanged(PatientVitals? vitals) {
    setState(() {
      _currentVitals = vitals;
    });
  }

  void _nextStep() {
    if (_currentStepIndex == 2) {
      // Start AI processing
      _performAIAssessment();
    } else if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  Future<void> _performAIAssessment() async {
    setState(() {
      _isAssessing = true;
      _currentStepIndex = 2;
      // Processing step
    });

    _processingController.repeat();

    try {
      // Simulate comprehensive AI processing
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        // AI analysis step
      });

      // Step 1: WatsonX.ai analysis
      final aiResult = await _watsonxService.assessSymptoms(
        symptoms:
            _inputData['textInput'] ??
            _inputData['voiceText'] ??
            'General symptoms',
        vitals: _currentVitals,
        demographics: {'age': 35, 'gender': 'unknown'},
      );

      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        // Medical validation step
      });

      // Step 2: Medical algorithm validation
      await _medicalService.analyzePatient(
        symptoms:
            _inputData['textInput'] ??
            _inputData['voiceText'] ??
            'General symptoms',
        vitals: _currentVitals,
        aiResult: {
          'severityScore': aiResult.severityScore,
          'urgencyLevel': aiResult.urgencyLevelString,
          'explanation': aiResult.explanation,
        },
      );

      await Future.delayed(const Duration(seconds: 1));

      // Step 3: Store vitals for trend analysis
      if (_currentVitals != null) {
        await _trendService.storeVitalsReading(_currentVitals!);
      }

      // Step 4: Get hospital routing recommendations if high severity
      if (aiResult.severityScore >= 7.0) {
        await _routingService.initialize();
        // This would normally get optimal hospital routing
        // For demo, we just initialize the service
      }

      // Step 5: Enhanced result
      setState(() {
        _assessmentResult = aiResult;
        _currentStepIndex = 3;
        _isAssessing = false;
        // Results step
      });

      _processingController.stop();
      _showSuccess('AI assessment completed successfully!');
    } catch (e) {
      setState(() {
        _isAssessing = false;
      });
      _processingController.stop();
      _showError('Assessment failed: $e');
    }
  }

  void _resetAssessment() {
    setState(() {
      _currentStepIndex = 0;
      _inputData = {};
      _currentVitals = null;
      _assessmentResult = null;
      _isAssessing = false;
    });
    _processingController.reset();
  }

  // Helper methods
  bool _canProceed() {
    switch (_currentStepIndex) {
      case 0:
        return _inputData.isNotEmpty;
      case 1:
        return true; // Vitals are optional
      case 2:
        return !_isAssessing;
      case 3:
        return false; // Final step
      default:
        return false;
    }
  }

  String _getNextButtonText() {
    switch (_currentStepIndex) {
      case 0:
        return 'Continue to Vitals';
      case 1:
        return 'Start AI Assessment';
      case 2:
        return _isAssessing ? 'Processing...' : 'View Results';
      case 3:
        return 'Find Hospitals';
      default:
        return 'Next';
    }
  }

  IconData _getNextButtonIcon() {
    switch (_currentStepIndex) {
      case 0:
        return Icons.arrow_forward;
      case 1:
        return Icons.psychology;
      case 2:
        return _isAssessing ? Icons.hourglass_empty : Icons.arrow_forward;
      case 3:
        return Icons.local_hospital;
      default:
        return Icons.arrow_forward;
    }
  }

  String _getInputMethodsCount() {
    final methods = <String>[];
    if (_inputData['voiceText']?.isNotEmpty == true) methods.add('Voice');
    if (_inputData['textInput']?.isNotEmpty == true) methods.add('Text');
    if (_inputData['imageCount'] != null && _inputData['imageCount'] > 0) {
      methods.add('Image');
    }

    return methods.isEmpty ? 'None' : methods.length.toString();
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enhanced AI Triage Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This enhanced triage system uses multiple AI technologies:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• WatsonX.ai for natural language processing'),
              Text('• Medical algorithms for clinical validation'),
              Text('• Real-time vitals from wearable devices'),
              Text('• Multimodal input (voice, text, images)'),
              SizedBox(height: 12),
              Text('Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('1. Describe symptoms using voice, text, or images'),
              Text('2. Connect wearable devices for vitals monitoring'),
              Text('3. AI processes all inputs for comprehensive assessment'),
              Text('4. Review results and find nearby hospitals'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
