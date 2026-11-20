import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';

/// ظل بطاقات تدفق المستخدم (سلة، طلب، طلباتي) — متوافق مع تفاصيل المنتج.
const Color kUserFlowCardShadow = Color(0x14134A8A);

/// ارتفاع الشريط السفلي العائم (بدون safe area النظام).
const double kUserShellNavOverlayHeight = 86;

/// مسافة الشريط السفلي + safe area — لأشرطة الإجراء الثابتة (سلة، إلخ).
double userShellNavOverlayPadding(BuildContext context) {
  return kUserShellNavOverlayHeight + MediaQuery.viewPaddingOf(context).bottom;
}

/// حشوة أسفل قوائم التمرير حتى يمر المحتوى خلف الشريط دون أن يُحجب آخر عنصر.
double userShellScrollBottomPadding(BuildContext context) {
  return userShellNavOverlayPadding(context) + 12;
}

/// حشوة أسفل قوائم التمرير عند إخفاء الشريط السفلي (سلة، طلباتي).
double userFlowScreenScrollBottomPadding(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).bottom + 16;
}

BoxDecoration userFlowCardDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? AppColors.card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
    boxShadow: const [
      BoxShadow(
        color: kUserFlowCardShadow,
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
  );
}

/// شريط علوي موحّد لصفحات السلة والطلب وطلباتي.
class UserFlowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const UserFlowAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  static void navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(0, initialLocation: true);
      return;
    }
    context.go('/');
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leading: showBack
          ? IconButton(
              tooltip: 'رجوع',
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
              onPressed: onBack ?? () => navigateBack(context),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      actions: actions,
    );
  }
}

/// بطاقة قسم بعنوان وأيقونة (ملخص الطلب، معلومات التوصيل).
class UserFlowSectionCard extends StatelessWidget {
  const UserFlowSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: userFlowCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// شريط سفلي: مجموع + زر إجراء.
class UserFlowSummaryBar extends StatelessWidget {
  const UserFlowSummaryBar({
    super.key,
    required this.totalLabel,
    required this.totalValue,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.shopping_bag_outlined,
  });

  final String totalLabel;
  final String totalValue;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: kUserFlowCardShadow.withValues(alpha: 0.85),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                totalLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                totalValue,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: loading ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, size: 20),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة فارغة موحّدة.
class UserFlowEmptyState extends StatelessWidget {
  const UserFlowEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.search_rounded, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شارة حالة الطلب.
class UserOrderStatusChip extends StatelessWidget {
  const UserOrderStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
