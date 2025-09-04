/// Query ordering for Firestore queries
class QueryOrder {
  final String field;
  final bool descending;

  const QueryOrder({required this.field, this.descending = false});

  /// Create ascending order
  factory QueryOrder.asc(String field) {
    return QueryOrder(field: field, descending: false);
  }

  /// Create descending order
  factory QueryOrder.desc(String field) {
    return QueryOrder(field: field, descending: true);
  }

  @override
  String toString() {
    return 'QueryOrder(field: $field, descending: $descending)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryOrder &&
        other.field == field &&
        other.descending == descending;
  }

  @override
  int get hashCode => Object.hash(field, descending);
}
