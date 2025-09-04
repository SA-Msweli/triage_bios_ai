import 'dart:io';

/// Mobile/Desktop-specific platform implementation
class PlatformConfig {
  /// Get environment variable for mobile/desktop platforms
  static String? getEnvironmentVariable(String key) {
    try {
      // Use Platform.environment for mobile/desktop
      return Platform.environment[key];
    } catch (e) {
      return null;
    }
  }
}
