import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../services/offline_support_service.dart';

/// Cache entry metadata
class CacheEntry {
  final String key;
  final dynamic data;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DataPriority priority;
  final int sizeBytes;

  CacheEntry({
    required this.key,
    required this.data,
    required this.createdAt,
    required this.expiresAt,
    required this.priority,
    required this.sizeBytes,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'key': key,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'priority': priority.name,
    'sizeBytes': sizeBytes,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    key: json['key'],
    data: json['data'],
    createdAt: DateTime.parse(json['createdAt']),
    expiresAt: DateTime.parse(json['expiresAt']),
    priority: DataPriority.values.firstWhere((e) => e.name == json['priority']),
    sizeBytes: json['sizeBytes'] ?? 0,
  );
}

/// Cache statistics
class CacheStats {
  final int totalEntries;
  final int totalSizeBytes;
  final Map<DataPriority, int> entriesByPriority;
  final Map<DataPriority, int> sizeByPriority;
  final int expiredEntries;
  final double hitRate;
  final double missRate;

  CacheStats({
    required this.totalEntries,
    required this.totalSizeBytes,
    required this.entriesByPriority,
    required this.sizeByPriority,
    required this.expiredEntries,
    required this.hitRate,
    required this.missRate,
  });

  Map<String, dynamic> toJson() => {
    'totalEntries': totalEntries,
    'totalSizeBytes': totalSizeBytes,
    'entriesByPriority': entriesByPriority.map((k, v) => MapEntry(k.name, v)),
    'sizeByPriority': sizeByPriority.map((k, v) => MapEntry(k.name, v)),
    'expiredEntries': expiredEntries,
    'hitRate': hitRate,
    'missRate': missRate,
  };
}

/// Intelligent cache manager for Firestore data
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Logger _logger = Logger();
  final Map<String, CacheEntry> _cache = {};
  
  // Cache configuration
  static const Duration _defaultTTL = Duration(hours: 1);
  static const int _maxCacheEntries = 1000;
  static const int _maxCacheSizeBytes = 50 * 1024 * 1024; // 50MB
  
  // Cache metrics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Get TTL based on data priority
  Duration _getTTLForPriority(DataPriority priority) {
    switch (priority) {
      case DataPriority.critical:
        return const Duration(minutes: 5);
      case DataPriority.high:
        return const Duration(minutes: 15);
      case DataPriority.medium:
        return const Duration(hours: 1);
      case DataPriority.low:
        return const Duration(hours: 6);
    }
  }

  /// Estimate size of data in bytes
  int _estimateDataSize(dynamic data) {
    try {
      final jsonString = jsonEncode(data);
      return jsonString.length * 2; // Rough estimate for UTF-16 encoding
    } catch (e) {
      return 1024; // Default estimate if encoding fails
    }
  }

  /// Store data in cache with intelligent policies
  Future<void> store({
    required String key,
    required dynamic data,
    required DataPriority priority,
    Duration? customTTL,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final ttl = customTTL ?? _getTTLForPriority(priority);
      final expiresAt = now.add(ttl);
      final sizeBytes = _estimateDataSize(data);

      final entry = CacheEntry(
        key: key,
        data: data,
        createdAt: now,
        expiresAt: expiresAt,
        priority: priority,
        sizeBytes: sizeBytes,
      );

      // Store in memory cache
      _cache[key] = entry;

      // Store in persistent cache
      await prefs.setString('cache_entry_$key', jsonEncode(entry.toJson()));

      // Trigger cleanup if needed
      await _cleanupIfNeeded();

      _logger.d('Cached data for key: $key (${priority.name} priority)');
    } catch (e) {
      _logger.e('Failed to store cache entry: $e');
    }
  }

  /// Retrieve data from cache
  Future<T?> get<T>(String key) async {
    try {
      // Check memory cache first
      if (_cache.containsKey(key)) {
        final entry = _cache[key]!;
        if (!entry.isExpired) {
          _cacheHits++;
          return entry.data as T?;
        } else {
          _cache.remove(key);
        }
      }

      // Check persistent cache
      final prefs = await SharedPreferences.getInstance();
      final entryData = prefs.getString('cache_entry_$key');
      
      if (entryData != null) {
        final entry = CacheEntry.fromJson(jsonDecode(entryData));
        
        if (!entry.isExpired) {
          // Restore to memory cache
          _cache[key] = entry;
          _cacheHits++;
          return entry.data as T?;
        } else {
          // Remove expired entry
          await prefs.remove('cache_entry_$key');
        }
      }

      _cacheMisses++;
      return null;
    } catch (e) {
      _logger.e('Failed to get cache entry: $e');
      _cacheMisses++;
      return null;
    }
  }

  /// Remove specific cache entry
  Future<void> remove(String key) async {
    try {
      _cache.remove(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_entry_$key');
      _logger.d('Removed cache entry: $key');
    } catch (e) {
      _logger.e('Failed to remove cache entry: $e');
    }
  }

  /// Clear all cache entries
  Future<void> clear() async {
    try {
      _cache.clear();
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      _cacheHits = 0;
      _cacheMisses = 0;
      
      _logger.i('Cache cleared');
    } catch (e) {
      _logger.e('Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStats> getStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));

      int totalEntries = 0;
      int totalSizeBytes = 0;
      int expiredEntries = 0;
      final entriesByPriority = <DataPriority, int>{};
      final sizeByPriority = <DataPriority, int>{};

      for (final key in keys) {
        final entryData = prefs.getString(key);
        if (entryData != null) {
          try {
            final entry = CacheEntry.fromJson(jsonDecode(entryData));
            
            totalEntries++;
            totalSizeBytes += entry.sizeBytes;
            
            if (entry.isExpired) {
              expiredEntries++;
            }
            
            entriesByPriority[entry.priority] = (entriesByPriority[entry.priority] ?? 0) + 1;
            sizeByPriority[entry.priority] = (sizeByPriority[entry.priority] ?? 0) + entry.sizeBytes;
          } catch (e) {
            // Count corrupted entries as expired
            expiredEntries++;
          }
        }
      }

      final totalRequests = _cacheHits + _cacheMisses;
      final hitRate = totalRequests > 0 ? (_cacheHits / totalRequests).toDouble() : 0.0;
      final missRate = totalRequests > 0 ? (_cacheMisses / totalRequests).toDouble() : 0.0;

      return CacheStats(
        totalEntries: totalEntries,
        totalSizeBytes: totalSizeBytes,
        entriesByPriority: entriesByPriority,
        sizeByPriority: sizeByPriority,
        expiredEntries: expiredEntries,
        hitRate: hitRate,
        missRate: missRate,
      );
    } catch (e) {
      _logger.e('Failed to get cache stats: $e');
      return CacheStats(
        totalEntries: 0,
        totalSizeBytes: 0,
        entriesByPriority: {},
        sizeByPriority: {},
        expiredEntries: 0,
        hitRate: 0.0,
        missRate: 0.0,
      );
    }
  }

  /// Cleanup expired entries and enforce size limits
  Future<void> _cleanupIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));
      
      final entries = <CacheEntry>[];
      
      // Load all entries and remove expired ones
      for (final key in keys) {
        final entryData = prefs.getString(key);
        if (entryData != null) {
          try {
            final entry = CacheEntry.fromJson(jsonDecode(entryData));
            if (entry.isExpired) {
              await prefs.remove(key);
              _cache.remove(entry.key);
            } else {
              entries.add(entry);
            }
          } catch (e) {
            // Remove corrupted entries
            await prefs.remove(key);
          }
        }
      }

      // Check if we need to enforce size limits
      if (entries.length > _maxCacheEntries || 
          entries.fold(0, (sum, entry) => sum + entry.sizeBytes) > _maxCacheSizeBytes) {
        
        // Sort by priority and age (keep high priority and recent entries)
        entries.sort((a, b) {
          final priorityComparison = b.priority.index.compareTo(a.priority.index);
          if (priorityComparison != 0) return priorityComparison;
          return b.createdAt.compareTo(a.createdAt);
        });

        // Remove excess entries
        final entriesToKeep = entries.take(_maxCacheEntries).where(
          (entry) => entries.take(entries.indexOf(entry) + 1)
              .fold(0, (sum, e) => sum + e.sizeBytes) <= _maxCacheSizeBytes
        ).toList();

        // Remove entries that exceed limits
        for (final entry in entries) {
          if (!entriesToKeep.contains(entry)) {
            await prefs.remove('cache_entry_${entry.key}');
            _cache.remove(entry.key);
          }
        }

        _logger.i('Cache cleanup completed. Kept ${entriesToKeep.length} entries');
      }
    } catch (e) {
      _logger.e('Cache cleanup failed: $e');
    }
  }

  /// Preload critical data into cache
  Future<void> preloadCriticalData() async {
    // This method can be implemented to preload important data
    _logger.i('Preloading critical data into cache');
  }

  // Method aliases for backward compatibility
  
  /// Alias for clear() method
  Future<void> clearAll() => clear();

  /// Retrieve data from cache (alias for get method)
  Future<T?> retrieve<T>(String key) => get<T>(key);

  /// Check if cache entry exists and is not expired
  Future<bool> exists(String key) async {
    final entry = await get(key);
    return entry != null;
  }

  /// Clear expired entries only
  Future<void> clearExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));
      
      int removedCount = 0;
      
      for (final key in keys) {
        final entryData = prefs.getString(key);
        if (entryData != null) {
          try {
            final entry = CacheEntry.fromJson(jsonDecode(entryData));
            if (entry.isExpired) {
              await prefs.remove(key);
              _cache.remove(entry.key);
              removedCount++;
            }
          } catch (e) {
            // Remove corrupted entries
            await prefs.remove(key);
            removedCount++;
          }
        }
      }
      
      _logger.i('Cleared $removedCount expired cache entries');
    } catch (e) {
      _logger.e('Failed to clear expired cache entries: $e');
    }
  }
}