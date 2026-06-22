import '../core/constants.dart';

String _networkRoot() {
  final apiUrl = AppConstants.backendUrl;
  if (apiUrl.endsWith('/api/v2')) {
    return apiUrl.substring(0, apiUrl.length - '/api/v2'.length);
  }
  return apiUrl;
}

/// Prepends the backend root to relative asset paths. Kept for future
/// dynamic shop items served from the server (merch, physical items).
String assetUrl(String path) =>
    path.startsWith('http://') || path.startsWith('https://') ? path : '$_networkRoot()$path';

/// Items 1–21 are bundled in the APK. Future items (>21) will use [assetUrl].
String shopThumbnailUrl(int id) => 'assets/shop/thumbs/shop_$id.webp';

String shopFullUrl(int id) => 'assets/shop/full/shop_$id.webp';

List<String> taskBackgroundUrls() =>
    List.generate(12, (i) => shopFullUrl(i + 1));

List<String> scratchCardUrls() =>
    List.generate(9, (i) => shopFullUrl(13 + i));
