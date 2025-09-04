import 'package:flutter/material.dart';
import '../shared/services/offline_support_service.dart';
import '../shared/services/enhanced_firestore_data_service.dart';
import '../shared/widgets/sync_status_widget.dart';
import '../shared/models/firestore/hospital_firestore.dart';
import '../shared/models/firestore/hospital_capacity_firestore.dart';

/// Example demonstrating offline support integration in a hospital finder screen
class OfflineSupportIntegrationExample extends StatefulWidget {
  const OfflineSupportIntegrationExample({super.key});

  @override
  State<OfflineSupportIntegrationExample> createState() =>
      _OfflineSupportIntegrationExampleState();
}

class _OfflineSupportIntegrationExampleState
    extends State<OfflineSupportIntegrationExample> {
  final EnhancedFirestoreDataService _dataService =
      EnhancedFirestoreDataService();
  final OfflineSupportService _offlineService = OfflineSupportService();

  List<HospitalFirestore> _hospitals = [];
  Map<String, HospitalCapacityFirestore> _capacities = {};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
    _setupRealTimeListeners();
  }

  /// Load hospitals with offline support
  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load hospitals with offline fallback
      final hospitals = await _dataService.getHospitals(
        isActive: true,
        limit: 20,
      );

      // Load capacity data for each hospital
      final capacities = <String, HospitalCapacityFirestore>{};
      for (final hospital in hospitals) {
        final capacity = await _dataService.getHospitalCapacity(hospital.id);
        if (capacity != null) {
          capacities[hospital.id] = capacity;
        }
      }

      setState(() {
        _hospitals = hospitals;
        _capacities = capacities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load hospitals: $e';
        _isLoading = false;
      });
    }
  }

  /// Setup real-time listeners with offline fallback
  void _setupRealTimeListeners() {
    // Listen to capacity updates
    _dataService
        .listenToHospitalCapacities(_hospitals.map((h) => h.id).toList())
        .listen(
          (capacities) {
            setState(() {
              for (final capacity in capacities) {
                _capacities[capacity.hospitalId] = capacity;
              }
            });
          },
          onError: (error) {
            // Handle real-time listener errors gracefully
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Real-time updates unavailable: Using cached data',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          },
        );
  }

  /// Refresh data manually
  Future<void> _refreshData() async {
    await _loadHospitals();
    await _offlineService.manualSync();
  }

  /// Show sync status details
  void _showSyncStatus() {
    SyncStatusBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Finder'),
        actions: [
          // Compact sync status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _showSyncStatus,
              child: const SyncStatusWidget(showDetails: false),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Connectivity and sync status banner
              StreamBuilder<bool>(
                stream: _offlineService.connectivityStream,
                initialData: _offlineService.isOnline,
                builder: (context, snapshot) {
                  final isOnline = snapshot.data ?? false;

                  if (!isOnline) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.orange.shade100,
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You\'re offline. Showing cached data.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showSyncStatus,
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),

              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadHospitals,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              // Hospital list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hospitals.isEmpty
                    ? _buildEmptyState()
                    : _buildHospitalList(),
              ),
            ],
          ),

          // Floating sync status (shows only when there are issues)
          FloatingSyncStatus(onTap: _showSyncStatus),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSyncStatus,
        tooltip: 'Sync Status',
        child: StreamBuilder<SyncStatusInfo>(
          stream: _offlineService.syncStatusStream,
          builder: (context, snapshot) {
            final syncStatus = snapshot.data?.status ?? SyncStatus.synced;

            switch (syncStatus) {
              case SyncStatus.syncing:
                return const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                );
              case SyncStatus.offline:
                return const Icon(Icons.cloud_off);
              case SyncStatus.error:
                return const Icon(Icons.error);
              case SyncStatus.conflictResolution:
                return const Icon(Icons.merge_type);
              default:
                return const Icon(Icons.sync);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hospitals found',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _hospitals.length,
        itemBuilder: (context, index) {
          final hospital = _hospitals[index];
          final capacity = _capacities[hospital.id];

          return _buildHospitalCard(hospital, capacity);
        },
      ),
    );
  }

  Widget _buildHospitalCard(
    HospitalFirestore hospital,
    HospitalCapacityFirestore? capacity,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hospital header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hospital.address.street}, ${hospital.address.city}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trauma level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTraumaLevelColor(
                      hospital.traumaLevel,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getTraumaLevelColor(
                        hospital.traumaLevel,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Level ${hospital.traumaLevel}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getTraumaLevelColor(hospital.traumaLevel),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Capacity information
            if (capacity != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildCapacityIndicator(
                      'Available Beds',
                      capacity.availableBeds,
                      capacity.totalBeds,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCapacityIndicator(
                      'ICU Beds',
                      capacity.icuAvailable,
                      capacity.icuBeds,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Wait time: ${capacity.averageWaitTime} min',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  // Data freshness indicator
                  _buildDataFreshnessIndicator(capacity.lastUpdated),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Capacity data unavailable',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Specializations
            if (hospital.specializations.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: hospital.specializations.take(3).map((spec) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(spec, style: const TextStyle(fontSize: 10)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityIndicator(
    String label,
    int available,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? available / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$available/$total',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataFreshnessIndicator(DateTime lastUpdated) {
    final now = DateTime.now();
    final age = now.difference(lastUpdated);

    Color color;
    IconData icon;
    String text;

    if (age.inMinutes < 5) {
      color = Colors.green;
      icon = Icons.fiber_manual_record;
      text = 'Live';
    } else if (age.inMinutes < 30) {
      color = Colors.orange;
      icon = Icons.schedule;
      text = '${age.inMinutes}m ago';
    } else {
      color = Colors.red;
      icon = Icons.warning;
      text = 'Stale';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getTraumaLevelColor(int level) {
    switch (level) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

/// Example of a settings screen for offline support configuration
class OfflineSettingsExample extends StatefulWidget {
  const OfflineSettingsExample({super.key});

  @override
  State<OfflineSettingsExample> createState() => _OfflineSettingsExampleState();
}

class _OfflineSettingsExampleState extends State<OfflineSettingsExample> {
  final OfflineSupportService _offlineService = OfflineSupportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sync status section
          const SyncStatusWidget(showDetails: true),

          const SizedBox(height: 24),

          // Cache management section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cache Management',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cache statistics
                  FutureBuilder<Map<String, dynamic>>(
                    future: Future.value(_offlineService.getCacheStats()),
                    builder: (context, snapshot) {
                      final stats = snapshot.data ?? {};

                      return Column(
                        children: [
                          _buildStatRow(
                            'Total Entries',
                            '${stats['totalEntries'] ?? 0}',
                          ),
                          _buildStatRow(
                            'Critical Data',
                            '${stats['criticalEntries'] ?? 0}',
                          ),
                          _buildStatRow(
                            'High Priority',
                            '${stats['highPriorityEntries'] ?? 0}',
                          ),
                          _buildStatRow(
                            'Pending Operations',
                            '${stats['pendingOperations'] ?? 0}',
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Cache actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _offlineService.clearCache();
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cache cleared')),
                            );
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Cache'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _offlineService.manualSync();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sync completed')),
                            );
                          },
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
