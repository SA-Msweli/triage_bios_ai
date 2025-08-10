import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';

class ApiResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  ApiResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
  });
}

class ApiClient {
  final http.Client _client = http.Client();
  final Logger _logger = Logger();
  String? _authToken;

  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, String> get _headers {
    final headers = Map<String, String>.from(_defaultHeaders);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Watson X.ai API calls
  Future<ApiResponse> triageAssessment({
    required String symptoms,
    required Map<String, dynamic> vitals,
    Map<String, dynamic>? location,
  }) async {
    try {
      final url = Uri.parse('${AppConstants.baseUrl}/triage');
      final body = jsonEncode({
        'symptoms': symptoms,
        'vitals': vitals,
        'location': location,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _logger.d('REQUEST: POST ${url.path}');
      _logger.d('Headers: $_headers');
      _logger.d('Data: $body');

      final response = await _client.post(url, headers: _headers, body: body);
      
      _logger.d('RESPONSE: ${response.statusCode} ${url.path}');
      _logger.d('Data: ${response.body}');

      return ApiResponse(
        statusCode: response.statusCode,
        data: jsonDecode(response.body),
        headers: response.headers,
      );
    } catch (e) {
      _logger.e('Triage assessment failed: $e');
      rethrow;
    }
  }

  // Hospital routing API calls
  Future<ApiResponse> findHospitals({
    required double latitude,
    required double longitude,
    double? radiusMiles,
    String? specialization,
  }) async {
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': (radiusMiles ?? AppConstants.hospitalSearchRadiusMiles).toString(),
        if (specialization != null) 'specialization': specialization,
      };
      
      final url = Uri.parse('${AppConstants.baseUrl}/hospitals').replace(queryParameters: queryParams);
      
      _logger.d('REQUEST: GET ${url.path}');
      _logger.d('Headers: $_headers');

      final response = await _client.get(url, headers: _headers);
      
      _logger.d('RESPONSE: ${response.statusCode} ${url.path}');
      _logger.d('Data: ${response.body}');

      return ApiResponse(
        statusCode: response.statusCode,
        data: jsonDecode(response.body),
        headers: response.headers,
      );
    } catch (e) {
      _logger.e('Hospital search failed: $e');
      rethrow;
    }
  }

  // Hospital capacity API calls
  Future<ApiResponse> getHospitalCapacity(String hospitalId) async {
    try {
      final url = Uri.parse('${AppConstants.baseUrl}/hospitals/$hospitalId/capacity');
      
      _logger.d('REQUEST: GET ${url.path}');
      _logger.d('Headers: $_headers');

      final response = await _client.get(url, headers: _headers);
      
      _logger.d('RESPONSE: ${response.statusCode} ${url.path}');
      _logger.d('Data: ${response.body}');

      return ApiResponse(
        statusCode: response.statusCode,
        data: jsonDecode(response.body),
        headers: response.headers,
      );
    } catch (e) {
      _logger.e('Hospital capacity fetch failed: $e');
      rethrow;
    }
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  void dispose() {
    _client.close();
  }
}