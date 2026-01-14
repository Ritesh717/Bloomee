/// Environment configuration for Bloomee
/// Use these constants to toggle features and experimental UI

class AppConfig {
  // Feature Flags
  // TEMPORARY: Hardcoded to true to enable new player
  // TODO: Revert to bool.fromEnvironment after testing
  static final bool useNewPlayerUI = true;

  static const bool enableDebugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: false,
  );

  static const bool enableExperimentalFeatures = bool.fromEnvironment(
    'EXPERIMENTAL_FEATURES',
    defaultValue: false,
  );

  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.bloomee.app',
  );

  // Logging
  static void log(String message) {
    if (enableDebugMode) {
      // ignore: avoid_print
      print('[AppConfig] $message');
    }
  }
}
