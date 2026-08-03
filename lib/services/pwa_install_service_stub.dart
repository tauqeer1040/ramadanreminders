/// Native (non-web) no-op implementation of the PWA install service.
class PwaInstallService {
  static void init() {}

  static bool get canInstall => false;

  static bool get isStandalone => false;

  static Future<bool> promptInstall() async => false;
}
