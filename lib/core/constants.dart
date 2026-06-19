class AppConstants {
  static const String _override = String.fromEnvironment('BACKEND_BASE_URL');

  static String get backendUrl =>
    _override.isNotEmpty ? _override : 'https://meowmin-backend.onrender.com/api/v2';
}
