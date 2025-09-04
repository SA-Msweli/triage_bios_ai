import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../services/offline_support_service.dart';

/// Utility class for managing cache operations and policies
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Logger _logger = Logger();
  
  // Cache configuration
  static const Duration _defaultTTL = Duration(hours: 1);
  static const int _maxCacheEntries = 1000;
  static const int _maxCacheSizeBytes = 50 * 1024 * 1024; // 50MB

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

      // Store the cache entry
      await prefs.setString('cache_entry_$key', jsonEncode(entry.toJson()));

      // Update cache metadata
      await _updateCacheMetadata(key, entry);

      // Perform cache cleanup if needed
      await _performCacheCleanup();

      _logger.d('Cached data for key: $key (${priority.name}, ${sizeBytes}B)');
    } catch (e) {
      _logger.e('Failed to store cache entry for key $key: $e');
    }
  }

  /// Retrieve data from cache
  Future<T?> retrieve<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entryData = prefs.getString('cache_entry_$key');

      if (entryData == null) {
        _cacheMisses++;
        return null;
      }

      final entry = CacheEntry.fromJson(jsonDecode(entryData));

      if (entry.isExpired) {
        // Remove expired entry
        await prefs.remove('cache_entry_$key');
        await _removeCacheMetadata(key);
        _cacheMisses++;
        return null;
      }

      _cacheHits++;
      return entry.data as T?;
    } catch (e) {
      _logger.e('Failed to retrieve cache entry for key $key: $e');
      _cacheMisses++;
      return null;
    }
  }

  /// Check if key exists in cache and is not expired
  Future<bool> exists(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entryData = prefs.getString('cache_entry_$key');

      if (entryData == null) return false;

      final entry = CacheEntry.fromJson(jsonDecode(entryData));
      return !entry.isExpired;
    } catch (e) {
      _logger.e('Failed to check cache existence for key $key: $e');
      return false;
    }
  }

  /// Remove specific cache entry
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_entry_$key');
      await _removeCacheMetadata(key);
      _logger.d('Removed cache entry for key: $key');
    } catch (e) {
      _logger.e('Failed to remove cache entry for key $key: $e');
    }
  }

  /// Clear all cache entries
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));

      for (final key in keys) {
        await prefs.remove(key);
      }

      // Clear metadata
      await prefs.remove('cache_metadata');
      
      // Reset metrics
      _cacheHits = 0;
      _cacheMisses = 0;

      _logger.i('Cleared all cache entries');
    } catch (e) {
      _logger.e('Failed to clear cache: $e');
    }
  }

  /// Clear expired entries
  Future<int> clearExpired() async {
    int removedCount = 0;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));

      for (final key in keys) {
        final entryData = prefs.getString(key);
        if (entryData != null) {
          try {
            final entry = CacheEntry.fromJson(jsonDecode(entryData));
            if (entry.isExpired) {
              await prefs.remove(key);
              await _removeCacheMetadata(entry.key);
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

    return removedCount;
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
      final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;
      final missRate = totalRequests > 0 ? _cacheMisses / totalRequests : 0.0;

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

  /// Update cache metadata
  Future<void> _updateCacheMetadata(String key, CacheEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString('cache_metadata') ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      
      metadata[key] = {
        'priority': entry.priority.name,
        'sizeBytes': entry.sizeBytes,
        'createdAt': entry.createdAt.toIso8601String(),
        'expiresAt': entry.expiresAt.toIso8601String(),
      };
      
      await prefs.setString('cache_metadata', jsonEncode(metadata));
    } catch (e) {
      _logger.e('Failed to update cache metadata: $e');
    }
  }

  /// Remove cache metadata
  Future<void> _removeCacheMetadata(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString('cache_metadata') ?? '{}';
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      
      metadata.remove(key);
      
      await prefs.setString('cache_metadata', jsonEncode(metadata));
    } catch (e) {
      _logger.e('Failed to remove cache metadata: $e');
    }
  }

  /// Perform cache cleanup based on size and entry limits
  Future<void> _performCacheCleanup() async {
    try {
      final stats = await getStats();
      
      // Check if cleanup is needed
      if (stats.totalEntries <= _maxCacheEntries && stats.totalSizeBytes <= _maxCacheSizeBytes) {
        return;
      }

      _logger.i('Performing cache cleanup (${stats.totalEntries} entries, ${stats.totalSizeBytes}B)');

      // First, remove expired entries
      await clearExpired();

      // If still over limits, remove entries by priority (low priority first)
      final updatedStats = await getStats();
      if (updatedStats.totalEntries > _maxCacheEntries || updatedStats.totalSizeBytes > _maxCacheSizeBytes) {
        await _removeEntriesByPriority();
      }

      final finalStats = await getStats();
      _logger.i('Cache cleanup completed (${finalStats.totalEntries} entries, ${finalStats.totalSizeBytes}B)');
    } catch (e) {
      _logger.e('Failed to perform cache cleanup: $e');
    }
  }

  /// Remove cache entries by priority (lowest priority first)
  Future<void> _removeEntriesByPriority() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_entry_'));
      
      // Collect entries with their priorities
      final entries = <CacheEntry>[];
      for (final key in keys) {
        final entryData = prefs.getString(key);
        if (entryData != null) {
          try {
            final entry = CacheEntry.fromJson(jsonDecode(entryData));
            entries.add(entry);
          } catch (e) {
            // Remove corrupted entries
            await prefs.remove(key);
          }
        }
      }

      // Sort by priority (low priority first) and creation time (oldest first)
      entries.sort((a, b) {
        final priorityComparison = b.priority.index.compareTo(a.priority.index); // Reverse for low priority first
        if (priorityComparison != 0) return priorityComparison;
        return a.createdAt.compareTo(b.createdAt); // Oldest first
      });

      // Remove entries until we're under the limits
      int removedCount = 0;
      int currentSize = entries.fold(0, (sum, entry) => sum + entry.sizeBytes);
      
      for (final entry in entries) {
        if (entries.length - removedCount <= _maxCacheEntries * 0.8 && 
            currentSize <= _maxCacheSizeBytes * 0.8) {
          break; // Keep some buffer
        }
        
        await prefs.remove('cache_entry_${entry.key}');
        await _removeCacheMetadata(entry.key);
        currentSize -= entry.sizeBytes;
        removedCount++;
      }

      _logger.i('Removed $removedCount cache entries during cleanup');
    } catch (e) {
      _logger.e('Failed to remove entries by priority: $e');
    }
  }

  /// Preload critical data into cache
  Future<void> preloadCriticalData(Map<String, dynamic> criticalData) async {
    try {
      for (final entry in criticalData.entries) {
        await store(
          key: entry.key,
          data: entry.value,
          priority: DataPriority.critical,
        );
      }
      
      _logger.i('Preloaded ${criticalData.length} critical data entries');
    } catch (e) {
      _logger.e('Failed to preload critical data: $e');
    }
  }

  /// Warm up cache with frequently accessed data
  Future<void> warmUpCache(List<String> frequentKeys, Future<dynamic> Function(String) dataLoader) async {
    try {
      int warmedCount = 0;
      
      for (final key in frequentKeys) {
        final exists = await this.exists(key);
        if (!exists) {
          try {
            final data = await dataLoader(key);
            if (data != null) {
              await store(
                key: key,
                data: data,
                priority: DataPriority.high,
              );
              warmedCount++;
            }
          } catch (e) {
            _logger.w('Failed to warm up cache for key $key: $e');
          }
        }
      }
      
      _logger.i('Warmed up cache with $warmedCount entries');
    } catch (e) {
      _logger.e('Failed to warm up cache: $e');
    }
  }

  /// Reset cache metrics
  void resetMetrics() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _logger.i('Cache metrics reset');
  }
}