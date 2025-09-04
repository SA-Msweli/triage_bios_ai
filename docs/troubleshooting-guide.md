# Troubleshooting Guide - Firestore and Real-time Updates

## Overview

This guide provides solutions for common issues encountered with Firestore operations and real-time updates in the Triage-BIOS.ai application.

## Common Firestore Issues

### 1. Permission Denied Errors

**Symptoms:**
- `FirebaseError: Missing or insufficient permissions`
- `PERMISSION_DENIED: The caller does not have permission`

**Causes:**
- Incorrect Firestore security rules
- User not authenticated
- Missing required claims in auth token
- Attempting to access restricted collections

**Solutions:**

#### Check Authentication Status
```typescript
// Verify user is authenticated
const user = firebase.auth().currentUser;
if (!user) {
  console.error('User not authenticated');
  // Redirect to login or handle authentication
}
```

#### Review Security Rules
```javascript
// Example: Check if rules allow the operation
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /hospitals/{hospitalId} {
      allow read: if true; // Public read access
      allow write: if request.auth != null && 
                      request.auth.token.role in ['admin', 'hospital_admin'];
    }
  }
}
```

#### Verify User Claims
```typescript
// Check user's custom claims
const user = firebase.auth().currentUser;
if (user) {
  const idTokenResult = await user.getIdTokenResult();
  console.log('User claims:', idTokenResult.claims);
}
```

### 2. Query Performance Issues

**Symptoms:**
- Slow query execution (>2 seconds)
- High read costs
- Timeout errors

**Causes:**
- Missing composite indexes
- Inefficient query structure
- Large result sets without pagination
- Unnecessary real-time listeners

**Solutions:**

#### Create Required Indexes
```typescript
// Check Firebase Console for index suggestions
// Create composite indexes for multi-field queries
const query = db.collection('patient_vitals')
  .where('patientId', '==', patientId)
  .where('timestamp', '>=', startDate)
  .orderBy('timestamp', 'desc'); // Requires composite index
```

#### Optimize Query Structure
```typescript
// Bad: Multiple separate queries
const hospitals = await db.collection('hospitals').get();
const capacities = await db.collection('hospital_capacity').get();

// Good: Single query with proper filtering
const hospitalCapacities = await db.collection('hospital_capacity')
  .where('availableBeds', '>', 0)
  .limit(10)
  .get();
```

#### Implement Pagination
```typescript
// Use pagination for large result sets
let lastDoc = null;
const pageSize = 20;

const getNextPage = async () => {
  let query = db.collection('triage_results')
    .orderBy('createdAt', 'desc')
    .limit(pageSize);
    
  if (lastDoc) {
    query = query.startAfter(lastDoc);
  }
  
  const snapshot = await query.get();
  lastDoc = snapshot.docs[snapshot.docs.length - 1];
  
  return snapshot.docs.map(doc => doc.data());
};
```

### 3. Real-time Listener Issues

**Symptoms:**
- Listeners not receiving updates
- Memory leaks from undetached listeners
- Excessive listener connections
- Inconsistent real-time behavior

**Causes:**
- Listeners not properly detached
- Network connectivity issues
- Firestore offline persistence conflicts
- Multiple listeners on same data

**Solutions:**

#### Proper Listener Management
```typescript
class ListenerManager {
  private listeners: Map<string, () => void> = new Map();
  
  addListener(key: string, collection: string, callback: Function) {
    // Remove existing listener if present
    this.removeListener(key);
    
    const unsubscribe = db.collection(collection)
      .onSnapshot(callback, (error) => {
        console.error(`Listener error for ${key}:`, error);
        // Implement retry logic
        this.retryListener(key, collection, callback);
      });
    
    this.listeners.set(key, unsubscribe);
  }
  
  removeListener(key: string) {
    const unsubscribe = this.listeners.get(key);
    if (unsubscribe) {
      unsubscribe();
      this.listeners.delete(key);
    }
  }
  
  removeAllListeners() {
    this.listeners.forEach(unsubscribe => unsubscribe());
    this.listeners.clear();
  }
}
```

#### Handle Network Connectivity
```typescript
// Monitor network status and reconnect listeners
class NetworkAwareListener {
  private isOnline = navigator.onLine;
  
  constructor() {
    window.addEventListener('online', () => {
      this.isOnline = true;
      this.reconnectListeners();
    });
    
    window.addEventListener('offline', () => {
      this.isOnline = false;
    });
  }
  
  private reconnectListeners() {
    // Restart all real-time listeners
    this.listenerManager.removeAllListeners();
    this.initializeListeners();
  }
}
```

### 4. Offline Persistence Issues

**Symptoms:**
- Data not available offline
- Sync conflicts when coming back online
- Inconsistent offline behavior
- Cache size exceeded errors

**Causes:**
- Offline persistence not enabled
- Cache size limits exceeded
- Conflicting writes during offline period
- Improper offline query handling

**Solutions:**

#### Enable Offline Persistence
```typescript
// Enable offline persistence (call before any Firestore operations)
try {
  await firebase.firestore().enablePersistence({
    synchronizeTabs: true
  });
  console.log('Offline persistence enabled');
} catch (error) {
  if (error.code === 'failed-precondition') {
    console.warn('Multiple tabs open, persistence can only be enabled in one tab');
  } else if (error.code === 'unimplemented') {
    console.warn('Browser doesn\'t support offline persistence');
  }
}
```

#### Handle Sync Conflicts
```typescript
// Implement conflict resolution strategy
const handleSyncConflict = (localData: any, serverData: any) => {
  // Use server timestamp as tie-breaker
  if (serverData.updatedAt > localData.updatedAt) {
    return serverData;
  }
  
  // Or merge data based on business logic
  return {
    ...localData,
    ...serverData,
    updatedAt: serverData.updatedAt
  };
};
```

#### Monitor Cache Size
```typescript
// Monitor and manage cache size
const monitorCacheSize = async () => {
  try {
    const cacheSize = await firebase.firestore().app.storage().getUsage();
    console.log('Cache size:', cacheSize);
    
    if (cacheSize > 40 * 1024 * 1024) { // 40MB threshold
      console.warn('Cache size approaching limit, consider clearing old data');
      await clearOldCacheData();
    }
  } catch (error) {
    console.error('Error checking cache size:', error);
  }
};
```

## Real-time Update Issues

### 1. Delayed or Missing Updates

**Symptoms:**
- Updates not appearing in real-time
- Significant delays in data propagation
- Inconsistent update delivery

**Diagnostic Steps:**

#### Check Listener Status
```typescript
const diagnosticListener = db.collection('hospital_capacity')
  .onSnapshot(
    (snapshot) => {
      console.log('Snapshot metadata:', {
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        isFromCache: snapshot.metadata.fromCache,
        docChanges: snapshot.docChanges().length
      });
    },
    (error) => {
      console.error('Listener error:', error);
    }
  );
```

#### Verify Network Connectivity
```typescript
// Test Firestore connectivity
const testConnectivity = async () => {
  try {
    await db.collection('_test').doc('connectivity').set({
      timestamp: firebase.firestore.FieldValue.serverTimestamp()
    });
    console.log('Firestore connectivity: OK');
  } catch (error) {
    console.error('Firestore connectivity: FAILED', error);
  }
};
```

### 2. Memory Leaks from Listeners

**Symptoms:**
- Increasing memory usage over time
- Browser performance degradation
- Multiple duplicate listeners

**Solutions:**

#### Implement Listener Cleanup
```typescript
// React component example
useEffect(() => {
  const unsubscribe = db.collection('hospitals')
    .onSnapshot(setHospitals);
  
  // Cleanup on component unmount
  return () => unsubscribe();
}, []);

// Vue component example
export default {
  data() {
    return {
      unsubscribeListeners: []
    };
  },
  
  mounted() {
    const unsubscribe = db.collection('hospitals')
      .onSnapshot(this.updateHospitals);
    this.unsubscribeListeners.push(unsubscribe);
  },
  
  beforeDestroy() {
    this.unsubscribeListeners.forEach(unsubscribe => unsubscribe());
  }
};
```

#### Monitor Active Listeners
```typescript
class ListenerTracker {
  private static activeListeners = new Set();
  
  static addListener(id: string, unsubscribe: Function) {
    this.activeListeners.add({ id, unsubscribe });
    console.log(`Active listeners: ${this.activeListeners.size}`);
  }
  
  static removeListener(id: string) {
    const listener = Array.from(this.activeListeners)
      .find(l => l.id === id);
    
    if (listener) {
      listener.unsubscribe();
      this.activeListeners.delete(listener);
      console.log(`Active listeners: ${this.activeListeners.size}`);
    }
  }
}
```

## Error Handling Best Practices

### 1. Comprehensive Error Handling

```typescript
class FirestoreErrorHandler {
  static handleError(error: any, operation: string, context?: any) {
    console.error(`Firestore error during ${operation}:`, error);
    
    switch (error.code) {
      case 'permission-denied':
        this.handlePermissionError(error, context);
        break;
      case 'unavailable':
        this.handleUnavailableError(error, context);
        break;
      case 'deadline-exceeded':
        this.handleTimeoutError(error, context);
        break;
      case 'resource-exhausted':
        this.handleQuotaError(error, context);
        break;
      default:
        this.handleGenericError(error, context);
    }
  }
  
  private static handlePermissionError(error: any, context?: any) {
    // Log security incident
    console.warn('Permission denied - possible security issue');
    
    // Redirect to authentication if needed
    if (!firebase.auth().currentUser) {
      window.location.href = '/login';
    }
  }
  
  private static handleUnavailableError(error: any, context?: any) {
    // Implement retry logic with exponential backoff
    const retryDelay = Math.min(1000 * Math.pow(2, context?.retryCount || 0), 30000);
    
    setTimeout(() => {
      if (context?.retryCallback) {
        context.retryCallback(context.retryCount + 1);
      }
    }, retryDelay);
  }
}
```

### 2. Retry Mechanisms

```typescript
class RetryableFirestoreOperation {
  static async executeWithRetry<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    baseDelay: number = 1000
  ): Promise<T> {
    let lastError: any;
    
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        
        if (attempt === maxRetries) {
          throw error;
        }
        
        // Exponential backoff with jitter
        const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
        
        console.warn(`Retry attempt ${attempt + 1} after ${delay}ms`);
      }
    }
    
    throw lastError;
  }
}

// Usage example
const hospitalData = await RetryableFirestoreOperation.executeWithRetry(
  () => db.collection('hospitals').doc(hospitalId).get(),
  3,
  1000
);
```

## Performance Monitoring

### 1. Query Performance Tracking

```typescript
class PerformanceMonitor {
  static async trackQuery<T>(
    queryName: string,
    queryFunction: () => Promise<T>
  ): Promise<T> {
    const startTime = performance.now();
    
    try {
      const result = await queryFunction();
      const duration = performance.now() - startTime;
      
      console.log(`Query ${queryName} completed in ${duration.toFixed(2)}ms`);
      
      // Send metrics to monitoring service
      this.sendMetric('firestore_query_duration', duration, {
        query_name: queryName,
        status: 'success'
      });
      
      return result;
    } catch (error) {
      const duration = performance.now() - startTime;
      
      console.error(`Query ${queryName} failed after ${duration.toFixed(2)}ms:`, error);
      
      this.sendMetric('firestore_query_duration', duration, {
        query_name: queryName,
        status: 'error',
        error_code: error.code
      });
      
      throw error;
    }
  }
  
  private static sendMetric(name: string, value: number, tags: any) {
    // Implementation depends on your monitoring service
    // Example: DataDog, New Relic, Google Analytics, etc.
  }
}
```

### 2. Real-time Listener Monitoring

```typescript
class ListenerPerformanceMonitor {
  private static listenerMetrics = new Map();
  
  static trackListener(listenerId: string, collection: string) {
    const startTime = Date.now();
    let updateCount = 0;
    
    const originalCallback = arguments[2]; // Assuming callback is third argument
    
    const wrappedCallback = (snapshot: any) => {
      updateCount++;
      const now = Date.now();
      
      this.listenerMetrics.set(listenerId, {
        collection,
        startTime,
        lastUpdate: now,
        updateCount,
        avgUpdateInterval: (now - startTime) / updateCount
      });
      
      originalCallback(snapshot);
    };
    
    return wrappedCallback;
  }
  
  static getListenerStats() {
    return Array.from(this.listenerMetrics.entries()).map(([id, metrics]) => ({
      id,
      ...metrics,
      uptime: Date.now() - metrics.startTime
    }));
  }
}
```

## Debugging Tools

### 1. Firestore Debug Console

```typescript
class FirestoreDebugger {
  static enableDebugMode() {
    // Enable Firestore debug logging
    firebase.firestore.setLogLevel('debug');
    
    // Log all Firestore operations
    const originalGet = firebase.firestore.prototype.get;
    firebase.firestore.prototype.get = function(...args) {
      console.log('Firestore GET:', this.path, args);
      return originalGet.apply(this, args);
    };
  }
  
  static logCollectionStats(collectionName: string) {
    return db.collection(collectionName).get().then(snapshot => {
      console.log(`Collection ${collectionName} stats:`, {
        documentCount: snapshot.size,
        fromCache: snapshot.metadata.fromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites
      });
    });
  }
}
```

### 2. Network Diagnostics

```typescript
class NetworkDiagnostics {
  static async runDiagnostics() {
    const results = {
      connectivity: await this.testConnectivity(),
      latency: await this.measureLatency(),
      throughput: await this.measureThroughput()
    };
    
    console.log('Network diagnostics:', results);
    return results;
  }
  
  private static async testConnectivity(): Promise<boolean> {
    try {
      const response = await fetch('https://firestore.googleapis.com/', {
        method: 'HEAD',
        mode: 'no-cors'
      });
      return true;
    } catch {
      return false;
    }
  }
  
  private static async measureLatency(): Promise<number> {
    const start = performance.now();
    
    try {
      await db.collection('_diagnostics').doc('ping').get();
      return performance.now() - start;
    } catch {
      return -1;
    }
  }
}
```

## Emergency Procedures

### 1. Service Outage Response

1. **Detect Outage**
   - Monitor error rates and response times
   - Check Firebase Status Dashboard
   - Verify network connectivity

2. **Activate Fallback**
   - Switch to cached data
   - Enable offline mode
   - Display appropriate user messages

3. **Communicate Status**
   - Update status page
   - Notify users of service issues
   - Provide estimated resolution time

### 2. Data Corruption Recovery

1. **Identify Scope**
   - Determine affected collections
   - Identify time range of corruption
   - Assess data integrity

2. **Restore from Backup**
   - Use Firebase export/import tools
   - Restore from point-in-time backup
   - Validate restored data

3. **Prevent Recurrence**
   - Review and fix root cause
   - Implement additional validation
   - Update monitoring and alerts

For additional support, contact the Firebase support team or refer to the Firebase documentation.