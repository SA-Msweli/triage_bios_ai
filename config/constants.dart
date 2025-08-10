/// Application-wide constants
/// These are compile-time constants that don't change based on environment
class AppConstants {
  // App Information
  static const String appName = 'Triage-BIOS.ai';
  static const String appVersion = '2.0.0';
  static const String appBuildNumber = '1';
  static const String appDescription = 'AI-Powered Emergency Triage System';

  // Company Information
  static const String companyName = 'Triage-BIOS.ai Inc.';
  static const String companyWebsite = 'https://triage-bios.ai';
  static const String supportEmail = 'support@triage-bios.ai';
  static const String privacyPolicyUrl = 'https://triage-bios.ai/privacy';
  static const String termsOfServiceUrl = 'https://triage-bios.ai/terms';

  // API Versions
  static const String apiVersion = 'v1';
  static const String fhirVersion = 'R4';
  static const String watsonxApiVersion = '2023-05-29';

  // Medical Constants
  static const double maxSeverityScore = 10.0;
  static const double minSeverityScore = 0.0;
  static const double criticalThreshold = 8.0;
  static const double urgentThreshold = 6.0;
  static const double standardThreshold = 4.0;

  // Vital Signs Normal Ranges
  static const int normalHeartRateMin = 60;
  static const int normalHeartRateMax = 100;
  static const int normalSystolicBpMin = 90;
  static const int normalSystolicBpMax = 140;
  static const int normalDiastolicBpMin = 60;
  static const int normalDiastolicBpMax = 90;
  static const double normalTempFMin = 97.0;
  static const double normalTempFMax = 99.5;
  static const double normalOxygenSatMin = 95.0;
  static const int normalRespiratoryRateMin = 12;
  static const int normalRespiratoryRateMax = 20;

  // Critical Vital Signs Thresholds
  static const int criticalHeartRateHigh = 120;
  static const int criticalHeartRateLow = 50;
  static const int criticalSystolicBpHigh = 180;
  static const int criticalSystolicBpLow = 90;
  static const int criticalDiastolicBpHigh = 110;
  static const int criticalDiastolicBpLow = 60;
  static const double criticalTempF = 101.5;
  static const double criticalOxygenSat = 90.0;
  static const int criticalRespiratoryRateHigh = 30;
  static const int criticalRespiratoryRateLow = 8;

  // Time Constants
  static const int defaultTimeoutSeconds = 30;
  static const int shortTimeoutSeconds = 10;
  static const int longTimeoutSeconds = 60;
  static const int cacheExpirationMinutes = 5;
  static const int sessionTimeoutMinutes = 30;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const double modalElevation = 8.0;

  // Animation Durations
  static const int shortAnimationMs = 200;
  static const int mediumAnimationMs = 300;
  static const int longAnimationMs = 500;

  // Network Constants
  static const int maxRetryAttempts = 3;
  static const int retryDelayMs = 1000;
  static const int connectionTimeoutMs = 30000;
  static const int receiveTimeoutMs = 30000;

  // File Size Limits
  static const int maxImageSizeMb = 10;
  static const int maxAudioSizeMb = 5;
  static const int maxDocumentSizeMb = 20;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;
  static const int maxSymptomsLength = 2000;

  // Emergency Contact Numbers
  static const String defaultEmergencyNumber = '911'; // Default (US/Canada)
  static const String poisonControlNumber = '1-800-222-1222';
  static const String suicidePreventionNumber = '988';

  // Regional Emergency Numbers (use RegionalConfig.getEmergencyNumbers() for country-specific)
  static const Map<String, Map<String, String>> africanEmergencyNumbers = {
    'NG': {
      'police': '199',
      'fire': '199',
      'ambulance': '199',
      'emergency': '112',
    },
    'ZA': {
      'police': '10111',
      'fire': '10177',
      'ambulance': '10177',
      'emergency': '112',
    },
    'KE': {
      'police': '999',
      'fire': '999',
      'ambulance': '999',
      'emergency': '112',
    },
    'GH': {
      'police': '191',
      'fire': '192',
      'ambulance': '193',
      'emergency': '112',
    },
    'ET': {
      'police': '991',
      'fire': '993',
      'ambulance': '907',
      'emergency': '911',
    },
    'EG': {
      'police': '122',
      'fire': '180',
      'ambulance': '123',
      'emergency': '112',
    },
    'MA': {'police': '19', 'fire': '15', 'ambulance': '15', 'emergency': '112'},
    'TN': {
      'police': '197',
      'fire': '198',
      'ambulance': '190',
      'emergency': '112',
    },
    'RW': {
      'police': '112',
      'fire': '112',
      'ambulance': '912',
      'emergency': '112',
    },
    'UG': {
      'police': '999',
      'fire': '999',
      'ambulance': '911',
      'emergency': '112',
    },
    'TZ': {
      'police': '999',
      'fire': '999',
      'ambulance': '114',
      'emergency': '112',
    },
  };

  // Supported Languages (ISO 639-1 codes)
  static const List<String> supportedLanguages = [
    // Global Languages
    'en', // English - Global lingua franca
    'es', // Spanish - Global language
    'fr', // French - Global language, widely spoken in Africa
    'ar', // Arabic - Widely spoken in North Africa and Middle East
    'pt', // Portuguese - Spoken in several African countries
    // European Languages
    'de', // German
    'it', // Italian
    'ru', // Russian
    'nl', // Dutch
    'tr', // Turkish
    'pl', // Polish
    // Asian Languages
    'zh', // Chinese (Mandarin)
    'ja', // Japanese
    'ko', // Korean
    'hi', // Hindi
    // Major African Languages
    'sw', // Swahili - Widely spoken in East Africa (Kenya, Tanzania, Uganda)
    'am', // Amharic - Official language of Ethiopia
    'ha', // Hausa - Widely spoken in West Africa (Nigeria, Niger, Ghana)
    'yo', // Yoruba - Major language in Nigeria and Benin
    'ig', // Igbo - Major language in Nigeria
    'zu', // Zulu - Major language in South Africa
    'af', // Afrikaans - Spoken in South Africa and Namibia
    'xh', // Xhosa - Major language in South Africa
    'rw', // Kinyarwanda - Official language of Rwanda
    'rn', // Kirundi - Official language of Burundi
    'lg', // Luganda - Major language in Uganda
    'om', // Oromo - Widely spoken in Ethiopia
    'ti', // Tigrinya - Spoken in Ethiopia and Eritrea
    'so', // Somali - Spoken in Somalia, Ethiopia, Kenya
    'mg', // Malagasy - Official language of Madagascar
    'wo', // Wolof - Major language in Senegal
    'ff', // Fulfulde/Fula - Widely spoken across West Africa
    'bm', // Bambara - Major language in Mali
    'tw', // Twi - Major language in Ghana
    'ak', // Akan - Language family in Ghana
    'ee', // Ewe - Spoken in Ghana and Togo
    'ny', // Chichewa/Nyanja - Official language of Malawi
    'sn', // Shona - Major language in Zimbabwe
    'nd', // Ndebele - Spoken in Zimbabwe and South Africa
    'st', // Sesotho - Spoken in Lesotho and South Africa
    'tn', // Setswana - Official language of Botswana
    've', // Venda - Spoken in South Africa
    'ts', // Tsonga - Spoken in South Africa and Mozambique
    'ss', // Swati - Spoken in Eswatini and South Africa
    'nr', // Southern Ndebele - Spoken in South Africa
  ];

  // Supported Countries (ISO 3166-1 alpha-2 codes)
  static const List<String> supportedCountries = [
    // North America
    'US', // United States
    'CA', // Canada
    'MX', // Mexico
    // Europe
    'GB', // United Kingdom
    'DE', // Germany
    'FR', // France
    'ES', // Spain
    'IT', // Italy
    'NL', // Netherlands
    'SE', // Sweden
    'NO', // Norway
    'DK', // Denmark
    'FI', // Finland
    'CH', // Switzerland
    'AT', // Austria
    'BE', // Belgium
    'IE', // Ireland
    'PT', // Portugal
    // Oceania
    'AU', // Australia
    'NZ', // New Zealand
    // Major African Economic Countries
    'NG', // Nigeria - Largest economy in Africa
    'ZA', // South Africa - Second largest economy
    'EG', // Egypt - Third largest economy
    'KE', // Kenya - Major East African hub
    'GH', // Ghana - Stable West African economy
    'ET', // Ethiopia - Fastest growing African economy
    'TN', // Tunisia - North African economic hub
    'MA', // Morocco - Major North/West African economy
    'UG', // Uganda - Growing East African economy
    'TZ', // Tanzania - Major East African economy
    'RW', // Rwanda - Rapidly developing economy
    'SN', // Senegal - Stable West African economy
    'CI', // Côte d'Ivoire (Ivory Coast) - Major West African economy
    'BW', // Botswana - Stable Southern African economy
    'MU', // Mauritius - Island nation financial hub
    'ZM', // Zambia - Major copper producer
    'ZW', // Zimbabwe - Recovering economy
    'MW', // Malawi - Growing agricultural economy
    'MZ', // Mozambique - Emerging economy with natural resources
    'AO', // Angola - Oil-rich economy
    'CM', // Cameroon - Central African economic hub
    'DZ', // Algeria - Major North African oil economy
    'LY', // Libya - Oil-rich North African country
    'SD', // Sudan - Large North African country
    'CD', // Democratic Republic of Congo - Resource-rich Central Africa
    'MG', // Madagascar - Island nation off East Africa
  ];

  // Medical Specializations
  static const List<String> medicalSpecializations = [
    'Emergency Medicine',
    'Internal Medicine',
    'Family Medicine',
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Obstetrics and Gynecology',
    'Psychiatry',
    'Radiology',
    'Anesthesiology',
    'Surgery',
    'Dermatology',
    'Ophthalmology',
    'Otolaryngology',
    'Urology',
    'Oncology',
    'Endocrinology',
    'Gastroenterology',
    'Pulmonology',
    'Nephrology',
    'Rheumatology',
    'Infectious Disease',
    'Critical Care',
    'Trauma Surgery',
  ];

  // Hospital Departments
  static const List<String> hospitalDepartments = [
    'Emergency Department',
    'Intensive Care Unit',
    'Cardiac Care Unit',
    'Neonatal ICU',
    'Pediatric ICU',
    'Surgical ICU',
    'Medical ICU',
    'Burn Unit',
    'Trauma Center',
    'Stroke Center',
    'Cardiac Catheterization Lab',
    'Operating Room',
    'Recovery Room',
    'Maternity Ward',
    'Pediatric Ward',
    'Medical Ward',
    'Surgical Ward',
    'Psychiatric Unit',
    'Rehabilitation Unit',
    'Dialysis Center',
  ];

  // Wearable Device Types
  static const List<String> supportedWearableTypes = [
    'Apple Watch',
    'Samsung Galaxy Watch',
    'Fitbit',
    'Garmin',
    'Polar',
    'Oura Ring',
    'Withings',
    'Amazfit',
    'Huawei Watch',
    'Wear OS',
    'Medical Alert Device',
    'Continuous Glucose Monitor',
    'Blood Pressure Monitor',
    'Pulse Oximeter',
    'ECG Monitor',
    'Sleep Tracker',
  ];

  // Vital Sign Types
  static const List<String> vitalSignTypes = [
    'Heart Rate',
    'Blood Pressure',
    'Body Temperature',
    'Oxygen Saturation',
    'Respiratory Rate',
    'Blood Glucose',
    'Heart Rate Variability',
    'Steps',
    'Sleep Quality',
    'Stress Level',
    'Body Weight',
    'Body Mass Index',
    'Blood Pressure Variability',
    'Pulse Pressure',
    'Mean Arterial Pressure',
  ];

  // Symptom Categories
  static const List<String> symptomCategories = [
    'Cardiovascular',
    'Respiratory',
    'Neurological',
    'Gastrointestinal',
    'Musculoskeletal',
    'Dermatological',
    'Genitourinary',
    'Endocrine',
    'Psychiatric',
    'Infectious',
    'Allergic',
    'Pain',
    'Fever',
    'Fatigue',
    'Other',
  ];

  // Urgency Levels
  static const List<String> urgencyLevels = [
    'Critical',
    'Urgent',
    'Standard',
    'Non-Urgent',
  ];

  // User Roles
  static const List<String> userRoles = [
    'Patient',
    'Caregiver',
    'Healthcare Provider',
    'Administrator',
    'Emergency Dispatcher',
    'Paramedic',
    'Nurse',
    'Doctor',
    'Specialist',
    'Hospital Administrator',
    'System Administrator',
  ];

  // Subscription Types (Global)
  static const List<String> subscriptionTypes = [
    'Government Public',
    'Medical Insurance',
    'Children Free',
    'Pay As You Use',
    'Unverified',
    'Premium',
    'Enterprise',
    'Trial',
    'National Health Insurance',
    'Community Health Insurance',
    'Social Health Insurance',
    'Private Health Insurance',
    'Employer Health Scheme',
    'NGO Health Program',
    'International Aid Program',
  ];

  // Regional Healthcare Systems (use RegionalConfig.getHealthcareSystem() for country-specific)
  static const Map<String, String> africanHealthcareSystems = {
    'NG': 'National Health Insurance Scheme (NHIS)',
    'ZA': 'National Health Insurance (NHI)',
    'KE': 'National Hospital Insurance Fund (NHIF)',
    'GH': 'National Health Insurance Scheme (NHIS)',
    'ET': 'Community-Based Health Insurance (CBHI)',
    'EG': 'Health Insurance Organization (HIO)',
    'MA': 'Assurance Maladie Obligatoire (AMO)',
    'TN': 'Caisse Nationale d\'Assurance Maladie (CNAM)',
    'RW': 'Community-Based Health Insurance (Mutuelle de Santé)',
    'UG': 'National Health Insurance Scheme (NHIS)',
    'TZ': 'National Health Insurance Fund (NHIF)',
    'SN': 'Couverture Maladie Universelle (CMU)',
    'CI': 'Couverture Maladie Universelle (CMU)',
    'BW': 'Botswana National Health Insurance',
    'MU': 'National Health Service',
  };

  // Payment Triggers
  static const List<String> paymentTriggers = [
    'Hospital Arrival',
    'Emergency Dispatch',
    'Device Purchase',
    'Subscription Renewal',
    'Premium Feature Access',
    'Consultation Fee',
    'Data Export',
    'API Usage',
  ];

  // Error Codes
  static const String errorCodeGeneric = 'GENERIC_ERROR';
  static const String errorCodeNetwork = 'NETWORK_ERROR';
  static const String errorCodeTimeout = 'TIMEOUT_ERROR';
  static const String errorCodeAuthentication = 'AUTH_ERROR';
  static const String errorCodeAuthorization = 'AUTHZ_ERROR';
  static const String errorCodeValidation = 'VALIDATION_ERROR';
  static const String errorCodeNotFound = 'NOT_FOUND_ERROR';
  static const String errorCodeServerError = 'SERVER_ERROR';
  static const String errorCodeRateLimit = 'RATE_LIMIT_ERROR';
  static const String errorCodeMaintenance = 'MAINTENANCE_ERROR';

  // Success Messages
  static const String successTriageComplete =
      'Triage assessment completed successfully';
  static const String successHospitalRouted =
      'Hospital routing completed successfully';
  static const String successDataSaved = 'Data saved successfully';
  static const String successConsentRecorded = 'Consent recorded successfully';
  static const String successNotificationSent =
      'Notification sent successfully';

  // Regular Expressions
  static const String emailRegex =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phoneRegex = r'^\+?[1-9]\d{1,14}$';
  static const String passwordRegex =
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{6,}$';

  // Date Formats
  static const String dateFormatShort = 'MM/dd/yyyy';
  static const String dateFormatLong = 'MMMM dd, yyyy';
  static const String dateTimeFormat = 'MM/dd/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
  static const String isoDateFormat = 'yyyy-MM-ddTHH:mm:ss.SSSZ';

  // Storage Keys
  static const String storageKeyUser = 'user_data';
  static const String storageKeyToken = 'auth_token';
  static const String storageKeySettings = 'app_settings';
  static const String storageKeyCache = 'cache_data';
  static const String storageKeyConsent = 'consent_data';
  static const String storageKeyVitals = 'vitals_data';
  static const String storageKeyTriageHistory = 'triage_history';

  // Notification Types
  static const String notificationTypeEmergency = 'emergency';
  static const String notificationTypeReminder = 'reminder';
  static const String notificationTypeUpdate = 'update';
  static const String notificationTypeAlert = 'alert';
  static const String notificationTypeInfo = 'info';

  // Deep Link Schemes
  static const String deepLinkScheme = 'triageBiosAi';
  static const String deepLinkHost = 'app';

  // Feature Flags (Default Values)
  static const bool defaultEnableBlockchain = false;
  static const bool defaultEnableEmergencyDispatch = false;
  static const bool defaultEnablePayments = false;
  static const bool defaultEnableAnalytics = true;
  static const bool defaultEnableMultiLanguage = true;
  static const bool defaultEnableOfflineMode = true;
  static const bool defaultEnableVoiceInput = true;
  static const bool defaultEnableImageAnalysis = true;

  // Performance Thresholds
  static const int maxResponseTimeMs = 800;
  static const int maxVitalsProcessingTimeMs = 100;
  static const int maxHospitalRoutingTimeMs = 1000;
  static const int maxDashboardUpdateIntervalMs = 10000;

  // Security Constants
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 15;
  static const int passwordExpirationDays = 90;
  static const int sessionInactivityMinutes = 30;

  // Compliance Constants
  static const int hipaaAuditRetentionYears = 7;
  static const int gdprDataRetentionYears = 7;
  static const int consentExpirationMonths = 12;
  static const int dataExportTimeoutDays = 30;
}
