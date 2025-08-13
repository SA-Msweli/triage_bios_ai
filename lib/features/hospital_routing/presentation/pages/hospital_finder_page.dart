import 'package:flutter/material.dart';
import '../../../../shared/services/fhir_service.dart';
import '../../../../shared/services/hospital_routing_service.dart';

/// Hospital finder page for locating nearby emergency facilities
class HospitalFinderPage extends StatefulWidget {
  const HospitalFinderPage({super.key});

  @override
  State<HospitalFinderPage> createState() => _HospitalFinderPageState();
}

class _HospitalFinderPageState extends State<HospitalFinderPage> {
  final FhirService _fhirService = FhirService();
  final HospitalRoutingService _routingService = HospitalRoutingService();

  List<HospitalCapacity> _hospitals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _fhirService.initialize();
      await _routingService.initialize();

      // Load nearby hospitals (using NYC coordinates as default)
      final hospitals = await _fhirService.getHospitalCapacities(
        latitude: 40.7128,
        longitude: -74.0060,
        radiusKm: 25.0,
      );

      // Use routing service to optimize hospital order by travel time
      final optimizedHospitals = await _routingService.optimizeHospitalRoutes(
        hospitals,
        userLatitude: 40.7128,
        userLongitude: -74.0060,
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Hospitals'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHospitals,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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

    if (_errorMessage != null) {
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
              'Error Loading Hospitals',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHospitals,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_hospitals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hospitals found in your area'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                Icons.local_hospital,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_hospitals.length} hospitals found nearby',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Hospital list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _hospitals.length,
            itemBuilder: (context, index) {
              final hospital = _hospitals[index];
              return _buildHospitalCard(hospital);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHospitalCard(HospitalCapacity hospital) {
    final occupancyRate = hospital.occupancyRate;
    final isNearCapacity = hospital.isNearCapacity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    ),
                  ),
                ),
                if (hospital.distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${hospital.distanceKm!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Capacity information
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

            const SizedBox(height: 12),

            // Status and actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isNearCapacity
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNearCapacity ? Icons.warning : Icons.check_circle,
                        size: 16,
                        color: isNearCapacity
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNearCapacity ? 'Near Capacity' : 'Available',
                        style: TextStyle(
                          color: isNearCapacity
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showHospitalDetails(hospital),
                  icon: const Icon(Icons.info, size: 16),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _navigateToHospital(hospital),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Navigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityItem(
    String label,
    String value,
    double? occupancyRate,
    bool isWarning,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.red : null,
          ),
        ),
        if (occupancyRate != null) ...[
          const SizedBox(height: 4),
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
