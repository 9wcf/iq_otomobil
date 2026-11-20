import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/theme/user_ui_assets.dart';
import 'package:iq_otomobil/core/widgets/count_badge.dart';
import 'package:iq_otomobil/features/cart/presentation/providers/cart_provider.dart';
import 'package:iq_otomobil/features/catalog/presentation/widgets/user_product_list_tile.dart';

/// هيكل التبويبات الرئيسية — يزامن الشريط السفلي مع المسار الحالي.
class UserMainShell extends ConsumerStatefulWidget {
  const UserMainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// يُستخدم من redirect أو تنقل خارجي لمعرفة تبويب الشريط من المسار.
  static int? tabIndexForLocation(String location) {
    if (location.startsWith('/cart') || location.startsWith('/checkout')) {
      return 1;
    }
    if (location.startsWith('/my-orders') || location.startsWith('/track/')) {
      return 2;
    }
    if (location.startsWith('/plates')) return 3;
    if (location.startsWith('/account')) return 4;
    if (location == '/' ||
        location.startsWith('/search') ||
        location.startsWith('/category/') ||
        location.startsWith('/product/') ||
        location.startsWith('/favorites')) {
      return 0;
    }
    return null;
  }

  @override
  ConsumerState<UserMainShell> createState() => _UserMainShellState();
}

class _UserMainShellState extends ConsumerState<UserMainShell> {
  String? _cartUid;

  @override
  void initState() {
    super.initState();
    _cartUid = SupabaseService.currentUserId;
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(cartCountNotifierProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = SupabaseService.currentUserId;
    if (_cartUid != currentUid) {
      _cartUid = currentUid;
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(cartCountNotifierProvider.notifier).reload();
      });
    }

    final cartCount = ref.watch(cartCountNotifierProvider);
    final selectedIndex = widget.navigationShell.currentIndex;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // سلة الطلبات وطلباتي: شاشة مركّزة بدون شريط سفلي.
    final showBottomNav = selectedIndex != 1 && selectedIndex != 2;

    return Scaffold(
      extendBody: showBottomNav,
      backgroundColor: kProductListBackground,
      body: Builder(
        builder: (context) {
          if (!showBottomNav) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                widget.navigationShell.goBranch(0, initialLocation: true);
              },
              child: widget.navigationShell,
            );
          }
          // إزالة الحشوة التي يضيفها Scaffold مع extendBody — ListView يضيفها تلقائياً
          // فيظهر المحتوى فوق الشريط بدل أن يمر خلفه.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(
                bottom: mq.viewPadding.bottom,
              ),
            ),
            child: widget.navigationShell,
          );
        },
      ),
      bottomNavigationBar: showBottomNav
          ? Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Row(
                        children: [
                          _NavItem(
                            selected: selectedIndex == 0,
                            label: 'الرئيسية',
                            onTap: () => _onSelect(0),
                            icon: _navBarIcon(UserUiAssets.navHome,
                                selected: selectedIndex == 0),
                          ),
                          _NavItem(
                            selected: selectedIndex == 1,
                            label: 'سلة الطلبات',
                            onTap: () => _onSelect(1),
                            icon: _NavCartIcon(
                                count: cartCount, selected: selectedIndex == 1),
                          ),
                          _NavItem(
                            selected: selectedIndex == 2,
                            label: 'طلباتي',
                            onTap: () => _onSelect(2),
                            icon: _navBarIcon(UserUiAssets.navOrders,
                                selected: selectedIndex == 2),
                          ),
                          _NavItem(
                            selected: selectedIndex == 3,
                            label: 'لوحات',
                            onTap: () => _onSelect(3),
                            icon: _navBarIcon(UserUiAssets.navPlates,
                                selected: selectedIndex == 3),
                          ),
                          _NavItem(
                            selected: selectedIndex == 4,
                            label: 'حسابي',
                            onTap: () => _onSelect(4),
                            icon: _navBarIcon(UserUiAssets.navProfile,
                                selected: selectedIndex == 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _onSelect(int index) {
    if (index == 4 && !SupabaseService.isLoggedIn) {
      context.push('/auth');
      return;
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.icon,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget icon;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  static const _activeBlue = Color(0xFF4F7CFF);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: _activeBlue.withValues(alpha: 0.12),
              highlightColor: _activeBlue.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.selected ? 14 : 10,
                        vertical: widget.selected ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.selected
                            ? _activeBlue.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: widget.icon,
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: widget.selected ? 11 : 10,
                        fontWeight:
                            widget.selected ? FontWeight.w800 : FontWeight.w600,
                        color: widget.selected
                            ? _activeBlue
                            : AppColors.textSecondary,
                        height: 1.1,
                      ),
                      child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _NavCartIcon extends StatelessWidget {
  const _NavCartIcon({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 28.0 : 24.0;
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            UserUiAssets.navCart,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          CountBadge(count: count, right: -2, top: -2),
        ],
      ),
    );
  }
}

Widget _navBarIcon(String asset, {bool selected = false}) {
  final size = selected ? 28.0 : 24.0;
  return Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );
}
