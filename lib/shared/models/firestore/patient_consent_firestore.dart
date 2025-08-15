import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for patient consent management
class PatientConsentFirestore extends Equatable {
  final String id;
  final String patientId;
  final String providerId;
  final ConsentType consentType;
  final List<String> dataScopes;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final bool isActive;
  final String blockchainTxId;
  final String ipAddress;
  final Map<String, dynamic> consentDetails;

  const PatientConsentFirestore({
    required this.id,
    required this.patientId,
    required this.providerId,
    required this.consentType,
    required this.dataScopes,
    required this.grantedAt,
    this.expiresAt,
    this.revokedAt,
    required this.isActive,
    required this.blockchainTxId,
    required this.ipAddress,
    required this.consentDetails,
  });

  /// Check if consent is currently valid
  bool get isValid {
    if (!isActive || revokedAt != null) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// Check if consent is expired
  bool get isExpired {
    return expiresAt != null && DateTime.now().isAfter(expiresAt!);
  }

  /// Check if consent was revoked
  bool get isRevoked => revokedAt != null;

  /// Get consent status
  ConsentStatus get status {
    if (isRevoked) return ConsentStatus.revoked;
    if (isExpired) return ConsentStatus.expired;
    if (isValid) return ConsentStatus.active;
    return ConsentStatus.inactive;
  }

  /// Create from Firestore document
  factory PatientConsentFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return PatientConsentFirestore(
      id: snapshot.id,
      patientId: data['patientId'] as String,
      providerId: data['providerId'] as String,
      consentType: ConsentType.fromString(data['consentType'] as String),
      dataScopes: List<String>.from(data['dataScopes'] as List),
      grantedAt: (data['grantedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      revokedAt: (data['revokedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool,
      blockchainTxId: data['blockchainTxId'] as String,
      ipAddress: data['ipAddress'] as String,
      consentDetails: Map<String, dynamic>.from(data['consentDetails'] as Map),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'providerId': providerId,
      'consentType': consentType.toString(),
      'dataScopes': dataScopes,
      'grantedAt': Timestamp.fromDate(grantedAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
      'isActive': isActive,
      'blockchainTxId': blockchainTxId,
      'ipAddress': ipAddress,
      'consentDetails': consentDetails,
      'isValid': isValid,
      'isExpired': isExpired,
      'isRevoked': isRevoked,
      'status': status.toString(),
    };
  }

  PatientConsentFirestore copyWith({
    String? id,
    String? patientId,
    String? providerId,
    ConsentType? consentType,
    List<String>? dataScopes,
    DateTime? grantedAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
    bool? isActive,
    String? blockchainTxId,
    String? ipAddress,
    Map<String, dynamic>? consentDetails,
  }) {
    return PatientConsentFirestore(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      providerId: providerId ?? this.providerId,
      consentType: consentType ?? this.consentType,
      dataScopes: dataScopes ?? this.dataScopes,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
      isActive: isActive ?? this.isActive,
      blockchainTxId: blockchainTxId ?? this.blockchainTxId,
      ipAddress: ipAddress ?? this.ipAddress,
      consentDetails: consentDetails ?? this.consentDetails,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    providerId,
    consentType,
    dataScopes,
    grantedAt,
    expiresAt,
    revokedAt,
    isActive,
    blockchainTxId,
    ipAddress,
    consentDetails,
  ];
}

enum ConsentType {
  treatment,
  dataSharing,
  emergency;

  factory ConsentType.fromString(String value) {
    switch (value) {
      case 'treatment':
        return ConsentType.treatment;
      case 'data_sharing':
        return ConsentType.dataSharing;
      case 'emergency':
        return ConsentType.emergency;
      default:
        return ConsentType.treatment;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ConsentType.treatment:
        return 'treatment';
      case ConsentType.dataSharing:
        return 'data_sharing';
      case ConsentType.emergency:
        return 'emergency';
    }
  }

  String get displayName {
    switch (this) {
      case ConsentType.treatment:
        return 'Treatment Consent';
      case ConsentType.dataSharing:
        return 'Data Sharing Consent';
      case ConsentType.emergency:
        return 'Emergency Consent';
    }
  }
}

enum ConsentStatus {
  active,
  expired,
  revoked,
  inactive;

  @override
  String toString() {
    switch (this) {
      case ConsentStatus.active:
        return 'active';
      case ConsentStatus.expired:
        return 'expired';
      case ConsentStatus.revoked:
        return 'revoked';
      case ConsentStatus.inactive:
        return 'inactive';
    }
  }

  String get displayName {
    switch (this) {
      case ConsentStatus.active:
        return 'Active';
      case ConsentStatus.expired:
        return 'Expired';
      case ConsentStatus.revoked:
        return 'Revoked';
      case ConsentStatus.inactive:
        return 'Inactive';
    }
  }
}
