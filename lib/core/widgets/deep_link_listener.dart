import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/utils/product_deep_link.dart';

/// يستمع للروابط أثناء تشغيل التطبيق ويوجّه لصفحة المنتج.
class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _appLinks.uriLinkStream.listen(_onUri);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingLink());
  }

  void _onUri(Uri uri) {
    if (kDebugMode) {
      debugPrint('🔗 Deep link received: $uri');
    }
    _navigate(uri);
  }

  Future<void> _consumePendingLink() async {
    final pending = ProductDeepLinkBootstrap.initialProductPath;
    if (pending != null) {
      ProductDeepLinkBootstrap.clearInitial();
      widget.router.go(pending);
      return;
    }

    try {
      final latest = await _appLinks.getLatestLink();
      _navigate(latest);
    } catch (_) {}
  }

  void _navigate(Uri? uri) {
    final path = ProductDeepLink.pathFromUri(uri);
    if (path == null) return;
    widget.router.go(path);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// يُستدعى قبل runApp لالتقاط الرابط عند فتح التطبيق من رابط.
Future<void> captureInitialProductDeepLink() async {
  try {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    final latest = initial ?? await appLinks.getLatestLink();
    ProductDeepLinkBootstrap.initialProductPath =
        ProductDeepLink.pathFromUri(latest);
    if (kDebugMode && latest != null) {
      debugPrint('🔗 Initial deep link: $latest');
      debugPrint('🔗 Resolved path: ${ProductDeepLinkBootstrap.initialProductPath}');
    }
  } catch (e) {
    ProductDeepLinkBootstrap.initialProductPath = null;
    if (kDebugMode) {
      debugPrint('🔗 Deep link capture failed: $e');
    }
  }
}
