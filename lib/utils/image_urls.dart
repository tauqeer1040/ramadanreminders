import '../core/constants.dart';

String get _baseRoot {
  final apiUrl = AppConstants.backendUrl;
  if (apiUrl.endsWith('/api/v2')) {
    return apiUrl.substring(0, apiUrl.length - '/api/v2'.length);
  }
  return apiUrl;
}

String assetUrl(String path) =>
    path.startsWith('http://') || path.startsWith('https://') ? path : '$_baseRoot$path';

String shopThumbnailUrl(int id) => assetUrl('/assets/shop/thumbs/shop_$id.webp');
String shopFullUrl(int id) => assetUrl('/assets/shop/full/shop_$id.webp');

List<String> taskBackgroundUrls() =>
    List.generate(12, (i) => shopFullUrl(i + 1));

List<String> scratchCardUrls() =>
    List.generate(9, (i) => shopFullUrl(13 + i));
