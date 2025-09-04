import 'package:flutter/material.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/widgets/responsive_layouts.dart';
import '../../../../shared/utils/overflow_detection.dart';

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
  String? _selectedImagePath;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {}); // Update UI when text changes
    });
  }

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
    final availableTabs = <Widget>[];

    if (widget.enableVoice) {
      availableTabs.add(_buildTabButton('Voice', Icons.mic, _isListening, 0));
    }
    if (widget.enableText) {
      availableTabs.add(_buildTabButton('Text', Icons.text_fields, false, 1));
    }
    if (widget.enableImage) {
      availableTabs.add(_buildTabButton('Image', Icons.camera_alt, false, 2));
    }

    return ConstrainedResponsiveContainer(
      maxWidth: 600,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ResponsiveBreakpoints.isMobile(context)
            ? Column(
                children: availableTabs
                    .map(
                      (tab) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SizedBox(width: double.infinity, child: tab),
                      ),
                    )
                    .toList(),
              )
            : Row(
                children: availableTabs
                    .map((tab) => Expanded(child: tab))
                    .toList(),
              ),
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
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.button(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedInputMethod = index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 16 : 12,
              horizontal: isMobile ? 20 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isMobile ? 24 : 20,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: isMobile ? 12 : 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: isMobile ? 16 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceInputSection() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isTablet = ResponsiveBreakpoints.isTablet(context);

    return Column(
      children: [
        ConstrainedResponsiveContainer(
          minHeight: isMobile ? 180 : 200,
          maxHeight: isMobile ? 220 : 280,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: _isListening ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isListening
                    ? Colors.red.shade200
                    : Colors.grey.shade200,
                width: _isListening ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Responsive microphone icon with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(_isListening ? 16 : 12),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: isMobile
                        ? 40
                        : isTablet
                        ? 48
                        : 56,
                    color: _isListening ? Colors.red : Colors.grey,
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  _isListening ? 'Listening...' : 'Tap to start recording',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: _isListening
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  'Describe your symptoms in your own words',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: isMobile ? 12 : 14),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                // Voice level indicator when listening
                if (_isListening) ...[
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildVoiceLevelIndicator(),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // Responsive voice control buttons
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: 12,
          children: [
            ConstrainedResponsiveContainer.button(
              child: ElevatedButton.icon(
                onPressed: _toggleVoiceRecording,
                icon: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  size: isMobile ? 20 : 18,
                ),
                label: Text(
                  _isListening ? 'Stop Recording' : 'Start Recording',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening ? Colors.red : null,
                  foregroundColor: _isListening ? Colors.white : null,
                  minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 16,
                    vertical: isMobile ? 14 : 12,
                  ),
                ),
              ),
            ),
            if (_isListening)
              ConstrainedResponsiveContainer.button(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isListening = false),
                  icon: Icon(Icons.pause, size: isMobile ? 20 : 18),
                  label: const Text('Pause', overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 16,
                      vertical: isMobile ? 14 : 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ).withOverflowDetection(debugName: 'Voice Input Section');
  }

  Widget _buildVoiceLevelIndicator() {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 100)),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: _isListening ? (8 + (index * 2.0)) : 4,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextInputSection() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive text input with proper constraints (200-500px width)
        ConstrainedResponsiveContainer(
          minWidth: 200,
          maxWidth: 500,
          child: TextField(
            controller: _textController,
            maxLines: isMobile ? 4 : 5,
            minLines: isMobile ? 3 : 4,
            decoration: InputDecoration(
              hintText: isMobile
                  ? 'Describe your symptoms, pain level, duration...'
                  : 'Describe your symptoms, pain level, duration, and any other relevant details...',
              border: const OutlineInputBorder(),
              contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
              hintStyle: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
            style: TextStyle(fontSize: isMobile ? 14 : 16),
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // Character counter
        Row(
          children: [
            Expanded(
              child: Text(
                '${_textController.text.length}/1000 characters',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _textController.text.length > 800
                      ? Colors.orange
                      : Colors.grey,
                ),
              ),
            ),
            if (_textController.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _textController.clear();
                  });
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),

        // Responsive submit button
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: 12,
          children: [
            ConstrainedResponsiveContainer.button(
              child: ElevatedButton.icon(
                onPressed: _textController.text.trim().isNotEmpty
                    ? _processTextInput
                    : null,
                icon: Icon(Icons.send, size: isMobile ? 20 : 18),
                label: const Text(
                  'Submit Symptoms',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 16,
                    vertical: isMobile ? 14 : 12,
                  ),
                ),
              ),
            ),
            ConstrainedResponsiveContainer.button(
              child: OutlinedButton.icon(
                onPressed: _showTextInputHelp,
                icon: Icon(Icons.help_outline, size: isMobile ? 20 : 18),
                label: const Text('Help', overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 16,
                    vertical: isMobile ? 14 : 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).withOverflowDetection(debugName: 'Text Input Section');
  }

  Widget _buildImageInputSection() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isTablet = ResponsiveBreakpoints.isTablet(context);
    final hasImage = _selectedImagePath != null || _capturedImagePath != null;

    return Column(
      children: [
        // Responsive image preview area with aspect ratio preservation
        ConstrainedResponsiveContainer(
          minHeight: isMobile ? 180 : 200,
          maxHeight: isMobile
              ? 300
              : isTablet
              ? 350
              : 400,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.blue.shade200 : Colors.grey.shade200,
                width: hasImage ? 2 : 1,
              ),
            ),
            child: hasImage ? _buildImagePreview() : _buildImagePlaceholder(),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // Image info and actions
        if (hasImage) ...[
          _buildImageInfo(),
          SizedBox(height: isMobile ? 12 : 16),
        ],

        // Responsive image action buttons
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: 12,
          children: [
            ConstrainedResponsiveContainer.button(
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: Icon(Icons.camera_alt, size: isMobile ? 20 : 18),
                label: Text(
                  hasImage ? 'Retake Photo' : 'Take Photo',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 16,
                    vertical: isMobile ? 14 : 12,
                  ),
                ),
              ),
            ),
            ConstrainedResponsiveContainer.button(
              child: OutlinedButton.icon(
                onPressed: _selectFromGallery,
                icon: Icon(Icons.photo_library, size: isMobile ? 20 : 18),
                label: Text(
                  hasImage ? 'Choose Different' : 'From Gallery',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 16,
                    vertical: isMobile ? 14 : 12,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Additional image actions when image is selected
        if (hasImage) ...[
          SizedBox(height: isMobile ? 8 : 12),
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 2,
            spacing: 12,
            children: [
              ConstrainedResponsiveContainer.button(
                child: ElevatedButton.icon(
                  onPressed: _processImageInput,
                  icon: Icon(Icons.send, size: isMobile ? 20 : 18),
                  label: const Text(
                    'Submit Image',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  ),
                ),
              ),
              ConstrainedResponsiveContainer.button(
                child: OutlinedButton.icon(
                  onPressed: _clearImage,
                  icon: Icon(Icons.clear, size: isMobile ? 20 : 18),
                  label: const Text('Remove', overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: Size(double.infinity, isMobile ? 48 : 44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ).withOverflowDetection(debugName: 'Image Input Section');
  }

  Widget _buildImagePlaceholder() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt,
            size: isMobile ? 40 : 48,
            color: Colors.grey.shade600,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Take a photo of visible symptoms',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: isMobile ? 16 : 18),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Photos help AI provide better assessment',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: isMobile ? 12 : 14),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        11,
      ), // Slightly smaller than container
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder for actual image - in real implementation would show the image
          Container(
            color: Colors.blue.shade50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 64, color: Colors.blue.shade300),
                const SizedBox(height: 8),
                Text(
                  'Image Preview',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedImagePath ?? _capturedImagePath ?? 'image.jpg',
                  style: TextStyle(color: Colors.blue.shade500, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // Image overlay with controls
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.check_circle, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageInfo() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Image ready for AI analysis. The image will be processed to identify visible symptoms.',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: isMobile ? 12 : 14,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStatus() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: isMobile ? 18 : 20,
              height: isMobile ? 18 : 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Text(
                _isProcessingVoice
                    ? 'Processing voice input...'
                    : _isProcessingImage
                    ? 'Processing image...'
                    : 'Processing your input...',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: isMobile ? 14 : 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSummary() {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final hasAnyInput =
        _textController.text.isNotEmpty ||
        _selectedImagePath != null ||
        _capturedImagePath != null;

    if (!hasAnyInput) {
      return const SizedBox.shrink();
    }

    return ConstrainedResponsiveContainer.card(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Input Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: isMobile ? 14 : 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'Your symptoms have been recorded and will be analyzed by our AI system.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.green.shade600,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            if (_textController.text.isNotEmpty) ...[
              SizedBox(height: isMobile ? 6 : 8),
              Text(
                '✓ Text description: ${_textController.text.length} characters',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.green.shade600,
                ),
              ),
            ],
            if (_selectedImagePath != null || _capturedImagePath != null) ...[
              SizedBox(height: isMobile ? 6 : 8),
              Text(
                '✓ Image: ${_selectedImagePath != null ? "Gallery" : "Camera"} photo attached',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ],
        ),
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
    if (_textController.text.trim().isNotEmpty) {
      _notifyInputReceived({
        'type': 'text',
        'content': _textController.text.trim(),
        'length': _textController.text.trim().length,
      });
      _textController.clear();
      setState(() {}); // Refresh UI
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
          _capturedImagePath =
              'captured_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _selectedImagePath = null; // Clear gallery selection
        });
        _notifyInputReceived({
          'type': 'image',
          'content': 'Photo captured',
          'source': 'camera',
          'path': _capturedImagePath,
        });
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
          _selectedImagePath =
              'gallery_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _capturedImagePath = null; // Clear camera capture
        });
        _notifyInputReceived({
          'type': 'image',
          'content': 'Image selected from gallery',
          'source': 'gallery',
          'path': _selectedImagePath,
        });
      }
    });
  }

  void _processImageInput() {
    final imagePath = _selectedImagePath ?? _capturedImagePath;
    if (imagePath != null) {
      _notifyInputReceived({
        'type': 'image_processed',
        'content': 'Image submitted for AI analysis',
        'path': imagePath,
        'source': _selectedImagePath != null ? 'gallery' : 'camera',
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImagePath = null;
      _capturedImagePath = null;
    });
  }

  void _showTextInputHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Symptom Description Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To help our AI provide the best assessment, please include:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                '📍',
                'Location of symptoms (e.g., chest, head, abdomen)',
              ),
              _buildHelpItem(
                '⏱️',
                'Duration (e.g., started 2 hours ago, ongoing for 3 days)',
              ),
              _buildHelpItem(
                '📊',
                'Severity (e.g., mild, moderate, severe, scale 1-10)',
              ),
              _buildHelpItem(
                '🔄',
                'Pattern (e.g., constant, comes and goes, getting worse)',
              ),
              _buildHelpItem(
                '🎯',
                'Triggers (e.g., after eating, during exercise, at rest)',
              ),
              _buildHelpItem('💊', 'What helps or makes it worse'),
              const SizedBox(height: 12),
              Text(
                'Example: "Sharp chest pain on the left side, started 30 minutes ago after climbing stairs. Pain level 7/10, feels like pressure. Taking deep breaths makes it worse."',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
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

  Widget _buildHelpItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _notifyInputReceived(Map<String, dynamic> input) {
    widget.onInputReceived?.call(input);
  }
}
