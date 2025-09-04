# Offline Support and Caching Implementation

This document describes the comprehensive offline support and intelligent caching system implemented for the Triage-BIOS.ai application.

## Overview

The offline support system provides seamless functionality when network connectivity is limited or unavailable, ensuring critical healthcare data remains accessible and operations can continue during emergencies.

## Key Features

### 1. Firestore Offline Persistence
- **Mobile Platforms**: Full offline persistence with unlimited cache size
- **Web Platforms**: Limited offline persistence with 40MB cache limit
- **Automatic Sync**: Seamless synchronization when connectivity is restored
- **Conflict Resolution**: Server-side timestamp precedence for data conflicts

### 2. Intelligent Caching Strategy
- **Priority-Based Caching**: Critical hospital data cached with highest priority
- **TTL Management**: Different cache lifetimes based on data importance
- **Size Management**: Automatic cleanup when cache limits are exceeded
- **Memory + Persistent**: Two-tier caching for optimal performance

### 3. Offline Operations Queue
- **Operation Queuing**: Store create/update/delete operations when offline
- **Priority Processing**: Critical operations processed first when online
- **Batch Operations**: Efficient bulk processing of queued operations
- **Error Handling**: Robust error recovery and retry mechanisms

### 4. Real-time Sync Status
- **Status Indicators**: Visual feedback on sync state and connectivity
- **Progress Tracking**: Monitor pending operations and conflicts
- **Manual Sync**: User-triggered synchronization
- **Detailed Diagnostics**: Comprehensive sync status information

## Architecture

### Core Components

#### OfflineSupportService
Main service managing offline functionality:
```dart
class OfflineSupportService {
  // Cache management with intelligent prioritization
  Future<void> cacheData({
    required String key,
    required dynamic data,
    required DataPriority priority,
    Duration? customTTL,
  });

  // Offline operation queuing
  Future<void> addOfflineOperation(OfflineOperation operation);

  // Manual synchronization
  Future<void> manualSync();

  // Real-time status streams
  Stream<SyncStatusInfo> get syncStatusStream;
  Stream<bool> get connectivityStream;
}
```

#### EnhancedFirestoreDataService
Enhanced data service with offline support:
```dart
class EnhancedFirestoreDataService {
  // Hospital data with offline fallback
  Future<List<HospitalFirestore>> getHospitals({
    bool forceRefresh = false,
  });

  // Capacity data with real-time caching
  Future<HospitalCapacityFirestore?> getHospitalCapacity(
    String hospitalId, 
    {bool forceRefresh = false}
  );

  // Patient data with offline queuing
  Future<void> storePatientVitals(PatientVitalsFirestore vitals);
}
```

#### CacheManager
Utility for advanced cache operations:
```dart
class CacheManager {
  // Store with priority and TTL
  Future<void> store({
    required String key,
    required dynamic data,
    required DataPriority priority,
    Duration? customTTL,
  });

  // Retrieve with type safety
  Future<T?> retrieve<T>(String key);

  // Cache statistics and cleanup
  Future<CacheStats> getStats();
  Future<int> clearExpired();
}
```

### Data Priority Levels

1. **Critical**: Emergency contacts, active hospitals (5-minute TTL)
2. **High**: Hospital capacity, patient vitals (15-minute TTL)
3. **Medium**: Triage results, patient history (1-hour TTL)
4. **Low**: Analytics, logs (6-hour TTL)

### Sync Status States

- **Synced**: All data synchronized, no pending operations
- **Syncing**: Active synchronization in progress
- **Offline**: No network connectivity, using cached data
- **Error**: Synchronization failed, manual intervention may be needed
- **Conflict Resolution**: Resolving data conflicts with server

## UI Components

### SyncStatusWidget
Displays current sync status with optional details:
```dart
// Compact status indicator
SyncStatusWidget(showDetails: false)

// Detailed status panel
SyncStatusWidget(showDetails: true)
```

### FloatingSyncStatus
Minimal floating indicator for issues:
```dart
FloatingSyncStatus(
  onTap: () => SyncStatusBottomSheet.show(context),
)
```

### SyncStatusBottomSheet
Comprehensive sync management interface:
```dart
SyncStatusBottomSheet.show(context);
```

## Configuration

### Firestore Settings
```dart
// Mobile configuration
firestore.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);

// Web configuration
firestore.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 40 * 1024 * 1024, // 40MB
);
```

### Cache Limits
```dart
static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
static const int _maxCacheEntries = 1000;
static const Duration _criticalDataTTL = Duration(minutes: 5);
```

## Usage Examples

### Basic Integration
```dart
class HospitalFinderPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hospital Finder'),
        actions: [
          // Sync status indicator
          SyncStatusWidget(showDetails: false),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          StreamBuilder<bool>(
            stream: offlineService.connectivityStream,
            builder: (context, snapshot) {
              if (!(snapshot.data ?? true)) {
                return OfflineBanner();
              }
              return SizedBox.shrink();
            },
          ),
          
          // Main content with offline support
          Expanded(child: HospitalList()),
        ],
      ),
    );
  }
}
```

### Data Operations
```dart
// Load hospitals with offline fallback
final hospitals = await dataService.getHospitals(
  isActive: true,
  forceRefresh: false, // Use cache if available
);

// Store patient data with offline queuing
await dataService.storePatientVitals(vitals);

// Manual sync trigger
await offlineService.manualSync();
```

### Cache Management
```dart
// Cache critical data
await offlineService.cacheData(
  key: 'emergency_contacts',
  data: emergencyContacts,
  priority: DataPriority.critical,
);

// Get cache statistics
final stats = offlineService.getCacheStats();
print('Cache entries: ${stats['totalEntries']}');
print('Critical data: ${stats['criticalEntries']}');

// Clear expired cache
await cacheManager.clearExpired();
```

## Conflict Resolution

The system uses server-side timestamp precedence for conflict resolution:

1. **Server Newer**: Discard local changes, update cache with server data
2. **Local Newer**: Retry local operation, overwrite server data
3. **Concurrent Updates**: Server timestamp wins, notify user of conflict

```dart
Future<void> _handleConflict(OfflineOperation operation) async {
  final serverDoc = await docRef.get();
  final serverTimestamp = serverData['updatedAt'] as Timestamp?;
  
  if (serverTimestamp != null && 
      serverTimestamp.toDate().isAfter(operation.timestamp)) {
    // Server data is newer, discard local changes
    await _updateCacheWithServerData(serverData);
  } else {
    // Local data is newer, retry operation
    await _retryOperation(operation);
  }
}
```

## Performance Considerations

### Cache Optimization
- **Memory Cache**: Fast access for frequently used data
- **Persistent Cache**: Survives app restarts for critical data
- **Intelligent Cleanup**: Remove expired and low-priority data first
- **Size Monitoring**: Prevent excessive memory usage

### Network Efficiency
- **Batch Operations**: Group multiple operations for efficiency
- **Incremental Sync**: Only sync changed data
- **Compression**: Minimize data transfer size
- **Connection Pooling**: Reuse connections for multiple operations

### Battery Optimization
- **Adaptive Sync**: Reduce sync frequency when battery is low
- **Background Limits**: Respect platform background execution limits
- **Efficient Listeners**: Minimize real-time listener overhead

## Testing

### Unit Tests
```dart
test('should cache data with different priorities', () async {
  await offlineService.cacheData(
    key: 'test_critical',
    data: {'type': 'critical'},
    priority: DataPriority.critical,
  );

  final cachedData = await offlineService.getCachedData('test_critical');
  expect(cachedData, isNotNull);
});
```

### Integration Tests
```dart
testWidgets('should show offline banner when disconnected', (tester) async {
  // Simulate offline state
  when(mockOfflineService.isOnline).thenReturn(false);
  
  await tester.pumpWidget(HospitalFinderPage());
  
  expect(find.byType(OfflineBanner), findsOneWidget);
});
```

## Monitoring and Diagnostics

### Cache Statistics
- Total cache entries and size
- Entries by priority level
- Hit/miss ratios
- Expired entry count

### Sync Metrics
- Pending operation count
- Conflict resolution count
- Last successful sync time
- Error frequency and types

### Performance Metrics
- Cache access times
- Sync operation duration
- Network request success rates
- Battery usage impact

## Security Considerations

### Data Protection
- **Encryption**: All cached data encrypted at rest
- **Access Control**: Cache access restricted by user permissions
- **Audit Logging**: Track all cache and sync operations
- **Data Retention**: Automatic cleanup of sensitive cached data

### Privacy Compliance
- **HIPAA Compliance**: Healthcare data handling requirements
- **Data Minimization**: Cache only necessary data
- **User Consent**: Respect user privacy preferences
- **Right to Deletion**: Support data deletion requests

## Troubleshooting

### Common Issues

#### Cache Not Working
1. Check SharedPreferences permissions
2. Verify cache size limits
3. Check for storage space issues
4. Review cache TTL settings

#### Sync Failures
1. Verify network connectivity
2. Check Firebase authentication
3. Review Firestore security rules
4. Monitor error logs

#### Performance Issues
1. Check cache size and cleanup frequency
2. Monitor memory usage
3. Review sync operation batching
4. Optimize query patterns

### Debug Tools
```dart
// Enable debug logging
Logger.level = Level.debug;

// Monitor cache statistics
final stats = await cacheManager.getStats();
print('Cache stats: ${stats.toJson()}');

// Track sync operations
offlineService.syncStatusStream.listen((status) {
  print('Sync status: ${status.status}');
  print('Pending operations: ${status.pendingOperations}');
});
```

## Future Enhancements

### Planned Features
- **Predictive Caching**: Machine learning-based cache preloading
- **Peer-to-Peer Sync**: Device-to-device data sharing
- **Advanced Compression**: Improved data compression algorithms
- **Smart Retry**: Intelligent retry strategies for failed operations

### Performance Improvements
- **Background Sync**: More efficient background synchronization
- **Delta Sync**: Sync only changed portions of data
- **Connection Awareness**: Adapt behavior based on connection quality
- **Battery Optimization**: Further reduce battery usage

This offline support system ensures the Triage-BIOS.ai application remains functional and reliable even in challenging network conditions, providing critical healthcare services when they're needed most.