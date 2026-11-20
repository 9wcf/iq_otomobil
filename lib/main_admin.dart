import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/app.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await SupabaseService.init();

  runApp(
    ProviderScope(
      overrides: [
        appVariantProvider.overrideWithValue(AppVariant.admin),
      ],
      child: const IqOtomobilApp(),
    ),
  );
}

