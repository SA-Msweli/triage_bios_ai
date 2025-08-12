import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';

class EmergencyAccessService {
  static final EmergencyAccessService _instance =
      EmergencyAccessService._internal();
  factory EmergencyAccessService() => _instance;
  EmergencyAccessService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  static const String _emergencyAccessKey = 'emergency_access_logs';

  /// Request emergency access to patient data
  Future<EmergencyAccessResult> requestEmergencyAccess({
    required String providerId,
    required String patientId,
    required String justification,
    required EmergencyType emergencyType,
    List<String>? requiredDataScopes,
  }) async {
    try {
      _logger.w('Emergency access requested: $providerId -> $patientId');

      // Validate emergency justification
      if (justification.length < 20) {
        return EmergencyAccessResult.failure(
          'Emergency justification must be at least 20 characters',
        );
      }

      // Create emergency access record
      final emergencyAccess = EmergencyAccess(
        accessId: _uuid.v4(),
        providerId: providerId,
        patientId: patientId,
        emergencyType: emergencyType,
        justification: justification,
        requestedAt: DateTime.now(),
        expiresAt: DateTime.now().add(
          const Duration(hours: 24),
        ), // 24-hour emergency access
        dataScopes: requiredDataScopes ?? ['vitals', 'assessments', 'history'],
        isActive: true,
        reviewRequired: true,
        approvedBy: null, // Auto-approved for emergencies
      );

      // Log emergency access
      await _logEmergencyAccess(emergencyAccess);

      // Notify patient (when possible)
      await _notifyPatientOfEmergencyAccess(patientId, emergencyAccess);

      // Notify administrators
      await _notifyAdministrators(emergencyAccess);

      _logger.w('Emergency access granted: ${emergencyAccess.accessId}');
      return EmergencyAccessResult.success(emergencyAccess);
    } catch (e) {
      _logger.e('Emergency access request failed: $e');
      return EmergencyAccessResult.failure('Emergency access failed: $e');
    }
  }

  /// Check if provider has active emergency access to patient
  Future<bool> hasEmergencyAccess(String providerId, String patientId) async {
    try {
      final accessRecords = await _getEmergencyAccessRecords(patientId);
      return accessRecords.any(
        (access) =>
            access.providerId == providerId &&
            access.isActive &&
            !access.isExpired,
      );
    } catch (e) {
      _logger.e('Error checking emergency access: $e');
      return false;
    }
  }

  /// Revoke emergency access
  Future<void> revokeEmergencyAccess(String accessId) async {
    try {
      final allRecords = await _getAllEmergencyAccessRecords();
      final recordIndex = allRecords.indexWhere(
        (record) => record.accessId == accessId,
      );

      if (recordIndex != -1) {
        allRecords[recordIndex] = allRecords[recordIndex].copyWith(
          isActive: false,
          revokedAt: DateTime.now(),
        );
        await _storeAllEmergencyAccessRecords(allRecords);
        _logger.i('Emergency access revoked: $accessId');
      }
    } catch (e) {
      _logger.e('Failed to revoke emergency access: $e');
    }
  }

  /// Get emergency access records for patient
  Future<List<EmergencyAccess>> getPatientEmergencyAccessRecords(
    String patientId,
  ) async {
    return await _getEmergencyAccessRecords(patientId);
  }

  /// Get all emergency access records requiring review
  Future<List<EmergencyAccess>> getRecordsRequiringReview() async {
    try {
      final allRecords = await _getAllEmergencyAccessRecords();
      return allRecords.where((record) => record.reviewRequired).toList();
    } catch (e) {
      _logger.e('Error getting records requiring review: $e');
      return [];
    }
  }

  /// Complete post-incident review
  Future<void> completeReview({
    required String accessId,
    required String reviewerId,
    required String reviewNotes,
    required bool approved,
  }) async {
    try {
      final allRecords = await _getAllEmergencyAccessRecords();
      final recordIndex = allRecords.indexWhere(
        (record) => record.accessId == accessId,
      );

      if (recordIndex != -1) {
        allRecords[recordIndex] = allRecords[recordIndex].copyWith(
          reviewRequired: false,
          reviewedAt: DateTime.now(),
          reviewedBy: reviewerId,
          reviewNotes: reviewNotes,
          reviewApproved: approved,
        );
        await _storeAllEmergencyAccessRecords(allRecords);
        _logger.i('Emergency access review completed: $accessId');
      }
    } catch (e) {
      _logger.e('Failed to complete review: $e');
    }
  }

  // Private helper methods

  Future<void> _logEmergencyAccess(EmergencyAccess access) async {
    try {
      final allRecords = await _getAllEmergencyAccessRecords();
      allRecords.add(access);
      await _storeAllEmergencyAccessRecords(allRecords);
    } catch (e) {
      _logger.e('Failed to log emergency access: $e');
    }
  }

  Future<void> _notifyPatientOfEmergencyAccess(
    String patientId,
    EmergencyAccess access,
  ) async {
    // In a real implementation, this would send notifications via email, SMS, or app notification
    _logger.i('Patient notification sent for emergency access: $patientId');

    // Mock notification delay
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _notifyAdministrators(EmergencyAccess access) async {
    // In a real implementation, this would notify hospital administrators
    _logger.i(
      'Administrator notification sent for emergency access: ${access.accessId}',
    );

    // Mock notification delay
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<List<EmergencyAccess>> _getEmergencyAccessRecords(
    String patientId,
  ) async {
    try {
      final allRecords = await _getAllEmergencyAccessRecords();
      return allRecords
          .where((record) => record.patientId == patientId)
          .toList();
    } catch (e) {
      _logger.e('Failed to get emergency access records: $e');
      return [];
    }
  }

  Future<List<EmergencyAccess>> _getAllEmergencyAccessRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getString(_emergencyAccessKey) ?? '[]';
      final recordsList = jsonDecode(recordsJson) as List;

      return recordsList
          .map((data) => EmergencyAccess.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Failed to get all emergency access records: $e');
      return [];
    }
  }

  Future<void> _storeAllEmergencyAccessRecords(
    List<EmergencyAccess> records,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = jsonEncode(records.map((r) => r.toJson()).toList());
      await prefs.setString(_emergencyAccessKey, recordsJson);
    } catch (e) {
      _logger.e('Failed to store emergency access records: $e');
    }
  }
}

class EmergencyAccess {
  final String accessId;
  final String providerId;
  final String patientId;
  final EmergencyType emergencyType;
  final String justification;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final List<String> dataScopes;
  final bool isActive;
  final bool reviewRequired;
  final String? approvedBy;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final bool? reviewApproved;
  final DateTime? revokedAt;

  const EmergencyAccess({
    required this.accessId,
    required this.providerId,
    required this.patientId,
    required this.emergencyType,
    required this.justification,
    required this.requestedAt,
    required this.expiresAt,
    required this.dataScopes,
    required this.isActive,
    required this.reviewRequired,
    this.approvedBy,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.reviewApproved,
    this.revokedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  EmergencyAccess copyWith({
    String? accessId,
    String? providerId,
    String? patientId,
    EmergencyType? emergencyType,
    String? justification,
    DateTime? requestedAt,
    DateTime? expiresAt,
    List<String>? dataScopes,
    bool? isActive,
    bool? reviewRequired,
    String? approvedBy,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewNotes,
    bool? reviewApproved,
    DateTime? revokedAt,
  }) {
    return EmergencyAccess(
      accessId: accessId ?? this.accessId,
      providerId: providerId ?? this.providerId,
      patientId: patientId ?? this.patientId,
      emergencyType: emergencyType ?? this.emergencyType,
      justification: justification ?? this.justification,
      requestedAt: requestedAt ?? this.requestedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      dataScopes: dataScopes ?? this.dataScopes,
      isActive: isActive ?? this.isActive,
      reviewRequired: reviewRequired ?? this.reviewRequired,
      approvedBy: approvedBy ?? this.approvedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewApproved: reviewApproved ?? this.reviewApproved,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessId': accessId,
      'providerId': providerId,
      'patientId': patientId,
      'emergencyType': emergencyType.name,
      'justification': justification,
      'requestedAt': requestedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'dataScopes': dataScopes,
      'isActive': isActive,
      'reviewRequired': reviewRequired,
      'approvedBy': approvedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'reviewApproved': reviewApproved,
      'revokedAt': revokedAt?.toIso8601String(),
    };
  }

  factory EmergencyAccess.fromJson(Map<String, dynamic> json) {
    return EmergencyAccess(
      accessId: json['accessId'],
      providerId: json['providerId'],
      patientId: json['patientId'],
      emergencyType: EmergencyType.values.firstWhere(
        (e) => e.name == json['emergencyType'],
      ),
      justification: json['justification'],
      requestedAt: DateTime.parse(json['requestedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      dataScopes: List<String>.from(json['dataScopes']),
      isActive: json['isActive'],
      reviewRequired: json['reviewRequired'],
      approvedBy: json['approvedBy'],
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'])
          : null,
      reviewedBy: json['reviewedBy'],
      reviewNotes: json['reviewNotes'],
      reviewApproved: json['reviewApproved'],
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'])
          : null,
    );
  }
}

enum EmergencyType {
  cardiac,
  trauma,
  respiratory,
  neurological,
  pediatric,
  psychiatric,
  overdose,
  other,
}

class EmergencyAccessResult {
  final bool success;
  final EmergencyAccess? access;
  final String? error;

  const EmergencyAccessResult._({
    required this.success,
    this.access,
    this.error,
  });

  factory EmergencyAccessResult.success(EmergencyAccess access) {
    return EmergencyAccessResult._(success: true, access: access);
  }

  factory EmergencyAccessResult.failure(String error) {
    return EmergencyAccessResult._(success: false, error: error);
  }
}
