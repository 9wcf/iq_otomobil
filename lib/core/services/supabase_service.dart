import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// معلومات المستخدم الحالية
class AuthUserInfo {
  const AuthUserInfo({
    required this.id,
    this.phone,
    this.email,
  });

  final String id;
  final String? phone;
  final String? email;
}

class SupabaseService {
  // ⚠️ ضع قيمك الحقيقية هنا من Supabase Dashboard → Settings → API
  static const _url = 'https://hnndxfgfvrwfccxeywel.supabase.co';
  static const _anonKey = 'sb_publishable_ndCQT5KbYXWTpoT2uSCcsw_9X_nEm-h';

  static Future<void> _warnIfPlaceholderKeys() async {
    if (kDebugMode &&
        (_url.contains('YOUR_PROJECT') || _anonKey.contains('YOUR_ANON'))) {
      debugPrint(
          '⚠️ تنبيه: مفاتيح Supabase لم يتم ضبطها. اذهب إلى supabase_service.dart وأدخل الرابط والمفتاح.');
    }
  }

  /// تهيئة Supabase — OTP بالهاتف أو إيميل + كلمة مرور
  static Future<void> init() async {
    await _warnIfPlaceholderKeys();

    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
      debug: kDebugMode,
    );
  }

  /// اسم قديم للتوافق مع نقاط الدخول الحالية
  static Future<void> initUserPhoneOtp() => init();

  static SupabaseClient get client => Supabase.instance.client;

  static String get projectUrl => _url;

  static String? get currentUserId => client.auth.currentUser?.id;

  static AuthUserInfo? get currentUserInfo {
    final u = client.auth.currentUser;
    if (u == null) return null;
    return AuthUserInfo(id: u.id, phone: u.phone, email: u.email);
  }

  static bool get isLoggedIn => currentUserId != null;

  static Stream<void> get authStateChanges =>
      client.auth.onAuthStateChange.map((_) {});

  static Future<void> signOutAll() => client.auth.signOut();
}
