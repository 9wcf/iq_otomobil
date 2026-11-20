import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/auth_provider.dart';

/// محتوى تبويب «ملفي» للمروج (بدون Scaffold — يُستخدم داخل [PromoterMainScreen]).
class PromoterProfileBody extends ConsumerStatefulWidget {
  const PromoterProfileBody({super.key});

  @override
  ConsumerState<PromoterProfileBody> createState() => _PromoterProfileBodyState();
}

class _PromoterProfileBodyState extends ConsumerState<PromoterProfileBody> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('full_name, phone, role, merchant_status, account_status')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = row;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authActionProvider.notifier).logout();
    if (!mounted) return;
    context.go('/auth');
  }

  Future<void> _deleteAccount() async {
    final auth = SupabaseService.currentUserInfo;
    final phone = (_profile?['phone']?.toString().trim().isNotEmpty == true)
        ? _profile!['phone'].toString().trim()
        : (auth?.phone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ لا يوجد رقم هاتف مرتبط بالحساب'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيتم حذف حساب التاجر نهائياً بعد إدخال رمز التحقق.\nلا يمكن التراجع.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(authActionProvider.notifier).requestOtp(
          phone: phone,
          intent: OtpIntent.accountDeletion,
        );
    if (!mounted) return;

    final codeCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رمز التحقق المرسل إلى رقمك.'),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رمز التحقق',
                prefixIcon: Icon(Icons.sms_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (submitted != true) return;

    await ref.read(authActionProvider.notifier).verifyOtp(
          phone: phone,
          token: codeCtrl.text.trim(),
          intent: OtpIntent.accountDeletion,
        );
    if (!mounted) return;

    final st = ref.read(authActionProvider);
    if (st is AsyncData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حذف الحساب'), backgroundColor: Colors.green),
      );
      context.go('/auth');
    } else if (st is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${st.error}'), backgroundColor: Colors.red),
      );
    }
  }

  String _statusLabel({
    required String role,
    required String merchantStatus,
    required String accountStatus,
  }) {
    final r = role.trim();
    if (r != 'promoter' && r != 'admin') {
      return switch (merchantStatus) {
        'pending' => 'طلب ترقية قيد المراجعة',
        'rejected' => 'تم رفض طلب الترقية',
        'approved' => 'تمت الموافقة على الترقية',
        _ => 'غير مرقّى كتاجر',
      };
    }
    return switch (accountStatus) {
      'approved' => 'معتمد',
      'pending' => 'قيد مراجعة الإدارة',
      'rejected' => 'مرفوض',
      _ => accountStatus.isEmpty ? '—' : accountStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = SupabaseService.currentUserInfo;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      );
    }

    final name = _profile?['full_name']?.toString().trim();
    final phone = _profile?['phone']?.toString().trim() ??
        auth?.phone?.trim() ??
        '';
    final role = _profile?['role']?.toString() ?? 'user';
    final merchantStatus = _profile?['merchant_status']?.toString() ?? 'none';
    final accountStatus = _profile?['account_status']?.toString() ?? 'approved';

    return RefreshIndicator(
      color: Colors.lightBlueAccent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.amber.shade700,
            child: Text(
              (name != null && name.isNotEmpty)
                  ? name[0].toUpperCase()
                  : (phone.isNotEmpty ? phone[0] : 'م'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            (name != null && name.isNotEmpty) ? name : 'تاجر',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              phone,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.blue[300]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حالة الحساب',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusLabel(
                          role: role,
                          merchantStatus: merchantStatus,
                          accountStatus: accountStatus,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              'حذف الحساب نهائياً',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
