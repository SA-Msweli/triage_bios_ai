import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../shared/services/multimodal_input_service.dart';
import '../../../../shared/services/watsonx_service.dart';
import '../../../../config/app_config.dart';

/// Enhanced multimodal input widget supporting voice, image, and text input
class MultimodalInputWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onInputReceived;
  final bool enableVoice;
  final bool enableImage;
  final bool enableText;

  const MultimodalInputWidget({
    super.key,
    required this.onInputReceived,
    this.enableVoice = true,
    this.enableImage = true,
    this.enableText = true,
  });

  @override
  State<MultimodalInputWidget> createState() => _MultimodalInputWidgetState();
}

class _MultimodalInputWidgetState extends State<MultimodalInputWidget>
    with TickerProviderStateMixin {
  final MultiModalInputService _multiModalService = MultiModalInputService();
  final WatsonxService _watsonxService = WatsonxService();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isListening = false;
  bool _isProcessingImage = false;
  bool _isProcessingVoice = false;
  String _voiceText = '';
  List<File> _selectedImages = [];
  late AnimationController _voiceAnimationController;
  late Animation<double> _voiceAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
  }

  @override
  void dispose() {
    _textController.dispose();
    _voiceAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await _multiModalService.initialize();
      _watsonxService.initialize(
        apiKey: AppConfig.instance.watsonxApiKey,
        projectId: AppConfig.instance.watsonxProjectId,
      );
    } catch (e) {
      _showError('Failed to initialize multimodal services: $e');
    }
  }

  void _setupAnimations() {
    _voiceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _voiceAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _voiceAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI-Powered Symptom Input',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use voice, images, or text to describe your symptoms. Our AI will analyze all inputs for comprehensive assessment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            // Input method tabs
            _buildInputMethodTabs(),

            const SizedBox(height: 24),

            // Voice input section
            if (widget.enableVoice) ...[
              _buildVoiceInputSection(),
              const SizedBox(height: 16),
            ],

            // Image input section
            if (widget.enableImage) ...[
              _buildImageInputSection(),
              const SizedBox(height: 16),
            ],

            // Text input section
            if (widget.enableText) ...[
              _buildTextInputSection(),
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
              child: _buildTabButton(
                'Voice',
                Icons.mic,
                _isListening,
                () => _toggleVoiceInput(),
              ),
            ),
          if (widget.enableImage)
            Expanded(
              child: _buildTabButton(
                'Image',
                Icons.camera_alt,
                _selectedImages.isNotEmpty,
                () => _selectImage(),
              ),
            ),
          if (widget.enableText)
            Expanded(
              child: _buildTabButton(
                'Text',
                Icons.text_fields,
                _textController.text.isNotEmpty,
                () => _focusTextInput(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isListening
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isListening
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _voiceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _voiceAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isListening ? 'Listening...' : 'Voice Input',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isListening
                          ? 'Speak clearly about your symptoms'
                          : 'Tap to start voice recording',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _toggleVoiceInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening ? Colors.red : null,
                  foregroundColor: _isListening ? Colors.white : null,
                ),
                child: Text(_isListening ? 'Stop' : 'Start'),
              ),
            ],
          ),
          if (_voiceText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transcribed Text:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_voiceText),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image Analysis',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Take photos of visible symptoms or medical documents',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _selectImage(fromCamera: true),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _selectImage(fromCamera: false),
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.text_fields,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Text Description',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Type detailed description of your symptoms',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _textController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe your symptoms in detail...',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _updateResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processing with AI...',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _isProcessingVoice
                      ? 'Analyzing voice input with WatsonX.ai'
                      : 'Processing images with computer vision',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    final hasAnyInput =
        _voiceText.isNotEmpty ||
        _selectedImages.isNotEmpty ||
        _textController.text.isNotEmpty;

    if (!hasAnyInput) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Use any combination of voice, image, or text input to describe your symptoms. The AI will analyze all inputs together.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Input Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_voiceText.isNotEmpty)
            _buildSummaryItem(
              'Voice Input',
              '${_voiceText.length} characters transcribed',
            ),
          if (_selectedImages.isNotEmpty)
            _buildSummaryItem(
              'Images',
              '${_selectedImages.length} image(s) selected',
            ),
          if (_textController.text.isNotEmpty)
            _buildSummaryItem(
              'Text Input',
              '${_textController.text.length} characters typed',
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // Input handling methods
  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _stopVoiceInput();
    } else {
      await _startVoiceInput();
    }
  }

  Future<void> _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _isProcessingVoice = false;
    });

    _voiceAnimationController.repeat(reverse: true);

    try {
      // Simulate voice input for demo
      await Future.delayed(const Duration(seconds: 2));

      // Mock transcription result
      setState(() {
        _voiceText =
            'I have been experiencing chest pain and shortness of breath for the past 2 hours. The pain is sharp and gets worse when I breathe deeply.';
        _isProcessingVoice = true;
      });

      // Simulate AI processing
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        _isProcessingVoice = false;
      });

      _updateResults();
    } catch (e) {
      _showError('Voice input failed: $e');
    }
  }

  Future<void> _stopVoiceInput() async {
    setState(() {
      _isListening = false;
    });
    _voiceAnimationController.stop();
  }

  Future<void> _selectImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
          _isProcessingImage = true;
        });

        // Simulate AI image processing
        await Future.delayed(const Duration(seconds: 2));

        setState(() {
          _isProcessingImage = false;
        });

        _updateResults();
      }
    } catch (e) {
      _showError('Image selection failed: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _updateResults();
  }

  void _focusTextInput() {
    // Focus on text input field
    FocusScope.of(context).requestFocus();
  }

  void _updateResults() {
    final inputData = {
      'voiceText': _voiceText,
      'textInput': _textController.text,
      'imageCount': _selectedImages.length,
      'images': _selectedImages.map((f) => f.path).toList(),
      'hasMultimodalInput': true,
      'inputTypes': [
        if (_voiceText.isNotEmpty) 'voice',
        if (_textController.text.isNotEmpty) 'text',
        if (_selectedImages.isNotEmpty) 'image',
      ],
    };

    widget.onInputReceived(inputData);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
