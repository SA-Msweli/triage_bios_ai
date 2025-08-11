import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Responsive vitals input and display widget
class VitalsDisplayWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const VitalsDisplayWidget({
    super.key,
    required this.onDataChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<VitalsDisplayWidget> createState() => _VitalsDisplayWidgetState();
}

class _VitalsDisplayWidgetState extends State<VitalsDisplayWidget> {
  final _heartRateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _oxygenController = TextEditingController();

  bool _hasWearableDevice = false;
  bool _isConnecting = false;
  String _deviceStatus = 'Not connected';

  @override
  void dispose() {
    _heartRateController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _temperatureController.dispose();
    _oxygenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vital Signs',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect a wearable device or manually enter your vital signs.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Wearable device connection
              _buildWearableConnection(),
              const SizedBox(height: 32),

              if (isWideScreen) ...[
                // Wide screen layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildManualVitalsInput()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildVitalsSummary()),
                  ],
                ),
              ] else ...[
                // Narrow screen layout
                _buildManualVitalsInput(),
                const SizedBox(height: 32),
                _buildVitalsSummary(),
              ],

              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWearableConnection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.watch, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Wearable Device',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Connect your smartwatch or fitness tracker for automatic vital signs monitoring.',
              style: Theme.of(context).textTheme.bodyMedium,
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
                  _deviceStatus,
                  style: TextStyle(
                    color: _hasWearableDevice
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: _hasWearableDevice
                        ? FontWeight.bold
                        : FontWeight.normal,
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
                  ElevatedButton(
                    onPressed: _connectWearableDevice,
                    child: Text(
                      _hasWearableDevice ? 'Disconnect' : 'Connect Device',
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

            // Heart Rate and Oxygen Saturation
            Row(
              children: [
                Expanded(
                  child: _buildVitalInput(
                    controller: _heartRateController,
                    label: 'Heart Rate',
                    unit: 'bpm',
                    icon: Icons.favorite,
                    color: Colors.red,
                    hint: '60-100',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVitalInput(
                    controller: _oxygenController,
                    label: 'Oxygen Saturation',
                    unit: '%',
                    icon: Icons.air,
                    color: Colors.blue,
                    hint: '95-100',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Blood Pressure
            Row(
              children: [
                Expanded(
                  child: _buildVitalInput(
                    controller: _systolicController,
                    label: 'Systolic BP',
                    unit: 'mmHg',
                    icon: Icons.monitor_heart,
                    color: Colors.purple,
                    hint: '90-140',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                Text('/', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVitalInput(
                    controller: _diastolicController,
                    label: 'Diastolic BP',
                    unit: 'mmHg',
                    icon: Icons.monitor_heart,
                    color: Colors.purple,
                    hint: '60-90',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Temperature
            _buildVitalInput(
              controller: _temperatureController,
              label: 'Body Temperature',
              unit: '°F',
              icon: Icons.thermostat,
              color: Colors.orange,
              hint: '97.0-99.5',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalInput({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
    required String hint,
    required List<TextInputFormatter> inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: unit,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          inputFormatters: inputFormatters,
          onChanged: (_) => _updateVitalsData(),
        ),
      ],
    );
  }

  Widget _buildVitalsSummary() {
    final vitals = _getCurrentVitals();
    if (vitals.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  'Vitals Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: vitals.entries.map((entry) {
                final status = _getVitalStatus(entry.key, entry.value);
                return _buildVitalChip(entry.key, entry.value, status);
              }).toList(),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getVitalsRecommendation(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalChip(String vital, dynamic value, String status) {
    Color color;
    switch (status) {
      case 'normal':
        color = Colors.green;
        break;
      case 'warning':
        color = Colors.orange;
        break;
      case 'critical':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      avatar: Icon(
        status == 'normal'
            ? Icons.check_circle
            : status == 'warning'
            ? Icons.warning
            : Icons.error,
        color: color,
        size: 16,
      ),
      label: Text('$vital: $value'),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _canProceed() ? widget.onNext : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Find Hospital'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  // Helper methods

  Future<void> _connectWearableDevice() async {
    setState(() {
      _isConnecting = true;
    });

    // Simulate device connection
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isConnecting = false;
      _hasWearableDevice = !_hasWearableDevice;
      _deviceStatus = _hasWearableDevice
          ? 'Apple Watch connected'
          : 'Not connected';
    });

    if (_hasWearableDevice) {
      // Simulate receiving vitals from device
      _simulateWearableVitals();
    } else {
      // Clear vitals when disconnecting
      _clearVitals();
    }
  }

  void _simulateWearableVitals() {
    setState(() {
      _heartRateController.text = '72';
      _systolicController.text = '120';
      _diastolicController.text = '80';
      _temperatureController.text = '98.6';
      _oxygenController.text = '98';
    });
    _updateVitalsData();
  }

  void _clearVitals() {
    setState(() {
      _heartRateController.clear();
      _systolicController.clear();
      _diastolicController.clear();
      _temperatureController.clear();
      _oxygenController.clear();
    });
    _updateVitalsData();
  }

  Map<String, dynamic> _getCurrentVitals() {
    final vitals = <String, dynamic>{};

    if (_heartRateController.text.isNotEmpty) {
      vitals['Heart Rate'] = '${_heartRateController.text} bpm';
    }
    if (_systolicController.text.isNotEmpty &&
        _diastolicController.text.isNotEmpty) {
      vitals['Blood Pressure'] =
          '${_systolicController.text}/${_diastolicController.text} mmHg';
    }
    if (_temperatureController.text.isNotEmpty) {
      vitals['Temperature'] = '${_temperatureController.text}°F';
    }
    if (_oxygenController.text.isNotEmpty) {
      vitals['Oxygen Sat'] = '${_oxygenController.text}%';
    }

    return vitals;
  }

  String _getVitalStatus(String vital, dynamic value) {
    switch (vital) {
      case 'Heart Rate':
        final hr = int.tryParse(_heartRateController.text) ?? 0;
        if (hr < 60 || hr > 100) return 'warning';
        if (hr < 50 || hr > 120) return 'critical';
        return 'normal';
      case 'Blood Pressure':
        final systolic = int.tryParse(_systolicController.text) ?? 0;
        final diastolic = int.tryParse(_diastolicController.text) ?? 0;
        if (systolic > 140 || diastolic > 90) return 'warning';
        if (systolic > 180 || diastolic > 120) return 'critical';
        return 'normal';
      case 'Temperature':
        final temp = double.tryParse(_temperatureController.text) ?? 0;
        if (temp > 99.5 || temp < 97.0) return 'warning';
        if (temp > 101.5) return 'critical';
        return 'normal';
      case 'Oxygen Sat':
        final o2 = int.tryParse(_oxygenController.text) ?? 0;
        if (o2 < 95) return 'warning';
        if (o2 < 90) return 'critical';
        return 'normal';
      default:
        return 'normal';
    }
  }

  String _getVitalsRecommendation() {
    final vitals = _getCurrentVitals();
    final warnings = vitals.entries
        .where((e) => _getVitalStatus(e.key, e.value) != 'normal')
        .toList();

    if (warnings.isEmpty) {
      return 'Your vital signs appear to be within normal ranges.';
    } else if (warnings.any(
      (e) => _getVitalStatus(e.key, e.value) == 'critical',
    )) {
      return 'Some vital signs are concerning. You will be prioritized for immediate care.';
    } else {
      return 'Some vital signs are outside normal ranges. This will be considered in your triage assessment.';
    }
  }

  bool _canProceed() {
    return _getCurrentVitals().isNotEmpty;
  }

  void _updateVitalsData() {
    final vitals = _getCurrentVitals();
    final vitalsSeverityBoost = _calculateVitalsSeverityBoost();

    widget.onDataChanged({
      'vitals': vitals,
      'hasWearableDevice': _hasWearableDevice,
      'deviceStatus': _deviceStatus,
      'vitalsSeverityBoost': vitalsSeverityBoost,
    });
  }

  double _calculateVitalsSeverityBoost() {
    double boost = 0.0;

    // Heart rate boost
    final hr = int.tryParse(_heartRateController.text) ?? 0;
    if (hr > 120 || hr < 50) {
      boost += 2.0;
    } else if (hr > 100 || hr < 60) {
      boost += 1.0;
    }

    // Oxygen saturation boost
    final o2 = int.tryParse(_oxygenController.text) ?? 100;
    if (o2 < 90) {
      boost += 3.0;
    } else if (o2 < 95) {
      boost += 1.5;
    }

    // Temperature boost
    final temp = double.tryParse(_temperatureController.text) ?? 98.6;
    if (temp > 103) {
      boost += 2.5;
    } else if (temp > 101.5) {
      boost += 1.5;
    }

    // Blood pressure boost
    final systolic = int.tryParse(_systolicController.text) ?? 120;
    final diastolic = int.tryParse(_diastolicController.text) ?? 80;
    if (systolic > 180 || diastolic > 120) {
      boost += 3.0;
    } else if (systolic < 90 || diastolic < 60) {
      boost += 2.0;
    }

    return boost.clamp(0.0, 3.0);
  }
}
