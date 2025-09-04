import 'package:flutter/material.dart';
import '../../../../shared/services/firestore_data_service.dart';
import '../../../../shared/services/hospital_routing_service.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/constrained_responsive_container.dart';
import '../../../../shared/models/hospital_capacity.dart';
import '../widgets/hospital_map_widget.dart';

/// Hospital finder page for locating nearby emergency facilities
class HospitalFinderPage extends StatefulWidget {
  const HospitalFinderPage({super.key});

  @override
  State<HospitalFinderPage> createState() => _HospitalFinderPageState();
}

class _HospitalFinderPageState extends State<HospitalFinderPage> {
  final FirestoreDataService _firestoreService = FirestoreDataService();
  final HospitalRoutingService _routingService = HospitalRoutingService();

  List<HospitalCapacity> _hospitals = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showMapView = false;

  // Real-time data streams
  Stream<List<HospitalCapacity>>? _hospitalStream;
  List<String> _hospitalIds = [];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    // Clean up any active streams
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _routingService.initialize();

      // Load nearby hospitals (using NYC coordinates as default)
      final hospitals = await _firestoreService.getHospitalsInRadius(
        latitude: 40.7128,
        longitude: -74.0060,
        radiusKm: 50.0,
      );

      // Convert HospitalFirestore to HospitalCapacity using proper factory method
      final hospitalCapacities = hospitals
          .map((hospital) => HospitalCapacity.fromFirestore(hospital))
          .toList();

      // Use routing service to optimize hospital order by travel time
      final optimizedHospitals = await _routingService.optimizeHospitalRoutes(
        hospitalCapacities,
        userLatitude: 40.7128,
        userLongitude: -74.0060,
      );

      // Store hospital IDs for real-time monitoring
      _hospitalIds = optimizedHospitals.map((h) => h.hospitalId).toList();

      // Set up real-time capacity monitoring
      _setupRealTimeMonitoring();

      setState(() {
        _hospitals = optimizedHospitals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load hospitals: $e';
        _isLoading = false;
      });
    }
  }

  void _setupRealTimeMonitoring() {
    if (_hospitalIds.isNotEmpty) {
      _hospitalStream = _firestoreService
          .listenToHospitalCapacities(_hospitalIds)
          .map((capacities) {
            // Convert to HospitalCapacity and maintain order
            final capacityMap = <String, HospitalCapacity>{};
            for (final capacity in capacities) {
              capacityMap[capacity.hospitalId] =
                  HospitalCapacity.fromFirestoreCapacity(capacity);
            }

            // Update existing hospitals with new capacity data
            return _hospitals.map((hospital) {
              final updatedCapacity = capacityMap[hospital.hospitalId];
              return updatedCapacity ?? hospital;
            }).toList();
          });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Hospitals'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // Toggle between list and map view
          IconButton(
            icon: Icon(_showMapView ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMapView = !_showMapView;
              });
            },
            tooltip: _showMapView ? 'Show List' : 'Show Map',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHospitals,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildResponsiveBody(context),
    );
  }

  Widget _buildResponsiveBody(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isTablet = ResponsiveBreakpoints.isTablet(context);

    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    if (_hospitals.isEmpty) {
      return _buildEmptyState(context);
    }

    // Use StreamBuilder for real-time updates when available
    if (_hospitalStream != null) {
      return StreamBuilder<List<HospitalCapacity>>(
        stream: _hospitalStream,
        initialData: _hospitals,
        builder: (context, snapshot) {
          final hospitals = snapshot.data ?? _hospitals;

          // Show connection status indicator
          final isConnected =
              snapshot.connectionState == ConnectionState.active;

          return Column(
            children: [
              if (!isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Real-time updates unavailable',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _buildHospitalContent(
                  context,
                  hospitals,
                  isMobile,
                  isTablet,
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildHospitalContent(context, _hospitals, isMobile, isTablet);
  }

  Widget _buildHospitalContent(
    BuildContext context,
    List<HospitalCapacity> hospitals,
    bool isMobile,
    bool isTablet,
  ) {
    // On mobile, show either map or list based on toggle
    if (isMobile) {
      return _showMapView
          ? _buildMapView(context, hospitals)
          : _buildListView(context, hospitals);
    }

    // On tablet and desktop, show both map and list side by side
    return Row(
      children: [
        // Map view (left side)
        Expanded(
          flex: isTablet ? 1 : 2,
          child: _buildMapView(context, hospitals),
        ),

        // List view (right side)
        Expanded(flex: 1, child: _buildListView(context, hospitals)),
      ],
    );
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
              'Error Loading Hospitals',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontSize: isMobile ? 18 : 24,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 12 : 14),
            ),
            SizedBox(height: isMobile ? 12 : 24),
            ConstrainedResponsiveContainer.button(
              child: ElevatedButton.icon(
                onPressed: _loadHospitals,
                icon: Icon(Icons.refresh, size: isMobile ? 18 : 20),
                label: Text(
                  'Try Again',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital,
            size: isMobile ? 48 : 64,
            color: Colors.grey,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'No hospitals found in your area',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: isMobile ? 16 : 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context, List<HospitalCapacity> hospitals) {
    return ConstrainedResponsiveContainer.hospitalMap(
      child: HospitalMapWidget(
        hospitals: hospitals,
        severityScore: null, // Can be passed from triage results
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<HospitalCapacity> hospitals,
  ) {
    return Column(
      children: [
        // Header with real-time indicator
        Container(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                Icons.local_hospital,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${hospitals.length} hospitals found nearby',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hospitalStream != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi, size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Hospital list
        Expanded(
          child: ListView.builder(
            padding: ResponsiveBreakpoints.getResponsivePadding(context),
            itemCount: hospitals.length,
            itemBuilder: (context, index) {
              final hospital = hospitals[index];
              return _buildResponsiveHospitalCard(hospital);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveHospitalCard(HospitalCapacity hospital) {
    final occupancyRate = hospital.occupancyRate;
    final isNearCapacity = hospital.isNearCapacity;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ConstrainedResponsiveContainer.card(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Card(
        child: Padding(
          padding: ResponsiveBreakpoints.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hospital name and distance
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 16 : 18,
                      ),
                      maxLines: isMobile ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hospital.distanceKm != null) ...[
                    SizedBox(width: isMobile ? 8 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 6 : 8,
                        vertical: isMobile ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                      ),
                      child: Text(
                        '${hospital.distanceKm!.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: isMobile ? 8 : 12),

              // Capacity information - responsive layout
              if (isMobile)
                // Mobile: Stack vertically for better readability
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCapacityItem(
                            'Beds',
                            '${hospital.availableBeds}/${hospital.totalBeds}',
                            occupancyRate,
                            isNearCapacity,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCapacityItem(
                            'Emergency',
                            '${hospital.emergencyBeds}',
                            null,
                            false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCapacityItem(
                            'ICU',
                            '${hospital.icuBeds}',
                            null,
                            false,
                          ),
                        ),
                        const Expanded(
                          child: SizedBox(),
                        ), // Empty space for alignment
                      ],
                    ),
                  ],
                )
              else
                // Tablet/Desktop: Horizontal layout
                Row(
                  children: [
                    Expanded(
                      child: _buildCapacityItem(
                        'Total Beds',
                        '${hospital.availableBeds}/${hospital.totalBeds}',
                        occupancyRate,
                        isNearCapacity,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCapacityItem(
                        'Emergency',
                        '${hospital.emergencyBeds}',
                        null,
                        false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCapacityItem(
                        'ICU',
                        '${hospital.icuBeds}',
                        null,
                        false,
                      ),
                    ),
                  ],
                ),

              SizedBox(height: isMobile ? 8 : 12),

              // Status and actions - responsive layout
              if (isMobile)
                // Mobile: Stack vertically
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusChip(isNearCapacity),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ConstrainedResponsiveContainer.button(
                            child: OutlinedButton.icon(
                              onPressed: () => _showHospitalDetails(hospital),
                              icon: Icon(Icons.info, size: isMobile ? 14 : 16),
                              label: Text(
                                'Details',
                                style: TextStyle(fontSize: isMobile ? 12 : 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ConstrainedResponsiveContainer.button(
                            child: ElevatedButton.icon(
                              onPressed: () => _navigateToHospital(hospital),
                              icon: Icon(
                                Icons.directions,
                                size: isMobile ? 14 : 16,
                              ),
                              label: Text(
                                'Navigate',
                                style: TextStyle(fontSize: isMobile ? 12 : 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                // Tablet/Desktop: Horizontal layout
                Row(
                  children: [
                    _buildStatusChip(isNearCapacity),
                    const Spacer(),
                    ConstrainedResponsiveContainer.button(
                      child: OutlinedButton.icon(
                        onPressed: () => _showHospitalDetails(hospital),
                        icon: const Icon(Icons.info, size: 16),
                        label: const Text('Details'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedResponsiveContainer.button(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToHospital(hospital),
                        icon: const Icon(Icons.directions, size: 16),
                        label: const Text('Navigate'),
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

  Widget _buildStatusChip(bool isNearCapacity) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isNearCapacity ? Colors.red.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNearCapacity ? Icons.warning : Icons.check_circle,
            size: isMobile ? 14 : 16,
            color: isNearCapacity ? Colors.red.shade700 : Colors.green.shade700,
          ),
          SizedBox(width: isMobile ? 3 : 4),
          Text(
            isNearCapacity ? 'Near Capacity' : 'Available',
            style: TextStyle(
              color: isNearCapacity
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityItem(
    String label,
    String value,
    double? occupancyRate,
    bool isWarning,
  ) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: isMobile ? 11 : 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isMobile ? 1 : 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.red : null,
            fontSize: isMobile ? 12 : 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (occupancyRate != null) ...[
          SizedBox(height: isMobile ? 3 : 4),
          LinearProgressIndicator(
            value: occupancyRate,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              isWarning ? Colors.red : Colors.green,
            ),
          ),
        ],
      ],
    );
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
            Text(
              'Distance: ${hospital.distanceKm?.toStringAsFixed(1) ?? 'Unknown'} km',
            ),
            Text('Total Beds: ${hospital.totalBeds}'),
            Text('Available Beds: ${hospital.availableBeds}'),
            Text('Emergency Beds: ${hospital.emergencyBeds}'),
            Text('ICU Beds: ${hospital.icuBeds}'),
            Text(
              'Occupancy: ${(hospital.occupancyRate * 100).toStringAsFixed(1)}%',
            ),
            Text(
              'Last Updated: ${hospital.lastUpdated.toString().split('.')[0]}',
            ),
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

  void _navigateToHospital(HospitalCapacity hospital) {
    // In a real implementation, this would open maps or navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to ${hospital.name} would open here'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}
