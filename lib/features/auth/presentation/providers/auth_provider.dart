import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// رُمي بعد تسجيل تاجر جديد (حساب قيد المراجعة) — الواجهة تعرضه كنجاح لا كخطأ.
class PendingMerchantSignup implements Exception {
  PendingMerchantSignup(
      [this.message = 'تم التسجيل. حسابك قيد مراجعة الإدارة.']);
  final String message;
  @override
  String toString() => message;
}

class MerchantPendingApproval implements Exception {
  MerchantPendingApproval(
      [this.message = 'حسابك قيد المراجعة وبانتظار موافقة الإدارة.']);
  final String message;
  @override
  String toString() => message;
}

class MerchantRejected implements Exception {
  MerchantRejected([this.message = 'تم رفض حسابك. تواصل مع الإدارة.']);
  final String message;
  @override
  String toString() => message;
}

class MerchantUpgradeRequired implements Exception {
  MerchantUpgradeRequired(
      [this.message = 'حسابك غير مرقّى كتاجر بعد. أرسل طلب ترقية للإدارة.']);
  final String message;
  @override
  String toString() => message;
}

class OtpResendCooldownException implements Exception {
  OtpResendCooldownException(this.remaining);
  final Duration remaining;

  @override
  String toString() => 'OTP resend blocked for ${remaining.inSeconds}s';
}

/// تسجيل جديد (OTP + كلمة مرور) مقابل استعادة كلمة المرور أو حذف الحساب.
enum OtpIntent { registration, passwordRecovery, accountDeletion }

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authSessionProvider =
    StreamProvider((ref) => SupabaseService.authStateChanges);

class AuthRepository {
  final _client = SupabaseService.client;

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    return _client.from('profiles').select().eq('id', uid).maybeSingle();
  }

  Future<String?> getRoleByUid(String uid) async {
    final profile = await getProfile(uid);
    final r = profile?['role']?.toString().trim();
    if (r == null || r.isEmpty) return null;
    return r;
  }

  Future<void> upsertProfile({
    required String uid,
    required String phone,
    String? fullName,
    String? role,
    String? accountStatus,
    String? merchantStatus,
  }) async {
    final fn = fullName?.trim();
    await _client.from('profiles').upsert(
      {
        'id': uid,
        'phone': phone,
        if (role != null) 'role': role,
        if (fn != null && fn.isNotEmpty) 'full_name': fn,
        if (accountStatus != null) 'account_status': accountStatus,
        if (merchantStatus != null) 'merchant_status': merchantStatus,
      },
      onConflict: 'id',
    );
  }

  Future<String> requestMerchantUpgrade(String uid, {String? fullName}) async {
    final fn = fullName?.trim();
    await _client.from('profiles').update({
      'merchant_status': 'pending',
      if (fn != null && fn.isNotEmpty) 'full_name': fn,
    }).eq('id', uid);
    return 'pending';
  }
}

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final AuthRepository _repo;
  static const Duration _otpResendCooldown = Duration(minutes: 10);

  AuthNotifier({required this.ref, required AuthRepository repo})
      : _repo = repo,
        super(const AsyncData(null));

  Future<String?> _getRole({required String uid}) => _repo.getRoleByUid(uid);

  bool _isRoleAllowed({required AppVariant variant, required String? role}) {
    final r = (role ?? 'user').trim();
    return switch (variant) {
      AppVariant.admin => r == 'admin',
      AppVariant.promoter => r == 'user' || r == 'promoter' || r == 'admin',
      AppVariant.user => r == 'user' || r == 'promoter' || r == 'admin',
    };
  }

  String _cooldownKey({
    required String phone,
    required OtpIntent intent,
  }) {
    final normalizedPhone = phone.replaceAll(RegExp(r'\s+|-'), '').trim();
    return 'otp_cooldown_${intent.name}_$normalizedPhone';
  }

  Future<void> _ensureCooldownAllowed({
    required String phone,
    required OtpIntent intent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cooldownKey(phone: phone, intent: intent);
    final lastSentMs = prefs.getInt(key);
    if (lastSentMs == null) return;

    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSentMs),
    );
    final remaining = _otpResendCooldown - elapsed;
    if (remaining.inSeconds > 0) {
      throw OtpResendCooldownException(remaining);
    }
  }

  Future<void> _rememberOtpSentAt({
    required String phone,
    required OtpIntent intent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cooldownKey(phone: phone, intent: intent);
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _guardMerchantApproval(String uid) async {
    final variant = ref.read(appVariantProvider);
    if (variant != AppVariant.promoter) return;

    final profile = await _repo.getProfile(uid);
    final role = (profile?['role'] as String? ?? 'user').trim();
    final merchantStatus =
        (profile?['merchant_status'] as String? ?? 'none').trim();

    if (role != 'promoter' && role != 'admin') {
      if (merchantStatus == 'pending') throw MerchantPendingApproval();
      if (merchantStatus == 'rejected') throw MerchantRejected();
      throw MerchantUpgradeRequired();
    }

    if (role == 'promoter' && merchantStatus != 'approved') {
      if (merchantStatus == 'pending') throw MerchantPendingApproval();
      if (merchantStatus == 'rejected') throw MerchantRejected();
      throw MerchantPendingApproval(
          'حساب التاجر غير مُعتمد بعد. بانتظار موافقة الإدارة.');
    }

    final status = (profile?['account_status'] as String? ?? 'approved').trim();
    if (status == 'pending') throw MerchantPendingApproval();
    if (status == 'rejected') throw MerchantRejected();
  }

  Future<void> loginWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await SupabaseService.client.auth.signInWithPassword(
        phone: phone,
        password: password,
      );

      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) throw StateError('فشل تسجيل الدخول');

      final variant = ref.read(appVariantProvider);
      final existing = await _repo.getProfile(uid);
      final metaName = SupabaseService
          .client.auth.currentUser?.userMetadata?['full_name']
          ?.toString()
          .trim();

      final existingRole = existing?['role']?.toString().trim();
      final existingName = existing?['full_name']?.toString().trim();
      if (existing == null || existingRole == null || existingRole.isEmpty) {
        await _repo.upsertProfile(
          uid: uid,
          phone: phone,
          role: 'user',
          merchantStatus: existing?['merchant_status']?.toString() ?? 'none',
          fullName: metaName,
        );
      } else {
        await _repo.upsertProfile(
          uid: uid,
          phone: phone,
          fullName:
              (existingName == null || existingName.isEmpty) ? metaName : null,
        );
      }

      final role = await _getRole(uid: uid);
      if (!_isRoleAllowed(variant: variant, role: role)) {
        await SupabaseService.signOutAll();
        throw StateError('هذا الحساب غير مخوّل للدخول لهذا التطبيق');
      }

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> requestUpgradeToMerchant({String? fullName}) async {
    state = const AsyncLoading();
    try {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) throw StateError('سجل الدخول أولاً');
      await _repo.requestMerchantUpgrade(uid, fullName: fullName);
      state = AsyncError(MerchantPendingApproval(), StackTrace.current);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> requestOtp({
    required String phone,
    String? fullName,
    required OtpIntent intent,
  }) async {
    state = const AsyncLoading();
    try {
      if (intent == OtpIntent.registration ||
          intent == OtpIntent.passwordRecovery) {
        await _ensureCooldownAllowed(phone: phone, intent: intent);
      }

      if (intent == OtpIntent.accountDeletion) {
        await SupabaseService.client.auth.signInWithOtp(phone: phone);
        state = const AsyncData(null);
        return;
      }

      final variant = ref.read(appVariantProvider);
      if (intent == OtpIntent.registration && variant == AppVariant.admin) {
        throw StateError('التسجيل برقم الهاتف غير متاح من تطبيق الإدارة');
      }

      await SupabaseService.client.auth.signInWithOtp(phone: phone);

      if (intent == OtpIntent.registration ||
          intent == OtpIntent.passwordRecovery) {
        await _rememberOtpSentAt(phone: phone, intent: intent);
      }

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String token,
    required OtpIntent intent,
    String? fullName,
    String? newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      final variant = ref.read(appVariantProvider);

      await SupabaseService.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      final sessionUid = SupabaseService.client.auth.currentUser?.id;
      if (sessionUid == null) {
        throw StateError('فشل تسجيل الدخول');
      }
      final uid = sessionUid;

      if (newPassword != null && newPassword.isNotEmpty) {
        await SupabaseService.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      }

      final authUser = SupabaseService.client.auth.currentUser;
      final phoneForProfile =
          (authUser?.phone != null && authUser!.phone!.trim().isNotEmpty)
              ? authUser.phone!.trim()
              : phone.trim();

      if (intent == OtpIntent.accountDeletion) {
        try {
          await SupabaseService.client.functions.invoke('delete-account');
        } on FunctionException catch (e) {
          final msg = e.toString();
          if (msg.toLowerCase().contains('not found') ||
              msg.toLowerCase().contains('404')) {
            throw StateError(
              'ميزة حذف الحساب غير مفعلة على الخادم بعد.\n'
              'قم بنشر Edge Function: `delete-account` ثم أعد المحاولة.',
            );
          }
          rethrow;
        }
        await SupabaseService.signOutAll();
        state = const AsyncData(null);
        return;
      }

      if (intent == OtpIntent.passwordRecovery) {
        if (newPassword == null || newPassword.isEmpty) {
          await SupabaseService.signOutAll();
          throw StateError('أدخل كلمة المرور الجديدة');
        }
        await _repo.upsertProfile(uid: uid, phone: phoneForProfile);
        await _guardMerchantApproval(uid);
        final role = await _getRole(uid: uid);
        if (!_isRoleAllowed(variant: variant, role: role)) {
          await SupabaseService.signOutAll();
          throw StateError('هذا الحساب غير مخوّل للدخول لهذا التطبيق');
        }
        state = const AsyncData(null);
        return;
      }

      if (variant == AppVariant.admin) {
        await SupabaseService.signOutAll();
        throw StateError('التسجيل غير مدعوم من تطبيق الإدارة');
      }

      const intendedRole = 'user';

      if (newPassword == null || newPassword.isEmpty) {
        await SupabaseService.signOutAll();
        throw StateError('أدخل كلمة المرور');
      }

      final existing = await _repo.getProfile(uid);
      if (existing != null) {
        final hasPhone =
            (existing['phone']?.toString().trim().isNotEmpty == true);
        if (hasPhone) {
          await SupabaseService.signOutAll();
          throw StateError('هذا الرقم مسجّل مسبقاً. استخدم «تسجيل الدخول».');
        }
      }

      final allowName =
          variant == AppVariant.user || variant == AppVariant.promoter;

      final fn = fullName?.trim();
      final merchantStatus =
          variant == AppVariant.promoter ? 'pending' : 'none';

      await _repo.upsertProfile(
        uid: uid,
        phone: phoneForProfile,
        fullName: allowName ? fn : null,
        role: intendedRole,
        merchantStatus: merchantStatus,
      );

      final role = await _getRole(uid: uid);
      if (!_isRoleAllowed(variant: variant, role: role)) {
        await SupabaseService.signOutAll();
        throw StateError('هذا الحساب غير مخوّل للدخول لهذا التطبيق');
      }

      if (variant == AppVariant.promoter && merchantStatus == 'pending') {
        await SupabaseService.signOutAll();
        throw PendingMerchantSignup();
      }

      await _guardMerchantApproval(uid);

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    try {
      await SupabaseService.signOutAll();
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> loginAdminEmailPassword({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final variant = ref.read(appVariantProvider);
      if (variant != AppVariant.admin) {
        throw StateError('هذه الطريقة مخصصة لتطبيق الأدمن');
      }

      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final uid = SupabaseService.currentUserId;
      if (uid == null) throw StateError('فشل تسجيل الدخول');

      final role = await _getRole(uid: uid);
      if (role != 'admin') {
        await SupabaseService.signOutAll();
        throw StateError('هذا الحساب ليس حساب مدير');
      }

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final authActionProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(ref: ref, repo: ref.watch(authRepositoryProvider)),
);
