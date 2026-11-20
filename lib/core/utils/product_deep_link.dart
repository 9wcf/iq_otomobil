import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/config/product_share_config.dart';

/// يحوّل الروابط الواردة (HTTPS أو iqotomobil://) إلى مسار go_router.
abstract final class ProductDeepLink {
  static String? pathFromUri(Uri? uri) {
    if (uri == null) return null;

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (!ProductShareConfig.acceptedHttpsHosts.contains(uri.host)) {
        return null;
      }
      return _pathFromHttps(uri);
    }

    if (uri.scheme == ProductShareConfig.customScheme &&
        uri.host == 'product') {
      final id = _firstPathSegment(uri);
      if (id == null || id.isEmpty) return null;
      return '/product/${Uri.decodeComponent(id)}';
    }

    return null;
  }

  /// يحوّل موقع go_router (قد يكون iqotomobil://...) إلى مسار داخلي.
  static String? pathFromRouterState(GoRouterState state) {
    final fromUri = pathFromUri(state.uri);
    if (fromUri != null) return fromUri;

    final location = state.matchedLocation.trim();
    if (location.contains('://')) {
      return pathFromUri(Uri.tryParse(location));
    }
    if (location.startsWith('/product/')) return location;

    final full = state.uri.toString();
    if (full.contains('://')) {
      return pathFromUri(Uri.tryParse(full));
    }
    return null;
  }

  static String? _pathFromHttps(Uri uri) {
    // Storage أو Edge Function: ...product-share...?id=UUID
    if (uri.path.contains('product-share')) {
      final queryId = uri.queryParameters['id']?.trim();
      if (queryId != null && queryId.isNotEmpty) {
        return '/product/${Uri.decodeComponent(queryId)}';
      }
    }

    // دومين مخصص: .../product/UUID
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first == 'product') {
      final id = Uri.decodeComponent(segments[1]);
      if (id.isNotEmpty) return '/product/$id';
    }

    final legacyQueryId = uri.queryParameters['id']?.trim();
    if (legacyQueryId != null && legacyQueryId.isNotEmpty) {
      return '/product/$legacyQueryId';
    }

    return null;
  }

  static String? _firstPathSegment(Uri uri) {
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final raw = uri.path.replaceFirst('/', '').trim();
    return raw.isEmpty ? null : raw;
  }
}

/// يحتفظ برابط المنتج عند فتح التطبيق من رابط خارجي.
abstract final class ProductDeepLinkBootstrap {
  static String? initialProductPath;

  static void clearInitial() => initialProductPath = null;
}
