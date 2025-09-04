import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for hospital capacity data
class HospitalCapacityFirestore extends Equatable {
  final String id;
  final String hospitalId;
  final int totalBeds;
  final int availableBeds;
  final int icuBeds;
  final int icuAvailable;
  final int emergencyBeds;
  final int emergencyAvailable;
  final int staffOnDuty;
  final int patientsInQueue;
  final double averageWaitTime;
  final DateTime lastUpdated;
  final DataSource dataSource;
  final bool isRealTime;

  const HospitalCapacityFirestore({
    required this.id,
    required this.hospitalId,
    required this.totalBeds,
    required this.availableBeds,
    required this.icuBeds,
    required this.icuAvailable,
    required this.emergencyBeds,
    required this.emergencyAvailable,
    required this.staffOnDuty,
    required this.patientsInQueue,
    required this.averageWaitTime,
    required this.lastUpdated,
    required this.dataSource,
    required this.isRealTime,
  });

  /// Calculated occupancy rate
  double get occupancyRate =>
      totalBeds > 0 ? (totalBeds - availableBeds) / totalBeds : 1.0;

  /// Check if hospital is near capacity
  bool get isNearCapacity => occupancyRate > 0.85;

  /// Check if hospital is at capacity
  bool get isAtCapacity => occupancyRate > 0.95;

  /// Check if data is fresh (within 10 minutes)
  bool get isDataFresh => DateTime.now().difference(lastUpdated).inMinutes < 10;

  /// Create from Firestore document
  factory HospitalCapacityFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return HospitalCapacityFirestore(
      id: snapshot.id,
      hospitalId: data['hospitalId'] as String,
      totalBeds: data['totalBeds'] as int,
      availableBeds: data['availableBeds'] as int,
      icuBeds: data['icuBeds'] as int,
      icuAvailable: data['icuAvailable'] as int,
      emergencyBeds: data['emergencyBeds'] as int,
      emergencyAvailable: data['emergencyAvailable'] as int,
      staffOnDuty: data['staffOnDuty'] as int,
      patientsInQueue: data['patientsInQueue'] as int,
      averageWaitTime: (data['averageWaitTime'] as num).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      dataSource: DataSource.fromString(data['dataSource'] as String),
      isRealTime: data['isRealTime'] as bool,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'hospitalId': hospitalId,
      'totalBeds': totalBeds,
      'availableBeds': availableBeds,
      'icuBeds': icuBeds,
      'icuAvailable': icuAvailable,
      'emergencyBeds': emergencyBeds,
      'emergencyAvailable': emergencyAvailable,
      'staffOnDuty': staffOnDuty,
      'patientsInQueue': patientsInQueue,
      'averageWaitTime': averageWaitTime,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'dataSource': dataSource.toString(),
      'isRealTime': isRealTime,
      'occupancyRate': occupancyRate, // Calculated field for queries
    };
  }

  /// Create from JSON
  factory HospitalCapacityFirestore.fromJson(Map<String, dynamic> json) {
    return HospitalCapacityFirestore(
      id: json['id'] as String,
      hospitalId: json['hospitalId'] as String,
      totalBeds: json['totalBeds'] as int,
      availableBeds: json['availableBeds'] as int,
      icuBeds: json['icuBeds'] as int,
      icuAvailable: json['icuAvailable'] as int,
      emergencyBeds: json['emergencyBeds'] as int,
      emergencyAvailable: json['emergencyAvailable'] as int,
      staffOnDuty: json['staffOnDuty'] as int,
      patientsInQueue: json['patientsInQueue'] as int,
      averageWaitTime: (json['averageWaitTime'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      dataSource: DataSource.fromString(json['dataSource'] as String),
      isRealTime: json['isRealTime'] as bool,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hospitalId': hospitalId,
      'totalBeds': totalBeds,
      'availableBeds': availableBeds,
      'icuBeds': icuBeds,
      'icuAvailable': icuAvailable,
      'emergencyBeds': emergencyBeds,
      'emergencyAvailable': emergencyAvailable,
      'staffOnDuty': staffOnDuty,
      'patientsInQueue': patientsInQueue,
      'averageWaitTime': averageWaitTime,
      'lastUpdated': lastUpdated.toIso8601String(),
      'dataSource': dataSource.toString(),
      'isRealTime': isRealTime,
      'occupancyRate': occupancyRate,
    };
  }

  HospitalCapacityFirestore copyWith({
    String? id,
    String? hospitalId,
    int? totalBeds,
    int? availableBeds,
    int? icuBeds,
    int? icuAvailable,
    int? emergencyBeds,
    int? emergencyAvailable,
    int? staffOnDuty,
    int? patientsInQueue,
    double? averageWaitTime,
    DateTime? lastUpdated,
    DataSource? dataSource,
    bool? isRealTime,
  }) {
    return HospitalCapacityFirestore(
      id: id ?? this.id,
      hospitalId: hospitalId ?? this.hospitalId,
      totalBeds: totalBeds ?? this.totalBeds,
      availableBeds: availableBeds ?? this.availableBeds,
      icuBeds: icuBeds ?? this.icuBeds,
      icuAvailable: icuAvailable ?? this.icuAvailable,
      emergencyBeds: emergencyBeds ?? this.emergencyBeds,
      emergencyAvailable: emergencyAvailable ?? this.emergencyAvailable,
      staffOnDuty: staffOnDuty ?? this.staffOnDuty,
      patientsInQueue: patientsInQueue ?? this.patientsInQueue,
      averageWaitTime: averageWaitTime ?? this.averageWaitTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dataSource: dataSource ?? this.dataSource,
      isRealTime: isRealTime ?? this.isRealTime,
    );
  }

  @override
  List<Object> get props => [
    id,
    hospitalId,
    totalBeds,
    availableBeds,
    icuBeds,
    icuAvailable,
    emergencyBeds,
    emergencyAvailable,
    staffOnDuty,
    patientsInQueue,
    averageWaitTime,
    lastUpdated,
    dataSource,
    isRealTime,
  ];
}

enum DataSource {
  firestore,
  customApi;

  factory DataSource.fromString(String value) {
    switch (value) {
      case 'firestore':
        return DataSource.firestore;
      case 'custom_api':
        return DataSource.customApi;
      default:
        return DataSource.firestore;
    }
  }

  @override
  String toString() {
    switch (this) {
      case DataSource.firestore:
        return 'firestore';
      case DataSource.customApi:
        return 'custom_api';
    }
  }
}
