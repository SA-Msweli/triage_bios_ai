// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Web-specific platform implementation
class PlatformConfig {
  /// Get environment variable for web platform
  static String? getEnvironmentVariable(String key) {
    try {
      // Strategy 1: Check JavaScript global variables (injected at build time)
      final jsValue = js.context['env']?[key];
      if (jsValue != null && jsValue is String && jsValue.isNotEmpty) {
        return jsValue;
      }

      // Strategy 2: Check window object for environment variables
      final windowEnv = html.window.localStorage['env_$key'];
      if (windowEnv != null && windowEnv.isNotEmpty) {
        return windowEnv;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
