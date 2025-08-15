import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/hospital.dart';
import '../../data/services/hospital_service.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/utils/overflow_detection.dart';

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
  GoogleMapController?
  _mapController; // Used in onMapCreated callback for future map operations
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
    // Wrap the entire widget with responsive constraints and overflow detection
    return ConstrainedResponsiveContainer.hospitalMap(
      child: Column(
        children: [
          // Map container with responsive height constraints
          Expanded(child: _buildMapContent(context)),

          // Hospital info panel with responsive behavior
          if (_selectedHospital != null)
            _buildResponsiveHospitalInfoPanel(context),
        ],
      ),
    ).withOverflowDetection(debugName: 'Hospital Map Widget');
  }

  Widget _buildMapContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    return _buildMap(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: isMobile ? 3.0 : 4.0),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Loading nearby hospitals...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 14 : 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Center(
      child: Padding(
        padding: ResponsiveBreakpoints.getResponsivePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isMobile ? 48 : 64,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              'Error Loading Map',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: isMobile ? 18 : 24),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 12 : 14),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            ConstrainedResponsiveContainer.button(
              child: FilledButton.icon(
                onPressed: _initializeMap,
                icon: Icon(Icons.refresh, size: isMobile ? 18 : 20),
                label: Text(
                  'Retry',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultLocation,
        zoom: isMobile
            ? 11.0
            : 12.0, // Slightly zoomed out on mobile for better overview
      ),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _onMapCreated();
      },
      markers: _buildMarkers(),
      myLocationEnabled: true,
      myLocationButtonEnabled: !isMobile, // Hide on mobile to save space
      compassEnabled: !isMobile, // Hide on mobile to save space
      mapToolbarEnabled: false,
      zoomControlsEnabled:
          isMobile, // Show zoom controls on mobile since other controls are hidden
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled:
          !isMobile, // Disable tilt on mobile for simpler interaction
      minMaxZoomPreference: MinMaxZoomPreference(
        isMobile ? 10.0 : 8.0, // Minimum zoom
        18.0, // Maximum zoom
      ),
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

  Widget _buildResponsiveHospitalInfoPanel(BuildContext context) {
    final hospital = _selectedHospital!;
    final distance = _currentPosition != null
        ? hospital.distanceFrom(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          )
        : null;

    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Container(
      width: double.infinity,
      padding: ResponsiveBreakpoints.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : null,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: isMobile
              ? 200
              : 250, // Limit panel height to prevent map domination
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHospitalHeader(context, hospital, distance),
              SizedBox(height: isMobile ? 8 : 12),
              _buildCapacityInfo(context, hospital),
              SizedBox(height: isMobile ? 8 : 12),
              _buildActionButtons(context, hospital),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalHeader(
    BuildContext context,
    Hospital hospital,
    double? distance,
  ) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hospital.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                ),
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (distance != null) ...[
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  '${distance.toStringAsFixed(1)} miles away',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: isMobile ? 12 : 14),
                ),
              ],
            ],
          ),
        ),
        if (_recommendedHospital?.id == hospital.id) ...[
          SizedBox(width: isMobile ? 8 : 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            ),
            child: Text(
              isMobile ? 'REC' : 'RECOMMENDED',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 10 : 12,
              ),
            ),
          ),
        ],
        SizedBox(width: isMobile ? 4 : 8),
        IconButton(
          onPressed: () {
            setState(() {
              _selectedHospital = null;
            });
          },
          icon: Icon(Icons.close, size: isMobile ? 20 : 24),
          constraints: BoxConstraints(
            minWidth: isMobile ? 36 : 44,
            minHeight: isMobile ? 36 : 44,
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityInfo(BuildContext context, Hospital hospital) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile) {
      // Stack info chips vertically on mobile for better readability
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.bed,
                  label: '${hospital.capacity.availableBeds} beds',
                  color: hospital.capacity.availableBeds > 10
                      ? Colors.green
                      : hospital.capacity.availableBeds > 0
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.access_time,
                  label: '${hospital.performance.averageWaitTime.toInt()} min',
                  color: hospital.performance.averageWaitTime < 30
                      ? Colors.green
                      : hospital.performance.averageWaitTime < 60
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Horizontal layout for tablet and desktop
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildInfoChip(
            icon: Icons.bed,
            label: '${hospital.capacity.availableBeds} beds available',
            color: hospital.capacity.availableBeds > 10
                ? Colors.green
                : hospital.capacity.availableBeds > 0
                ? Colors.orange
                : Colors.red,
          ),
          _buildInfoChip(
            icon: Icons.access_time,
            label: '${hospital.performance.averageWaitTime.toInt()} min wait',
            color: hospital.performance.averageWaitTime < 30
                ? Colors.green
                : hospital.performance.averageWaitTime < 60
                ? Colors.orange
                : Colors.red,
          ),
        ],
      );
    }
  }

  Widget _buildActionButtons(BuildContext context, Hospital hospital) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Row(
      children: [
        Expanded(
          child: ConstrainedResponsiveContainer.button(
            child: OutlinedButton.icon(
              onPressed: () => _callHospital(hospital),
              icon: Icon(Icons.phone, size: isMobile ? 16 : 18),
              label: Text(
                'Call',
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            ),
          ),
        ),
        SizedBox(width: isMobile ? 8 : 12),
        Expanded(
          child: ConstrainedResponsiveContainer.button(
            child: FilledButton.icon(
              onPressed: () => _navigateToHospital(hospital),
              icon: Icon(Icons.directions, size: isMobile ? 16 : 18),
              label: Text(
                'Navigate',
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: color),
          SizedBox(width: isMobile ? 3 : 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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

  /// Called when the map is created and controller is available
  void _onMapCreated() {
    _logger.i('Map created and controller initialized');

    // If we have a recommended hospital, animate to it
    if (_recommendedHospital != null) {
      _animateToHospital(_recommendedHospital!);
    }
  }

  /// Animate map camera to a specific hospital
  Future<void> _animateToHospital(Hospital hospital) async {
    if (_mapController == null) return;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(hospital.latitude, hospital.longitude),
            zoom: 15.0,
          ),
        ),
      );
      _logger.i('Animated to hospital: ${hospital.name}');
    } catch (e) {
      _logger.e('Failed to animate to hospital: $e');
    }
  }
}
