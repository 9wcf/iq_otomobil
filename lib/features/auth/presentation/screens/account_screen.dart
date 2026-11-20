import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/widgets/user_flow_ui.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/auth_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:iq_otomobil/core/utils/support_whatsapp.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(appVariantProvider);
    final loggedIn = SupabaseService.isLoggedIn;

    if (!loggedIn) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const UserFlowAppBar(title: 'حسابي'),
      body: _LoggedInView(ref: ref, context: context, variant: variant),
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final WidgetRef ref;
  final BuildContext context;
  final AppVariant variant;

  const _LoggedInView({
    required this.ref,
    required this.context,
    required this.variant,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = SupabaseService.currentUserInfo;

    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return FutureBuilder(
      future: SupabaseService.client
          .from('profiles')
          .select('role, full_name, phone')
          .eq('id', user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final profile = snapshot.data;
        final role = profile?['role'] as String?;
        final profileName = profile?['full_name'] as String?;
        final profilePhone = profile?['phone'] as String?;
        final displayName = (profileName != null && profileName.trim().isNotEmpty)
            ? profileName.trim()
            : (profilePhone != null && profilePhone.trim().isNotEmpty)
                ? profilePhone.trim()
                : (user.phone != null && user.phone!.trim().isNotEmpty)
                    ? user.phone!.trim()
                    : (user.email != null && user.email!.trim().isNotEmpty)
                        ? user.email!.trim()
                        : 'مستخدم';
        final isPromoter = role == 'promoter';
        final isAdmin = role == 'admin';

        Future<void> startDeleteFlow() async {
          final phone = (profilePhone != null && profilePhone.trim().isNotEmpty)
              ? profilePhone.trim()
              : (user.phone ?? '').trim();
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
                'سيتم حذف الحساب نهائياً من النظام بعد إدخال رمز التحقق.\nلا يمكن التراجع.',
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
          if (!context.mounted) return;

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
          if (!context.mounted) return;

          final st = ref.read(authActionProvider);
          if (st is AsyncData) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ تم حذف الحساب'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/auth');
          } else if (st is AsyncError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ ${st.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        Future<void> contactSupportViaWhatsApp() async {
          await openSupportWhatsApp(
            context: context,
            message: 'مرحبا، أحتاج دعم بخصوص تطبيق IQ OTOMOBIL',
            includeUserPhoneInMessage: true,
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            userShellScrollBottomPadding(context),
          ),
          children: [
            _ProfileCard(
              displayName: displayName,
              isPromoter: isPromoter,
              isAdmin: isAdmin,
            ),
            if (variant != AppVariant.user && (isPromoter || isAdmin)) ...[
              const SizedBox(height: 16),
              _PressableCard(
                onTap: () => context.push('/promoter'),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _IconTile(
                      icon: Icons.dashboard_rounded,
                      color: AppColors.primary,
                      background: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة المروج',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'إضافة منتجات ومتابعة الطلبات',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SupportCard(onWhatsApp: contactSupportViaWhatsApp),
            if (variant == AppVariant.user) ...[
              const SizedBox(height: 16),
              const _AppVersionCard(),
            ],
            const SizedBox(height: 28),
            _AccountOutlinedButton(
              label: 'تسجيل الخروج',
              icon: Icons.logout_rounded,
              foreground: AppColors.primary,
              border: AppColors.border,
              onPressed: () => ref
                  .read(authActionProvider.notifier)
                  .logout()
                  .then((_) => context.go('/')),
            ),
            const SizedBox(height: 14),
            _AccountOutlinedButton(
              label: 'حذف الحساب نهائياً',
              icon: Icons.delete_forever_outlined,
              foreground: const Color(0xFFDC4B4B),
              border: const Color(0xFFF5B4B4),
              background: const Color(0xFFFFF5F5),
              onPressed: startDeleteFlow,
            ),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.isPromoter,
    required this.isAdmin,
  });

  final String displayName;
  final bool isPromoter;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final roleLabel = isPromoter
        ? 'مروج معتمد'
        : isAdmin
            ? 'مدير النظام'
            : 'عضو';
    final roleColor = isPromoter
        ? AppColors.success
        : isAdmin
            ? AppColors.primary
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: userFlowCardDecoration().copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  const Color(0xFF7EB8FF).withValues(alpha: 0.28),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.inputFill,
                  child: Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: AppColors.primary.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: roleColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPromoter)
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: roleColor,
                        ),
                      if (isPromoter) const SizedBox(width: 5),
                      Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onWhatsApp});

  final VoidCallback onWhatsApp;

  static const _whatsappGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: userFlowCardDecoration().copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              _IconTile(
                icon: Icons.support_agent_rounded,
                color: _whatsappGreen,
                background: _whatsappGreen.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الدعم',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'واتساب الإدارة: ${SupportContact.display}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _WhatsAppButton(onPressed: onWhatsApp),
        ],
      ),
    );
  }
}

class _WhatsAppButton extends StatefulWidget {
  const _WhatsAppButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<_WhatsAppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFF22C55E).withValues(alpha: 0.12),
            highlightColor: const Color(0xFF22C55E).withValues(alpha: 0.06),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF22C55E).withValues(alpha: _pressed ? 0.88 : 1),
                    const Color(0xFF16A34A).withValues(alpha: _pressed ? 0.88 : 1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.28),
                    blurRadius: _pressed ? 8 : 14,
                    offset: Offset(0, _pressed ? 2 : 6),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'تواصل معنا عبر واتساب',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData
            ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
            : '...';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: userFlowCardDecoration().copyWith(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إصدار التطبيق',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      version,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountOutlinedButton extends StatefulWidget {
  const _AccountOutlinedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.foreground,
    required this.border,
    this.background = Colors.white,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color foreground;
  final Color border;
  final Color background;

  @override
  State<_AccountOutlinedButton> createState() => _AccountOutlinedButtonState();
}

class _AccountOutlinedButtonState extends State<_AccountOutlinedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, size: 20, color: widget.foreground),
            label: Text(
              widget.label,
              style: TextStyle(
                color: widget.foreground,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: widget.background,
              side: BorderSide(color: widget.border, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.988 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(22),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: Ink(
              decoration: userFlowCardDecoration().copyWith(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: kUserFlowCardShadow.withValues(alpha: _pressed ? 0.5 : 1),
                    blurRadius: _pressed ? 10 : 16,
                    offset: Offset(0, _pressed ? 3 : 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
