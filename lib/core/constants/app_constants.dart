class AppConstants {
  // App Info
  static const String appName = 'Triage-BIOS.ai';
  static const String appTagline = 'Vital Intelligence for Critical Decisions';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'https://api.triage-bios.ai/v1';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com';

  // Triage Scoring
  static const double maxSeverityScore = 10.0;
  static const double criticalThreshold = 8.0;
  static const double urgentThreshold = 6.0;
  static const double standardThreshold = 4.0;

  // Vitals Thresholds
  static const int normalHeartRateMin = 60;
  static const int normalHeartRateMax = 100;
  static const int tachycardiaThreshold = 120;
  static const int bradycardiaThreshold = 50;

  static const String normalBloodPressureMax = '140/90';
  static const String hypertensiveCrisisThreshold = '180/120';
  static const String hypotensionThreshold = '90/60';

  static const double normalSpO2Min = 95.0;
  static const double hypoxemiaThreshold = 90.0;

  static const double normalTempMax = 99.5; // Fahrenheit
  static const double feverThreshold = 101.5;

  // Hospital Search
  static const double hospitalSearchRadiusMiles = 50.0;
  static const int maxHospitalResults = 10;

  // Response Times
  static const int triageTimeoutMs = 800;
  static const int routingTimeoutMs = 2000;

  // Cache Duration
  static const Duration hospitalCacheDuration = Duration(minutes: 5);
  static const Duration vitalsCacheDuration = Duration(seconds: 30);
}
