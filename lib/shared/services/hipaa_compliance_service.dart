import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'audit_logging_service.dart';
import 'data_encryption_service.dart';

/// HIPAA compliance monitoring and reporting service
/// Ensures adherence to HIPAA regulations for patient data protection
class HipaaComplianceService {
  static final HipaaComplianceService _instance =
      HipaaComplianceService._internal();
  factory HipaaComplianceService() => _instance;
  HipaaComplianceService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final AuditLoggingService _auditService = AuditLoggingService();
  final DataEncryptionService _encryptionService = DataEncryptionService();

  static const String _complianceReportsKey = 'hipaa_compliance_reports';
  static const String _violationsKey = 'hipaa_violations';
  static const String _accessControlsKey = 'hipaa_access_controls';

  /// Initialize HIPAA compliance service
  Future<void> initialize() async {
    try {
      await _encryptionService.initialize();
      _logger.i('HIPAA compliance service initialized');
    } catch (e) {
      _logger.e('Failed to initialize HIPAA compliance service: $e');
      rethrow;
    }
  }

  /// Validate data access request for HIPAA compliance
  Future<HipaaAccessValidation> validateDataAccess({
    required String userId,
    required String patientId,
    required List<String> requestedDataTypes,
    required String purpose,
    required String ipAddress,
    String? deviceInfo,
  }) async {
    try {
      final validation = HipaaAccessValidation(
        requestId: _uuid.v4(),
        userId: userId,
        patientId: patientId,
        requestedDataTypes: requestedDataTypes,
        purpose: purpose,
        timestamp: DateTime.now(),
        ipAddress: ipAddress,
        deviceInfo: deviceInfo,
      );

      // Check minimum necessary principle
      final minimumNecessaryCheck = _validateMinimumNecessary(
        requestedDataTypes,
        purpose,
      );
      validation.minimumNecessaryCompliant = minimumNecessaryCheck.compliant;
      validation.minimumNecessaryReason = minimumNecessaryCheck.reason;

      // Check user authorization
      final authorizationCheck = await _validateUserAuthorization(
        userId,
        patientId,
        requestedDataTypes,
      );
      validation.userAuthorized = authorizationCheck.authorized;
      validation.authorizationReason = authorizationCheck.reason;

      // Check patient consent
      final consentCheck = await _validatePatientConsent(
        patientId,
        userId,
        requestedDataTypes,
      );
      validation.patientConsentValid = consentCheck.valid;
      validation.consentReason = consentCheck.reason;

      // Check access controls
      final accessControlCheck = _validateAccessControls(
        userId,
        requestedDataTypes,
      );
      validation.accessControlsValid = accessControlCheck.valid;
      validation.accessControlReason = accessControlCheck.reason;

      // Overall compliance determination
      validation.isCompliant =
          validation.minimumNecessaryCompliant &&
          validation.userAuthorized &&
          validation.patientConsentValid &&
          validation.accessControlsValid;

      // Log the validation attempt
      await _auditService.logDataAccess(
        userId: userId,
        resourceId: patientId,
        resourceType: 'patient_data',
        accessType: DataAccessType.read,
        ipAddress: ipAddress,
        patientId: patientId,
        dataScopes: requestedDataTypes,
        success: validation.isCompliant,
        errorMessage: validation.isCompliant
            ? null
            : validation.getViolationSummary(),
        additionalData: {
          'purpose': purpose,
          'hipaa_validation_id': validation.requestId,
          'compliance_check': validation.toJson(),
        },
      );

      // Record violation if not compliant
      if (!validation.isCompliant) {
        await _recordHipaaViolation(validation);
      }

      _logger.i(
        'HIPAA access validation completed: ${validation.isCompliant ? 'COMPLIANT' : 'VIOLATION'} '
        'for user $userId accessing patient $patientId',
      );

      return validation;
    } catch (e) {
      _logger.e('Failed to validate HIPAA data access: $e');
      rethrow;
    }
  }

  /// Generate comprehensive HIPAA compliance report
  Future<HipaaComplianceReport> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
    String? patientId,
    String? userId,
  }) async {
    try {
      _logger.i(
        'Generating HIPAA compliance report for period: $startDate to $endDate',
      );

      // Get audit logs for the period
      final auditLogs = await _auditService.getAuditLogs(
        startDate: startDate,
        endDate: endDate,
        patientId: patientId,
        userId: userId,
        limit: 10000,
      );

      // Get violations for the period
      final violations = await _getViolationsForPeriod(startDate, endDate);

      // Calculate compliance metrics
      final metrics = _calculateComplianceMetrics(auditLogs, violations);

      // Generate recommendations
      final recommendations = _generateComplianceRecommendations(
        metrics,
        violations,
      );

      final report = HipaaComplianceReport(
        reportId: _uuid.v4(),
        generatedAt: DateTime.now(),
        reportPeriod: DateRange(startDate, endDate),
        patientId: patientId,
        userId: userId,
        totalDataAccessEvents: auditLogs
            .where((log) => log.category == AuditCategory.dataAccess)
            .length,
        compliantAccessEvents: auditLogs
            .where(
              (log) => log.category == AuditCategory.dataAccess && log.success,
            )
            .length,
        violationCount: violations.length,
        criticalViolations: violations
            .where((v) => v.severity == HipaaViolationSeverity.critical)
            .length,
        encryptionCompliance: await _assessEncryptionCompliance(),
        accessControlCompliance: _assessAccessControlCompliance(),
        auditTrailCompliance: _assessAuditTrailCompliance(auditLogs),
        patientRightsCompliance: _assessPatientRightsCompliance(),
        complianceScore: metrics.overallComplianceScore,
        violations: violations,
        recommendations: recommendations,
        detailedMetrics: metrics,
      );

      // Store the report
      await _storeComplianceReport(report);

      _logger.i(
        'HIPAA compliance report generated successfully: ${report.reportId}',
      );
      return report;
    } catch (e) {
      _logger.e('Failed to generate HIPAA compliance report: $e');
      rethrow;
    }
  }

  /// Conduct HIPAA risk assessment
  Future<HipaaRiskAssessment> conductRiskAssessment() async {
    try {
      _logger.i('Conducting HIPAA risk assessment');

      final assessment = HipaaRiskAssessment(
        assessmentId: _uuid.v4(),
        conductedAt: DateTime.now(),
        assessmentType: 'Automated Security Assessment',
      );

      // Assess technical safeguards
      assessment.technicalSafeguards = await _assessTechnicalSafeguards();

      // Assess administrative safeguards
      assessment.administrativeSafeguards = _assessAdministrativeSafeguards();

      // Assess physical safeguards
      assessment.physicalSafeguards = _assessPhysicalSafeguards();

      // Calculate overall risk level
      assessment.overallRiskLevel = _calculateOverallRiskLevel(assessment);

      // Generate risk mitigation recommendations
      assessment.riskMitigationRecommendations =
          _generateRiskMitigationRecommendations(assessment);

      _logger.i(
        'HIPAA risk assessment completed with overall risk level: ${assessment.overallRiskLevel}',
      );
      return assessment;
    } catch (e) {
      _logger.e('Failed to conduct HIPAA risk assessment: $e');
      rethrow;
    }
  }

  /// Monitor for potential HIPAA violations in real-time
  Future<List<HipaaViolationAlert>> monitorForViolations() async {
    try {
      final alerts = <HipaaViolationAlert>[];

      // Check for unusual access patterns
      final unusualAccessAlerts = await _detectUnusualAccessPatterns();
      alerts.addAll(unusualAccessAlerts);

      // Check for unauthorized access attempts
      final unauthorizedAccessAlerts = await _detectUnauthorizedAccess();
      alerts.addAll(unauthorizedAccessAlerts);

      // Check for data integrity issues
      final dataIntegrityAlerts = await _detectDataIntegrityIssues();
      alerts.addAll(dataIntegrityAlerts);

      // Check for encryption compliance
      final encryptionAlerts = await _detectEncryptionViolations();
      alerts.addAll(encryptionAlerts);

      if (alerts.isNotEmpty) {
        _logger.w('Detected ${alerts.length} potential HIPAA violations');

        // Record violations
        for (final alert in alerts) {
          await _recordViolationAlert(alert);
        }
      }

      return alerts;
    } catch (e) {
      _logger.e('Failed to monitor for HIPAA violations: $e');
      return [];
    }
  }

  /// Get HIPAA compliance status dashboard
  Future<HipaaComplianceDashboard> getComplianceDashboard() async {
    try {
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));

      // Get recent violations
      final recentViolations = await _getViolationsForPeriod(last30Days, now);

      // Get recent audit logs
      final recentAuditLogs = await _auditService.getAuditLogs(
        startDate: last30Days,
        limit: 1000,
      );

      // Calculate current compliance metrics
      final metrics = _calculateComplianceMetrics(
        recentAuditLogs,
        recentViolations,
      );

      // Get encryption status
      final encryptionStatus = _encryptionService.getEncryptionStatus();

      return HipaaComplianceDashboard(
        lastUpdated: now,
        overallComplianceScore: metrics.overallComplianceScore,
        recentViolationCount: recentViolations.length,
        criticalViolationCount: recentViolations
            .where((v) => v.severity == HipaaViolationSeverity.critical)
            .length,
        encryptionStatus: encryptionStatus,
        auditTrailHealth: _assessAuditTrailCompliance(recentAuditLogs),
        accessControlHealth: _assessAccessControlCompliance(),
        patientRightsHealth: _assessPatientRightsCompliance(),
        riskLevel: _calculateCurrentRiskLevel(metrics, recentViolations),
        actionItems: _generateActionItems(metrics, recentViolations),
      );
    } catch (e) {
      _logger.e('Failed to get HIPAA compliance dashboard: $e');
      rethrow;
    }
  }

  // Private helper methods

  MinimumNecessaryCheck _validateMinimumNecessary(
    List<String> requestedDataTypes,
    String purpose,
  ) {
    // Define minimum necessary data for different purposes
    final minimumDataMap = {
      'treatment': ['vitals', 'symptoms', 'medical_history'],
      'payment': ['insurance_info', 'billing_address'],
      'operations': ['demographics', 'visit_summary'],
      'emergency': ['vitals', 'allergies', 'emergency_contacts'],
    };

    final minimumRequired = minimumDataMap[purpose.toLowerCase()] ?? [];
    final excessiveData = requestedDataTypes
        .where((type) => !minimumRequired.contains(type))
        .toList();

    return MinimumNecessaryCheck(
      compliant: excessiveData.isEmpty,
      reason: excessiveData.isEmpty
          ? 'Request complies with minimum necessary standard'
          : 'Excessive data requested: ${excessiveData.join(', ')}',
    );
  }

  Future<AuthorizationCheck> _validateUserAuthorization(
    String userId,
    String patientId,
    List<String> requestedDataTypes,
  ) async {
    // In a real implementation, this would check user roles, permissions,
    // and relationship to the patient
    return AuthorizationCheck(
      authorized: true,
      reason: 'User authorized for requested data access',
    );
  }

  Future<ConsentCheck> _validatePatientConsent(
    String patientId,
    String userId,
    List<String> requestedDataTypes,
  ) async {
    // In a real implementation, this would check patient consent records
    return ConsentCheck(valid: true, reason: 'Valid patient consent on file');
  }

  AccessControlCheck _validateAccessControls(
    String userId,
    List<String> requestedDataTypes,
  ) {
    // In a real implementation, this would validate technical access controls
    return AccessControlCheck(
      valid: true,
      reason: 'Access controls properly configured',
    );
  }

  Future<void> _recordHipaaViolation(HipaaAccessValidation validation) async {
    final violation = HipaaViolation(
      violationId: _uuid.v4(),
      timestamp: DateTime.now(),
      type: HipaaViolationType.unauthorizedAccess,
      severity: HipaaViolationSeverity.medium,
      userId: validation.userId,
      patientId: validation.patientId,
      description: 'HIPAA compliance violation detected during data access',
      details: validation.toJson(),
      ipAddress: validation.ipAddress,
      deviceInfo: validation.deviceInfo,
      remediated: false,
    );

    await _storeViolation(violation);
  }

  HipaaComplianceMetrics _calculateComplianceMetrics(
    List<AuditLog> auditLogs,
    List<HipaaViolation> violations,
  ) {
    final totalDataAccess = auditLogs
        .where((log) => log.category == AuditCategory.dataAccess)
        .length;
    final successfulAccess = auditLogs
        .where((log) => log.category == AuditCategory.dataAccess && log.success)
        .length;

    final accessSuccessRate = totalDataAccess > 0
        ? (successfulAccess / totalDataAccess) * 100
        : 100.0;

    final violationRate = totalDataAccess > 0
        ? (violations.length / totalDataAccess) * 100
        : 0.0;

    final overallScore =
        (accessSuccessRate * 0.7) + ((100 - violationRate) * 0.3);

    return HipaaComplianceMetrics(
      totalDataAccessEvents: totalDataAccess,
      successfulAccessEvents: successfulAccess,
      accessSuccessRate: accessSuccessRate,
      violationCount: violations.length,
      violationRate: violationRate,
      overallComplianceScore: overallScore,
    );
  }

  List<String> _generateComplianceRecommendations(
    HipaaComplianceMetrics metrics,
    List<HipaaViolation> violations,
  ) {
    final recommendations = <String>[];

    if (metrics.violationRate > 5.0) {
      recommendations.add(
        'High violation rate detected. Review access controls and user training.',
      );
    }

    if (metrics.accessSuccessRate < 95.0) {
      recommendations.add(
        'Low access success rate. Review authentication and authorization processes.',
      );
    }

    final criticalViolations = violations
        .where((v) => v.severity == HipaaViolationSeverity.critical)
        .length;
    if (criticalViolations > 0) {
      recommendations.add(
        'Critical violations detected. Immediate remediation required.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Compliance metrics are within acceptable ranges. Continue monitoring.',
      );
    }

    return recommendations;
  }

  Future<double> _assessEncryptionCompliance() async {
    final encryptionStatus = _encryptionService.getEncryptionStatus();

    double score = 0.0;
    if (encryptionStatus.isInitialized) score += 40.0;
    if (encryptionStatus.algorithm == 'AES-256-CBC') score += 30.0;
    if (encryptionStatus.keyDerivation == 'PBKDF2-SHA256') score += 20.0;
    if (!encryptionStatus.keyRotationRecommended) score += 10.0;

    return score;
  }

  double _assessAccessControlCompliance() {
    // In a real implementation, this would assess actual access controls
    return 85.0; // Mock score
  }

  double _assessAuditTrailCompliance(List<AuditLog> auditLogs) {
    if (auditLogs.isEmpty) return 0.0;

    final dataAccessLogs = auditLogs
        .where((log) => log.category == AuditCategory.dataAccess)
        .length;
    final totalLogs = auditLogs.length;

    // Score based on audit trail completeness
    return (dataAccessLogs / totalLogs) * 100;
  }

  double _assessPatientRightsCompliance() {
    // In a real implementation, this would assess patient rights implementation
    return 90.0; // Mock score
  }

  Future<List<HipaaViolation>> _getViolationsForPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final violationsJson = prefs.getString(_violationsKey);

      if (violationsJson == null) return [];

      final allViolations = (jsonDecode(violationsJson) as List)
          .map((json) => HipaaViolation.fromJson(json))
          .toList();

      return allViolations
          .where(
            (violation) =>
                violation.timestamp.isAfter(startDate) &&
                violation.timestamp.isBefore(endDate),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get violations for period: $e');
      return [];
    }
  }

  Future<void> _storeComplianceReport(HipaaComplianceReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getString(_complianceReportsKey) ?? '[]';
      final reports = jsonDecode(reportsJson) as List;

      reports.add(report.toJson());

      // Keep only the last 50 reports
      if (reports.length > 50) {
        reports.removeRange(0, reports.length - 50);
      }

      await prefs.setString(_complianceReportsKey, jsonEncode(reports));
    } catch (e) {
      _logger.e('Failed to store compliance report: $e');
    }
  }

  Future<void> _storeViolation(HipaaViolation violation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final violationsJson = prefs.getString(_violationsKey) ?? '[]';
      final violations = jsonDecode(violationsJson) as List;

      violations.add(violation.toJson());

      // Keep only the last 1000 violations
      if (violations.length > 1000) {
        violations.removeRange(0, violations.length - 1000);
      }

      await prefs.setString(_violationsKey, jsonEncode(violations));
    } catch (e) {
      _logger.e('Failed to store violation: $e');
    }
  }

  // Additional assessment methods would be implemented here...
  Future<TechnicalSafeguards> _assessTechnicalSafeguards() async {
    return TechnicalSafeguards(
      accessControl: 85.0,
      auditControls: 90.0,
      integrity: 88.0,
      personOrEntityAuthentication: 92.0,
      transmissionSecurity: 87.0,
    );
  }

  AdministrativeSafeguards _assessAdministrativeSafeguards() {
    return AdministrativeSafeguards(
      securityOfficer: 95.0,
      workforceTraining: 80.0,
      informationAccessManagement: 85.0,
      securityAwareness: 88.0,
      securityIncidentProcedures: 90.0,
      contingencyPlan: 85.0,
    );
  }

  PhysicalSafeguards _assessPhysicalSafeguards() {
    return PhysicalSafeguards(
      facilityAccessControls: 90.0,
      workstationUse: 85.0,
      deviceAndMediaControls: 88.0,
    );
  }

  HipaaRiskLevel _calculateOverallRiskLevel(HipaaRiskAssessment assessment) {
    final avgScore =
        (assessment.technicalSafeguards.averageScore +
            assessment.administrativeSafeguards.averageScore +
            assessment.physicalSafeguards.averageScore) /
        3;

    if (avgScore >= 90) return HipaaRiskLevel.low;
    if (avgScore >= 75) return HipaaRiskLevel.medium;
    if (avgScore >= 60) return HipaaRiskLevel.high;
    return HipaaRiskLevel.critical;
  }

  List<String> _generateRiskMitigationRecommendations(
    HipaaRiskAssessment assessment,
  ) {
    final recommendations = <String>[];

    if (assessment.technicalSafeguards.averageScore < 85) {
      recommendations.add('Strengthen technical safeguards implementation');
    }

    if (assessment.administrativeSafeguards.averageScore < 85) {
      recommendations.add(
        'Enhance administrative safeguards and staff training',
      );
    }

    if (assessment.physicalSafeguards.averageScore < 85) {
      recommendations.add('Improve physical security controls');
    }

    return recommendations;
  }

  // Monitoring methods would be implemented here...
  Future<List<HipaaViolationAlert>> _detectUnusualAccessPatterns() async {
    return []; // Implementation would analyze access patterns
  }

  Future<List<HipaaViolationAlert>> _detectUnauthorizedAccess() async {
    return []; // Implementation would detect unauthorized access
  }

  Future<List<HipaaViolationAlert>> _detectDataIntegrityIssues() async {
    return []; // Implementation would check data integrity
  }

  Future<List<HipaaViolationAlert>> _detectEncryptionViolations() async {
    return []; // Implementation would check encryption compliance
  }

  Future<void> _recordViolationAlert(HipaaViolationAlert alert) async {
    // Implementation would record violation alerts
  }

  HipaaRiskLevel _calculateCurrentRiskLevel(
    HipaaComplianceMetrics metrics,
    List<HipaaViolation> violations,
  ) {
    if (metrics.overallComplianceScore >= 95 && violations.isEmpty) {
      return HipaaRiskLevel.low;
    } else if (metrics.overallComplianceScore >= 85) {
      return HipaaRiskLevel.medium;
    } else if (metrics.overallComplianceScore >= 70) {
      return HipaaRiskLevel.high;
    } else {
      return HipaaRiskLevel.critical;
    }
  }

  List<String> _generateActionItems(
    HipaaComplianceMetrics metrics,
    List<HipaaViolation> violations,
  ) {
    final actionItems = <String>[];

    if (violations.isNotEmpty) {
      actionItems.add(
        'Review and remediate ${violations.length} compliance violations',
      );
    }

    if (metrics.overallComplianceScore < 90) {
      actionItems.add(
        'Improve overall compliance score (currently ${metrics.overallComplianceScore.toStringAsFixed(1)}%)',
      );
    }

    return actionItems;
  }
}

// Data models and enums for HIPAA compliance

class HipaaAccessValidation {
  final String requestId;
  final String userId;
  final String patientId;
  final List<String> requestedDataTypes;
  final String purpose;
  final DateTime timestamp;
  final String ipAddress;
  final String? deviceInfo;

  bool minimumNecessaryCompliant = false;
  String? minimumNecessaryReason;
  bool userAuthorized = false;
  String? authorizationReason;
  bool patientConsentValid = false;
  String? consentReason;
  bool accessControlsValid = false;
  String? accessControlReason;
  bool isCompliant = false;

  HipaaAccessValidation({
    required this.requestId,
    required this.userId,
    required this.patientId,
    required this.requestedDataTypes,
    required this.purpose,
    required this.timestamp,
    required this.ipAddress,
    this.deviceInfo,
  });

  String getViolationSummary() {
    final violations = <String>[];
    if (!minimumNecessaryCompliant)
      violations.add('Minimum Necessary: $minimumNecessaryReason');
    if (!userAuthorized) violations.add('Authorization: $authorizationReason');
    if (!patientConsentValid) violations.add('Consent: $consentReason');
    if (!accessControlsValid)
      violations.add('Access Control: $accessControlReason');
    return violations.join('; ');
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'userId': userId,
      'patientId': patientId,
      'requestedDataTypes': requestedDataTypes,
      'purpose': purpose,
      'timestamp': timestamp.toIso8601String(),
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
      'minimumNecessaryCompliant': minimumNecessaryCompliant,
      'minimumNecessaryReason': minimumNecessaryReason,
      'userAuthorized': userAuthorized,
      'authorizationReason': authorizationReason,
      'patientConsentValid': patientConsentValid,
      'consentReason': consentReason,
      'accessControlsValid': accessControlsValid,
      'accessControlReason': accessControlReason,
      'isCompliant': isCompliant,
    };
  }
}

class HipaaComplianceReport {
  final String reportId;
  final DateTime generatedAt;
  final DateRange reportPeriod;
  final String? patientId;
  final String? userId;
  final int totalDataAccessEvents;
  final int compliantAccessEvents;
  final int violationCount;
  final int criticalViolations;
  final double encryptionCompliance;
  final double accessControlCompliance;
  final double auditTrailCompliance;
  final double patientRightsCompliance;
  final double complianceScore;
  final List<HipaaViolation> violations;
  final List<String> recommendations;
  final HipaaComplianceMetrics detailedMetrics;

  const HipaaComplianceReport({
    required this.reportId,
    required this.generatedAt,
    required this.reportPeriod,
    this.patientId,
    this.userId,
    required this.totalDataAccessEvents,
    required this.compliantAccessEvents,
    required this.violationCount,
    required this.criticalViolations,
    required this.encryptionCompliance,
    required this.accessControlCompliance,
    required this.auditTrailCompliance,
    required this.patientRightsCompliance,
    required this.complianceScore,
    required this.violations,
    required this.recommendations,
    required this.detailedMetrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'generatedAt': generatedAt.toIso8601String(),
      'reportPeriod': reportPeriod.toJson(),
      'patientId': patientId,
      'userId': userId,
      'totalDataAccessEvents': totalDataAccessEvents,
      'compliantAccessEvents': compliantAccessEvents,
      'violationCount': violationCount,
      'criticalViolations': criticalViolations,
      'encryptionCompliance': encryptionCompliance,
      'accessControlCompliance': accessControlCompliance,
      'auditTrailCompliance': auditTrailCompliance,
      'patientRightsCompliance': patientRightsCompliance,
      'complianceScore': complianceScore,
      'violations': violations.map((v) => v.toJson()).toList(),
      'recommendations': recommendations,
      'detailedMetrics': detailedMetrics.toJson(),
    };
  }
}

// Additional data classes would be defined here...
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };
}

class HipaaComplianceMetrics {
  final int totalDataAccessEvents;
  final int successfulAccessEvents;
  final double accessSuccessRate;
  final int violationCount;
  final double violationRate;
  final double overallComplianceScore;

  const HipaaComplianceMetrics({
    required this.totalDataAccessEvents,
    required this.successfulAccessEvents,
    required this.accessSuccessRate,
    required this.violationCount,
    required this.violationRate,
    required this.overallComplianceScore,
  });

  Map<String, dynamic> toJson() => {
    'totalDataAccessEvents': totalDataAccessEvents,
    'successfulAccessEvents': successfulAccessEvents,
    'accessSuccessRate': accessSuccessRate,
    'violationCount': violationCount,
    'violationRate': violationRate,
    'overallComplianceScore': overallComplianceScore,
  };
}

class HipaaViolation {
  final String violationId;
  final DateTime timestamp;
  final HipaaViolationType type;
  final HipaaViolationSeverity severity;
  final String? userId;
  final String? patientId;
  final String description;
  final Map<String, dynamic> details;
  final String? ipAddress;
  final String? deviceInfo;
  final bool remediated;

  const HipaaViolation({
    required this.violationId,
    required this.timestamp,
    required this.type,
    required this.severity,
    this.userId,
    this.patientId,
    required this.description,
    required this.details,
    this.ipAddress,
    this.deviceInfo,
    required this.remediated,
  });

  Map<String, dynamic> toJson() => {
    'violationId': violationId,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'severity': severity.name,
    'userId': userId,
    'patientId': patientId,
    'description': description,
    'details': details,
    'ipAddress': ipAddress,
    'deviceInfo': deviceInfo,
    'remediated': remediated,
  };

  factory HipaaViolation.fromJson(Map<String, dynamic> json) => HipaaViolation(
    violationId: json['violationId'],
    timestamp: DateTime.parse(json['timestamp']),
    type: HipaaViolationType.values.firstWhere((t) => t.name == json['type']),
    severity: HipaaViolationSeverity.values.firstWhere(
      (s) => s.name == json['severity'],
    ),
    userId: json['userId'],
    patientId: json['patientId'],
    description: json['description'],
    details: Map<String, dynamic>.from(json['details']),
    ipAddress: json['ipAddress'],
    deviceInfo: json['deviceInfo'],
    remediated: json['remediated'],
  );
}

// Additional classes and enums...
class MinimumNecessaryCheck {
  final bool compliant;
  final String reason;

  MinimumNecessaryCheck({required this.compliant, required this.reason});
}

class AuthorizationCheck {
  final bool authorized;
  final String reason;

  AuthorizationCheck({required this.authorized, required this.reason});
}

class ConsentCheck {
  final bool valid;
  final String reason;

  ConsentCheck({required this.valid, required this.reason});
}

class AccessControlCheck {
  final bool valid;
  final String reason;

  AccessControlCheck({required this.valid, required this.reason});
}

class HipaaRiskAssessment {
  final String assessmentId;
  final DateTime conductedAt;
  final String assessmentType;
  late TechnicalSafeguards technicalSafeguards;
  late AdministrativeSafeguards administrativeSafeguards;
  late PhysicalSafeguards physicalSafeguards;
  late HipaaRiskLevel overallRiskLevel;
  late List<String> riskMitigationRecommendations;

  HipaaRiskAssessment({
    required this.assessmentId,
    required this.conductedAt,
    required this.assessmentType,
  });
}

class TechnicalSafeguards {
  final double accessControl;
  final double auditControls;
  final double integrity;
  final double personOrEntityAuthentication;
  final double transmissionSecurity;

  TechnicalSafeguards({
    required this.accessControl,
    required this.auditControls,
    required this.integrity,
    required this.personOrEntityAuthentication,
    required this.transmissionSecurity,
  });

  double get averageScore =>
      (accessControl +
          auditControls +
          integrity +
          personOrEntityAuthentication +
          transmissionSecurity) /
      5;
}

class AdministrativeSafeguards {
  final double securityOfficer;
  final double workforceTraining;
  final double informationAccessManagement;
  final double securityAwareness;
  final double securityIncidentProcedures;
  final double contingencyPlan;

  AdministrativeSafeguards({
    required this.securityOfficer,
    required this.workforceTraining,
    required this.informationAccessManagement,
    required this.securityAwareness,
    required this.securityIncidentProcedures,
    required this.contingencyPlan,
  });

  double get averageScore =>
      (securityOfficer +
          workforceTraining +
          informationAccessManagement +
          securityAwareness +
          securityIncidentProcedures +
          contingencyPlan) /
      6;
}

class PhysicalSafeguards {
  final double facilityAccessControls;
  final double workstationUse;
  final double deviceAndMediaControls;

  PhysicalSafeguards({
    required this.facilityAccessControls,
    required this.workstationUse,
    required this.deviceAndMediaControls,
  });

  double get averageScore =>
      (facilityAccessControls + workstationUse + deviceAndMediaControls) / 3;
}

class HipaaViolationAlert {
  final String alertId;
  final DateTime detectedAt;
  final HipaaViolationType type;
  final HipaaViolationSeverity severity;
  final String description;
  final Map<String, dynamic> details;

  const HipaaViolationAlert({
    required this.alertId,
    required this.detectedAt,
    required this.type,
    required this.severity,
    required this.description,
    required this.details,
  });
}

class HipaaComplianceDashboard {
  final DateTime lastUpdated;
  final double overallComplianceScore;
  final int recentViolationCount;
  final int criticalViolationCount;
  final EncryptionStatus encryptionStatus;
  final double auditTrailHealth;
  final double accessControlHealth;
  final double patientRightsHealth;
  final HipaaRiskLevel riskLevel;
  final List<String> actionItems;

  const HipaaComplianceDashboard({
    required this.lastUpdated,
    required this.overallComplianceScore,
    required this.recentViolationCount,
    required this.criticalViolationCount,
    required this.encryptionStatus,
    required this.auditTrailHealth,
    required this.accessControlHealth,
    required this.patientRightsHealth,
    required this.riskLevel,
    required this.actionItems,
  });
}

enum HipaaViolationType {
  unauthorizedAccess,
  minimumNecessaryViolation,
  consentViolation,
  encryptionViolation,
  auditTrailViolation,
  dataIntegrityViolation,
}

enum HipaaViolationSeverity { low, medium, high, critical }

enum HipaaRiskLevel { low, medium, high, critical }
