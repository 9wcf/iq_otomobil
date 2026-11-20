import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/app.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/widgets/deep_link_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await SupabaseService.init();
  await captureInitialProductDeepLink();

  runApp(
    ProviderScope(
      overrides: [
        appVariantProvider.overrideWithValue(AppVariant.user),
      ],
      child: const IqOtomobilApp(),
    ),
  );
}

