import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/triage_bloc.dart';
import '../bloc/triage_event.dart';
import '../bloc/triage_state.dart';
import '../../../../shared/services/multimodal_input_service.dart';

class SymptomInputWidget extends StatefulWidget {
  const SymptomInputWidget({super.key});

  @override
  State<SymptomInputWidget> createState() => _SymptomInputWidgetState();
}

class _SymptomInputWidgetState extends State<SymptomInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MultiModalInputService _multiModalService = MultiModalInputService();
  
  bool _isVoiceInputActive = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMultiModal();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeMultiModal() async {
    final initialized = await _multiModalService.initialize();
    setState(() {
      _isInitialized = initialized;
    });
  }

  void _submitSymptoms() {
    final symptoms = _controller.text.trim();
    if (symptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your symptoms'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get current vitals if available
    final currentState = context.read<TriageBloc>().state;
    final vitals = currentState is VitalsLoaded ? currentState.vitals : null;

    context.read<TriageBloc>().add(
      AssessSymptomsEvent(symptoms: symptoms, vitals: vitals),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TriageBloc, TriageState>(
      builder: (context, state) {
        final isLoading = state is TriageLoading;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Describe Your Symptoms',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !isLoading,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Please describe your symptoms in detail...\n\nFor example:\n• "I have severe chest pain that started 30 minutes ago"\n• "Difficulty breathing and dizziness since this morning"',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitSymptoms(),
                ),
                const SizedBox(height: 16),

                // Quick symptom buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickSymptomChip(
                      label: 'Chest Pain',
                      onTap: () => _addSymptom('chest pain'),
                      enabled: !isLoading,
                    ),
                    _QuickSymptomChip(
                      label: 'Difficulty Breathing',
                      onTap: () => _addSymptom('difficulty breathing'),
                      enabled: !isLoading,
                    ),
                    _QuickSymptomChip(
                      label: 'Severe Headache',
                      onTap: () => _addSymptom('severe headache'),
                      enabled: !isLoading,
                    ),
                    _QuickSymptomChip(
                      label: 'Nausea/Vomiting',
                      onTap: () => _addSymptom('nausea and vomiting'),
                      enabled: !isLoading,
                    ),
                    _QuickSymptomChip(
                      label: 'High Fever',
                      onTap: () => _addSymptom('high fever'),
                      enabled: !isLoading,
                    ),
                    _QuickSymptomChip(
                      label: 'Dizziness',
                      onTap: () => _addSymptom('dizziness'),
                      enabled: !isLoading,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Multi-modal input buttons
                Row(
                  children: [
                    // Voice input button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isInitialized && _multiModalService.isSpeechEnabled && !isLoading)
                            ? _toggleVoiceInput
                            : null,
                        icon: Icon(
                          _isVoiceInputActive ? Icons.mic : Icons.mic_none,
                          color: _isVoiceInputActive ? Colors.red : null,
                        ),
                        label: Text(_isVoiceInputActive ? 'Stop Recording' : 'Voice Input'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isVoiceInputActive ? Colors.red : null,
                          side: _isVoiceInputActive 
                              ? const BorderSide(color: Colors.red) 
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Image input button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !isLoading ? _captureImage : null,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Add Photo'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : _submitSymptoms,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(
                      isLoading ? 'Analyzing...' : 'Get AI Assessment',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addSymptom(String symptom) {
    final currentText = _controller.text;
    if (currentText.isEmpty) {
      _controller.text = symptom;
    } else {
      _controller.text = '$currentText, $symptom';
    }
    _focusNode.requestFocus();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isVoiceInputActive) {
      // Stop voice input
      await _multiModalService.stopVoiceInput();
      setState(() {
        _isVoiceInputActive = false;
      });
    } else {
      // Start voice input
      setState(() {
        _isVoiceInputActive = true;
      });

      final result = await _multiModalService.startVoiceInput(
        timeout: const Duration(seconds: 30),
        onPartialResult: (partialText) {
          // Show partial results in real-time
          setState(() {
            _controller.text = partialText;
          });
        },
      );

      setState(() {
        _isVoiceInputActive = false;
      });

      if (result.success && result.processedText != null) {
        _controller.text = result.processedText!;
        _focusNode.requestFocus();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice input captured: "${result.processedText}"'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice input failed: ${result.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    // Show options for camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final result = await _multiModalService.captureImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (result.success && result.analysis != null) {
      // Add image context to symptoms
      final imageContext = 'Image captured: ${result.analysis!.suggestedType}';
      final currentText = _controller.text;
      if (currentText.isEmpty) {
        _controller.text = imageContext;
      } else {
        _controller.text = '$currentText\n\n$imageContext';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image captured: ${result.analysis!.qualityAssessment}'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image capture failed: ${result.error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _QuickSymptomChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _QuickSymptomChip({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: enabled ? onTap : null,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: enabled
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }
}
