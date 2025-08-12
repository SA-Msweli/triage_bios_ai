import 'dart:convert';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderVerificationService {
  static final ProviderVerificationService _instance =
      ProviderVerificationService._internal();
  factory ProviderVerificationService() => _instance;
  ProviderVerificationService._internal();

  final Logger _logger = Logger();
  static const String _verifiedProvidersKey = 'verified_providers';

  /// Verify healthcare provider credentials
  Future<ProviderVerificationResult> verifyProvider({
    required String providerId,
    required String medicalLicense,
    required String deaNumber,
    required String hospitalAffiliation,
    required String specialization,
  }) async {
    try {
      _logger.i('Verifying provider credentials for: $providerId');

      // Simulate API calls to national databases
      await Future.delayed(const Duration(seconds: 2));

      // Mock verification logic
      final isLicenseValid = await _verifyMedicalLicense(medicalLicense);
      final isDeaValid = await _verifyDeaNumber(deaNumber);
      final isHospitalValid = await _verifyHospitalAffiliation(
        hospitalAffiliation,
      );

      if (!isLicenseValid) {
        return ProviderVerificationResult.failure('Invalid medical license');
      }

      if (!isDeaValid) {
        return ProviderVerificationResult.failure('Invalid DEA number');
      }

      if (!isHospitalValid) {
        return ProviderVerificationResult.failure(
          'Invalid hospital affiliation',
        );
      }

      // Create verified provider record
      final verifiedProvider = VerifiedProvider(
        providerId: providerId,
        medicalLicense: medicalLicense,
        deaNumber: deaNumber,
        hospitalAffiliation: hospitalAffiliation,
        specialization: specialization,
        verificationDate: DateTime.now(),
        expirationDate: DateTime.now().add(const Duration(days: 365)),
        isActive: true,
      );

      // Store verification
      await _storeVerifiedProvider(verifiedProvider);

      _logger.i('Provider verification successful: $providerId');
      return ProviderVerificationResult.success(verifiedProvider);
    } catch (e) {
      _logger.e('Provider verification failed: $e');
      return ProviderVerificationResult.failure('Verification failed: $e');
    }
  }

  /// Check if provider is verified and active
  Future<bool> isProviderVerified(String providerId) async {
    try {
      final provider = await _getVerifiedProvider(providerId);
      return provider != null && provider.isActive && !provider.isExpired;
    } catch (e) {
      _logger.e('Error checking provider verification: $e');
      return false;
    }
  }

  /// Get verified provider information
  Future<VerifiedProvider?> getVerifiedProvider(String providerId) async {
    return await _getVerifiedProvider(providerId);
  }

  /// Update provider verification status
  Future<void> updateProviderStatus(String providerId, bool isActive) async {
    try {
      final provider = await _getVerifiedProvider(providerId);
      if (provider != null) {
        final updatedProvider = provider.copyWith(isActive: isActive);
        await _storeVerifiedProvider(updatedProvider);
        _logger.i('Provider status updated: $providerId -> $isActive');
      }
    } catch (e) {
      _logger.e('Failed to update provider status: $e');
    }
  }

  /// Check for expiring credentials
  Future<List<VerifiedProvider>> getExpiringCredentials({
    int daysAhead = 30,
  }) async {
    try {
      final providers = await _getAllVerifiedProviders();
      final expirationThreshold = DateTime.now().add(Duration(days: daysAhead));

      return providers
          .where(
            (provider) =>
                provider.isActive &&
                provider.expirationDate.isBefore(expirationThreshold),
          )
          .toList();
    } catch (e) {
      _logger.e('Error getting expiring credentials: $e');
      return [];
    }
  }

  // Private helper methods

  Future<bool> _verifyMedicalLicense(String license) async {
    // Mock verification against national medical license database
    await Future.delayed(const Duration(milliseconds: 500));

    // Simple validation: license should be alphanumeric and 8+ characters
    return license.length >= 8 && RegExp(r'^[A-Z0-9]+$').hasMatch(license);
  }

  Future<bool> _verifyDeaNumber(String deaNumber) async {
    // Mock verification against DEA database
    await Future.delayed(const Duration(milliseconds: 500));

    // Simple validation: DEA number format (2 letters + 7 digits)
    return RegExp(r'^[A-Z]{2}[0-9]{7}$').hasMatch(deaNumber);
  }

  Future<bool> _verifyHospitalAffiliation(String hospital) async {
    // Mock verification against hospital database
    await Future.delayed(const Duration(milliseconds: 500));

    // Simple validation: hospital name should be non-empty
    return hospital.isNotEmpty;
  }

  Future<void> _storeVerifiedProvider(VerifiedProvider provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providersJson = prefs.getString(_verifiedProvidersKey) ?? '{}';
      final providersData = jsonDecode(providersJson) as Map<String, dynamic>;

      providersData[provider.providerId] = provider.toJson();
      await prefs.setString(_verifiedProvidersKey, jsonEncode(providersData));
    } catch (e) {
      _logger.e('Failed to store verified provider: $e');
      rethrow;
    }
  }

  Future<VerifiedProvider?> _getVerifiedProvider(String providerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providersJson = prefs.getString(_verifiedProvidersKey) ?? '{}';
      final providersData = jsonDecode(providersJson) as Map<String, dynamic>;

      final providerData = providersData[providerId] as Map<String, dynamic>?;
      if (providerData == null) return null;

      return VerifiedProvider.fromJson(providerData);
    } catch (e) {
      _logger.e('Failed to get verified provider: $e');
      return null;
    }
  }

  Future<List<VerifiedProvider>> _getAllVerifiedProviders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providersJson = prefs.getString(_verifiedProvidersKey) ?? '{}';
      final providersData = jsonDecode(providersJson) as Map<String, dynamic>;

      return providersData.values
          .map(
            (data) => VerifiedProvider.fromJson(data as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      _logger.e('Failed to get all verified providers: $e');
      return [];
    }
  }
}

class VerifiedProvider {
  final String providerId;
  final String medicalLicense;
  final String deaNumber;
  final String hospitalAffiliation;
  final String specialization;
  final DateTime verificationDate;
  final DateTime expirationDate;
  final bool isActive;

  const VerifiedProvider({
    required this.providerId,
    required this.medicalLicense,
    required this.deaNumber,
    required this.hospitalAffiliation,
    required this.specialization,
    required this.verificationDate,
    required this.expirationDate,
    required this.isActive,
  });

  bool get isExpired => DateTime.now().isAfter(expirationDate);

  VerifiedProvider copyWith({
    String? providerId,
    String? medicalLicense,
    String? deaNumber,
    String? hospitalAffiliation,
    String? specialization,
    DateTime? verificationDate,
    DateTime? expirationDate,
    bool? isActive,
  }) {
    return VerifiedProvider(
      providerId: providerId ?? this.providerId,
      medicalLicense: medicalLicense ?? this.medicalLicense,
      deaNumber: deaNumber ?? this.deaNumber,
      hospitalAffiliation: hospitalAffiliation ?? this.hospitalAffiliation,
      specialization: specialization ?? this.specialization,
      verificationDate: verificationDate ?? this.verificationDate,
      expirationDate: expirationDate ?? this.expirationDate,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'medicalLicense': medicalLicense,
      'deaNumber': deaNumber,
      'hospitalAffiliation': hospitalAffiliation,
      'specialization': specialization,
      'verificationDate': verificationDate.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory VerifiedProvider.fromJson(Map<String, dynamic> json) {
    return VerifiedProvider(
      providerId: json['providerId'],
      medicalLicense: json['medicalLicense'],
      deaNumber: json['deaNumber'],
      hospitalAffiliation: json['hospitalAffiliation'],
      specialization: json['specialization'],
      verificationDate: DateTime.parse(json['verificationDate']),
      expirationDate: DateTime.parse(json['expirationDate']),
      isActive: json['isActive'],
    );
  }
}

class ProviderVerificationResult {
  final bool success;
  final VerifiedProvider? provider;
  final String? error;

  const ProviderVerificationResult._({
    required this.success,
    this.provider,
    this.error,
  });

  factory ProviderVerificationResult.success(VerifiedProvider provider) {
    return ProviderVerificationResult._(success: true, provider: provider);
  }

  factory ProviderVerificationResult.failure(String error) {
    return ProviderVerificationResult._(success: false, error: error);
  }
}
