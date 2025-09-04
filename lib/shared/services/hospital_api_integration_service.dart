import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/firestore/hospital_firestore.dart';
import '../models/firestore/hospital_capacity_firestore.dart';
import '../models/firestore/hospital_integration_config_firestore.dart';
import 'data_source_manager.dart';

/// Hospital API integration service with automatic fallback to Firestore
class HospitalAPIIntegrationService {
  static final HospitalAPIIntegrationService _instance =
      HospitalAPIIntegrationService._internal();
  factory HospitalAPIIntegrationService() => _instance;
  HospitalAPIIntegrationService._internal();

  final Logger _logger = Logger();
  final http.Client _httpClient = http.Client();

  // Cache for authentication tokens
  final Map<String, AuthToken> _authTokenCache = {};

  /// Get hospital data from custom API
  Future<HospitalFirestore?> getHospitalData(
    String hospitalId,
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      if (config.apiConfig == null) {
        throw Exception('API configuration is null for hospital $hospitalId');
      }

      final apiConfig = config.apiConfig!;
      final headers = await _buildHeaders(hospitalId, config);

      final uri = Uri.parse('${apiConfig.baseUrl}/hospitals/$hospitalId');

      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(Duration(seconds: apiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHospitalData(hospitalId, data);
      } else {
        throw HttpException(
          'API request failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      _logger.e('Failed to get hospital data from API for $hospitalId: $e');
      rethrow;
    }
  }

  /// Get hospital capacity from custom API
  Future<HospitalCapacityFirestore?> getHospitalCapacity(
    String hospitalId,
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      if (config.apiConfig == null) {
        throw Exception('API configuration is null for hospital $hospitalId');
      }

      final apiConfig = config.apiConfig!;
      final headers = await _buildHeaders(hospitalId, config);

      final uri = Uri.parse(
        '${apiConfig.baseUrl}/hospitals/$hospitalId/capacity',
      );

      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(Duration(seconds: apiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseCapacityData(hospitalId, data);
      } else {
        throw HttpException(
          'API request failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      _logger.e('Failed to get hospital capacity from API for $hospitalId: $e');
      rethrow;
    }
  }

  /// Update hospital capacity via API
  Future<void> updateHospitalCapacity(
    String hospitalId,
    HospitalCapacityFirestore capacity,
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      if (config.apiConfig == null) {
        throw Exception('API configuration is null for hospital $hospitalId');
      }

      final apiConfig = config.apiConfig!;
      final headers = await _buildHeaders(hospitalId, config);
      headers['Content-Type'] = 'application/json';

      final uri = Uri.parse(
        '${apiConfig.baseUrl}/hospitals/$hospitalId/capacity',
      );
      final body = json.encode(_capacityToApiFormat(capacity));

      final response = await _httpClient
          .put(uri, headers: headers, body: body)
          .timeout(Duration(seconds: apiConfig.timeoutSeconds));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw HttpException(
          'API update failed with status ${response.statusCode}: ${response.body}',
        );
      }

      _logger.i(
        'Successfully updated hospital capacity via API for $hospitalId',
      );
    } catch (e) {
      _logger.e(
        'Failed to update hospital capacity via API for $hospitalId: $e',
      );
      rethrow;
    }
  }

  /// Check API health status
  Future<DataSourceHealthStatus> checkAPIHealth(
    String hospitalId,
    HospitalIntegrationConfigFirestore config,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (config.apiConfig == null) {
        throw Exception('API configuration is null');
      }

      final apiConfig = config.apiConfig!;
      final headers = await _buildHeaders(hospitalId, config);

      final uri = Uri.parse('${apiConfig.baseUrl}/health');

      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(Duration(seconds: apiConfig.timeoutSeconds));

      stopwatch.stop();

      final isHealthy = response.statusCode >= 200 && response.statusCode < 300;

      return DataSourceHealthStatus(
        hospitalId: hospitalId,
        dataSource: config.dataSource,
        isHealthy: isHealthy,
        lastChecked: DateTime.now(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: isHealthy
            ? null
            : 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      stopwatch.stop();

      return DataSourceHealthStatus(
        hospitalId: hospitalId,
        dataSource: config.dataSource,
        isHealthy: false,
        lastChecked: DateTime.now(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get real-time capacity updates stream
  Stream<HospitalCapacityFirestore> getCapacityUpdatesStream(
    String hospitalId,
    HospitalIntegrationConfigFirestore config,
  ) async* {
    if (!config.realTimeEnabled || config.apiConfig == null) {
      return;
    }

    while (true) {
      try {
        final capacity = await getHospitalCapacity(hospitalId, config);
        if (capacity != null) {
          yield capacity;
        }
      } catch (e) {
        _logger.w('Failed to get capacity update for $hospitalId: $e');
      }

      // Wait for next sync interval
      await Future.delayed(Duration(minutes: config.syncIntervalMinutes));
    }
  }

  /// Build HTTP headers with authentication
  Future<Map<String, String>> _buildHeaders(
    String hospitalId,
    HospitalIntegrationConfigFirestore config,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'Triage-BIOS-AI/1.0',
    };

    // Add custom headers from config
    headers.addAll(config.apiConfig!.headers);

    // Add authentication headers
    switch (config.apiConfig!.authType) {
      case AuthenticationType.apiKey:
        final apiKey = config.apiConfig!.credentials['apiKey'];
        if (apiKey != null) {
          headers['X-API-Key'] = apiKey;
        }
        break;

      case AuthenticationType.bearerToken:
        final token = config.apiConfig!.credentials['token'];
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        break;

      case AuthenticationType.basicAuth:
        final username = config.apiConfig!.credentials['username'];
        final password = config.apiConfig!.credentials['password'];
        if (username != null && password != null) {
          final credentials = base64Encode(utf8.encode('$username:$password'));
          headers['Authorization'] = 'Basic $credentials';
        }
        break;

      case AuthenticationType.oauth2:
        final token = await _getOAuth2Token(hospitalId, config);
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        break;

      case AuthenticationType.certificate:
        // Certificate authentication is handled at the HTTP client level
        break;

      case AuthenticationType.custom:
        // Custom authentication logic can be implemented here
        break;
    }

    return headers;
  }

  /// Get OAuth2 token with caching
  Future<String?> _getOAuth2Token(
    String hospitalId,
    HospitalIntegrationConfigFirestore config,
  ) async {
    try {
      // Check cache first
      final cachedToken = _authTokenCache[hospitalId];
      if (cachedToken != null && !cachedToken.isExpired) {
        return cachedToken.accessToken;
      }

      // Request new token
      final credentials = config.apiConfig!.credentials;
      final clientId = credentials['clientId'];
      final clientSecret = credentials['clientSecret'];
      final tokenUrl = credentials['tokenUrl'];

      if (clientId == null || clientSecret == null || tokenUrl == null) {
        throw Exception('Missing OAuth2 credentials for hospital $hospitalId');
      }

      final response = await _httpClient.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = AuthToken.fromJson(data);

        // Cache the token
        _authTokenCache[hospitalId] = token;

        return token.accessToken;
      } else {
        throw HttpException(
          'OAuth2 token request failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      _logger.e('Failed to get OAuth2 token for hospital $hospitalId: $e');
      return null;
    }
  }

  /// Parse hospital data from API response
  HospitalFirestore _parseHospitalData(
    String hospitalId,
    Map<String, dynamic> data,
  ) {
    return HospitalFirestore(
      id: hospitalId,
      name: data['name'] as String,
      address: HospitalAddress(
        street: data['address']['street'] as String,
        city: data['address']['city'] as String,
        state: data['address']['state'] as String,
        zipCode: data['address']['zipCode'] as String,
        country: data['address']['country'] as String? ?? 'US',
      ),
      location: HospitalLocation(
        latitude: (data['location']['latitude'] as num).toDouble(),
        longitude: (data['location']['longitude'] as num).toDouble(),
      ),
      contact: HospitalContact(
        phone: data['contact']['phone'] as String,
        email: data['contact']['email'] as String,
        website: data['contact']['website'] as String?,
      ),
      traumaLevel: data['traumaLevel'] as int? ?? 1,
      specializations: List<String>.from(
        data['specializations'] as List? ?? [],
      ),
      certifications: List<String>.from(data['certifications'] as List? ?? []),
      operatingHours: HospitalOperatingHours(
        emergency: data['operatingHours']['emergency'] as String? ?? '24/7',
        general: data['operatingHours']['general'] as String? ?? '24/7',
      ),
      createdAt: DateTime.parse(
        data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        data['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  /// Parse capacity data from API response
  HospitalCapacityFirestore _parseCapacityData(
    String hospitalId,
    Map<String, dynamic> data,
  ) {
    return HospitalCapacityFirestore(
      id: '', // Will be set by Firestore
      hospitalId: hospitalId,
      totalBeds: data['totalBeds'] as int,
      availableBeds: data['availableBeds'] as int,
      icuBeds: data['icuBeds'] as int? ?? 0,
      icuAvailable: data['icuAvailable'] as int? ?? 0,
      emergencyBeds: data['emergencyBeds'] as int? ?? 0,
      emergencyAvailable: data['emergencyAvailable'] as int? ?? 0,
      staffOnDuty: data['staffOnDuty'] as int? ?? 0,
      patientsInQueue: data['patientsInQueue'] as int? ?? 0,
      averageWaitTime: (data['averageWaitTime'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(
        data['lastUpdated'] as String? ?? DateTime.now().toIso8601String(),
      ),
      dataSource: DataSource.customApi,
      isRealTime: data['isRealTime'] as bool? ?? false,
    );
  }

  /// Convert capacity to API format
  Map<String, dynamic> _capacityToApiFormat(
    HospitalCapacityFirestore capacity,
  ) {
    return {
      'hospitalId': capacity.hospitalId,
      'totalBeds': capacity.totalBeds,
      'availableBeds': capacity.availableBeds,
      'icuBeds': capacity.icuBeds,
      'icuAvailable': capacity.icuAvailable,
      'emergencyBeds': capacity.emergencyBeds,
      'emergencyAvailable': capacity.emergencyAvailable,
      'staffOnDuty': capacity.staffOnDuty,
      'patientsInQueue': capacity.patientsInQueue,
      'averageWaitTime': capacity.averageWaitTime,
      'occupancyRate': capacity.occupancyRate,
      'lastUpdated': capacity.lastUpdated.toIso8601String(),
      'isRealTime': capacity.isRealTime,
    };
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
    _authTokenCache.clear();
  }
}

/// Authentication token model
class AuthToken {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final DateTime issuedAt;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.issuedAt,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      issuedAt: DateTime.now(),
    );
  }

  bool get isExpired {
    final expiryTime = issuedAt.add(
      Duration(seconds: expiresIn - 60),
    ); // 60s buffer
    return DateTime.now().isAfter(expiryTime);
  }
}
