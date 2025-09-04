/// Result of a paginated query
class PaginatedResult<T> {
  final List<T> items;
  final String? nextPageToken;
  final bool hasMore;
  final int? totalCount;

  const PaginatedResult({
    required this.items,
    this.nextPageToken,
    required this.hasMore,
    this.totalCount,
  });

  /// Create empty result
  factory PaginatedResult.empty() {
    return PaginatedResult<T>(items: const [], hasMore: false);
  }

  /// Get the number of items in this page
  int get pageSize => items.length;

  /// Check if this is the first page
  bool get isFirstPage => nextPageToken == null;

  /// Check if there are items in this page
  bool get isEmpty => items.isEmpty;

  /// Check if there are items in this page
  bool get isNotEmpty => items.isNotEmpty;

  @override
  String toString() {
    return 'PaginatedResult(items: ${items.length}, hasMore: $hasMore, totalCount: $totalCount)';
  }
}

/// Cache for paginated results
class PaginationCache {
  final List<dynamic> items;
  final String? nextPageToken;
  final bool hasMore;
  final int? totalCount;
  final DateTime cachedAt;

  const PaginationCache({
    required this.items,
    this.nextPageToken,
    required this.hasMore,
    this.totalCount,
    required this.cachedAt,
  });

  /// Check if cache is still valid (5 minutes)
  bool get isValid {
    return DateTime.now().difference(cachedAt) < const Duration(minutes: 5);
  }

  /// Get cache age
  Duration get age => DateTime.now().difference(cachedAt);
}
