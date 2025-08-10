import 'package:flutter/foundation.dart';
import 'app_config.dart';

/// Environment-specific configuration management
/// Handles different configurations for development, staging, and production
class EnvironmentConfig {
  static late EnvironmentConfig _instance;
  static EnvironmentConfig get instance => _instance;

  final Environment _environment;
  final AppConfig _appConfig;

  EnvironmentConfig._(this._environment, this._appConfig);

  /// Initialize environment configuration
  static Future<void> initialize() async {
    // Determine environment
    Environment env;
    if (kDebugMode) {
      env = Environment.development;
    } else if (kProfileMode) {
      env = Environment.staging;
    } else {
      env = Environment.production;
    }

    // Override with environment variable if set
    final envString = const String.fromEnvironment('FLUTTER_ENV');
    if (envString.isNotEmpty) {
      env = Environment.values.firstWhere(
        (e) => e.name == envString,
        orElse: () => env,
      );
    }

    // Initialize app config
    await AppConfig.initialize();

    _instance = EnvironmentConfig._(env, AppConfig.instance);
  }

  // Getters
  Environment get environment => _environment;
  AppConfig get config => _appConfig;
  
  bool get isDevelopment => _environment == Environment.development;
  bool get isStaging => _environment == Environment.staging;
  bool get isProduction => _environment == Environment.production;

  // Environment-specific configurations
  String get baseUrl {
    switch (_environment) {
      case Environment.development:
        return 'https://dev-api.triage-bios.ai';
      case Environment.staging:
        return 'https://staging-api.triage-bios.ai';
      case Environment.production:
        return 'https://api.triage-bios.ai';
    }
  }

  String get websocketUrl {
    switch (_environment) {
      case Environment.development:
        return 'wss://dev-ws.triage-bios.ai';
      case Environment.staging:
        return 'wss://staging-ws.triage-bios.ai';
      case Environment.production:
        return 'wss://ws.triage-bios.ai';
    }
  }

  String get cdnUrl {
    switch (_environment) {
      case Environment.development:
        return 'https://dev-cdn.triage-bios.ai';
      case Environment.staging:
        return 'https://staging-cdn.triage-bios.ai';
      case Environment.production:
        return 'https://cdn.triage-bios.ai';
    }
  }

  // Logging configuration
  LogLevel get logLevel {
    switch (_environment) {
      case Environment.development:
        return LogLevel.debug;
      case Environment.staging:
        return LogLevel.info;
      case Environment.production:
        return LogLevel.warning;
    }
  }

  // Feature flags based on environment
  bool get enableDebugFeatures => isDevelopment;
  bool get enablePerformanceMonitoring => !isDevelopment;
  bool get enableCrashReporting => isProduction;
  bool get enableAnalytics => !isDevelopment;
  bool get enableDetailedLogging => isDevelopment;

  // Mock service configuration
  bool get useMockServices {
    switch (_environment) {
      case Environment.development:
        return true;
      case Environment.staging:
        return false;
      case Environment.production:
        return false;
    }
  }

  // API timeout configuration
  Duration get apiTimeout {
    switch (_environment) {
      case Environment.development:
        return const Duration(seconds: 60); // Longer for debugging
      case Environment.staging:
        return const Duration(seconds: 30);
      case Environment.production:
        return const Duration(seconds: 15); // Faster for production
    }
  }

  // Cache configuration
  Duration get cacheExpiration {
    switch (_environment) {
      case Environment.development:
        return const Duration(minutes: 1); // Short cache for development
      case Environment.staging:
        return const Duration(minutes: 5);
      case Environment.production:
        return const Duration(minutes: 15); // Longer cache for production
    }
  }

  // Rate limiting configuration
  int get rateLimitPerMinute {
    switch (_environment) {
      case Environment.development:
        return 1000; // High limit for development
      case Environment.staging:
        return 500;
      case Environment.production:
        return 100; // Conservative limit for production
    }
  }

  // Database configuration
  DatabaseConfig get databaseConfig {
    switch (_environment) {
      case Environment.development:
        return DatabaseConfig(
          host: 'localhost',
          port: 5432,
          database: 'triage_bios_ai_dev',
          poolSize: 5,
          connectionTimeout: const Duration(seconds: 30),
        );
      case Environment.staging:
        return DatabaseConfig(
          host: _appConfig.databaseHost,
          port: _appConfig.databasePort,
          database: 'triage_bios_ai_staging',
          poolSize: 10,
          connectionTimeout: const Duration(seconds: 15),
        );
      case Environment.production:
        return DatabaseConfig(
          host: _appConfig.databaseHost,
          port: _appConfig.databasePort,
          database: _appConfig.databaseName,
          poolSize: 20,
          connectionTimeout: const Duration(seconds: 10),
        );
    }
  }

  // Security configuration
  SecurityConfig get securityConfig {
    switch (_environment) {
      case Environment.development:
        return SecurityConfig(
          enableHttps: false,
          enableCertificatePinning: false,
          enableTokenRefresh: true,
          tokenExpirationHours: 24,
          enableBiometricAuth: false,
        );
      case Environment.staging:
        return SecurityConfig(
          enableHttps: true,
          enableCertificatePinning: false,
          enableTokenRefresh: true,
          tokenExpirationHours: 12,
          enableBiometricAuth: true,
        );
      case Environment.production:
        return SecurityConfig(
          enableHttps: true,
          enableCertificatePinning: true,
          enableTokenRefresh: true,
          tokenExpirationHours: 8,
          enableBiometricAuth: true,
        );
    }
  }

  // Monitoring configuration
  MonitoringConfig get monitoringConfig {
    switch (_environment) {
      case Environment.development:
        return MonitoringConfig(
          enablePerformanceMonitoring: false,
          enableCrashReporting: false,
          enableUserAnalytics: false,
          enableNetworkMonitoring: true,
          sampleRate: 1.0,
        );
      case Environment.staging:
        return MonitoringConfig(
          enablePerformanceMonitoring: true,
          enableCrashReporting: true,
          enableUserAnalytics: false,
          enableNetworkMonitoring: true,
          sampleRate: 0.5,
        );
      case Environment.production:
        return MonitoringConfig(
          enablePerformanceMonitoring: true,
          enableCrashReporting: true,
          enableUserAnalytics: true,
          enableNetworkMonitoring: true,
          sampleRate: 0.1,
        );
    }
  }

  // Get environment summary for debugging
  Map<String, dynamic> get environmentSummary => {
    'environment': _environment.name,
    'base_url': baseUrl,
    'websocket_url': websocketUrl,
    'cdn_url': cdnUrl,
    'log_level': logLevel.name,
    'use_mock_services': useMockServices,
    'api_timeout_seconds': apiTimeout.inSeconds,
    'cache_expiration_minutes': cacheExpiration.inMinutes,
    'rate_limit_per_minute': rateLimitPerMinute,
    'features': {
      'debug_features': enableDebugFeatures,
      'performance_monitoring': enablePerformanceMonitoring,
      'crash_reporting': enableCrashReporting,
      'analytics': enableAnalytics,
      'detailed_logging': enableDetailedLogging,
    },
    'database': {
      'host': databaseConfig.host,
      'port': databaseConfig.port,
      'database': databaseConfig.database,
      'pool_size': databaseConfig.poolSize,
    },
    'security': {
      'https_enabled': securityConfig.enableHttps,
      'certificate_pinning': securityConfig.enableCertificatePinning,
      'token_expiration_hours': securityConfig.tokenExpirationHours,
      'biometric_auth': securityConfig.enableBiometricAuth,
    },
    'monitoring': {
      'performance_monitoring': monitoringConfig.enablePerformanceMonitoring,
      'crash_reporting': monitoringConfig.enableCrashReporting,
      'user_analytics': monitoringConfig.enableUserAnalytics,
      'sample_rate': monitoringConfig.sampleRate,
    },
  };
}

/// Environment types
enum Environment {
  development,
  staging,
  production,
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Database configuration
class DatabaseConfig {
  final String host;
  final int port;
  final String database;
  final int poolSize;
  final Duration connectionTimeout;

  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.poolSize,
    required this.connectionTimeout,
  });
}

/// Security configuration
class SecurityConfig {
  final bool enableHttps;
  final bool enableCertificatePinning;
  final bool enableTokenRefresh;
  final int tokenExpirationHours;
  final bool enableBiometricAuth;

  const SecurityConfig({
    required this.enableHttps,
    required this.enableCertificatePinning,
    required this.enableTokenRefresh,
    required this.tokenExpirationHours,
    required this.enableBiometricAuth,
  });
}

/// Monitoring configuration
class MonitoringConfig {
  final bool enablePerformanceMonitoring;
  final bool enableCrashReporting;
  final bool enableUserAnalytics;
  final bool enableNetworkMonitoring;
  final double sampleRate;

  const MonitoringConfig({
    required this.enablePerformanceMonitoring,
    required this.enableCrashReporting,
    required this.enableUserAnalytics,
    required this.enableNetworkMonitoring,
    required this.sampleRate,
  });
}