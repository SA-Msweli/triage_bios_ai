import 'package:flutter/material.dart';
import '../../../../shared/services/fhir_service.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';

/// Responsive hospital map display widget
class HospitalMapWidget extends StatefulWidget {
  final List<HospitalCapacity> hospitals;
  final HospitalCapacity? selectedHospital;

  const HospitalMapWidget({
    super.key,
    required this.hospitals,
    this.selectedHospital,
  });

  @override
  State<HospitalMapWidget> createState() => _HospitalMapWidgetState();
}

class _HospitalMapWidgetState extends State<HospitalMapWidget> {
  HospitalCapacity? _hoveredHospital;

  @override
  Widget build(BuildContext context) {
    return ConstrainedResponsiveContainer.hospitalMap(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Map background (simulated)
              _buildMapBackground(),

              // Hospital markers
              ...widget.hospitals.map(
                (hospital) => _buildHospitalMarker(hospital),
              ),

              // Hospital info overlay
              if (_hoveredHospital != null)
                _buildHospitalInfoOverlay(_hoveredHospital!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.green.shade50,
            Colors.grey.shade100,
          ],
        ),
      ),
      child: CustomPaint(painter: MapGridPainter()),
    );
  }

  Widget _buildHospitalMarker(HospitalCapacity hospital) {
    final isSelected = widget.selectedHospital?.id == hospital.id;
    final isHovered = _hoveredHospital?.id == hospital.id;

    // Calculate position based on lat/lng (simplified)
    final left = _latLngToPixel(hospital.longitude, isLongitude: true);
    final top = _latLngToPixel(hospital.latitude, isLongitude: false);

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredHospital = hospital),
        onExit: (_) => setState(() => _hoveredHospital = null),
        child: GestureDetector(
          onTap: () => _showHospitalDetails(hospital),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected || isHovered ? 40 : 32,
            height: isSelected || isHovered ? 40 : 32,
            decoration: BoxDecoration(
              color: _getHospitalMarkerColor(hospital),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: isSelected || isHovered ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.local_hospital,
              color: Colors.white,
              size: isSelected || isHovered ? 20 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalInfoOverlay(HospitalCapacity hospital) {
    return Positioned(
      top: 16,
      left: 16,
      child: ConstrainedResponsiveContainer(
        minWidth: 200,
        maxWidth: ResponsiveBreakpoints.isMobile(context) ? 200 : 250,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hospital.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.bed, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${hospital.availableBeds}/${hospital.totalBeds} beds',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Row(
                children: [
                  Icon(Icons.emergency, size: 16, color: Colors.red.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${hospital.emergencyBeds} emergency',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (hospital.distanceKm != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${hospital.distanceKm!.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Capacity indicator
              Row(
                children: [
                  Text(
                    'Capacity: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: hospital.occupancyRate,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getCapacityColor(hospital.occupancyRate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(hospital.occupancyRate * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getCapacityColor(hospital.occupancyRate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getHospitalMarkerColor(HospitalCapacity hospital) {
    if (widget.selectedHospital?.id == hospital.id) {
      return Colors.blue.shade600;
    }

    final occupancyRate = hospital.occupancyRate;
    if (occupancyRate > 0.9) {
      return Colors.red.shade600;
    } else if (occupancyRate > 0.8) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  Color _getCapacityColor(double occupancyRate) {
    if (occupancyRate > 0.9) {
      return Colors.red.shade600;
    } else if (occupancyRate > 0.8) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  double _latLngToPixel(double coordinate, {required bool isLongitude}) {
    // Simplified conversion for demo purposes
    // In a real implementation, this would use proper map projection
    if (isLongitude) {
      // Longitude to X coordinate
      return ((coordinate + 74.0060) * 1000).clamp(20.0, 350.0);
    } else {
      // Latitude to Y coordinate (inverted)
      return (400 - (coordinate - 40.7128) * 2000).clamp(20.0, 380.0);
    }
  }

  void _showHospitalDetails(HospitalCapacity hospital) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hospital.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Total Beds', '${hospital.totalBeds}'),
            _buildDetailRow('Available Beds', '${hospital.availableBeds}'),
            _buildDetailRow('Emergency Beds', '${hospital.emergencyBeds}'),
            _buildDetailRow('ICU Beds', '${hospital.icuBeds}'),
            if (hospital.distanceKm != null)
              _buildDetailRow(
                'Distance',
                '${hospital.distanceKm!.toStringAsFixed(1)} km',
              ),
            _buildDetailRow(
              'Occupancy Rate',
              '${(hospital.occupancyRate * 100).toStringAsFixed(1)}%',
            ),
            _buildDetailRow('Last Updated', _formatTime(hospital.lastUpdated)),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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
}

/// Custom painter for map grid background
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Draw grid lines
    for (int i = 0; i < size.width; i += 40) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }

    for (int i = 0; i < size.height; i += 40) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }

    // Draw some "roads" for visual appeal
    final roadPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 3;

    // Horizontal "roads"
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.3),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      roadPaint,
    );

    // Vertical "roads"
    canvas.drawLine(
      Offset(size.width * 0.4, 0),
      Offset(size.width * 0.4, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, 0),
      Offset(size.width * 0.8, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
