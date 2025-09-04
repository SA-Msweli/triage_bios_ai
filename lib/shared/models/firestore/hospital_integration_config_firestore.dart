import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for hospital integration configuration
class HospitalIntegrationConfigFirestore {
  final String id;
  final String hospitalId;
  final DataSourceType dataSource;
  final HospitalAPIConfig? apiConfig;
  final bool fallbackToFirestore;
  final bool realTimeEnabled;
  final int syncIntervalMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HospitalIntegrationConfigFirestore({
    required this.id,
    required this.hospitalId,
    required this.dataSource,
    this.apiConfig,
    required this.fallbackToFirestore,
    required this.realTimeEnabled,
    required this.syncIntervalMinutes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory HospitalIntegrationConfigFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return HospitalIntegrationConfigFirestore(
      id: doc.id,
      hospitalId: data['hospitalId'] as String,
      dataSource: DataSourceType.values.firstWhere(
        (e) => e.name == data['dataSource'],
        orElse: () => DataSourceType.firestore,
      ),
      apiConfig: data['apiConfig'] != null
          ? HospitalAPIConfig.fromMap(data['apiConfig'] as Map<String, dynamic>)
          : null,
      fallbackToFirestore: data['fallbackToFirestore'] as bool? ?? true,
      realTimeEnabled: data['realTimeEnabled'] as bool? ?? false,
      syncIntervalMinutes: data['syncIntervalMinutes'] as int? ?? 15,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'hospitalId': hospitalId,
      'dataSource': dataSource.name,
      'apiConfig': apiConfig?.toMap(),
      'fallbackToFirestore': fallbackToFirestore,
      'realTimeEnabled': realTimeEnabled,
      'syncIntervalMinutes': syncIntervalMinutes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  HospitalIntegrationConfigFirestore copyWith({
    String? id,
    String? hospitalId,
    DataSourceType? dataSource,
    HospitalAPIConfig? apiConfig,
    bool? fallbackToFirestore,
    bool? realTimeEnabled,
    int? syncIntervalMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HospitalIntegrationConfigFirestore(
      id: id ?? this.id,
      hospitalId: hospitalId ?? this.hospitalId,
      dataSource: dataSource ?? this.dataSource,
      apiConfig: apiConfig ?? this.apiConfig,
      fallbackToFirestore: fallbackToFirestore ?? this.fallbackToFirestore,
      realTimeEnabled: realTimeEnabled ?? this.realTimeEnabled,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Data source types for hospital integration
enum DataSourceType { firestore, customApi, hl7, fhir }

/// Hospital API configuration
class HospitalAPIConfig {
  final String baseUrl;
  final AuthenticationType authType;
  final Map<String, String> credentials;
  final Map<String, String> headers;
  final int timeoutSeconds;
  final int retryAttempts;
  final bool validateSsl;

  const HospitalAPIConfig({
    required this.baseUrl,
    required this.authType,
    required this.credentials,
    this.headers = const {},
    this.timeoutSeconds = 30,
    this.retryAttempts = 3,
    this.validateSsl = true,
  });

  /// Create from map
  factory HospitalAPIConfig.fromMap(Map<String, dynamic> map) {
    return HospitalAPIConfig(
      baseUrl: map['baseUrl'] as String,
      authType: AuthenticationType.values.firstWhere(
        (e) => e.name == map['authType'],
        orElse: () => AuthenticationType.apiKey,
      ),
      credentials: Map<String, String>.from(map['credentials'] as Map),
      headers: Map<String, String>.from(map['headers'] as Map? ?? {}),
      timeoutSeconds: map['timeoutSeconds'] as int? ?? 30,
      retryAttempts: map['retryAttempts'] as int? ?? 3,
      validateSsl: map['validateSsl'] as bool? ?? true,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'baseUrl': baseUrl,
      'authType': authType.name,
      'credentials': credentials,
      'headers': headers,
      'timeoutSeconds': timeoutSeconds,
      'retryAttempts': retryAttempts,
      'validateSsl': validateSsl,
    };
  }
}

/// Authentication types for hospital APIs
enum AuthenticationType {
  apiKey,
  oauth2,
  basicAuth,
  bearerToken,
  certificate,
  custom,
}

/// Hospital API endpoints configuration
class HospitalAPIEndpoints {
  final String capacityEndpoint;
  final String patientsEndpoint;
  final String vitalsEndpoint;
  final String statusEndpoint;

  const HospitalAPIEndpoints({
    required this.capacityEndpoint,
    required this.patientsEndpoint,
    required this.vitalsEndpoint,
    required this.statusEndpoint,
  });

  /// Create from map
  factory HospitalAPIEndpoints.fromMap(Map<String, dynamic> map) {
    return HospitalAPIEndpoints(
      capacityEndpoint: map['capacityEndpoint'] as String,
      patientsEndpoint: map['patientsEndpoint'] as String,
      vitalsEndpoint: map['vitalsEndpoint'] as String,
      statusEndpoint: map['statusEndpoint'] as String,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'capacityEndpoint': capacityEndpoint,
      'patientsEndpoint': patientsEndpoint,
      'vitalsEndpoint': vitalsEndpoint,
      'statusEndpoint': statusEndpoint,
    };
  }
}
