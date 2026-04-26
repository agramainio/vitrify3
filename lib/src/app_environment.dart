enum VitrifyEnvironment {
  demo,
  emulator,
  staging,
  production;

  static VitrifyEnvironment fromBuildConfig() {
    const value = String.fromEnvironment('VITRIFY_ENV', defaultValue: 'demo');
    return fromString(value);
  }

  static VitrifyEnvironment fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'emulator':
        return VitrifyEnvironment.emulator;
      case 'staging':
        return VitrifyEnvironment.staging;
      case 'production':
      case 'prod':
        return VitrifyEnvironment.production;
      case 'demo':
      default:
        return VitrifyEnvironment.demo;
    }
  }

  bool get usesFirebase => this != VitrifyEnvironment.demo;
}
