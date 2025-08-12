class PatientConsent {
  final String consentId;
  final String patientId;
  final String providerId;
  final String consentType;
  final List<String> dataScopes;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String blockchainTxId;
  final Map<String, dynamic> consentDetails;

  const PatientConsent({
    required this.consentId,
    required this.patientId,
    required this.providerId,
    required this.consentType,
    required this.dataScopes,
    required this.grantedAt,
    this.expiresAt,
    required this.isActive,
    required this.blockchainTxId,
    required this.consentDetails,
  });

  factory PatientConsent.fromJson(Map<String, dynamic> json) {
    return PatientConsent(
      consentId: json['consentId'],
      patientId: json['patientId'],
      providerId: json['providerId'],
      consentType: json['consentType'],
      dataScopes: List<String>.from(json['dataScopes']),
      grantedAt: DateTime.parse(json['grantedAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      isActive: json['isActive'],
      blockchainTxId: json['blockchainTxId'],
      consentDetails: Map<String, dynamic>.from(json['consentDetails']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consentId': consentId,
      'patientId': patientId,
      'providerId': providerId,
      'consentType': consentType,
      'dataScopes': dataScopes,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
      'blockchainTxId': blockchainTxId,
      'consentDetails': consentDetails,
    };
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool hasDataScope(String scope) => dataScopes.contains(scope);
}
