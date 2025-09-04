# Firestore Performance Optimization

This document describes the performance optimization implementations for the Triage-BIOS.ai Firebase/Firestore integration.

## Overview

The performance optimization system includes four main components:

1. **Query Optimization** - Optimized query structure and indexing
2. **Connection Pooling** - Efficient connection and listener management
3. **Data Pagination** - Large result set handling with infinite scrolling
4. **Performance Monitoring** - Real-time performance tracking and alerting

## Components

### 1. FirestorePerformanceService

The core service that provides optimized query execution with performance monitoring.

**Key Features:**
- Query performance tracking
- Connection pooling integration
- Pagination support
- Real-time listener management
- Performance metrics collection

**Usage:**
```dart
final performanceService = FirestorePerformanceService();

// Execute optimized query
final result = await performanceService.executeOptimizedQuery(
  collectionPath: 'hospitals',
  queryId: 'hospitals_by_location',
  filters: [
    QueryFilter.isEqualTo('isActive', true),
    QueryFilter.isGreaterThan('traumaLevel', 2),
  ],
  orderBy: [QueryOrder.desc('updatedAt')],
  limit: 20,
);

// Execute paginated query
final paginatedResult = await performanceService.executePaginatedQuery<Hospital>(
  collectionPath: 'hospitals',
  queryId: 'hospitals_paginated',
  fromFirestore: (doc) => Hospital.fromFirestore(doc),
  pageSize: 20,
  pageToken: nextPageToken,
);
```

### 2. OptimizedQueryService

High-level service providing domain-specific optimized queries.

**Key Features:**
- Hospital queries with location filtering
- Patient vitals queries with time-based filtering
- Triage results queries with urgency-based filtering
- Real-time listeners with automatic optimization

**Usage:**
```dart
final queryService = OptimizedQueryService();

// Get hospitals with pagination
final hospitals = await queryService.getHospitalsPaginated(
  specializations: ['cardiology', 'emergency'],
  minTraumaLevel: 2,
  latitude: 40.7128,
  longitude: -74.0060,
  radiusKm: 10.0,
  pageSize: 15,
);

// Get patient vitals with filtering
final vitals = await queryService.getPatientVitalsPaginated(
  patientId: 'patient123',
  startDate: DateTime.now().subtract(Duration(days: 7)),
  hasAbnormalVitals: true,
  pageSize: 20,
);
```

### 3. ConnectionPoolManager

Manages Firestore connections and listeners for optimal resource usage.

**Key Features:**
- Connection pooling with configurable limits
- Listener pooling with automatic cleanup
- Connection timeout handling
- Resource monitoring and metrics

**Configuration:**
- Max connections per pool: 10
- Max listeners per pool: 20
- Connection timeout: 30 seconds
- Idle timeout: 5 minutes

**Usage:**
```dart
final poolManager = ConnectionPoolManager();

// Execute pooled query
final result = await poolManager.executePooledQuery(
  collectionPath: 'hospitals',
  query: hospitalsQuery,
  poolKey: 'hospitals_active',
);

// Create pooled listener
final subscription = poolManager.createPooledListener(
  collectionPath: 'hospital_capacity',
  listenerId: 'capacity_monitor',
  query: capacityQuery,
  onData: (snapshot) => handleCapacityUpdate(snapshot),
  onError: (error) => handleError(error),
);
```

### 4. PerformanceMonitoringService

Monitors and alerts on Firestore performance issues.

**Key Features:**
- Real-time performance monitoring
- Configurable alerting system
- Performance trend analysis
- Optimization suggestions
- Historical performance tracking

**Usage:**
```dart
final monitoringService = PerformanceMonitoringService();

// Start monitoring
await monitoringService.startMonitoring(
  interval: Duration(minutes: 1),
  alertInterval: Duration(seconds: 30),
);

// Listen to alerts
monitoringService.alerts.listen((alert) {
  print('Performance Alert: ${alert.message}');
});

// Get performance summary
final summary = monitoringService.getCurrentSummary();
print('Performance Score: ${summary.performanceScore}');
```

## Query Optimization

### Firestore Indexes

The system includes optimized Firestore indexes for common query patterns:

**Hospital Queries:**
```json
{
  "collectionGroup": "hospitals",
  "fields": [
    {"fieldPath": "isActive", "order": "ASCENDING"},
    {"fieldPath": "traumaLevel", "order": "DESCENDING"},
    {"fieldPath": "updatedAt", "order": "DESCENDING"}
  ]
}
```

**Capacity Queries:**
```json
{
  "collectionGroup": "hospital_capacity",
  "fields": [
    {"fieldPath": "hospitalId", "order": "ASCENDING"},
    {"fieldPath": "lastUpdated", "order": "DESCENDING"}
  ]
}
```

**Patient Vitals Queries:**
```json
{
  "collectionGroup": "patient_vitals",
  "fields": [
    {"fieldPath": "hasAbnormalVitals", "order": "ASCENDING"},
    {"fieldPath": "vitalsSeverityScore", "order": "DESCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

### Query Patterns

**Optimized Hospital Search:**
1. Filter by active status first (most selective)
2. Apply location bounding box for geographic queries
3. Filter by specializations using array-contains-any
4. Order by relevance score or distance
5. Apply pagination with consistent ordering

**Optimized Capacity Monitoring:**
1. Query by hospital IDs in batches (max 10 per query)
2. Order by last updated timestamp
3. Use real-time listeners with connection pooling
4. Cache recent results for offline access

**Optimized Patient Data:**
1. Always filter by patient ID first
2. Use time-based filtering for large datasets
3. Apply severity filtering for critical vitals
4. Implement pagination for historical data

## Pagination Implementation

### Page Token System

The pagination system uses encoded page tokens for stateless pagination:

```dart
// Encode last document as page token
String encodePageToken(DocumentSnapshot doc) {
  return '${doc.reference.path}:${doc.get('timestamp')?.millisecondsSinceEpoch ?? 0}';
}

// Decode page token to start document
Future<DocumentSnapshot?> decodePageToken(String pageToken) async {
  final parts = pageToken.split(':');
  return await firestore.doc(parts[0]).get();
}
```

### Infinite Scrolling Support

```dart
class InfiniteScrollController {
  String? _nextPageToken;
  bool _hasMore = true;
  bool _isLoading = false;

  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    
    _isLoading = true;
    try {
      final result = await queryService.getHospitalsPaginated(
        pageToken: _nextPageToken,
        pageSize: 20,
      );
      
      _nextPageToken = result.nextPageToken;
      _hasMore = result.hasMore;
      
      // Add items to list
      items.addAll(result.items);
    } finally {
      _isLoading = false;
    }
  }
}
```

## Performance Monitoring

### Metrics Collected

**Query Metrics:**
- Execution count and frequency
- Average, min, max duration
- Error count and rate
- Result count statistics
- Last execution timestamp

**Connection Metrics:**
- Active connections per pool
- Connection wait times
- Success/failure rates
- Pool utilization rates

**Listener Metrics:**
- Active listener count
- Listener lifecycle duration
- Memory usage patterns
- Error rates and types

### Alert Types

**Slow Query Alerts:**
- Threshold: > 2 seconds average
- Critical: > 5 seconds average
- Cooldown: 5 minutes

**High Error Rate Alerts:**
- Threshold: > 10% error rate
- Critical: > 25% error rate
- Cooldown: 3 minutes

**High Listener Count Alerts:**
- Threshold: > 40 active listeners
- Critical: > 50 active listeners
- Cooldown: 10 minutes

### Performance Optimization Suggestions

The system automatically generates optimization suggestions:

1. **Index Optimization**: Identifies queries that would benefit from additional indexes
2. **Listener Optimization**: Suggests reducing active listener count
3. **Error Reduction**: Highlights queries with high error rates
4. **Cache Optimization**: Recommends caching strategies for frequently accessed data

## Best Practices

### Query Design

1. **Always filter by the most selective field first**
2. **Use compound indexes for multi-field queries**
3. **Limit result sets with appropriate page sizes**
4. **Avoid queries that scan large collections**
5. **Use array-contains-any sparingly (max 10 values)**

### Connection Management

1. **Reuse connections within the same collection**
2. **Set appropriate timeouts for queries**
3. **Clean up idle connections regularly**
4. **Monitor connection pool utilization**
5. **Use listener pooling for real-time updates**

### Performance Monitoring

1. **Monitor query performance continuously**
2. **Set up alerts for performance degradation**
3. **Review optimization suggestions regularly**
4. **Track performance trends over time**
5. **Optimize based on actual usage patterns**

## Configuration

### Environment Variables

```dart
// Performance thresholds
static const Duration slowQueryThreshold = Duration(seconds: 2);
static const Duration verySlowQueryThreshold = Duration(seconds: 5);
static const int maxActiveListeners = 50;
static const int maxCachedQueries = 100;

// Connection pool settings
static const int maxConnectionsPerPool = 10;
static const int maxListenersPerPool = 20;
static const Duration connectionTimeout = Duration(seconds: 30);
static const Duration idleTimeout = Duration(minutes: 5);
```

### Firestore Rules Optimization

```javascript
// Optimized security rules for performance
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Index-friendly hospital queries
    match /hospitals/{hospitalId} {
      allow read: if resource.data.isActive == true;
      allow write: if request.auth != null && 
                      request.auth.token.role in ['admin', 'hospital_admin'];
    }
    
    // Efficient capacity queries
    match /hospital_capacity/{capacityId} {
      allow read: if true;
      allow write: if request.auth != null && 
                      request.auth.token.hospitalId == resource.data.hospitalId;
    }
  }
}
```

## Testing

### Performance Tests

The system includes comprehensive performance tests:

```dart
// Query performance test
test('should execute queries within performance thresholds', () async {
  final stopwatch = Stopwatch()..start();
  
  final result = await performanceService.executeOptimizedQuery(
    collectionPath: 'hospitals',
    queryId: 'performance_test',
    filters: [QueryFilter.isEqualTo('isActive', true)],
    limit: 20,
  );
  
  stopwatch.stop();
  expect(stopwatch.elapsed.inMilliseconds, lessThan(2000));
  expect(result.docs.length, lessThanOrEqualTo(20));
});
```

### Load Testing

```dart
// Connection pool load test
test('should handle concurrent queries efficiently', () async {
  final futures = List.generate(50, (i) => 
    performanceService.executeOptimizedQuery(
      collectionPath: 'hospitals',
      queryId: 'load_test_$i',
      limit: 10,
    )
  );
  
  final results = await Future.wait(futures);
  expect(results.length, equals(50));
});
```

## Troubleshooting

### Common Issues

**Slow Queries:**
1. Check if appropriate indexes exist
2. Verify query structure and filtering order
3. Review result set sizes and pagination
4. Monitor connection pool utilization

**High Error Rates:**
1. Check Firestore security rules
2. Verify network connectivity
3. Review query syntax and parameters
4. Monitor authentication status

**Memory Issues:**
1. Check active listener count
2. Review connection pool sizes
3. Verify cleanup processes are running
4. Monitor cache sizes and TTL settings

### Debug Commands

```dart
// Get performance metrics
final metrics = performanceService.getQueryMetrics();
print('Query Metrics: $metrics');

// Get pool statistics
final stats = connectionPoolManager.getPoolStatistics();
print('Pool Statistics: $stats');

// Get optimization suggestions
final suggestions = monitoringService.getOptimizationSuggestions();
print('Optimization Suggestions: $suggestions');
```

## Future Enhancements

1. **Machine Learning-based Query Optimization**
2. **Predictive Caching Strategies**
3. **Advanced Connection Load Balancing**
4. **Real-time Performance Dashboards**
5. **Automated Index Recommendation System**