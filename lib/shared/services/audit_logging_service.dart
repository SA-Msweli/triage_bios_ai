import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuditLoggingService {
  static final AuditLoggingService _instance = AuditLoggingService._internal();
  factory AuditLoggingService() => _instance;
  AuditLoggingService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  static const String _auditLogsKey = 'audit_logs';
  static const int _maxLogsInMemory = 1000;

  /// Log authentication event
  Future<void> logAuthEvent({
    required String userId,
    required AuthEventType eventType,
    required String ipAddress,
    required String deviceInfo,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.authentication,
      eventType: eventType.name,
      userId: userId,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      success: success,
      errorMessage: errorMessage,
      additionalData: additionalData ?? {},
    );

    await _storeAuditLog(auditLog);
    _logger.i('Auth event logged: ${eventType.name} for user $userId');
  }

  /// Log data access event with enhanced HIPAA compliance tracking
  Future<void> logDataAccess({
    required String userId,
    required String resourceId,
    required String resourceType,
    required DataAccessType accessType,
    required String ipAddress,
    String? patientId,
    List<String>? dataScopes,
    bool success = true,
    String? errorMessage,
    String? purpose,
    bool minimumNecessaryCompliant = true,
    bool consentVerified = true,
    String? deviceFingerprint,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.dataAccess,
      eventType: accessType.name,
      userId: userId,
      resourceId: resourceId,
      resourceType: resourceType,
      ipAddress: ipAddress,
      patientId: patientId,
      dataScopes: dataScopes,
      success: success,
      errorMessage: errorMessage,
      additionalData: {
        'purpose': purpose,
        'minimum_necessary_compliant': minimumNecessaryCompliant,
        'consent_verified': consentVerified,
        'device_fingerprint': deviceFingerprint,
        'hipaa_compliant':
            success && minimumNecessaryCompliant && consentVerified,
        'access_timestamp_utc': DateTime.now().toUtc().toIso8601String(),
        ...?additionalData,
      },
    );

    await _storeAuditLog(auditLog);

    // Also store in Firestore for real-time compliance monitoring
    await _storeAuditLogInFirestore(auditLog);

    _logger.i(
      'Data access logged: ${accessType.name} on $resourceType by user $userId '
      '(HIPAA Compliant: ${auditLog.additionalData['hipaa_compliant']})',
    );
  }

  /// Log authorization decision
  Future<void> logAuthorizationDecision({
    required String userId,
    required String resource,
    required String action,
    required String permission,
    required bool granted,
    required String ipAddress,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.authorization,
      eventType: granted ? 'permission_granted' : 'permission_denied',
      userId: userId,
      resourceId: resource,
      ipAddress: ipAddress,
      success: granted,
      errorMessage: granted ? null : reason,
      additionalData: {
        'action': action,
        'permission': permission,
        ...?additionalData,
      },
    );

    await _storeAuditLog(auditLog);
    _logger.i(
      'Authorization logged: $permission ${granted ? 'granted' : 'denied'} for user $userId',
    );
  }

  /// Log security event
  Future<void> logSecurityEvent({
    required SecurityEventType eventType,
    required String ipAddress,
    String? userId,
    String? description,
    SecuritySeverity severity = SecuritySeverity.medium,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.security,
      eventType: eventType.name,
      userId: userId,
      ipAddress: ipAddress,
      success: false, // Security events are typically failures or alerts
      errorMessage: description,
      additionalData: {'severity': severity.name, ...?additionalData},
    );

    await _storeAuditLog(auditLog);
    _logger.w('Security event logged: ${eventType.name} - $description');
  }

  /// Log consent management event
  Future<void> logConsentEvent({
    required String patientId,
    required String providerId,
    required ConsentEventType eventType,
    required String ipAddress,
    List<String>? dataScopes,
    DateTime? expirationDate,
    String? blockchainTxId,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.consent,
      eventType: eventType.name,
      userId: patientId,
      patientId: patientId,
      ipAddress: ipAddress,
      dataScopes: dataScopes,
      success: true,
      additionalData: {
        'providerId': providerId,
        'expirationDate': expirationDate?.toIso8601String(),
        'blockchainTxId': blockchainTxId,
        ...?additionalData,
      },
    );

    await _storeAuditLog(auditLog);
    _logger.i('Consent event logged: ${eventType.name} for patient $patientId');
  }

  /// Get audit logs with filtering
  Future<List<AuditLog>> getAuditLogs({
    String? userId,
    String? patientId,
    AuditCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final allLogs = await _getAllAuditLogs();

      var filteredLogs = allLogs.where((log) {
        if (userId != null && log.userId != userId) return false;
        if (patientId != null && log.patientId != patientId) return false;
        if (category != null && log.category != category) return false;
        if (startDate != null && log.timestamp.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && log.timestamp.isAfter(endDate)) return false;
        return true;
      }).toList();

      // Sort by timestamp (newest first)
      filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply pagination
      final startIndex = offset;
      final endIndex = (startIndex + limit).clamp(0, filteredLogs.length);

      return filteredLogs.sublist(startIndex, endIndex);
    } catch (e) {
      _logger.e('Error getting audit logs: $e');
      return [];
    }
  }

  /// Generate compliance report
  Future<ComplianceReport> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
    String? patientId,
  }) async {
    try {
      final logs = await getAuditLogs(
        startDate: startDate,
        endDate: endDate,
        patientId: patientId,
        limit: 10000, // Get all logs for the period
      );

      final authEvents = logs
          .where((log) => log.category == AuditCategory.authentication)
          .length;
      final dataAccessEvents = logs
          .where((log) => log.category == AuditCategory.dataAccess)
          .length;
      final consentEvents = logs
          .where((log) => log.category == AuditCategory.consent)
          .length;
      final securityEvents = logs
          .where((log) => log.category == AuditCategory.security)
          .length;
      final failedEvents = logs.where((log) => !log.success).length;

      final uniqueUsers = logs
          .map((log) => log.userId)
          .where((id) => id != null)
          .toSet()
          .length;
      final uniquePatients = logs
          .map((log) => log.patientId)
          .where((id) => id != null)
          .toSet()
          .length;

      return ComplianceReport(
        reportId: _uuid.v4(),
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalEvents: logs.length,
        authenticationEvents: authEvents,
        dataAccessEvents: dataAccessEvents,
        consentEvents: consentEvents,
        securityEvents: securityEvents,
        failedEvents: failedEvents,
        uniqueUsers: uniqueUsers,
        uniquePatients: uniquePatients,
        complianceScore: _calculateComplianceScore(logs),
      );
    } catch (e) {
      _logger.e('Error generating compliance report: $e');
      rethrow;
    }
  }

  /// Detect suspicious activity patterns
  Future<List<SecurityAlert>> detectSuspiciousActivity() async {
    try {
      final recentLogs = await getAuditLogs(
        startDate: DateTime.now().subtract(const Duration(hours: 24)),
        limit: 1000,
      );

      final alerts = <SecurityAlert>[];

      // Detect multiple failed login attempts
      final failedLogins = recentLogs
          .where(
            (log) =>
                log.category == AuditCategory.authentication &&
                log.eventType == 'login_failed',
          )
          .toList();

      final failedLoginsByUser = <String, int>{};
      for (final log in failedLogins) {
        if (log.userId != null) {
          failedLoginsByUser[log.userId!] =
              (failedLoginsByUser[log.userId!] ?? 0) + 1;
        }
      }

      for (final entry in failedLoginsByUser.entries) {
        if (entry.value >= 5) {
          alerts.add(
            SecurityAlert(
              id: _uuid.v4(),
              type: SecurityAlertType.multipleFailedLogins,
              severity: SecuritySeverity.high,
              userId: entry.key,
              description:
                  'Multiple failed login attempts detected: ${entry.value} attempts',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }

      // Detect unusual data access patterns
      final dataAccessLogs = recentLogs
          .where((log) => log.category == AuditCategory.dataAccess)
          .toList();

      final accessByUser = <String, int>{};
      for (final log in dataAccessLogs) {
        if (log.userId != null) {
          accessByUser[log.userId!] = (accessByUser[log.userId!] ?? 0) + 1;
        }
      }

      for (final entry in accessByUser.entries) {
        if (entry.value >= 100) {
          // More than 100 data access events in 24 hours
          alerts.add(
            SecurityAlert(
              id: _uuid.v4(),
              type: SecurityAlertType.unusualDataAccess,
              severity: SecuritySeverity.medium,
              userId: entry.key,
              description:
                  'Unusual data access pattern detected: ${entry.value} access events',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }

      return alerts;
    } catch (e) {
      _logger.e('Error detecting suspicious activity: $e');
      return [];
    }
  }

  // Private helper methods

  Future<void> _storeAuditLog(AuditLog log) async {
    try {
      final allLogs = await _getAllAuditLogs();
      allLogs.add(log);

      // Keep only the most recent logs to prevent storage overflow
      if (allLogs.length > _maxLogsInMemory) {
        allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        allLogs.removeRange(_maxLogsInMemory, allLogs.length);
      }

      await _storeAllAuditLogs(allLogs);
    } catch (e) {
      _logger.e('Failed to store audit log: $e');
    }
  }

  Future<List<AuditLog>> _getAllAuditLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_auditLogsKey) ?? '[]';
      final logsList = jsonDecode(logsJson) as List;

      return logsList
          .map((data) => AuditLog.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Failed to get audit logs: $e');
      return [];
    }
  }

  Future<void> _storeAllAuditLogs(List<AuditLog> logs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = jsonEncode(logs.map((log) => log.toJson()).toList());
      await prefs.setString(_auditLogsKey, logsJson);
    } catch (e) {
      _logger.e('Failed to store audit logs: $e');
    }
  }

  double _calculateComplianceScore(List<AuditLog> logs) {
    if (logs.isEmpty) return 100.0;

    final totalEvents = logs.length;
    final successfulEvents = logs.where((log) => log.success).length;
    final consentEvents = logs
        .where((log) => log.category == AuditCategory.consent)
        .length;
    final hipaaCompliantEvents = logs
        .where((log) => log.additionalData['hipaa_compliant'] == true)
        .length;

    // Enhanced compliance score calculation with HIPAA factors
    final successRate = successfulEvents / totalEvents;
    final consentRate = consentEvents / totalEvents;
    final hipaaComplianceRate = hipaaCompliantEvents / totalEvents;

    return ((successRate * 0.4) +
            (consentRate * 0.3) +
            (hipaaComplianceRate * 0.3)) *
        100;
  }

  /// Store audit log in Firestore for real-time monitoring
  Future<void> _storeAuditLogInFirestore(AuditLog auditLog) async {
    try {
      // This would integrate with FirestoreDataService to store audit logs
      // For now, we'll just log that it would be stored
      _logger.d('Audit log would be stored in Firestore: ${auditLog.id}');
    } catch (e) {
      _logger.e('Failed to store audit log in Firestore: $e');
    }
  }

  /// Log encryption/decryption events for compliance
  Future<void> logEncryptionEvent({
    required String userId,
    required String operation, // 'encrypt' or 'decrypt'
    required String dataType,
    required String resourceId,
    required String ipAddress,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.security,
      eventType: 'data_$operation',
      userId: userId,
      resourceId: resourceId,
      resourceType: dataType,
      ipAddress: ipAddress,
      success: success,
      errorMessage: errorMessage,
      additionalData: {
        'encryption_operation': operation,
        'data_type': dataType,
        'compliance_requirement': 'HIPAA_164.312(a)(2)(iv)',
        ...?additionalData,
      },
    );

    await _storeAuditLog(auditLog);
    _logger.i(
      'Encryption event logged: $operation on $dataType by user $userId',
    );
  }

  /// Log HIPAA compliance check events
  Future<void> logComplianceCheck({
    required String userId,
    required String checkType,
    required bool compliant,
    required String ipAddress,
    String? patientId,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    final auditLog = AuditLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: AuditCategory.security,
      eventType: 'compliance_check',
      userId: userId,
      ipAddress: ipAddress,
      patientId: patientId,
      success: compliant,
      errorMessage: compliant ? null : reason,
      additionalData: {
        'check_type': checkType,
        'compliance_result': compliant,
        'hipaa_regulation': 'Various',
        ...?additionalData,
      },
    );

    await _storeAuditLog(auditLog);
    _logger.i(
      'Compliance check logged: $checkType - ${compliant ? 'COMPLIANT' : 'VIOLATION'}',
    );
  }
}

// Data models and enums

class AuditLog {
  final String id;
  final DateTime timestamp;
  final AuditCategory category;
  final String eventType;
  final String? userId;
  final String? resourceId;
  final String? resourceType;
  final String ipAddress;
  final String? deviceInfo;
  final String? patientId;
  final List<String>? dataScopes;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> additionalData;

  const AuditLog({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.eventType,
    this.userId,
    this.resourceId,
    this.resourceType,
    required this.ipAddress,
    this.deviceInfo,
    this.patientId,
    this.dataScopes,
    required this.success,
    this.errorMessage,
    required this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'category': category.name,
      'eventType': eventType,
      'userId': userId,
      'resourceId': resourceId,
      'resourceType': resourceType,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
      'patientId': patientId,
      'dataScopes': dataScopes,
      'success': success,
      'errorMessage': errorMessage,
      'additionalData': additionalData,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      category: AuditCategory.values.firstWhere(
        (c) => c.name == json['category'],
      ),
      eventType: json['eventType'],
      userId: json['userId'],
      resourceId: json['resourceId'],
      resourceType: json['resourceType'],
      ipAddress: json['ipAddress'],
      deviceInfo: json['deviceInfo'],
      patientId: json['patientId'],
      dataScopes: json['dataScopes'] != null
          ? List<String>.from(json['dataScopes'])
          : null,
      success: json['success'],
      errorMessage: json['errorMessage'],
      additionalData: Map<String, dynamic>.from(json['additionalData']),
    );
  }
}

class ComplianceReport {
  final String reportId;
  final DateTime generatedAt;
  final DateTime startDate;
  final DateTime endDate;
  final int totalEvents;
  final int authenticationEvents;
  final int dataAccessEvents;
  final int consentEvents;
  final int securityEvents;
  final int failedEvents;
  final int uniqueUsers;
  final int uniquePatients;
  final double complianceScore;

  const ComplianceReport({
    required this.reportId,
    required this.generatedAt,
    required this.startDate,
    required this.endDate,
    required this.totalEvents,
    required this.authenticationEvents,
    required this.dataAccessEvents,
    required this.consentEvents,
    required this.securityEvents,
    required this.failedEvents,
    required this.uniqueUsers,
    required this.uniquePatients,
    required this.complianceScore,
  });
}

class SecurityAlert {
  final String id;
  final SecurityAlertType type;
  final SecuritySeverity severity;
  final String? userId;
  final String description;
  final DateTime detectedAt;

  const SecurityAlert({
    required this.id,
    required this.type,
    required this.severity,
    this.userId,
    required this.description,
    required this.detectedAt,
  });
}

enum AuditCategory {
  authentication,
  authorization,
  dataAccess,
  consent,
  security,
  system,
}

enum AuthEventType {
  login,
  logout,
  loginFailed,
  mfaChallenge,
  mfaSuccess,
  mfaFailed,
  passwordReset,
  accountLocked,
}

enum DataAccessType { read, write, delete, export, print }

enum SecurityEventType {
  suspiciousLogin,
  multipleFailedAttempts,
  unusualDataAccess,
  unauthorizedAccess,
  dataExfiltration,
  systemIntrusion,
}

enum ConsentEventType { granted, revoked, expired, modified }

enum SecuritySeverity { low, medium, high, critical }

enum SecurityAlertType {
  multipleFailedLogins,
  unusualDataAccess,
  suspiciousActivity,
  dataExfiltration,
}
