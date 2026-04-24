import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // ⚠️ ضع قيمك الحقيقية هنا من Supabase Dashboard → Settings → API
  static const _url = 'https://hnndxfgfvrwfccxeywel.supabase.co';
  static const _anonKey = 'sb_publishable_ndCQT5KbYXWTpoT2uSCcsw_9X_nEm-h';

  static Future<void> init() async {
    // تحذير في وضع التطوير إذا نسيت تغيير المفاتيح
    if (kDebugMode &&
        (_url.contains('YOUR_PROJECT') || _anonKey.contains('YOUR_ANON'))) {
      debugPrint(
          '⚠️ تنبيه: مفاتيح Supabase لم يتم ضبطها. اذهب إلى supabase_service.dart وأدخل الرابط والمفتاح.');
    }

    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
      debug: kDebugMode,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
