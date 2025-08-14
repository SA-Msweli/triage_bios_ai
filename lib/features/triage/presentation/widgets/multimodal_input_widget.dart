import 'package:flutter/material.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';

/// Widget for multimodal input (voice, text, image) in triage assessment
class MultimodalInputWidget extends StatefulWidget {
  final bool enableVoice;
  final bool enableText;
  final bool enableImage;
  final Function(Map<String, dynamic>)? onInputReceived;

  const MultimodalInputWidget({
    super.key,
    this.enableVoice = true,
    this.enableText = true,
    this.enableImage = true,
    this.onInputReceived,
  });

  @override
  State<MultimodalInputWidget> createState() => _MultimodalInputWidgetState();
}

class _MultimodalInputWidgetState extends State<MultimodalInputWidget> {
  int _selectedInputMethod = 0;
  bool _isListening = false;
  bool _isProcessingVoice = false;
  bool _isProcessingImage = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedResponsiveContainer.card(
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.input, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Describe Your Symptoms',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input method tabs
              _buildInputMethodTabs(),
              const SizedBox(height: 16),

              // Voice input section
              if (widget.enableVoice && _selectedInputMethod == 0) ...[
                _buildVoiceInputSection(),
                const SizedBox(height: 16),
              ],

              // Text input section
              if (widget.enableText && _selectedInputMethod == 1) ...[
                _buildTextInputSection(),
                const SizedBox(height: 16),
              ],

              // Image input section
              if (widget.enableImage && _selectedInputMethod == 2) ...[
                _buildImageInputSection(),
                const SizedBox(height: 16),
              ],

              // Processing status
              if (_isProcessingVoice || _isProcessingImage) ...[
                _buildProcessingStatus(),
                const SizedBox(height: 16),
              ],

              // Results summary
              _buildResultsSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputMethodTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (widget.enableVoice)
            Expanded(
              child: _buildTabButton('Voice', Icons.mic, _isListening, 0),
            ),
          if (widget.enableText)
            Expanded(
              child: _buildTabButton('Text', Icons.text_fields, false, 1),
            ),
          if (widget.enableImage)
            Expanded(
              child: _buildTabButton('Image', Icons.camera_alt, false, 2),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    IconData icon,
    bool isActive,
    int index,
  ) {
    final isSelected = _selectedInputMethod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedInputMethod = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInputSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _isListening ? Colors.red.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isListening ? Colors.red.shade200 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 48,
                color: _isListening ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _isListening ? 'Listening...' : 'Tap to start recording',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Describe your symptoms in your own words',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _toggleVoiceRecording,
          icon: Icon(_isListening ? Icons.stop : Icons.mic),
          label: Text(_isListening ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isListening ? Colors.red : null,
            foregroundColor: _isListening ? Colors.white : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText:
                'Describe your symptoms, pain level, duration, and any other relevant details...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _processTextInput,
          child: const Text('Submit Symptoms'),
        ),
      ],
    );
  }

  Widget _buildImageInputSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 48, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text(
                'Take a photo of visible symptoms',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Photos help AI provide better assessment',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('From Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Processing your input...',
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Input Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your symptoms have been recorded and will be analyzed by our AI system.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _toggleVoiceRecording() {
    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      // Start voice recording
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isListening) {
          setState(() {
            _isListening = false;
            _isProcessingVoice = true;
          });

          // Simulate processing
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isProcessingVoice = false;
              });
              _notifyInputReceived({
                'type': 'voice',
                'content': 'Voice input processed',
              });
            }
          });
        }
      });
    }
  }

  void _processTextInput() {
    if (_textController.text.isNotEmpty) {
      _notifyInputReceived({'type': 'text', 'content': _textController.text});
      _textController.clear();
    }
  }

  void _takePhoto() {
    setState(() {
      _isProcessingImage = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
        _notifyInputReceived({'type': 'image', 'content': 'Photo captured'});
      }
    });
  }

  void _selectFromGallery() {
    setState(() {
      _isProcessingImage = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
        _notifyInputReceived({
          'type': 'image',
          'content': 'Image selected from gallery',
        });
      }
    });
  }

  void _notifyInputReceived(Map<String, dynamic> input) {
    widget.onInputReceived?.call(input);
  }
}
