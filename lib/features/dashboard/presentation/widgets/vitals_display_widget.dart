import 'package:flutter/material.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';

/// Widget for displaying and managing patient vitals data
class VitalsDisplayWidget extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataChanged;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const VitalsDisplayWidget({
    super.key,
    this.onDataChanged,
    this.onNext,
    this.onBack,
  });

  @override
  State<VitalsDisplayWidget> createState() => _VitalsDisplayWidgetState();
}

class _VitalsDisplayWidgetState extends State<VitalsDisplayWidget> {
  bool _hasWearableDevice = false;
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWearableConnection(),
        const SizedBox(height: 16),
        _buildManualVitalsInput(),
      ],
    );
  }

  Widget _buildWearableConnection() {
    return ConstrainedResponsiveContainer.card(
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.watch, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Wearable Device',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Connect your smartwatch or fitness tracker for automatic vital signs monitoring.',
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _hasWearableDevice
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _hasWearableDevice ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _hasWearableDevice ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      color: _hasWearableDevice ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_isConnecting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    ConstrainedResponsiveContainer.button(
                      child: ElevatedButton(
                        onPressed: _connectWearableDevice,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        child: Text(
                          _hasWearableDevice ? 'Disconnect' : 'Connect Device',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
              if (_hasWearableDevice) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Real-time Monitoring Active',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const Text(
                              'Vitals are being automatically updated from your device.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualVitalsInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Entry',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your vital signs manually if you don\'t have a connected device.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showManualEntryDialog,
              child: const Text('Enter Vitals Manually'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.onBack != null)
                  OutlinedButton(
                    onPressed: widget.onBack,
                    child: const Text('Back'),
                  ),
                const Spacer(),
                if (widget.onNext != null)
                  ElevatedButton(
                    onPressed: widget.onNext,
                    child: const Text('Continue'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _connectWearableDevice() {
    setState(() {
      _isConnecting = true;
    });

    // Simulate connection process
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _hasWearableDevice = !_hasWearableDevice;
        });
      }
    });
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Vitals Entry'),
        content: const Text('Manual vitals entry feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
