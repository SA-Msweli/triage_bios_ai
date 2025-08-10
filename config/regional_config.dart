import 'constants.dart';

/// Regional configuration utilities for different global markets
/// Provides unified access to country-specific data and configurations
class RegionalConfig {
  
  // =============================================================================
  // Country Support Detection
  // =============================================================================
  
  /// Check if a country is supported by the platform
  static bool isCountrySupported(String countryCode) {
    return AppConstants.supportedCountries.contains(countryCode.toUpperCase());
  }
  
  /// Check if a country is in Africa
  static bool isAfricanCountry(String countryCode) {
    final africanCountries = [
      'NG', 'ZA', 'EG', 'KE', 'GH', 'ET', 'TN', 'MA', 'UG', 'TZ', 
      'RW', 'SN', 'CI', 'BW', 'MU', 'ZM', 'ZW', 'MW', 'MZ', 'AO', 
      'CM', 'DZ', 'LY', 'SD', 'CD', 'MG'
    ];
    return africanCountries.contains(countryCode.toUpperCase());
  }
  
  /// Check if a country is in Europe
  static bool isEuropeanCountry(String countryCode) {
    final europeanCountries = [
      'GB', 'DE', 'FR', 'ES', 'IT', 'NL', 'SE', 'NO', 'DK', 'FI', 
      'CH', 'AT', 'BE', 'IE', 'PT'
    ];
    return europeanCountries.contains(countryCode.toUpperCase());
  }
  
  /// Check if a country is in North America
  static bool isNorthAmericanCountry(String countryCode) {
    final northAmericanCountries = ['US', 'CA', 'MX'];
    return northAmericanCountries.contains(countryCode.toUpperCase());
  }
  
  // =============================================================================
  // Emergency Services
  // =============================================================================
  
  /// Get emergency numbers for any supported country
  static Map<String, String> getEmergencyNumbers(String countryCode) {
    final code = countryCode.toUpperCase();
    
    // African countries
    if (AppConstants.africanEmergencyNumbers.containsKey(code)) {
      return AppConstants.africanEmergencyNumbers[code]!;
    }
    
    // Default emergency numbers for other regions
    final defaultNumbers = {
      // North America
      'US': {'police': '911', 'fire': '911', 'ambulance': '911', 'emergency': '911'},
      'CA': {'police': '911', 'fire': '911', 'ambulance': '911', 'emergency': '911'},
      'MX': {'police': '911', 'fire': '911', 'ambulance': '911', 'emergency': '911'},
      
      // Europe
      'GB': {'police': '999', 'fire': '999', 'ambulance': '999', 'emergency': '112'},
      'DE': {'police': '110', 'fire': '112', 'ambulance': '112', 'emergency': '112'},
      'FR': {'police': '17', 'fire': '18', 'ambulance': '15', 'emergency': '112'},
      'ES': {'police': '091', 'fire': '080', 'ambulance': '061', 'emergency': '112'},
      'IT': {'police': '113', 'fire': '115', 'ambulance': '118', 'emergency': '112'},
      'NL': {'police': '112', 'fire': '112', 'ambulance': '112', 'emergency': '112'},
      'SE': {'police': '112', 'fire': '112', 'ambulance': '112', 'emergency': '112'},
      'NO': {'police': '112', 'fire': '110', 'ambulance': '113', 'emergency': '112'},
      'DK': {'police': '114', 'fire': '112', 'ambulance': '112', 'emergency': '112'},
      'FI': {'police': '112', 'fire': '112', 'ambulance': '112', 'emergency': '112'},
      'CH': {'police': '117', 'fire': '118', 'ambulance': '144', 'emergency': '112'},
      'AT': {'police': '133', 'fire': '122', 'ambulance': '144', 'emergency': '112'},
      'BE': {'police': '101', 'fire': '100', 'ambulance': '100', 'emergency': '112'},
      'IE': {'police': '999', 'fire': '999', 'ambulance': '999', 'emergency': '112'},
      'PT': {'police': '112', 'fire': '112', 'ambulance': '112', 'emergency': '112'},
      
      // Oceania
      'AU': {'police': '000', 'fire': '000', 'ambulance': '000', 'emergency': '000'},
      'NZ': {'police': '111', 'fire': '111', 'ambulance': '111', 'emergency': '111'},
    };
    
    return defaultNumbers[code] ?? {
      'police': '112', 'fire': '112', 'ambulance': '112', 'emergency': '112'
    };
  }
  
  // =============================================================================
  // Healthcare Systems
  // =============================================================================
  
  /// Get healthcare system name for any supported country
  static String getHealthcareSystem(String countryCode) {
    final code = countryCode.toUpperCase();
    
    // African healthcare systems
    if (AppConstants.africanHealthcareSystems.containsKey(code)) {
      return AppConstants.africanHealthcareSystems[code]!;
    }
    
    // Other regional healthcare systems
    final healthcareSystems = {
      // North America
      'US': 'Private Healthcare System with Medicare/Medicaid',
      'CA': 'Canada Health Act (Universal Healthcare)',
      'MX': 'Instituto Mexicano del Seguro Social (IMSS)',
      
      // Europe
      'GB': 'National Health Service (NHS)',
      'DE': 'Statutory Health Insurance (GKV)',
      'FR': 'Sécurité Sociale',
      'ES': 'Sistema Nacional de Salud',
      'IT': 'Servizio Sanitario Nazionale (SSN)',
      'NL': 'Zorgverzekeringswet (Health Insurance Act)',
      'SE': 'Swedish Healthcare System',
      'NO': 'Norwegian Healthcare System',
      'DK': 'Danish Healthcare System',
      'FI': 'Finnish Healthcare System',
      'CH': 'Swiss Healthcare System',
      'AT': 'Austrian Healthcare System',
      'BE': 'Belgian Healthcare System',
      'IE': 'Health Service Executive (HSE)',
      'PT': 'Serviço Nacional de Saúde',
      
      // Oceania
      'AU': 'Medicare Australia',
      'NZ': 'New Zealand Health System',
    };
    
    return healthcareSystems[code] ?? 'National Healthcare System';
  }
  
  // =============================================================================
  // Languages
  // =============================================================================
  
  /// Get primary languages for any supported country
  static List<String> getPrimaryLanguages(String countryCode) {
    final languageMap = {
      // African countries
      'NG': ['en', 'ha', 'yo', 'ig'], // Nigeria
      'ZA': ['en', 'af', 'zu', 'xh'], // South Africa
      'EG': ['ar', 'en'], // Egypt
      'KE': ['en', 'sw'], // Kenya
      'GH': ['en', 'tw', 'ak'], // Ghana
      'ET': ['am', 'om', 'ti', 'so'], // Ethiopia
      'TN': ['ar', 'fr'], // Tunisia
      'MA': ['ar', 'fr'], // Morocco
      'UG': ['en', 'sw', 'lg'], // Uganda
      'TZ': ['sw', 'en'], // Tanzania
      'RW': ['rw', 'en', 'fr'], // Rwanda
      'SN': ['fr', 'wo'], // Senegal
      'CI': ['fr'], // Côte d'Ivoire
      'BW': ['en', 'tn'], // Botswana
      'MU': ['en', 'fr'], // Mauritius
      'ZM': ['en'], // Zambia
      'ZW': ['en', 'sn', 'nd'], // Zimbabwe
      'MW': ['en', 'ny'], // Malawi
      'MZ': ['pt'], // Mozambique
      'AO': ['pt'], // Angola
      'CM': ['fr', 'en'], // Cameroon
      'DZ': ['ar', 'fr'], // Algeria
      'LY': ['ar'], // Libya
      'SD': ['ar', 'en'], // Sudan
      'CD': ['fr'], // Democratic Republic of Congo
      'MG': ['mg', 'fr'], // Madagascar
      
      // North America
      'US': ['en', 'es'], // United States
      'CA': ['en', 'fr'], // Canada
      'MX': ['es'], // Mexico
      
      // Europe
      'GB': ['en'], // United Kingdom
      'DE': ['de'], // Germany
      'FR': ['fr'], // France
      'ES': ['es'], // Spain
      'IT': ['it'], // Italy
      'NL': ['nl'], // Netherlands
      'SE': ['sv'], // Sweden
      'NO': ['no'], // Norway
      'DK': ['da'], // Denmark
      'FI': ['fi', 'sv'], // Finland
      'CH': ['de', 'fr', 'it'], // Switzerland
      'AT': ['de'], // Austria
      'BE': ['nl', 'fr', 'de'], // Belgium
      'IE': ['en', 'ga'], // Ireland
      'PT': ['pt'], // Portugal
      
      // Oceania
      'AU': ['en'], // Australia
      'NZ': ['en', 'mi'], // New Zealand
    };
    
    return languageMap[countryCode.toUpperCase()] ?? ['en'];
  }
  
  // =============================================================================
  // Currency and Economic Data
  // =============================================================================
  
  /// Get currency code for any supported country
  static String getCurrencyCode(String countryCode) {
    final currencyMap = {
      // African countries
      'NG': 'NGN', 'ZA': 'ZAR', 'EG': 'EGP', 'KE': 'KES', 'GH': 'GHS',
      'ET': 'ETB', 'TN': 'TND', 'MA': 'MAD', 'UG': 'UGX', 'TZ': 'TZS',
      'RW': 'RWF', 'SN': 'XOF', 'CI': 'XOF', 'BW': 'BWP', 'MU': 'MUR',
      'ZM': 'ZMW', 'ZW': 'ZWL', 'MW': 'MWK', 'MZ': 'MZN', 'AO': 'AOA',
      'CM': 'XAF', 'DZ': 'DZD', 'LY': 'LYD', 'SD': 'SDG', 'CD': 'CDF',
      'MG': 'MGA',
      
      // North America
      'US': 'USD', 'CA': 'CAD', 'MX': 'MXN',
      
      // Europe
      'GB': 'GBP', 'DE': 'EUR', 'FR': 'EUR', 'ES': 'EUR', 'IT': 'EUR',
      'NL': 'EUR', 'SE': 'SEK', 'NO': 'NOK', 'DK': 'DKK', 'FI': 'EUR',
      'CH': 'CHF', 'AT': 'EUR', 'BE': 'EUR', 'IE': 'EUR', 'PT': 'EUR',
      
      // Oceania
      'AU': 'AUD', 'NZ': 'NZD',
    };
    
    return currencyMap[countryCode.toUpperCase()] ?? 'USD';
  }
  
  /// Get timezone for any supported country
  static String getTimezone(String countryCode) {
    final timezoneMap = {
      // African countries
      'NG': 'Africa/Lagos', 'ZA': 'Africa/Johannesburg', 'EG': 'Africa/Cairo',
      'KE': 'Africa/Nairobi', 'GH': 'Africa/Accra', 'ET': 'Africa/Addis_Ababa',
      'TN': 'Africa/Tunis', 'MA': 'Africa/Casablanca', 'UG': 'Africa/Kampala',
      'TZ': 'Africa/Dar_es_Salaam', 'RW': 'Africa/Kigali', 'SN': 'Africa/Dakar',
      'CI': 'Africa/Abidjan', 'BW': 'Africa/Gaborone', 'MU': 'Indian/Mauritius',
      'ZM': 'Africa/Lusaka', 'ZW': 'Africa/Harare', 'MW': 'Africa/Blantyre',
      'MZ': 'Africa/Maputo', 'AO': 'Africa/Luanda', 'CM': 'Africa/Douala',
      'DZ': 'Africa/Algiers', 'LY': 'Africa/Tripoli', 'SD': 'Africa/Khartoum',
      'CD': 'Africa/Kinshasa', 'MG': 'Indian/Antananarivo',
      
      // North America
      'US': 'America/New_York', 'CA': 'America/Toronto', 'MX': 'America/Mexico_City',
      
      // Europe
      'GB': 'Europe/London', 'DE': 'Europe/Berlin', 'FR': 'Europe/Paris',
      'ES': 'Europe/Madrid', 'IT': 'Europe/Rome', 'NL': 'Europe/Amsterdam',
      'SE': 'Europe/Stockholm', 'NO': 'Europe/Oslo', 'DK': 'Europe/Copenhagen',
      'FI': 'Europe/Helsinki', 'CH': 'Europe/Zurich', 'AT': 'Europe/Vienna',
      'BE': 'Europe/Brussels', 'IE': 'Europe/Dublin', 'PT': 'Europe/Lisbon',
      
      // Oceania
      'AU': 'Australia/Sydney', 'NZ': 'Pacific/Auckland',
    };
    
    return timezoneMap[countryCode.toUpperCase()] ?? 'UTC';
  }
  
  // =============================================================================
  // Country Information
  // =============================================================================
  
  /// Get country name from country code
  static String getCountryName(String countryCode) {
    final countryNames = {
      // African countries
      'NG': 'Nigeria', 'ZA': 'South Africa', 'EG': 'Egypt', 'KE': 'Kenya',
      'GH': 'Ghana', 'ET': 'Ethiopia', 'TN': 'Tunisia', 'MA': 'Morocco',
      'UG': 'Uganda', 'TZ': 'Tanzania', 'RW': 'Rwanda', 'SN': 'Senegal',
      'CI': 'Côte d\'Ivoire', 'BW': 'Botswana', 'MU': 'Mauritius', 'ZM': 'Zambia',
      'ZW': 'Zimbabwe', 'MW': 'Malawi', 'MZ': 'Mozambique', 'AO': 'Angola',
      'CM': 'Cameroon', 'DZ': 'Algeria', 'LY': 'Libya', 'SD': 'Sudan',
      'CD': 'Democratic Republic of Congo', 'MG': 'Madagascar',
      
      // North America
      'US': 'United States', 'CA': 'Canada', 'MX': 'Mexico',
      
      // Europe
      'GB': 'United Kingdom', 'DE': 'Germany', 'FR': 'France', 'ES': 'Spain',
      'IT': 'Italy', 'NL': 'Netherlands', 'SE': 'Sweden', 'NO': 'Norway',
      'DK': 'Denmark', 'FI': 'Finland', 'CH': 'Switzerland', 'AT': 'Austria',
      'BE': 'Belgium', 'IE': 'Ireland', 'PT': 'Portugal',
      
      // Oceania
      'AU': 'Australia', 'NZ': 'New Zealand',
    };
    
    return countryNames[countryCode.toUpperCase()] ?? 'Unknown';
  }
  
  /// Get continent for a country
  static String getContinent(String countryCode) {
    final code = countryCode.toUpperCase();
    
    if (isAfricanCountry(code)) return 'Africa';
    if (isEuropeanCountry(code)) return 'Europe';
    if (isNorthAmericanCountry(code)) return 'North America';
    if (['AU', 'NZ'].contains(code)) return 'Oceania';
    
    return 'Unknown';
  }
  
  // =============================================================================
  // Language Utilities
  // =============================================================================
  
  /// Check if country uses specific language as official language
  static bool usesLanguage(String countryCode, String languageCode) {
    final primaryLanguages = getPrimaryLanguages(countryCode);
    return primaryLanguages.contains(languageCode.toLowerCase());
  }
  
  /// Check if country uses English as official language
  static bool usesEnglish(String countryCode) => usesLanguage(countryCode, 'en');
  
  /// Check if country uses French as official language
  static bool usesFrench(String countryCode) => usesLanguage(countryCode, 'fr');
  
  /// Check if country uses Arabic as official language
  static bool usesArabic(String countryCode) => usesLanguage(countryCode, 'ar');
  
  /// Check if country uses Spanish as official language
  static bool usesSpanish(String countryCode) => usesLanguage(countryCode, 'es');
  
  // =============================================================================
  // Regional Economic Communities (for Africa)
  // =============================================================================
  
  /// Get regional economic communities for African countries
  static List<String> getRegionalCommunities(String countryCode) {
    if (!isAfricanCountry(countryCode)) return [];
    
    final communities = {
      'NG': ['ECOWAS', 'AU'], 'ZA': ['SADC', 'AU'], 'EG': ['AU', 'COMESA'],
      'KE': ['EAC', 'COMESA', 'AU'], 'GH': ['ECOWAS', 'AU'], 'ET': ['AU', 'IGAD'],
      'TN': ['AMU', 'AU'], 'MA': ['AMU', 'AU'], 'UG': ['EAC', 'AU'],
      'TZ': ['EAC', 'SADC', 'AU'], 'RW': ['EAC', 'AU'], 'SN': ['ECOWAS', 'AU'],
      'CI': ['ECOWAS', 'AU'], 'BW': ['SADC', 'AU'], 'MU': ['SADC', 'AU'],
      'ZM': ['SADC', 'COMESA', 'AU'], 'ZW': ['SADC', 'AU'], 'MW': ['SADC', 'COMESA', 'AU'],
      'MZ': ['SADC', 'AU'], 'AO': ['SADC', 'AU'], 'CM': ['CEMAC', 'AU'],
      'DZ': ['AMU', 'AU'], 'LY': ['AMU', 'AU'], 'SD': ['AU', 'IGAD'],
      'CD': ['SADC', 'CEMAC', 'AU'], 'MG': ['SADC', 'AU'],
    };
    
    return communities[countryCode.toUpperCase()] ?? ['AU'];
  }
  
  // =============================================================================
  // Economic Classification
  // =============================================================================
  
  /// Get World Bank economic classification for any country
  static String getEconomicClassification(String countryCode) {
    final classifications = {
      // African countries
      'NG': 'Lower-middle income', 'ZA': 'Upper-middle income', 'EG': 'Lower-middle income',
      'KE': 'Lower-middle income', 'GH': 'Lower-middle income', 'ET': 'Low income',
      'TN': 'Upper-middle income', 'MA': 'Lower-middle income', 'UG': 'Low income',
      'TZ': 'Lower-middle income', 'RW': 'Low income', 'SN': 'Lower-middle income',
      'CI': 'Lower-middle income', 'BW': 'Upper-middle income', 'MU': 'High income',
      'ZM': 'Lower-middle income', 'ZW': 'Lower-middle income', 'MW': 'Low income',
      'MZ': 'Low income', 'AO': 'Lower-middle income', 'CM': 'Lower-middle income',
      'DZ': 'Upper-middle income', 'LY': 'Upper-middle income', 'SD': 'Low income',
      'CD': 'Low income', 'MG': 'Low income',
      
      // Other regions
      'US': 'High income', 'CA': 'High income', 'MX': 'Upper-middle income',
      'GB': 'High income', 'DE': 'High income', 'FR': 'High income',
      'ES': 'High income', 'IT': 'High income', 'NL': 'High income',
      'SE': 'High income', 'NO': 'High income', 'DK': 'High income',
      'FI': 'High income', 'CH': 'High income', 'AT': 'High income',
      'BE': 'High income', 'IE': 'High income', 'PT': 'High income',
      'AU': 'High income', 'NZ': 'High income',
    };
    
    return classifications[countryCode.toUpperCase()] ?? 'Unknown';
  }
}