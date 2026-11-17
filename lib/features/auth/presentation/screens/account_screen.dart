import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iq_otomobil/core/config/app_config.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = SupabaseService.client.auth.currentSession;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: session == null
          ? _GuestView(theme: theme, context: context)
          : _LoggedInView(ref: ref, context: context),
    );
  }
}

class _GuestView extends StatelessWidget {
  final ThemeData theme;
  final BuildContext context;
  const _GuestView({required this.theme, required this.context});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 72, color: Colors.blue[300]),
              const SizedBox(height: 16),
              Text('مرحباً بك كضيف',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('سجل دخولك للوصول لجميع المزايا وإتمام الشراء',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => context.push('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تسجيل الدخول / إنشاء حساب')),
            ],
          ),
        ),
      );
}

class _LoggedInView extends ConsumerWidget {
  final WidgetRef ref;
  final BuildContext context;
  const _LoggedInView({required this.ref, required this.context});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = SupabaseService.client.auth.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    return FutureBuilder(
      future: SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.blue));
        }

        final role = snapshot.data?['role'] as String?;
        final isPromoter = role == 'promoter';
        final isAdmin = role == 'admin';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة الملف الشخصي
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: Icon(Icons.person,
                            size: 32, color: Colors.blue[300])),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              user.userMetadata?['full_name'] ??
                                  user.email ??
                                  user.phone ??
                                  'مستخدم',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                              isPromoter
                                  ? 'مروج معتمد'
                                  : isAdmin
                                      ? 'مدير النظام'
                                      : 'عضو',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isPromoter
                                    ? Colors.green
                                    : isAdmin
                                        ? Colors.blue
                                        : Colors.grey,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ✅ زر لوحة المروج (يظهر فقط للمروجين والأدمن)
            if (isPromoter || isAdmin) ...[
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: ListTile(
                  leading: Icon(Icons.dashboard, color: Colors.blue[300]),
                  title: const Text('لوحة المروج',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: const Text('إضافة منتجات ومتابعة الطلبات',
                      style: TextStyle(color: Colors.grey)),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.blue[300]),
                  onTap: () => context.push('/promoter'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ✅ زر طلباتي
            Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                  leading: Icon(Icons.shopping_bag_outlined,
                      color: Colors.green[300]),
                  title: const Text('طلباتي',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('تتبع حالة طلباتك',
                      style: TextStyle(color: Colors.grey)),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.green[300]),
                  onTap: () {
                    print('🔘 الانتقال لصفحة طلباتي');
                    context.push('/my-orders');
                  }),
            ),
            const SizedBox(height: 12),

            // ✅ زر تقييماتي - تم التعديل هنا للانتقال الفعلي للصفحة
            Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                  leading: Icon(Icons.star_outline, color: Colors.amber[300]),
                  title: const Text('تقييماتي',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('شاهد تقييماتك للمنتجات',
                      style: TextStyle(color: Colors.grey)),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.amber[300]),
                  onTap: () {
                    print('🔘 الانتقال لصفحة تقييماتي');
                    context.push('/my-reviews'); // ✅ التعديل: الانتقال الفعلي
                  }),
            ),
            const SizedBox(height: 12),

            // الدعم والمساعدة
            Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                  leading: Icon(Icons.support_agent, color: Colors.blue[300]),
                  title: const Text('الدعم والمساعدة',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('تواصل معنا واطلب الدعم',
                      style: TextStyle(color: Colors.grey)),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.blue[300]),
                  onTap: () => _openUrl(AppConfig.supportUrl)),
            ),
            const SizedBox(height: 12),

            // سياسة الخصوصية
            Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined,
                      color: Colors.green[300]),
                  title: const Text('سياسة الخصوصية',
                      style: TextStyle(color: Colors.white)),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.green[300]),
                  onTap: () => _openUrl(AppConfig.privacyPolicyUrl)),
            ),
            const SizedBox(height: 12),

            // حذف الحساب (مطلوب من آبل)
            Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('حذف الحساب',
                      style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('حذف حسابك وبياناتك نهائياً',
                      style: TextStyle(color: Colors.grey)),
                  onTap: () => _confirmDeleteAccount(context, ref)),
            ),
            const SizedBox(height: 24),

            // زر تسجيل الخروج
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(authActionProvider.notifier)
                    .logout()
                    .then((_) => context.go('/')),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('حذف الحساب نهائياً؟',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'سيتم حذف حسابك وجميع بياناتك (الطلبات والتقييمات) نهائياً ولا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // يستدعي Edge Function في Supabase تحذف المستخدم وبياناته
      await SupabaseService.client.functions.invoke('delete-account');
      await ref.read(authActionProvider.notifier).logout();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف حسابك بنجاح')),
        );
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الحساب: $e')),
        );
      }
    }
  }
}
