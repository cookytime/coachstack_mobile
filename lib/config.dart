class Config {
  // Android emulator uses 10.0.2.2 to reach your host machine.
  // If testing on a physical device, use your LAN IP (e.g. http://192.168.1.12:8787)
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://coachstackapi.glencook.tech',
  );
}