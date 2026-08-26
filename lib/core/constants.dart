class AppConstants {
  static const String _override = String.fromEnvironment('BACKEND_BASE_URL');

  static String get backendUrl =>
    _override.isNotEmpty ? _override : 'https://meowmin.taucity.xyz/api/v2';

  static const String webAppUrl = 'https://meowmin.taucity.xyz/app/';
}
