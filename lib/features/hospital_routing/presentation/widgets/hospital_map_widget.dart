import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/hospital.dart';
import '../../data/services/hospital_service.dart';

class HospitalMapWidget extends StatefulWidget {
  final double? severityScore;
  final Function(Hospital)? onHospitalSelected;

  const HospitalMapWidget({
    super.key,
    this.severityScore,
    this.onHospitalSelected,
  });

  @override
  State<HospitalMapWidget> createState() => _HospitalMapWidgetState();
}

class _HospitalMapWidgetState extends State<HospitalMapWidget> {
  final Logger _logger = Logger();
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<Hospital> _hospitals = [];
  Hospital? _selectedHospital;
  Hospital? _recommendedHospital;
  bool _isLoading = true;
  String? _error;

  // Default location (NYC) if location services are unavailable
  static const LatLng _defaultLocation = LatLng(40.7589, -73.9851);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current location
      await _getCurrentLocation();

      // Load nearby hospitals
      await _loadNearbyHospitals();

      // Get recommendation if severity score is provided
      if (widget.severityScore != null) {
        await _getRecommendation();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Failed to initialize map: $e');
      setState(() {
        _error = 'Failed to load hospital data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.w(
          'Location permissions denied forever, using default location',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        _logger.w('Location permissions denied, using default location');
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _logger.i(
        'Current location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
      );
    } catch (e) {
      _logger.w('Failed to get current location: $e');
      // Will use default location
    }
  }

  Future<void> _loadNearbyHospitals() async {
    final lat = _currentPosition?.latitude ?? _defaultLocation.latitude;
    final lng = _currentPosition?.longitude ?? _defaultLocation.longitude;

    _hospitals = await HospitalService().getNearbyHospitals(
      latitude: lat,
      longitude: lng,
      radiusMiles: 25.0,
    );

    _logger.i('Loaded ${_hospitals.length} nearby hospitals');
  }

  Future<void> _getRecommendation() async {
    if (widget.severityScore == null) return;

    final lat = _currentPosition?.latitude ?? _defaultLocation.latitude;
    final lng = _currentPosition?.longitude ?? _defaultLocation.longitude;

    _recommendedHospital = await HospitalService().getOptimalHospital(
      latitude: lat,
      longitude: lng,
      severityScore: widget.severityScore!,
    );

    if (_recommendedHospital != null) {
      _logger.i('Recommended hospital: ${_recommendedHospital!.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading nearby hospitals...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Map',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _initializeMap, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Map
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : _defaultLocation,
              zoom: 12.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
        ),

        // Hospital info panel
        if (_selectedHospital != null) _buildHospitalInfoPanel(),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Add hospital markers
    for (final hospital in _hospitals) {
      final isRecommended = _recommendedHospital?.id == hospital.id;

      markers.add(
        Marker(
          markerId: MarkerId(hospital.id),
          position: LatLng(hospital.latitude, hospital.longitude),
          icon: _getHospitalIcon(hospital, isRecommended),
          infoWindow: InfoWindow(
            title: hospital.name,
            snippet: '${hospital.capacity.availableBeds} beds available',
          ),
          onTap: () {
            setState(() {
              _selectedHospital = hospital;
            });
            widget.onHospitalSelected?.call(hospital);
          },
        ),
      );
    }

    return markers;
  }

  BitmapDescriptor _getHospitalIcon(Hospital hospital, bool isRecommended) {
    if (isRecommended) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (hospital.capacity.availableBeds == 0) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (hospital.capacity.occupancyRate > 0.85) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  Widget _buildHospitalInfoPanel() {
    final hospital = _selectedHospital!;
    final distance = _currentPosition != null
        ? hospital.distanceFrom(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (distance != null)
                      Text(
                        '${distance.toStringAsFixed(1)} miles away',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (_recommendedHospital?.id == hospital.id)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'RECOMMENDED',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedHospital = null;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Capacity info
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.bed,
                label: '${hospital.capacity.availableBeds} beds',
                color: hospital.capacity.availableBeds > 10
                    ? Colors.green
                    : hospital.capacity.availableBeds > 0
                    ? Colors.orange
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                icon: Icons.access_time,
                label:
                    '${hospital.performance.averageWaitTime.toInt()} min wait',
                color: hospital.performance.averageWaitTime < 30
                    ? Colors.green
                    : hospital.performance.averageWaitTime < 60
                    ? Colors.orange
                    : Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callHospital(hospital),
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _navigateToHospital(hospital),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _callHospital(Hospital hospital) {
    // In a real app, this would use url_launcher to make a phone call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${hospital.name}: ${hospital.phoneNumber}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _navigateToHospital(Hospital hospital) {
    // In a real app, this would open the maps app for navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening navigation to ${hospital.name}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}
