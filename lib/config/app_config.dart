import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized application configuration
/// Loads settings from environment variables with fallback defaults
class AppConfig {
  static late AppConfig _instance;
  static AppConfig get instance => _instance;

  // Private constructor
  AppConfig._();

  /// Initialize the configuration
  static Future<void> initialize() async {
    _instance = AppConfig._();

    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print('AppConfig initialized with environment variables');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Warning: .env file not found, using defaults: $e');
      }
    }
  }

  String? _getEnv(String key) {
    return dotenv.env[key];
  }

  // =============================================================================
  // IBM Watson X.ai Configuration
  // =============================================================================

  String get watsonxApiKey =>
      _getEnv('WATSONX_API_KEY') ?? 'demo_watsonx_api_key';

  String get watsonxProjectId =>
      _getEnv('WATSONX_PROJECT_ID') ?? 'demo_project_id';

  String get watsonxBaseUrl =>
      _getEnv('WATSONX_BASE_URL') ?? 'https://us-south.ml.cloud.ibm.com';

  String get watsonxApiVersion =>
      _getEnv('WATSONX_API_VERSION') ?? '2023-05-29';

  String get graniteModelId =>
      _getEnv('GRANITE_MODEL_ID') ?? 'ibm/granite-13b-chat-v2';

  // =============================================================================
  // IBM Cloud Configuration
  // =============================================================================

  String get ibmCloudApiKey =>
      _getEnv('IBM_CLOUD_API_KEY') ?? 'demo_ibm_cloud_api_key';

  String get ibmCloudRegion => _getEnv('IBM_CLOUD_REGION') ?? 'us-south';

  String get ibmBlockchainServiceUrl =>
      _getEnv('IBM_BLOCKCHAIN_SERVICE_URL') ??
      'https://demo-blockchain.ibm.com';

  // =============================================================================
  // Firebase Configuration
  // =============================================================================

  // Web Configuration
  String get firebaseWebApiKey =>
      _getEnv('FIREBASE_WEB_API_KEY') ?? 'demo-firebase-web-api-key';

  String get firebaseWebAppId =>
      _getEnv('FIREBASE_WEB_APP_ID') ?? '1:123456789:web:abcdef123456';

  String get firebaseProjectId =>
      _getEnv('FIREBASE_PROJECT_ID') ?? 'triage-bios-ai-demo';

  String get firebaseAuthDomain =>
      _getEnv('FIREBASE_AUTH_DOMAIN') ?? 'triage-bios-ai-demo.firebaseapp.com';

  String get firebaseStorageBucket =>
      _getEnv('FIREBASE_STORAGE_BUCKET') ?? 'triage-bios-ai-demo.appspot.com';

  String get firebaseMessagingSenderId =>
      _getEnv('FIREBASE_MESSAGING_SENDER_ID') ?? '123456789';

  String get firebaseMeasurementId =>
      _getEnv('FIREBASE_MEASUREMENT_ID') ?? 'G-XXXXXXXXXX';

  // Android Configuration
  String get firebaseAndroidApiKey =>
      _getEnv('FIREBASE_ANDROID_API_KEY') ?? 'demo-firebase-android-api-key';

  String get firebaseAndroidAppId =>
      _getEnv('FIREBASE_ANDROID_APP_ID') ?? '1:123456789:android:abcdef123456';

  // iOS Configuration
  String get firebaseIosApiKey =>
      _getEnv('FIREBASE_IOS_API_KEY') ?? 'demo-firebase-ios-api-key';

  String get firebaseIosAppId =>
      _getEnv('FIREBASE_IOS_APP_ID') ?? '1:123456789:ios:abcdef123456';

  String get firebaseIosBundleId =>
      _getEnv('FIREBASE_IOS_BUNDLE_ID') ?? 'com.example.triageBiosAi';

  // Firebase Feature Flags
  bool get useFirebase => _getEnv('USE_FIREBASE')?.toLowerCase() == 'true';

  // =============================================================================
  // Hospital FHIR API Configuration
  // =============================================================================

  List<String> get demoHospitalFhirUrls => [
    _getEnv('DEMO_HOSPITAL_1_FHIR_URL') ??
        'https://demo-hospital-1.fhir.org/R4',
    _getEnv('DEMO_HOSPITAL_2_FHIR_URL') ??
        'https://demo-hospital-2.fhir.org/R4',
    _getEnv('DEMO_HOSPITAL_3_FHIR_URL') ??
        'https://demo-hospital-3.fhir.org/R4',
    _getEnv('DEMO_HOSPITAL_4_FHIR_URL') ??
        'https://demo-hospital-4.fhir.org/R4',
    _getEnv('DEMO_HOSPITAL_5_FHIR_URL') ??
        'https://demo-hospital-5.fhir.org/R4',
  ];

  String get productionFhirBaseUrl =>
      _getEnv('PRODUCTION_FHIR_BASE_URL') ??
      'https://api.healthcare.gov/fhir/R4';

  String get fhirClientId => _getEnv('FHIR_CLIENT_ID') ?? 'demo_fhir_client_id';

  String get fhirClientSecret =>
      _getEnv('FHIR_CLIENT_SECRET') ?? 'demo_fhir_client_secret';

  // African Healthcare System FHIR Endpoints
  String get africaCdcFhirUrl =>
      _getEnv('AFRICA_CDC_FHIR_URL') ?? 'https://demo-africacdc.org/fhir/R4';

  String get whoAfroFhirUrl =>
      _getEnv('WHO_AFRO_FHIR_URL') ?? 'https://demo-who-afro.int/fhir/R4';

  // Country-specific Healthcare APIs
  Map<String, String> get countryFhirUrls => {
    'NG':
        _getEnv('NIGERIA_FHIR_URL') ??
        'https://demo-nigeria-health.gov.ng/fhir/R4',
    'ZA':
        _getEnv('SOUTH_AFRICA_FHIR_URL') ??
        'https://demo-sa-health.gov.za/fhir/R4',
    'KE':
        _getEnv('KENYA_FHIR_URL') ?? 'https://demo-kenya-health.go.ke/fhir/R4',
    'GH':
        _getEnv('GHANA_FHIR_URL') ?? 'https://demo-ghana-health.gov.gh/fhir/R4',
    'ET':
        _getEnv('ETHIOPIA_FHIR_URL') ??
        'https://demo-ethiopia-health.gov.et/fhir/R4',
    'EG':
        _getEnv('EGYPT_FHIR_URL') ?? 'https://demo-egypt-health.gov.eg/fhir/R4',
    'MA':
        _getEnv('MOROCCO_FHIR_URL') ??
        'https://demo-morocco-health.gov.ma/fhir/R4',
    'TN':
        _getEnv('TUNISIA_FHIR_URL') ??
        'https://demo-tunisia-health.gov.tn/fhir/R4',
    'RW':
        _getEnv('RWANDA_FHIR_URL') ??
        'https://demo-rwanda-health.gov.rw/fhir/R4',
    'UG':
        _getEnv('UGANDA_FHIR_URL') ??
        'https://demo-uganda-health.go.ug/fhir/R4',
    'TZ':
        _getEnv('TANZANIA_FHIR_URL') ??
        'https://demo-tanzania-health.go.tz/fhir/R4',
  };

  // =============================================================================
  // Wearable Device Integration
  // =============================================================================

  bool get healthKitEnabled =>
      _getEnv('HEALTHKIT_ENABLED')?.toLowerCase() == 'true';

  String get googleHealthConnectClientId =>
      _getEnv('GOOGLE_HEALTH_CONNECT_CLIENT_ID') ??
      'demo_google_health_client_id';

  bool get googleHealthConnectEnabled =>
      _getEnv('GOOGLE_HEALTH_CONNECT_ENABLED')?.toLowerCase() == 'true';

  String get samsungHealthAppId =>
      _getEnv('SAMSUNG_HEALTH_APP_ID') ?? 'demo_samsung_health_app_id';

  bool get samsungHealthEnabled =>
      _getEnv('SAMSUNG_HEALTH_ENABLED')?.toLowerCase() == 'true';

  String get fitbitClientId =>
      _getEnv('FITBIT_CLIENT_ID') ?? 'demo_fitbit_client_id';

  String get fitbitClientSecret =>
      _getEnv('FITBIT_CLIENT_SECRET') ?? 'demo_fitbit_client_secret';

  bool get fitbitEnabled => _getEnv('FITBIT_ENABLED')?.toLowerCase() == 'true';

  String get garminConsumerKey =>
      _getEnv('GARMIN_CONSUMER_KEY') ?? 'demo_garmin_consumer_key';

  String get garminConsumerSecret =>
      _getEnv('GARMIN_CONSUMER_SECRET') ?? 'demo_garmin_consumer_secret';

  bool get garminEnabled => _getEnv('GARMIN_ENABLED')?.toLowerCase() == 'true';

  String get ouraClientId => _getEnv('OURA_CLIENT_ID') ?? 'demo_oura_client_id';

  String get ouraClientSecret =>
      _getEnv('OURA_CLIENT_SECRET') ?? 'demo_oura_client_secret';

  bool get ouraEnabled => _getEnv('OURA_ENABLED')?.toLowerCase() == 'true';

  // =============================================================================
  // Maps and Location Services
  // =============================================================================

  String get googleMapsApiKey =>
      _getEnv('GOOGLE_MAPS_API_KEY') ?? 'demo_google_maps_api_key';

  String get googlePlacesApiKey =>
      _getEnv('GOOGLE_PLACES_API_KEY') ?? 'demo_google_places_api_key';

  String get hereMapsApiKey =>
      _getEnv('HERE_MAPS_API_KEY') ?? 'demo_here_maps_api_key';

  String get africaMappingApiKey =>
      _getEnv('AFRICA_MAPPING_API_KEY') ?? 'demo_africa_mapping_api_key';

  String get openStreetMapApiKey =>
      _getEnv('OPENSTREETMAP_API_KEY') ?? 'demo_openstreetmap_api_key';

  // =============================================================================
  // Emergency Services Integration
  // =============================================================================

  String get emergencyDispatchApiUrl =>
      _getEnv('EMERGENCY_DISPATCH_API_URL') ??
      'https://demo-emergency-dispatch.com/v1';

  String get emergencyDispatchApiKey =>
      _getEnv('EMERGENCY_DISPATCH_API_KEY') ??
      'demo_emergency_dispatch_api_key';

  String get ambulanceRoutingApiUrl =>
      _getEnv('AMBULANCE_ROUTING_API_URL') ??
      'https://demo-ambulance-routing.com/v1';

  String get ambulanceRoutingApiKey =>
      _getEnv('AMBULANCE_ROUTING_API_KEY') ?? 'demo_ambulance_routing_api_key';

  // African Emergency Services
  String get africaEmergencyServicesApiUrl =>
      _getEnv('AFRICA_EMERGENCY_SERVICES_API_URL') ??
      'https://demo-africa-emergency.org/v1';

  String get africaEmergencyServicesApiKey =>
      _getEnv('AFRICA_EMERGENCY_SERVICES_API_KEY') ??
      'demo_africa_emergency_api_key';

  // Country-specific emergency services
  Map<String, String> get countryEmergencyApiUrls => {
    'NG':
        _getEnv('NIGERIA_EMERGENCY_API_URL') ??
        'https://demo-nigeria-emergency.gov.ng/v1',
    'ZA':
        _getEnv('SOUTH_AFRICA_EMERGENCY_API_URL') ??
        'https://demo-sa-emergency.gov.za/v1',
    'KE':
        _getEnv('KENYA_EMERGENCY_API_URL') ??
        'https://demo-kenya-emergency.go.ke/v1',
    'GH':
        _getEnv('GHANA_EMERGENCY_API_URL') ??
        'https://demo-ghana-emergency.gov.gh/v1',
    'ET':
        _getEnv('ETHIOPIA_EMERGENCY_API_URL') ??
        'https://demo-ethiopia-emergency.gov.et/v1',
  };

  // =============================================================================
  // Database Configuration
  // =============================================================================

  String get databaseUrl =>
      _getEnv('DATABASE_URL') ??
      'postgresql://demo:demo@localhost:5432/triage_bios_ai';

  String get databaseHost => _getEnv('DATABASE_HOST') ?? 'localhost';

  int get databasePort =>
      int.tryParse(_getEnv('DATABASE_PORT') ?? '5432') ?? 5432;

  String get databaseName => _getEnv('DATABASE_NAME') ?? 'triage_bios_ai';

  String get databaseUser => _getEnv('DATABASE_USER') ?? 'demo_user';

  String get databasePassword =>
      _getEnv('DATABASE_PASSWORD') ?? 'demo_password';

  String get sqliteDatabasePath =>
      _getEnv('SQLITE_DATABASE_PATH') ?? './data/triage_bios_ai.db';

  String get redisUrl => _getEnv('REDIS_URL') ?? 'redis://localhost:6379';

  String get redisHost => _getEnv('REDIS_HOST') ?? 'localhost';

  int get redisPort => int.tryParse(_getEnv('REDIS_PORT') ?? '6379') ?? 6379;

  String? get redisPassword => _getEnv('REDIS_PASSWORD');

  // =============================================================================
  // Authentication & Security
  // =============================================================================

  String get jwtSecret =>
      _getEnv('JWT_SECRET') ?? 'demo_jwt_secret_key_change_in_production';

  int get jwtExpirationHours =>
      int.tryParse(_getEnv('JWT_EXPIRATION_HOURS') ?? '24') ?? 24;

  String get encryptionKey =>
      _getEnv('ENCRYPTION_KEY') ?? 'demo_encryption_key_32_chars_long';

  int get bcryptRounds => int.tryParse(_getEnv('BCRYPT_ROUNDS') ?? '12') ?? 12;

  String get googleOAuthClientId =>
      _getEnv('GOOGLE_OAUTH_CLIENT_ID') ?? 'demo_google_oauth_client_id';

  String get googleOAuthClientSecret =>
      _getEnv('GOOGLE_OAUTH_CLIENT_SECRET') ??
      'demo_google_oauth_client_secret';

  String get appleOAuthClientId =>
      _getEnv('APPLE_OAUTH_CLIENT_ID') ?? 'demo_apple_oauth_client_id';

  String get appleOAuthClientSecret =>
      _getEnv('APPLE_OAUTH_CLIENT_SECRET') ?? 'demo_apple_oauth_client_secret';

  // =============================================================================
  // Blockchain & Consent Management
  // =============================================================================

  String get hyperledgerFabricNetworkUrl =>
      _getEnv('HYPERLEDGER_FABRIC_NETWORK_URL') ??
      'https://demo-hyperledger.com';

  String get hyperledgerFabricUserId =>
      _getEnv('HYPERLEDGER_FABRIC_USER_ID') ?? 'demo_fabric_user';

  String get hyperledgerFabricUserSecret =>
      _getEnv('HYPERLEDGER_FABRIC_USER_SECRET') ?? 'demo_fabric_secret';

  String get ipfsGatewayUrl =>
      _getEnv('IPFS_GATEWAY_URL') ?? 'https://ipfs.io/ipfs/';

  String get ipfsApiUrl =>
      _getEnv('IPFS_API_URL') ??
      'https://api.pinata.cloud/pinning/pinFileToIPFS';

  String get ipfsApiKey => _getEnv('IPFS_API_KEY') ?? 'demo_ipfs_api_key';

  // =============================================================================
  // Payment & Monetization (RevenueCat)
  // =============================================================================

  String get revenueCatPublicApiKey =>
      _getEnv('REVENUECAT_PUBLIC_API_KEY') ?? 'demo_revenuecat_public_key';

  String get revenueCatSecretApiKey =>
      _getEnv('REVENUECAT_SECRET_API_KEY') ?? 'demo_revenuecat_secret_key';

  String get revenueCatAppUserId =>
      _getEnv('REVENUECAT_APP_USER_ID') ?? 'demo_revenuecat_app_user_id';

  String get governmentIdVerificationApiUrl =>
      _getEnv('GOVERNMENT_ID_VERIFICATION_API_URL') ??
      'https://demo-id-verification.gov/v1';

  String get governmentIdVerificationApiKey =>
      _getEnv('GOVERNMENT_ID_VERIFICATION_API_KEY') ?? 'demo_gov_id_api_key';

  String get insuranceVerificationApiUrl =>
      _getEnv('INSURANCE_VERIFICATION_API_URL') ??
      'https://demo-insurance-verification.com/v1';

  String get insuranceVerificationApiKey =>
      _getEnv('INSURANCE_VERIFICATION_API_KEY') ?? 'demo_insurance_api_key';

  // African Government ID Verification Services
  Map<String, String> get countryIdVerificationUrls => {
    'NG':
        _getEnv('NIGERIA_NIN_VERIFICATION_URL') ??
        'https://demo-nigeria-nin.gov.ng/v1/verify',
    'ZA':
        _getEnv('SOUTH_AFRICA_ID_VERIFICATION_URL') ??
        'https://demo-sa-id.gov.za/v1/verify',
    'KE':
        _getEnv('KENYA_ID_VERIFICATION_URL') ??
        'https://demo-kenya-id.go.ke/v1/verify',
    'GH':
        _getEnv('GHANA_ID_VERIFICATION_URL') ??
        'https://demo-ghana-id.gov.gh/v1/verify',
    'ET':
        _getEnv('ETHIOPIA_ID_VERIFICATION_URL') ??
        'https://demo-ethiopia-id.gov.et/v1/verify',
    'EG':
        _getEnv('EGYPT_ID_VERIFICATION_URL') ??
        'https://demo-egypt-id.gov.eg/v1/verify',
    'MA':
        _getEnv('MOROCCO_ID_VERIFICATION_URL') ??
        'https://demo-morocco-id.gov.ma/v1/verify',
    'RW':
        _getEnv('RWANDA_ID_VERIFICATION_URL') ??
        'https://demo-rwanda-id.gov.rw/v1/verify',
  };

  // African Healthcare Insurance Systems
  Map<String, String> get countryInsuranceApiUrls => {
    'NG':
        _getEnv('NIGERIA_NHIS_API_URL') ??
        'https://demo-nigeria-nhis.gov.ng/v1',
    'ZA':
        _getEnv('SOUTH_AFRICA_MEDICAL_SCHEMES_API_URL') ??
        'https://demo-sa-medical.co.za/v1',
    'KE': _getEnv('KENYA_NHIF_API_URL') ?? 'https://demo-kenya-nhif.or.ke/v1',
    'GH': _getEnv('GHANA_NHIS_API_URL') ?? 'https://demo-ghana-nhis.gov.gh/v1',
    'RW':
        _getEnv('RWANDA_CBHI_API_URL') ?? 'https://demo-rwanda-cbhi.gov.rw/v1',
  };

  // =============================================================================
  // Notification Services
  // =============================================================================

  String get fcmServerKey => _getEnv('FCM_SERVER_KEY') ?? 'demo_fcm_server_key';

  String get fcmSenderId => _getEnv('FCM_SENDER_ID') ?? 'demo_fcm_sender_id';

  String get apnsKeyId => _getEnv('APNS_KEY_ID') ?? 'demo_apns_key_id';

  String get apnsTeamId => _getEnv('APNS_TEAM_ID') ?? 'demo_apns_team_id';

  String get apnsBundleId =>
      _getEnv('APNS_BUNDLE_ID') ?? 'com.triageBiosAi.app';

  String get twilioAccountSid =>
      _getEnv('TWILIO_ACCOUNT_SID') ?? 'demo_twilio_account_sid';

  String get twilioAuthToken =>
      _getEnv('TWILIO_AUTH_TOKEN') ?? 'demo_twilio_auth_token';

  String get twilioPhoneNumber =>
      _getEnv('TWILIO_PHONE_NUMBER') ?? '+1234567890';

  String get sendGridApiKey =>
      _getEnv('SENDGRID_API_KEY') ?? 'demo_sendgrid_api_key';

  String get sendGridFromEmail =>
      _getEnv('SENDGRID_FROM_EMAIL') ?? 'noreply@triage-bios.ai';

  // =============================================================================
  // Analytics & Monitoring
  // =============================================================================

  String get sentryDsn =>
      _getEnv('SENTRY_DSN') ?? 'https://demo-sentry-dsn@sentry.io/demo';

  String get newRelicLicenseKey =>
      _getEnv('NEW_RELIC_LICENSE_KEY') ?? 'demo_new_relic_license_key';

  String get googleAnalyticsTrackingId =>
      _getEnv('GOOGLE_ANALYTICS_TRACKING_ID') ?? 'GA-DEMO-123456';

  String get mixpanelProjectToken =>
      _getEnv('MIXPANEL_PROJECT_TOKEN') ?? 'demo_mixpanel_token';

  // =============================================================================
  // Development & Testing
  // =============================================================================

  String get nodeEnv => _getEnv('NODE_ENV') ?? 'development';

  String get flutterEnv => _getEnv('FLUTTER_ENV') ?? 'development';

  bool get debugMode =>
      _getEnv('DEBUG_MODE')?.toLowerCase() == 'true' || kDebugMode;

  String get logLevel => _getEnv('LOG_LEVEL') ?? 'debug';

  bool get useMockWatsonx =>
      _getEnv('USE_MOCK_WATSONX')?.toLowerCase() == 'true' || debugMode;

  bool get useMockFhir =>
      _getEnv('USE_MOCK_FHIR')?.toLowerCase() == 'true' || debugMode;

  bool get useMockWearables =>
      _getEnv('USE_MOCK_WEARABLES')?.toLowerCase() == 'true' || debugMode;

  bool get useMockPayments =>
      _getEnv('USE_MOCK_PAYMENTS')?.toLowerCase() == 'true' || debugMode;

  String get testDatabaseUrl =>
      _getEnv('TEST_DATABASE_URL') ??
      'postgresql://test:test@localhost:5432/triage_bios_ai_test';

  String get testRedisUrl =>
      _getEnv('TEST_REDIS_URL') ?? 'redis://localhost:6380';

  // =============================================================================
  // Feature Flags
  // =============================================================================

  bool get enableBlockchainConsent =>
      _getEnv('ENABLE_BLOCKCHAIN_CONSENT')?.toLowerCase() == 'true';

  bool get enableEmergencyDispatch =>
      _getEnv('ENABLE_EMERGENCY_DISPATCH')?.toLowerCase() == 'true';

  bool get enablePaymentProcessing =>
      _getEnv('ENABLE_PAYMENT_PROCESSING')?.toLowerCase() == 'true';

  bool get enableAdvancedAnalytics =>
      _getEnv('ENABLE_ADVANCED_ANALYTICS')?.toLowerCase() == 'true';

  bool get enableMultiLanguage =>
      _getEnv('ENABLE_MULTI_LANGUAGE')?.toLowerCase() != 'false';

  bool get enableOfflineMode =>
      _getEnv('ENABLE_OFFLINE_MODE')?.toLowerCase() != 'false';

  bool get enableVoiceInput =>
      _getEnv('ENABLE_VOICE_INPUT')?.toLowerCase() != 'false';

  bool get enableImageAnalysis =>
      _getEnv('ENABLE_IMAGE_ANALYSIS')?.toLowerCase() != 'false';

  // =============================================================================
  // Rate Limiting & Performance
  // =============================================================================

  int get apiRateLimitPerMinute =>
      int.tryParse(_getEnv('API_RATE_LIMIT_PER_MINUTE') ?? '100') ?? 100;

  int get watsonxTimeoutSeconds =>
      int.tryParse(_getEnv('WATSONX_TIMEOUT_SECONDS') ?? '30') ?? 30;

  int get fhirTimeoutSeconds =>
      int.tryParse(_getEnv('FHIR_TIMEOUT_SECONDS') ?? '15') ?? 15;

  int get cacheTtlSeconds =>
      int.tryParse(_getEnv('CACHE_TTL_SECONDS') ?? '300') ?? 300;

  int get maxConcurrentRequests =>
      int.tryParse(_getEnv('MAX_CONCURRENT_REQUESTS') ?? '50') ?? 50;

  // =============================================================================
  // Compliance & Audit
  // =============================================================================

  bool get hipaaComplianceMode =>
      _getEnv('HIPAA_COMPLIANCE_MODE')?.toLowerCase() != 'false';

  bool get gdprComplianceMode =>
      _getEnv('GDPR_COMPLIANCE_MODE')?.toLowerCase() != 'false';

  int get auditLogRetentionDays =>
      int.tryParse(_getEnv('AUDIT_LOG_RETENTION_DAYS') ?? '2555') ?? 2555;

  bool get dataEncryptionAtRest =>
      _getEnv('DATA_ENCRYPTION_AT_REST')?.toLowerCase() != 'false';

  bool get dataEncryptionInTransit =>
      _getEnv('DATA_ENCRYPTION_IN_TRANSIT')?.toLowerCase() != 'false';

  // =============================================================================
  // Computed Properties
  // =============================================================================

  bool get isProduction => flutterEnv == 'production';
  bool get isDevelopment => flutterEnv == 'development';
  bool get isTest => flutterEnv == 'test';

  Duration get watsonxTimeout => Duration(seconds: watsonxTimeoutSeconds);
  Duration get fhirTimeout => Duration(seconds: fhirTimeoutSeconds);
  Duration get cacheTtl => Duration(seconds: cacheTtlSeconds);
  Duration get jwtExpiration => Duration(hours: jwtExpirationHours);

  /// Get all enabled wearable platforms
  List<String> get enabledWearablePlatforms {
    final platforms = <String>[];
    if (healthKitEnabled) platforms.add('healthkit');
    if (googleHealthConnectEnabled) platforms.add('google_health_connect');
    if (samsungHealthEnabled) platforms.add('samsung_health');
    if (fitbitEnabled) platforms.add('fitbit');
    if (garminEnabled) platforms.add('garmin');
    if (ouraEnabled) platforms.add('oura');
    return platforms;
  }

  /// Get configuration summary for debugging
  Map<String, dynamic> get configSummary => {
    'environment': flutterEnv,
    'debug_mode': debugMode,
    'watsonx_configured': watsonxApiKey != 'demo_watsonx_api_key',
    'fhir_configured': fhirClientId != 'demo_fhir_client_id',
    'enabled_wearables': enabledWearablePlatforms,
    'feature_flags': {
      'blockchain_consent': enableBlockchainConsent,
      'emergency_dispatch': enableEmergencyDispatch,
      'payment_processing': enablePaymentProcessing,
      'advanced_analytics': enableAdvancedAnalytics,
      'multi_language': enableMultiLanguage,
      'offline_mode': enableOfflineMode,
      'voice_input': enableVoiceInput,
      'image_analysis': enableImageAnalysis,
    },
    'mock_services': {
      'watsonx': useMockWatsonx,
      'fhir': useMockFhir,
      'wearables': useMockWearables,
      'payments': useMockPayments,
    },
  };
}
