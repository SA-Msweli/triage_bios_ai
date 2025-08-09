import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Basic consent management service for patient data sharing
class ConsentService {
  static final ConsentService _instance = ConsentService._internal();
  factory ConsentService() => _instance;
  ConsentService._internal();

  final Logger _logger = Logger();
  static const String _consentKey = 'patient_consent_records';

  /// Record patient consent for data sharing with a hospital
  Future<ConsentRecord> recordConsent({
    required String patientId,
    required String hospitalId,
    required List<String> dataScope,
    required bool consentGranted,
    String? reason,
  }) async {
    try {
      final consentRecord = ConsentRecord(
        id: _generateConsentId(patientId, hospitalId),
        patientId: patientId,
        hospitalId: hospitalId,
        dataScope: dataScope,
        consentGranted: consentGranted,
        timestamp: DateTime.now(),
        reason: reason,
        expirationTime: _calculateExpiration(consentGranted),
      );

      await _storeConsentRecord(consentRecord);
      
      _logger.i(
        'Consent recorded: Patient $patientId ${consentGranted ? 'granted' : 'denied'} '
        'data sharing with hospital $hospitalId',
      );

      return consentRecord;
    } catch (e) {
      _logger.e('Failed to record consent: $e');
      rethrow;
    }
  }

  /// Verify if patient has valid consent for data sharing
  Future<ConsentVerification> verifyConsent({
    required String patientId,
    required String hospitalId,
    required List<String> requestedData,
  }) async {
    try {
      final consentRecords = await _getConsentRecords(patientId, hospitalId);
      
      // Find the most recent valid consent
      ConsentRecord? validConsent;
      for (final record in consentRecords.reversed) {
        if (_isConsentValid(record) && _coversRequestedData(record.dataScope, requestedData)) {
          validConsent = record;
          break;
        }
      }

      final verification = ConsentVerification(
        isValid: validConsent != null,
        consentRecord: validConsent,
        requestedData: requestedData,
        verificationTime: DateTime.now(),
      );

      _logger.i(
        'Consent verification: Patient $patientId consent for hospital $hospitalId is '
        '${verification.isValid ? 'VALID' : 'INVALID'}',
      );

      return verification;
    } catch (e) {
      _logger.e('Failed to verify consent: $e');
      return ConsentVerification(
        isValid: false,
        consentRecord: null,
        requestedData: requestedData,
        verificationTime: DateTime.now(),
      );
    }
  }

  /// Get all consent records for a patient
  Future<List<ConsentRecord>> getPatientConsentHistory(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consentJson = prefs.getString(_consentKey);
      
      if (consentJson == null) return [];

      final allConsents = (jsonDecode(consentJson) as List)
          .map((json) => ConsentRecord.fromJson(json))
          .toList();

      return allConsents.where((consent) => consent.patientId == patientId).toList();
    } catch (e) {
      _logger.e('Failed to get consent history: $e');
      return [];
    }
  }

  /// Revoke consent for a specific hospital
  Future<void> revokeConsent({
    required String patientId,
    required String hospitalId,
    String? reason,
  }) async {
    try {
      await recordConsent(
        patientId: patientId,
        hospitalId: hospitalId,
        dataScope: [],
        consentGranted: false,
        reason: reason ?? 'Patient revoked consent',
      );

      _logger.i('Consent revoked: Patient $patientId revoked consent for hospital $hospitalId');
    } catch (e) {
      _logger.e('Failed to revoke consent: $e');
      rethrow;
    }
  }

  /// Get audit trail for compliance reporting
  Future<List<ConsentAuditEntry>> getAuditTrail({
    String? patientId,
    String? hospitalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final allConsents = await _getAllConsentRecords();
      
      var filteredConsents = allConsents.where((consent) {
        if (patientId != null && consent.patientId != patientId) return false;
        if (hospitalId != null && consent.hospitalId != hospitalId) return false;
        if (fromDate != null && consent.timestamp.isBefore(fromDate)) return false;
        if (toDate != null && consent.timestamp.isAfter(toDate)) return false;
        return true;
      }).toList();

      return filteredConsents.map((consent) => ConsentAuditEntry(
        consentId: consent.id,
        patientId: consent.patientId,
        hospitalId: consent.hospitalId,
        action: consent.consentGranted ? 'GRANTED' : 'DENIED',
        timestamp: consent.timestamp,
        dataScope: consent.dataScope,
        reason: consent.reason,
      )).toList();
    } catch (e) {
      _logger.e('Failed to get audit trail: $e');
      return [];
    }
  }

  /// Clear all consent records (for testing/privacy)
  Future<void> clearAllConsents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_consentKey);
      _logger.i('All consent records cleared');
    } catch (e) {
      _logger.e('Failed to clear consent records: $e');
    }
  }

  // Private helper methods

  String _generateConsentId(String patientId, String hospitalId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'consent_${patientId}_${hospitalId}_$timestamp';
  }

  DateTime _calculateExpiration(bool consentGranted) {
    if (!consentGranted) {
      return DateTime.now(); // Denied consent expires immediately
    }
    // Granted consent expires in 30 days
    return DateTime.now().add(const Duration(days: 30));
  }

  Future<void> _storeConsentRecord(ConsentRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existingConsents = await _getAllConsentRecords();
    
    existingConsents.add(record);
    
    final consentJson = jsonEncode(
      existingConsents.map((consent) => consent.toJson()).toList(),
    );
    
    await prefs.setString(_consentKey, consentJson);
  }

  Future<List<ConsentRecord>> _getAllConsentRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consentJson = prefs.getString(_consentKey);
      
      if (consentJson == null) return [];

      return (jsonDecode(consentJson) as List)
          .map((json) => ConsentRecord.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Failed to get all consent records: $e');
      return [];
    }
  }

  Future<List<ConsentRecord>> _getConsentRecords(String patientId, String hospitalId) async {
    final allConsents = await _getAllConsentRecords();
    return allConsents
        .where((consent) => 
            consent.patientId == patientId && 
            consent.hospitalId == hospitalId)
        .toList();
  }

  bool _isConsentValid(ConsentRecord record) {
    if (!record.consentGranted) return false;
    return DateTime.now().isBefore(record.expirationTime);
  }

  bool _coversRequestedData(List<String> consentScope, List<String> requestedData) {
    // Check if all requested data types are covered by consent scope
    return requestedData.every((dataType) => consentScope.contains(dataType));
  }
}

/// Represents a consent record
class ConsentRecord {
  final String id;
  final String patientId;
  final String hospitalId;
  final List<String> dataScope;
  final bool consentGranted;
  final DateTime timestamp;
  final DateTime expirationTime;
  final String? reason;

  ConsentRecord({
    required this.id,
    required this.patientId,
    required this.hospitalId,
    required this.dataScope,
    required this.consentGranted,
    required this.timestamp,
    required this.expirationTime,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'hospitalId': hospitalId,
    'dataScope': dataScope,
    'consentGranted': consentGranted,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'expirationTime': expirationTime.millisecondsSinceEpoch,
    'reason': reason,
  };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
    id: json['id'],
    patientId: json['patientId'],
    hospitalId: json['hospitalId'],
    dataScope: List<String>.from(json['dataScope']),
    consentGranted: json['consentGranted'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    expirationTime: DateTime.fromMillisecondsSinceEpoch(json['expirationTime']),
    reason: json['reason'],
  );
}

/// Represents consent verification result
class ConsentVerification {
  final bool isValid;
  final ConsentRecord? consentRecord;
  final List<String> requestedData;
  final DateTime verificationTime;

  ConsentVerification({
    required this.isValid,
    required this.consentRecord,
    required this.requestedData,
    required this.verificationTime,
  });
}

/// Represents an audit trail entry
class ConsentAuditEntry {
  final String consentId;
  final String patientId;
  final String hospitalId;
  final String action;
  final DateTime timestamp;
  final List<String> dataScope;
  final String? reason;

  ConsentAuditEntry({
    required this.consentId,
    required this.patientId,
    required this.hospitalId,
    required this.action,
    required this.timestamp,
    required this.dataScope,
    this.reason,
  });
}