# Configuration Management

This directory contains all configuration files for the Triage-BIOS.ai application.

## Files Overview

### `.env.example`
Template file showing all available environment variables with example values. Copy this to `.env` and fill in your actual values.

### `.env`
Your actual environment configuration file. **Never commit this file to version control** as it contains sensitive API keys and secrets.

### `app_config.dart`
Main configuration class that loads settings from environment variables with fallback defaults. This is the primary interface for accessing configuration throughout the app.

### `constants.dart`
Application-wide constants that don't change based on environment (medical thresholds, UI constants, etc.).

### `environment_config.dart`
Environment-specific configuration management for development, staging, and production environments.

## Setup Instructions

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in your actual API keys and configuration values in `.env`**

3. **Initialize configuration in your app:**
   ```dart
   import 'config/environment_config.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     
     // Initialize configuration
     await EnvironmentConfig.initialize();
     
     runApp(MyApp());
   }
   ```

4. **Use configuration throughout your app:**
   ```dart
   import 'config/environment_config.dart';
   
   final config = EnvironmentConfig.instance.config;
   final watsonxApiKey = config.watsonxApiKey;
   final isProduction = EnvironmentConfig.instance.isProduction;
   ```

## Configuration Categories

### 🤖 AI & Machine Learning
- IBM Watson X.ai API keys and endpoints
- Model configurations and parameters
- AI service timeouts and rate limits

### 🏥 Healthcare Integration
- Hospital FHIR API endpoints
- Emergency services integration
- Medical device and wearable APIs
- African healthcare system integrations
- Country-specific health insurance APIs

### 🌍 African Market Support
- 25+ major African countries supported
- Country-specific emergency numbers and services
- African healthcare system integrations (NHIS, NHIF, CBHI, etc.)
- Multi-language support including major African languages
- Regional economic community integrations
- Local currency and timezone support

### 🔐 Security & Authentication
- JWT secrets and encryption keys
- OAuth provider configurations
- Blockchain and consent management

### 💳 Payment & Monetization
- RevenueCat subscription management
- Government ID and insurance verification
- Payment processing configurations

### 📱 Mobile & Platform
- Push notification services (FCM, APNS)
- Maps and location services
- Platform-specific configurations

### 📊 Analytics & Monitoring
- Performance monitoring (Sentry, New Relic)
- Analytics providers (Google Analytics, Mixpanel)
- Logging and debugging configurations

### 🗄️ Data & Storage
- Database connection strings
- Cache configurations (Redis)
- File storage and CDN settings

## Environment-Specific Settings

### Development
- Mock services enabled
- Detailed logging
- Longer timeouts for debugging
- Local database connections

### Staging
- Real services with test data
- Performance monitoring enabled
- Production-like security settings
- Staging database connections

### Production
- All real services
- Optimized performance settings
- Maximum security configurations
- Production database connections

## Security Best Practices

1. **Never commit `.env` files** - They're in `.gitignore` for a reason
2. **Use different API keys** for each environment
3. **Rotate secrets regularly** in production
4. **Use strong encryption keys** (32+ characters)
5. **Enable HTTPS** in staging and production
6. **Use certificate pinning** in production

## Feature Flags

The configuration system includes feature flags to enable/disable functionality:

```dart
// Check if a feature is enabled
if (config.enableBlockchainConsent) {
  // Blockchain consent functionality
}

if (config.enableVoiceInput) {
  // Voice input functionality
}
```

Available feature flags:
- `ENABLE_BLOCKCHAIN_CONSENT` - Blockchain-based consent management
- `ENABLE_EMERGENCY_DISPATCH` - Emergency services integration
- `ENABLE_PAYMENT_PROCESSING` - Payment and subscription features
- `ENABLE_ADVANCED_ANALYTICS` - Advanced analytics and reporting
- `ENABLE_MULTI_LANGUAGE` - Multi-language support
- `ENABLE_OFFLINE_MODE` - Offline functionality
- `ENABLE_VOICE_INPUT` - Voice input for symptoms
- `ENABLE_IMAGE_ANALYSIS` - Image analysis for medical documentation

## Mock Services

For development and testing, mock services can be enabled:

```dart
// Use mock services in development
USE_MOCK_WATSONX=true
USE_MOCK_FHIR=true
USE_MOCK_WEARABLES=true
USE_MOCK_PAYMENTS=true
```

This allows development without requiring real API keys or external service dependencies.

## Troubleshooting

### Configuration Not Loading
1. Ensure `.env` file exists in the project root
2. Check that `flutter_dotenv` package is added to `pubspec.yaml`
3. Verify `EnvironmentConfig.initialize()` is called before using config

### Missing API Keys
1. Check `.env.example` for required keys
2. Ensure all required keys are set in your `.env` file
3. Use mock services for development if real keys aren't available

### Environment Detection Issues
1. Set `FLUTTER_ENV` environment variable explicitly
2. Check that environment-specific configurations are correct
3. Use `EnvironmentConfig.instance.environmentSummary` for debugging

## African Market Features

### Supported Countries (25+ Major African Economies)
- **West Africa**: Nigeria, Ghana, Senegal, Côte d'Ivoire
- **East Africa**: Kenya, Ethiopia, Uganda, Tanzania, Rwanda
- **Southern Africa**: South Africa, Botswana, Zambia, Zimbabwe, Malawi, Mozambique
- **North Africa**: Egypt, Tunisia, Morocco, Algeria, Libya, Sudan
- **Central Africa**: Cameroon, Democratic Republic of Congo, Angola
- **Island Nations**: Mauritius, Madagascar

### African-Specific Features
- **Emergency Services**: Country-specific emergency numbers (112, 999, 191, etc.)
- **Healthcare Systems**: Integration with NHIS, NHIF, CBHI, and other national systems
- **Languages**: Support for 30+ African languages including Swahili, Hausa, Yoruba, Amharic
- **Currencies**: Local currency support (Naira, Rand, Shilling, Cedi, etc.)
- **Timezones**: Accurate timezone handling across African regions
- **Regional Communities**: ECOWAS, SADC, EAC, AU integration support

### Usage Example
```dart
import 'config/regional_config.dart';

// Get emergency numbers for any country (unified approach)
final emergencyNumbers = RegionalConfig.getEmergencyNumbers('NG');
print(emergencyNumbers['ambulance']); // "199"

// Get healthcare system for any country
final healthSystem = RegionalConfig.getHealthcareSystem('KE');
print(healthSystem); // "National Hospital Insurance Fund (NHIF)"

// Get primary languages for any country
final languages = RegionalConfig.getPrimaryLanguages('ZA');
print(languages); // ['en', 'af', 'zu', 'xh']

// Check country support and region
final isSupported = RegionalConfig.isCountrySupported('NG');
final isAfrican = RegionalConfig.isAfricanCountry('NG');
final continent = RegionalConfig.getContinent('NG');
print('$isSupported, $isAfrican, $continent'); // true, true, Africa

// Works for all regions
final usEmergency = RegionalConfig.getEmergencyNumbers('US');
final ukHealthcare = RegionalConfig.getHealthcareSystem('GB');
final germanLanguages = RegionalConfig.getPrimaryLanguages('DE');
```

## Adding New Configuration

1. **Add to `.env.example`** with example value
2. **Add to `app_config.dart`** with getter and fallback
3. **Update this README** with documentation
4. **Add to environment-specific configs** if needed
5. **For regional data**: Update `regional_config.dart` with country-specific data

Example:
```dart
// In app_config.dart
String get newApiKey => 
    dotenv.env['NEW_API_KEY'] ?? 'demo_new_api_key';
```

## Support

For configuration issues or questions:
- Check this README first
- Review the example files
- Contact the development team
- Create an issue in the project repository