import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';

class ApiClient {
  late final Dio _dio;
  final Logger _logger = Logger();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('REQUEST: ${options.method} ${options.path}');
          _logger.d('Headers: ${options.headers}');
          _logger.d('Data: ${options.data}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('RESPONSE: ${response.statusCode} ${response.requestOptions.path}');
          _logger.d('Data: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('ERROR: ${error.message}');
          _logger.e('Response: ${error.response?.data}');
          handler.next(error);
        },
      ),
    );
  }

  // Watson X.ai API calls
  Future<Response> triageAssessment({
    required String symptoms,
    required Map<String, dynamic> vitals,
    Map<String, dynamic>? location,
  }) async {
    try {
      final response = await _dio.post('/triage', data: {
        'symptoms': symptoms,
        'vitals': vitals,
        'location': location,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return response;
    } catch (e) {
      _logger.e('Triage assessment failed: $e');
      rethrow;
    }
  }

  // Hospital routing API calls
  Future<Response> findHospitals({
    required double latitude,
    required double longitude,
    double? radiusMiles,
    String? specialization,
  }) async {
    try {
      final response = await _dio.get('/hospitals', queryParameters: {
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMiles ?? AppConstants.hospitalSearchRadiusMiles,
        if (specialization != null) 'specialization': specialization,
      });
      return response;
    } catch (e) {
      _logger.e('Hospital search failed: $e');
      rethrow;
    }
  }

  // Hospital capacity API calls
  Future<Response> getHospitalCapacity(String hospitalId) async {
    try {
      final response = await _dio.get('/hospitals/$hospitalId/capacity');
      return response;
    } catch (e) {
      _logger.e('Hospital capacity fetch failed: $e');
      rethrow;
    }
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}