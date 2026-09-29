class FeatureFlags {
  FeatureFlags._();
  // Original app me ye false tha (overlay disabled).
  // Yahan stable foreground-service overlay wapas enable hai.
  static const bool floatingOverlayEnabled = true;
  static const bool visionModeEnabled = true;
  static const bool multiProviderFallbackEnabled = true;
  static const bool confirmSensitiveActions = true;
}
