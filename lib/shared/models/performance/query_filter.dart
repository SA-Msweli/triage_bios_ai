/// Query filter for Firestore queries
class QueryFilter {
  final String field;
  final FilterType type;
  final dynamic value;

  const QueryFilter({
    required this.field,
    required this.type,
    required this.value,
  });

  /// Create equality filter
  factory QueryFilter.isEqualTo(String field, dynamic value) {
    return QueryFilter(field: field, type: FilterType.isEqualTo, value: value);
  }

  /// Create not equal filter
  factory QueryFilter.isNotEqualTo(String field, dynamic value) {
    return QueryFilter(
      field: field,
      type: FilterType.isNotEqualTo,
      value: value,
    );
  }

  /// Create less than filter
  factory QueryFilter.isLessThan(String field, dynamic value) {
    return QueryFilter(field: field, type: FilterType.isLessThan, value: value);
  }

  /// Create less than or equal filter
  factory QueryFilter.isLessThanOrEqualTo(String field, dynamic value) {
    return QueryFilter(
      field: field,
      type: FilterType.isLessThanOrEqualTo,
      value: value,
    );
  }

  /// Create greater than filter
  factory QueryFilter.isGreaterThan(String field, dynamic value) {
    return QueryFilter(
      field: field,
      type: FilterType.isGreaterThan,
      value: value,
    );
  }

  /// Create greater than or equal filter
  factory QueryFilter.isGreaterThanOrEqualTo(String field, dynamic value) {
    return QueryFilter(
      field: field,
      type: FilterType.isGreaterThanOrEqualTo,
      value: value,
    );
  }

  /// Create array contains filter
  factory QueryFilter.arrayContains(String field, dynamic value) {
    return QueryFilter(
      field: field,
      type: FilterType.arrayContains,
      value: value,
    );
  }

  /// Create array contains any filter
  factory QueryFilter.arrayContainsAny(String field, List<dynamic> values) {
    return QueryFilter(
      field: field,
      type: FilterType.arrayContainsAny,
      value: values,
    );
  }

  /// Create where in filter
  factory QueryFilter.whereIn(String field, List<dynamic> values) {
    return QueryFilter(field: field, type: FilterType.whereIn, value: values);
  }

  /// Create where not in filter
  factory QueryFilter.whereNotIn(String field, List<dynamic> values) {
    return QueryFilter(
      field: field,
      type: FilterType.whereNotIn,
      value: values,
    );
  }

  /// Create is null filter
  factory QueryFilter.isNull(String field) {
    return QueryFilter(field: field, type: FilterType.isNull, value: null);
  }

  /// Create is not null filter
  factory QueryFilter.isNotNull(String field) {
    return QueryFilter(field: field, type: FilterType.isNotNull, value: null);
  }

  @override
  String toString() {
    return 'QueryFilter(field: $field, type: $type, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryFilter &&
        other.field == field &&
        other.type == type &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(field, type, value);
}

/// Types of query filters
enum FilterType {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
  whereNotIn,
  isNull,
  isNotNull,
}
