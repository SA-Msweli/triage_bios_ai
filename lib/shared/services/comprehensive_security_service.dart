import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'audit_logging_service.dart';
import 'data_encryption_service.dart';
import 'hipaa_compliance_service.dart';
import 'auth_service.dart';

/// Comprehensive security service that integrates all security components
/// Provides a unified interface for security operations and compliance monitoring
class ComprehensiveSecurityService {
  static final ComprehensiveSecurityService _instance =
      ComprehensiveSecurityService._internal();
  factory ComprehensiveSecurityService() => _instance;
  ComprehensiveSecurityService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  // Security service dependencies
  final AuditLoggingService _auditService = AuditLoggingService();
  final DataEncryptionService _encryptionService = DataEncryptionService();
  final HipaaComplianceService _hipaaService = HipaaComplianceService();
  final AuthService _authService = AuthService();

  bool _isInitialized = false;

  /// Initialize the comprehensive security service
  Future<void> initialize() async {
    try {
      _logger.i('Initializing comprehensive security service...');

      // Initialize all security components
      await _encryptionService.initialize();
      await _hipaaService.initialize();

      _isInitialized = true;
      _logger.i('Comprehensive security service initialized successfully');

      // Log the initialization
      await _auditService.logSecurityEvent(
        eventType: SecurityEventType.systemIntrusion, // Using as system event
        ipAddress: '127.0.0.1',
        description: 'Security service initialized',
        severity: SecuritySeverity.low,
        additionalData: {
          'component': 'comprehensive_security_service',
          'initialization_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.e('Failed to initialize comprehensive security service: $e');
      rethrow;
    }
  }

  /// Secure data access with comprehensive validation and logging
  Future<SecureDataAccessResult> secureDataAccess({
    required String userId,
    required String patientId,
    required List<String> requestedDataTypes,
    required String purpose,
    required String ipAddress,
    String? deviceInfo,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      _ensureInitialized();

      final accessId = _uuid.v4();
      _logger.i('Processing secure data access request: $accessId');

      // Step 1: Validate HIPAA compliance
      final hipaaValidation = await _hipaaService.validateDataAccess(
        userId: userId,
        patientId: patientId,
        requestedDataTypes: requestedDataTypes,
        purpose: purpose,
        ipAddress: ipAddress,
        deviceInfo: deviceInfo,
      );

      // Step 2: Check user authentication and authorization
      final authValid =
          _authService.isAuthenticated &&
          _authService.canAccessPatientData(userId, patientId);

      // Step 3: Log the access attempt
      await _auditService.logDataAccess(
        userId: userId,
        resourceId: patientId,
        resourceType: 'patient_data',
        accessType: DataAccessType.read,
        ipAddress: ipAddress,
        patientId: patientId,
        dataScopes: requestedDataTypes,
        success: hipaaValidation.isCompliant && authValid,
        purpose: purpose,
        minimumNecessaryCompliant: hipaaValidation.minimumNecessaryCompliant,
        consentVerified: hipaaValidation.patientConsentValid,
        deviceFingerprint: _generateDeviceFingerprint(deviceInfo),
        additionalData: {
          'access_id': accessId,
          'validation_details': hipaaValidation.toJson(),
          'auth_valid': authValid,
          ...?additionalContext,
        },
      );

      // Step 4: Create access result
      final result = SecureDataAccessResult(
        accessId: accessId,
        userId: userId,
        patientId: patientId,
        requestedDataTypes: requestedDataTypes,
        purpose: purpose,
        timestamp: DateTime.now(),
        isAuthorized: hipaaValidation.isCompliant && authValid,
        hipaaValidation: hipaaValidation,
        authenticationValid: authValid,
        securityScore: _calculateSecurityScore(hipaaValidation, authValid),
        accessToken: hipaaValidation.isCompliant && authValid
            ? _generateSecureAccessToken(accessId, userId, patientId)
            : null,
      );

      _logger.i(
        'Secure data access processed: $accessId - '
        '${result.isAuthorized ? 'AUTHORIZED' : 'DENIED'}',
      );

      return result;
    } catch (e) {
      _logger.e('Failed to process secure data access: $e');

      // Log the error
      await _auditService.logSecurityEvent(
        eventType: SecurityEventType.systemIntrusion,
        ipAddress: ipAddress,
        userId: userId,
        description: 'Secure data access failed: $e',
        severity: SecuritySeverity.high,
      );

      rethrow;
    }
  }

  /// Encrypt sensitive patient data with audit logging
  Future<SecureEncryptionResult> encryptPatientData({
    required String userId,
    required Map<String, dynamic> patientData,
    required String patientId,
    required String ipAddress,
    String? purpose,
  }) async {
    try {
      _ensureInitialized();

      final encryptionId = _uuid.v4();
      _logger.d('Encrypting patient data: $encryptionId');

      // Encrypt the data
      final encryptedData = await _encryptionService.encryptPatientData(
        patientData,
      );

      // Log the encryption event
      await _auditService.logEncryptionEvent(
        userId: userId,
        operation: 'encrypt',
        dataType: 'patient_data',
        resourceId: patientId,
        ipAddress: ipAddress,
        success: true,
        additionalData: {
          'encryption_id': encryptionId,
          'data_size': jsonEncode(patientData).length,
          'algorithm': encryptedData.algorithm,
          'purpose': purpose,
        },
      );

      return SecureEncryptionResult(
        encryptionId: encryptionId,
        encryptedData: encryptedData,
        success: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Failed to encrypt patient data: $e');

      // Log the encryption failure
      await _auditService.logEncryptionEvent(
        userId: userId,
        operation: 'encrypt',
        dataType: 'patient_data',
        resourceId: patientId,
        ipAddress: ipAddress,
        success: false,
        errorMessage: e.toString(),
      );

      return SecureEncryptionResult(
        encryptionId: _uuid.v4(),
        encryptedData: null,
        success: false,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Decrypt sensitive patient data with audit logging
  Future<SecureDecryptionResult> decryptPatientData({
    required String userId,
    required EncryptedData encryptedData,
    required String patientId,
    required String ipAddress,
    String? purpose,
  }) async {
    try {
      _ensureInitialized();

      final decryptionId = _uuid.v4();
      _logger.d('Decrypting patient data: $decryptionId');

      // Decrypt the data
      final decryptedData = await _encryptionService.decryptPatientData(
        encryptedData,
      );

      // Log the decryption event
      await _auditService.logEncryptionEvent(
        userId: userId,
        operation: 'decrypt',
        dataType: 'patient_data',
        resourceId: patientId,
        ipAddress: ipAddress,
        success: true,
        additionalData: {
          'decryption_id': decryptionId,
          'algorithm': encryptedData.algorithm,
          'purpose': purpose,
        },
      );

      return SecureDecryptionResult(
        decryptionId: decryptionId,
        decryptedData: decryptedData,
        success: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Failed to decrypt patient data: $e');

      // Log the decryption failure
      await _auditService.logEncryptionEvent(
        userId: userId,
        operation: 'decrypt',
        dataType: 'patient_data',
        resourceId: patientId,
        ipAddress: ipAddress,
        success: false,
        errorMessage: e.toString(),
      );

      return SecureDecryptionResult(
        decryptionId: _uuid.v4(),
        decryptedData: null,
        success: false,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Generate comprehensive security report
  Future<ComprehensiveSecurityReport> generateSecurityReport({
    required DateTime startDate,
    required DateTime endDate,
    String? patientId,
    String? userId,
  }) async {
    try {
      _ensureInitialized();

      _logger.i('Generating comprehensive security report');

      // Generate HIPAA compliance report
      final hipaaReport = await _hipaaService.generateComplianceReport(
        startDate: startDate,
        endDate: endDate,
        patientId: patientId,
        userId: userId,
      );

      // Generate audit compliance report
      final auditReport = await _auditService.generateComplianceReport(
        startDate: startDate,
        endDate: endDate,
        patientId: patientId,
      );

      // Get encryption status
      final encryptionStatus = _encryptionService.getEncryptionStatus();

      // Conduct risk assessment
      final riskAssessment = await _hipaaService.conductRiskAssessment();

      // Monitor for violations
      final violations = await _hipaaService.monitorForViolations();

      return ComprehensiveSecurityReport(
        reportId: _uuid.v4(),
        generatedAt: DateTime.now(),
        reportPeriod: DateRange(startDate, endDate),
        hipaaComplianceReport: hipaaReport,
        auditComplianceReport: auditReport,
        encryptionStatus: encryptionStatus,
        riskAssessment: riskAssessment,
        recentViolations: violations,
        overallSecurityScore: _calculateOverallSecurityScore(
          hipaaReport,
          auditReport,
          encryptionStatus,
          riskAssessment,
        ),
        recommendations: _generateSecurityRecommendations(
          hipaaReport,
          auditReport,
          encryptionStatus,
          riskAssessment,
          violations,
        ),
      );
    } catch (e) {
      _logger.e('Failed to generate comprehensive security report: $e');
      rethrow;
    }
  }

  /// Monitor security in real-time
  Future<SecurityMonitoringResult> monitorSecurity() async {
    try {
      _ensureInitialized();

      // Monitor for HIPAA violations
      final hipaaViolations = await _hipaaService.monitorForViolations();

      // Detect suspicious activity
      final suspiciousActivity = await _auditService.detectSuspiciousActivity();

      // Check encryption status
      final encryptionStatus = _encryptionService.getEncryptionStatus();

      // Get compliance dashboard
      final complianceDashboard = await _hipaaService.getComplianceDashboard();

      return SecurityMonitoringResult(
        timestamp: DateTime.now(),
        hipaaViolations: hipaaViolations,
        suspiciousActivity: suspiciousActivity,
        encryptionStatus: encryptionStatus,
        complianceDashboard: complianceDashboard,
        overallThreatLevel: _calculateThreatLevel(
          hipaaViolations,
          suspiciousActivity,
          encryptionStatus,
        ),
        actionRequired:
            hipaaViolations.isNotEmpty || suspiciousActivity.isNotEmpty,
      );
    } catch (e) {
      _logger.e('Failed to monitor security: $e');
      rethrow;
    }
  }

  /// Validate field-level access with encryption
  Future<SecureFieldAccessResult> secureFieldAccess({
    required String userId,
    required String fieldName,
    required String encryptedValue,
    required String patientId,
    required String ipAddress,
    String? purpose,
  }) async {
    try {
      _ensureInitialized();

      // Validate access to specific field
      final accessValidation = await _hipaaService.validateDataAccess(
        userId: userId,
        patientId: patientId,
        requestedDataTypes: [fieldName],
        purpose: purpose ?? 'treatment',
        ipAddress: ipAddress,
      );

      if (!accessValidation.isCompliant) {
        return SecureFieldAccessResult(
          fieldName: fieldName,
          success: false,
          decryptedValue: null,
          error: 'Access denied: ${accessValidation.getViolationSummary()}',
        );
      }

      // Decrypt the field value
      final decryptedValue = await _encryptionService.decryptField(
        encryptedValue,
      );

      // Log the field access
      await _auditService.logDataAccess(
        userId: userId,
        resourceId: patientId,
        resourceType: 'patient_field',
        accessType: DataAccessType.read,
        ipAddress: ipAddress,
        patientId: patientId,
        dataScopes: [fieldName],
        success: true,
        purpose: purpose,
        additionalData: {'field_name': fieldName, 'field_access': true},
      );

      return SecureFieldAccessResult(
        fieldName: fieldName,
        success: true,
        decryptedValue: decryptedValue,
      );
    } catch (e) {
      _logger.e('Failed to access secure field: $e');
      return SecureFieldAccessResult(
        fieldName: fieldName,
        success: false,
        decryptedValue: null,
        error: e.toString(),
      );
    }
  }

  // Private helper methods

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('Comprehensive security service not initialized');
    }
  }

  String _generateDeviceFingerprint(String? deviceInfo) {
    if (deviceInfo == null) return 'unknown';

    // Generate a simple fingerprint based on device info
    final bytes = utf8.encode(deviceInfo);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  double _calculateSecurityScore(
    HipaaAccessValidation validation,
    bool authValid,
  ) {
    double score = 0.0;

    if (validation.minimumNecessaryCompliant) score += 25.0;
    if (validation.userAuthorized) score += 25.0;
    if (validation.patientConsentValid) score += 25.0;
    if (validation.accessControlsValid) score += 15.0;
    if (authValid) score += 10.0;

    return score;
  }

  String _generateSecureAccessToken(
    String accessId,
    String userId,
    String patientId,
  ) {
    final tokenData = {
      'access_id': accessId,
      'user_id': userId,
      'patient_id': patientId,
      'issued_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    };

    return base64.encode(utf8.encode(jsonEncode(tokenData)));
  }

  double _calculateOverallSecurityScore(
    HipaaComplianceReport hipaaReport,
    ComplianceReport auditReport,
    EncryptionStatus encryptionStatus,
    HipaaRiskAssessment riskAssessment,
  ) {
    final hipaaScore = hipaaReport.complianceScore;
    final auditScore = auditReport.complianceScore;
    final encryptionScore = encryptionStatus.isInitialized ? 90.0 : 50.0;
    final riskScore = _riskLevelToScore(riskAssessment.overallRiskLevel);

    return (hipaaScore * 0.4) +
        (auditScore * 0.3) +
        (encryptionScore * 0.2) +
        (riskScore * 0.1);
  }

  double _riskLevelToScore(HipaaRiskLevel riskLevel) {
    switch (riskLevel) {
      case HipaaRiskLevel.low:
        return 95.0;
      case HipaaRiskLevel.medium:
        return 75.0;
      case HipaaRiskLevel.high:
        return 50.0;
      case HipaaRiskLevel.critical:
        return 25.0;
    }
  }

  List<String> _generateSecurityRecommendations(
    HipaaComplianceReport hipaaReport,
    ComplianceReport auditReport,
    EncryptionStatus encryptionStatus,
    HipaaRiskAssessment riskAssessment,
    List<HipaaViolationAlert> violations,
  ) {
    final recommendations = <String>[];

    if (hipaaReport.complianceScore < 90) {
      recommendations.add(
        'Improve HIPAA compliance score (currently ${hipaaReport.complianceScore.toStringAsFixed(1)}%)',
      );
    }

    if (auditReport.complianceScore < 90) {
      recommendations.add('Enhance audit trail completeness');
    }

    if (encryptionStatus.keyRotationRecommended) {
      recommendations.add('Rotate encryption keys');
    }

    if (riskAssessment.overallRiskLevel == HipaaRiskLevel.high ||
        riskAssessment.overallRiskLevel == HipaaRiskLevel.critical) {
      recommendations.add(
        'Address high-risk security vulnerabilities immediately',
      );
    }

    if (violations.isNotEmpty) {
      recommendations.add(
        'Investigate and remediate ${violations.length} security violations',
      );
    }

    return recommendations;
  }

  SecurityThreatLevel _calculateThreatLevel(
    List<HipaaViolationAlert> violations,
    List<SecurityAlert> suspiciousActivity,
    EncryptionStatus encryptionStatus,
  ) {
    final criticalViolations = violations
        .where((v) => v.severity == HipaaViolationSeverity.critical)
        .length;
    final highSeverityAlerts = suspiciousActivity
        .where(
          (a) =>
              a.severity == SecuritySeverity.high ||
              a.severity == SecuritySeverity.critical,
        )
        .length;

    if (criticalViolations > 0 || highSeverityAlerts > 0) {
      return SecurityThreatLevel.critical;
    } else if (violations.length > 5 || suspiciousActivity.length > 10) {
      return SecurityThreatLevel.high;
    } else if (violations.isNotEmpty || suspiciousActivity.isNotEmpty) {
      return SecurityThreatLevel.medium;
    } else {
      return SecurityThreatLevel.low;
    }
  }
}

// Data models for comprehensive security service

class SecureDataAccessResult {
  final String accessId;
  final String userId;
  final String patientId;
  final List<String> requestedDataTypes;
  final String purpose;
  final DateTime timestamp;
  final bool isAuthorized;
  final HipaaAccessValidation hipaaValidation;
  final bool authenticationValid;
  final double securityScore;
  final String? accessToken;

  const SecureDataAccessResult({
    required this.accessId,
    required this.userId,
    required this.patientId,
    required this.requestedDataTypes,
    required this.purpose,
    required this.timestamp,
    required this.isAuthorized,
    required this.hipaaValidation,
    required this.authenticationValid,
    required this.securityScore,
    this.accessToken,
  });
}

class SecureEncryptionResult {
  final String encryptionId;
  final EncryptedData? encryptedData;
  final bool success;
  final DateTime timestamp;
  final String? error;

  const SecureEncryptionResult({
    required this.encryptionId,
    this.encryptedData,
    required this.success,
    required this.timestamp,
    this.error,
  });
}

class SecureDecryptionResult {
  final String decryptionId;
  final Map<String, dynamic>? decryptedData;
  final bool success;
  final DateTime timestamp;
  final String? error;

  const SecureDecryptionResult({
    required this.decryptionId,
    this.decryptedData,
    required this.success,
    required this.timestamp,
    this.error,
  });
}

class SecureFieldAccessResult {
  final String fieldName;
  final bool success;
  final String? decryptedValue;
  final String? error;

  const SecureFieldAccessResult({
    required this.fieldName,
    required this.success,
    this.decryptedValue,
    this.error,
  });
}

class ComprehensiveSecurityReport {
  final String reportId;
  final DateTime generatedAt;
  final DateRange reportPeriod;
  final HipaaComplianceReport hipaaComplianceReport;
  final ComplianceReport auditComplianceReport;
  final EncryptionStatus encryptionStatus;
  final HipaaRiskAssessment riskAssessment;
  final List<HipaaViolationAlert> recentViolations;
  final double overallSecurityScore;
  final List<String> recommendations;

  const ComprehensiveSecurityReport({
    required this.reportId,
    required this.generatedAt,
    required this.reportPeriod,
    required this.hipaaComplianceReport,
    required this.auditComplianceReport,
    required this.encryptionStatus,
    required this.riskAssessment,
    required this.recentViolations,
    required this.overallSecurityScore,
    required this.recommendations,
  });
}

class SecurityMonitoringResult {
  final DateTime timestamp;
  final List<HipaaViolationAlert> hipaaViolations;
  final List<SecurityAlert> suspiciousActivity;
  final EncryptionStatus encryptionStatus;
  final HipaaComplianceDashboard complianceDashboard;
  final SecurityThreatLevel overallThreatLevel;
  final bool actionRequired;

  const SecurityMonitoringResult({
    required this.timestamp,
    required this.hipaaViolations,
    required this.suspiciousActivity,
    required this.encryptionStatus,
    required this.complianceDashboard,
    required this.overallThreatLevel,
    required this.actionRequired,
  });
}

enum SecurityThreatLevel { low, medium, high, critical }
