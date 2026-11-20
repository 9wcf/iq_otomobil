import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/core/routing/app_router.dart';
import 'package:iq_otomobil/core/theme/app_theme.dart';
import 'package:iq_otomobil/core/widgets/deep_link_listener.dart';

class IqOtomobilApp extends ConsumerWidget {
  const IqOtomobilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(appVariantProvider);
    final isUserApp = variant == AppVariant.user;
    final router = AppRouter.routerFor(variant);

    final app = MaterialApp.router(
      title: variant.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: isUserApp ? AppTheme.light : AppTheme.dark,
      themeMode: isUserApp ? ThemeMode.light : ThemeMode.system,
      routerConfig: router,
      builder: (_, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );

    if (!isUserApp) return app;

    return DeepLinkListener(
      router: router,
      child: app,
    );
  }
}

