import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/app_variant.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/products/presentation/screens/add_product_screen.dart';
import 'package:iq_otomobil/features/products/presentation/screens/promoter_my_products_screen.dart';

// ✅ استيرادات الشاشات
import 'package:iq_otomobil/features/cart/presentation/screens/cart_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/checkout_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/promoter_main_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/promoter_requests_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/customer_orders_screen.dart';
import 'package:iq_otomobil/features/plates/presentation/screens/plates_screen.dart';
import 'package:iq_otomobil/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:iq_otomobil/features/admin/presentation/screens/admin_promoter_detail_screen.dart';
import 'package:iq_otomobil/features/admin/presentation/screens/ad_management_screen.dart';
import 'package:iq_otomobil/features/admin/presentation/screens/admin_app_controls_screen.dart';
import 'package:iq_otomobil/features/auth/presentation/screens/admin_auth_screen.dart';
import 'package:iq_otomobil/features/auth/presentation/screens/auth_screen.dart';
import 'package:iq_otomobil/features/auth/presentation/screens/account_screen.dart';
import 'package:iq_otomobil/features/ads/presentation/widgets/ad_banner.dart';
import 'package:iq_otomobil/features/splash/presentation/splash_screen.dart';
import 'package:iq_otomobil/features/catalog/data/shared_spare_categories.dart';
import 'package:iq_otomobil/features/catalog/data/search_price_ranges.dart';
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';
import 'package:iq_otomobil/features/products/data/car_models_catalog.dart';
import 'package:iq_otomobil/features/products/presentation/widgets/car_brand_icon.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/catalog/presentation/widgets/user_product_list_tile.dart';
import 'package:iq_otomobil/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:iq_otomobil/core/widgets/count_badge.dart';
import 'package:iq_otomobil/core/widgets/stable_scroll_behavior.dart';
import 'package:iq_otomobil/core/widgets/user_flow_ui.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/user_profile_provider.dart';
import 'package:iq_otomobil/features/cart/presentation/providers/cart_provider.dart';
import 'package:iq_otomobil/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:iq_otomobil/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/providers/user_orders_badge_provider.dart';
import 'package:iq_otomobil/features/ads/presentation/providers/ad_provider.dart';
import 'package:iq_otomobil/features/plates/presentation/providers/plate_provider.dart';
import 'package:iq_otomobil/features/orders/presentation/providers/order_provider.dart';
import 'package:iq_otomobil/features/system/presentation/screens/runtime_guard_screens.dart';
import 'package:iq_otomobil/core/routing/user_main_shell.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/core/utils/product_deep_link.dart';
import 'package:iq_otomobil/core/utils/product_share.dart';
import 'package:iq_otomobil/core/utils/support_whatsapp.dart';
import 'package:iq_otomobil/core/utils/friendly_error_message.dart';
import 'package:cached_network_image/cached_network_image.dart';

void _reloadCartProviders(BuildContext context, {int optimisticDelta = 0}) {
  if (!context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final countNotifier = container.read(cartCountNotifierProvider.notifier);
  if (optimisticDelta != 0) countNotifier.applyDelta(optimisticDelta);
  countNotifier.reload();
  container.invalidate(cartItemsProvider);
}

// ✅ دالة إضافة للسلة (مشتركة)
Future<void> _addToCart(BuildContext context, String productId) async {
  final uid = SupabaseService.currentUserId;
  if (uid == null) {
    if (context.mounted) context.push('/auth');
    return;
  }
  try {
    final existing = await SupabaseService.client
        .from('cart_items')
        .select('id, quantity')
        .eq('user_id', uid)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) {
      await SupabaseService.client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as num? ?? 0) + 1})
          .eq('user_id', uid)
          .eq('product_id', productId);
    } else {
      await SupabaseService.client.from('cart_items').insert({
        'user_id': uid,
        'product_id': productId,
        'quantity': 1,
      });
    }
    if (context.mounted) {
      _reloadCartProviders(context, optimisticDelta: 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ تمت الإضافة للسلة'),
            backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> _openWhatsAppForMissingProduct(BuildContext context) async {
  await openSupportWhatsApp(
    context: context,
    message:
        'مرحبا، أريد طلب قطعة غير متوفرة حالياً في تطبيق IQ OTOMOBIL.',
    includeUserPhoneInMessage: true,
  );
}

class AppRouter {
  static GoRouter? _userRouter;
  static GoRouter? _promoterRouter;
  static GoRouter? _adminRouter;

  static GoRouter get router => routerFor(AppVariant.user);

  static String _initialFor(AppVariant variant) {
    if (variant == AppVariant.user) {
      return ProductDeepLinkBootstrap.initialProductPath ?? '/splash';
    }
    return switch (variant) {
      AppVariant.admin => '/admin',
      AppVariant.promoter => '/promoter-splash',
      AppVariant.user => '/splash',
    };
  }

  static GoRouter routerFor(AppVariant variant) {
    switch (variant) {
      case AppVariant.user:
        return _userRouter ??= _buildRouter(variant);
      case AppVariant.promoter:
        return _promoterRouter ??= _buildRouter(variant);
      case AppVariant.admin:
        return _adminRouter ??= _buildRouter(variant);
    }
  }

  static GoRouter _buildRouter(AppVariant variant) => GoRouter(
        initialLocation: _initialFor(variant),
        onException: (context, state, router) {
          final productPath = ProductDeepLink.pathFromRouterState(state);
          if (productPath != null) {
            router.go(productPath);
            return;
          }
          router.go('/');
        },
        routes: [
          if (variant == AppVariant.user) ...[
            GoRoute(
                path: '/splash',
                builder: (_, __) => const SplashScreen(title: 'IQ OTOMBIL')),
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) =>
                  UserMainShell(navigationShell: navigationShell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (_, __) => const HomeScreen(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/cart',
                      builder: (_, __) => const CartScreen(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/my-orders',
                      builder: (_, __) => const CustomerOrdersScreen(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/plates',
                      builder: (_, __) => const PlatesScreen(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/account',
                      redirect: (_, __) =>
                          SupabaseService.isLoggedIn ? null : '/auth',
                      builder: (_, __) => const AccountScreen(),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/maintenance',
              builder: (_, __) => const MaintenanceModeScreen(),
            ),
            GoRoute(
              path: '/force-update',
              builder: (_, __) => const ForceUpdateScreen(),
            ),
            GoRoute(
              path: '/search',
              builder: (_, state) => SearchScreen(
                initialBrandStorageLabel: state.uri.queryParameters['brand'],
              ),
            ),
            GoRoute(
                path: '/category/:categoryId',
                builder: (_, state) => CategoryScreen(
                    categoryId: state.pathParameters['categoryId']!,
                    categoryName: state.uri.queryParameters['name'] ?? '')),
            GoRoute(
              path: '/product/:productId',
              builder: (_, state) => ProductDetailScreen(
                productId: state.pathParameters['productId']!,
              ),
            ),
            GoRoute(
                path: '/favorites',
                builder: (_, __) => const FavoritesScreen()),
            GoRoute(
                path: '/checkout', builder: (_, __) => const CheckoutScreen()),
            GoRoute(
              path: '/track/:orderId',
              builder: (_, state) => OrderTrackingScreen(
                  orderId: state.pathParameters['orderId']!),
            ),
          ],
          if (variant == AppVariant.promoter) ...[
            GoRoute(
              path: '/',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/promoter-splash',
              builder: (_, __) => const SplashScreen(
                title: 'IQ OTOMBIL التاجر',
                nextRoute: '/promoter',
                backgroundColor: Color(0xFF0F172A),
                accentColor: Color(0xFF38BDF8),
              ),
            ),
            GoRoute(
              path: '/promoter/requests',
              builder: (_, __) => const PromoterRequestsScreen(),
            ),
            GoRoute(
              path: '/promoter/my-products',
              builder: (_, __) => const PromoterMyProductsScreen(),
            ),
            GoRoute(
                path: '/promoter',
                builder: (_, __) => const PromoterMainScreen()),
            GoRoute(
              path: '/add-product',
              builder: (_, state) => AddProductScreen(
                editProductId: state.uri.queryParameters['edit'],
              ),
            ),
          ],
          if (variant == AppVariant.admin) ...[
            GoRoute(
              path: '/',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
            GoRoute(
              path: '/admin/promoter/:promoterId',
              builder: (_, state) => AdminPromoterDetailScreen(
                promoterId: state.pathParameters['promoterId']!,
              ),
            ),
            GoRoute(
              path: '/admin/ads',
              builder: (_, __) => const AdManagementScreen(),
            ),
            GoRoute(
              path: '/admin/system-controls',
              builder: (_, __) => const AdminAppControlsScreen(),
            ),
            GoRoute(
              path: '/admin/edit-product',
              builder: (_, state) => AddProductScreen(
                editProductId: state.uri.queryParameters['edit'],
              ),
            ),
          ],

          // Guard routes to prevent "route not found" when UI tries to navigate
          // across variants (hard separation).
          if (variant != AppVariant.admin)
            GoRoute(
              path: '/admin/promoter/:promoterId',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.admin)
            GoRoute(
              path: '/admin',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.admin)
            GoRoute(
              path: '/admin/system-controls',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.admin)
            GoRoute(
              path: '/admin/edit-product',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.promoter)
            GoRoute(
              path: '/promoter/requests',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.promoter)
            GoRoute(
              path: '/promoter/my-products',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.promoter)
            GoRoute(
              path: '/promoter',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),
          if (variant != AppVariant.promoter)
            GoRoute(
              path: '/add-product',
              redirect: (_, __) => _initialFor(variant),
              builder: (_, __) => const SizedBox.shrink(),
            ),

          GoRoute(
            path: '/auth',
            builder: (_, __) => variant == AppVariant.admin
                ? const AdminAuthScreen()
                : const AuthScreen(),
            redirect: (_, __) {
              final isLoggedIn = SupabaseService.isLoggedIn;
              return isLoggedIn ? _initialFor(variant) : null;
            },
          ),
          if (variant != AppVariant.user)
            GoRoute(
              path: '/account',
              redirect: (_, __) =>
                  SupabaseService.isLoggedIn ? null : '/auth',
              builder: (_, __) => const AccountScreen(),
            ),
        ],
        redirect: (context, state) {
          final productPath = ProductDeepLink.pathFromRouterState(state);
          if (productPath != null &&
              state.matchedLocation != productPath &&
              !state.matchedLocation.startsWith('/product/')) {
            return productPath;
          }

          final isLoggedIn = SupabaseService.isLoggedIn;

          if (variant == AppVariant.user &&
              state.matchedLocation == '/splash') {
            return null;
          }
          if (variant == AppVariant.promoter &&
              state.matchedLocation == '/promoter-splash') {
            return null;
          }

          // login guard
          final restrictedPrefixes = <String>[
            if (variant == AppVariant.user) ...[
              '/cart',
              '/checkout',
              '/my-orders',
              '/track'
            ],
            if (variant == AppVariant.promoter) ...[
              '/promoter',
              '/add-product'
            ],
            if (variant == AppVariant.admin) ...['/admin'],
          ];
          if (!isLoggedIn &&
              restrictedPrefixes
                  .any((p) => state.matchedLocation.startsWith(p))) {
            return '/auth';
          }

          // role guard (extra safety)
          if (isLoggedIn) {
            final matched = state.matchedLocation;
            if (variant == AppVariant.promoter &&
                (matched.startsWith('/promoter') ||
                    matched.startsWith('/add-product'))) {
              // The deeper role check stays in Auth flow; keep router light.
              // If needed, we can add a role fetch here too.
            }
          }

          return null;
        },
        refreshListenable: _AuthRefreshListener(),
      );
}

class _AuthRefreshListener extends ChangeNotifier {
  _AuthRefreshListener() {
    SupabaseService.authStateChanges.listen((_) => notifyListeners());
  }
}

// 🏠 الشاشة الرئيسية
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _latestPage = 0;
  String? _sessionUid;

  @override
  void initState() {
    super.initState();
    _sessionUid = SupabaseService.currentUserId;
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(favoriteIdsProvider.notifier).reload();
      ref.read(cartCountNotifierProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = SupabaseService.currentUserId;
    if (_sessionUid != currentUid) {
      _sessionUid = currentUid;
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(favoriteIdsProvider.notifier).reload();
        ref.read(cartCountNotifierProvider.notifier).reload();
      });
    }
    final favoritesCount = ref.watch(favoriteIdsProvider).length;
    final roleAsync = ref.watch(userProfileRoleProvider);
    final isAdmin = roleAsync.valueOrNull == 'admin';
    final isLoggedIn = SupabaseService.isLoggedIn;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: kProductListBackground,
      body: ScrollConfiguration(
        behavior: const StableScrollBehavior(),
        child: CustomScrollView(
          clipBehavior: Clip.hardEdge,
          slivers: [
            SliverAppBar(
              expandedHeight: kToolbarHeight,
              floating: false,
              pinned: true,
              stretch: false,
              scrolledUnderElevation: 0,
              backgroundColor: kProductListBackground,
              surfaceTintColor: Colors.transparent,
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: 'لوحة الإدارة',
                  icon: const Icon(Icons.admin_panel_settings,
                      color: AppColors.success),
                  onPressed: () => context.push('/admin'),
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'المفضلة',
                    icon: const Icon(Icons.favorite_border_rounded,
                        color: AppColors.primary),
                    onPressed: () => context.push('/favorites'),
                  ),
                  CountBadge(count: favoritesCount),
                ],
              ),
              IconButton(
                tooltip: isLoggedIn ? 'الملف الشخصي' : 'تسجيل الدخول',
                icon: Icon(
                  isLoggedIn ? Icons.person_outline : Icons.login,
                  color: AppColors.primary,
                ),
                onPressed: () =>
                    context.push(isLoggedIn ? '/account' : '/auth'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              color: kProductListBackground,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdBanner(
                      height: isSmallScreen ? 128 : 140,
                      margin: EdgeInsets.zero,
                      borderRadius: 16,
                      showShimmer: false,
                    ),
                    const SizedBox(height: 8),
                    _HomeSearchBar(onTap: () => context.push('/search'))
                        .animate()
                        .fadeIn(delay: 80.ms)
                        .slideY(begin: 0.08, end: 0),
                    const SizedBox(height: 3),
                    const _HomeBrandsRow(),
                    const SizedBox(height: 2),
                    const _LuxuryCategoryGrid(),
                    const SizedBox(height: 4.8),
                    Consumer(
                      builder: (context, ref, _) {
                        final async =
                            ref.watch(latestProductsPageProvider(_latestPage));
                        return async.when(
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _LatestProductsSectionTitle(),
                              const Padding(
                                padding: EdgeInsets.only(top: 6, bottom: 4),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          error: (e, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _LatestProductsSectionTitle(),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  friendlyErrorMessage(e),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          data: (page) {
                            final items = page.items;
                            final hasNext = page.hasNext;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _LatestProductsSectionTitle(),
                                ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: kProductCardListSpacing),
                                  itemBuilder: (ctx, i) {
                                    final p = items[i];
                                    final images = p['images'];
                                    final imageUrl =
                                        (images is List && images.isNotEmpty)
                                            ? images.first.toString()
                                            : null;
                                    final title = productDisplayTitle(p);
                                    final subtitle =
                                        sparePartCategoryDisplayName(
                                            p['category_id']?.toString());
                                    final brandStored =
                                        p['brand_id']?.toString().trim();
                                    final brandLabel = (brandStored != null &&
                                            brandStored.isNotEmpty)
                                        ? (brandByStorageLabel(brandStored)
                                                ?.displayLine ??
                                            brandStored)
                                        : null;
                                    return UserProductListTile(
                                      productId: p['id']?.toString() ?? '',
                                      imageUrl: imageUrl,
                                      title: title,
                                      subtitle: subtitle,
                                      brandLabel: brandLabel,
                                      price: p['price'],
                                      conditionLabel: productConditionLabelAr(
                                          p['condition']?.toString()),
                                      onTap: () =>
                                          context.push('/product/${p['id']}'),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _latestPage > 0
                                            ? () =>
                                                setState(() => _latestPage -= 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_left),
                                        label: const Text('السابق'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(
                                              color: AppColors.border),
                                          disabledForegroundColor:
                                              AppColors.textSecondary,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: hasNext
                                            ? () =>
                                                setState(() => _latestPage += 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_right),
                                        label: const Text('التالي'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: AppColors
                                              .primary
                                              .withValues(alpha: 0.35),
                                          disabledForegroundColor:
                                              Colors.white54,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _LuxuryServiceCard(
                      icon: Icons.shopping_bag,
                      title: 'اطلب قطعة غير متوفرة',
                      subtitle: '',
                      gradient: [AppColors.accent, AppColors.primary],
                      bottomMargin: 0,
                      onTap: () {
                        _openWhatsAppForMissingProduct(context);
                      },
                    ).animate().fadeIn(delay: 300.ms),
                    SizedBox(
                      height: userShellScrollBottomPadding(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// عنوان قسم «أحدث المنتجات».
class _LatestProductsSectionTitle extends StatelessWidget {
  const _LatestProductsSectionTitle();

  static const _verticalPadding = EdgeInsets.only(top: 8, bottom: 8);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _verticalPadding,
      child: Text(
        'أحدث المنتجات',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          height: 1.15,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// شريط بحث عصري مدمج مع قسم البانر.
class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({required this.onTap});

  final VoidCallback onTap;

  static const _primary = Color(0xFF4F7CFF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: _primary.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ابحث عن قطعة غيار، موديل، أو ماركة...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// صف ماركات أفقي تحت البحث — الضغط يفتح شاشة البحث مع فلتر الماركة.
class _HomeBrandsRow extends StatelessWidget {
  const _HomeBrandsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ScrollConfiguration(
        behavior: const StableScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          physics: const ClampingScrollPhysics(),
          itemCount: kCarBrandsCatalog.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final brand = kCarBrandsCatalog[index];
          return _BrandCard(
            brand: brand,
            selected: false,
            compact: true,
            onTap: () {
              final q = Uri.encodeQueryComponent(brand.storageLabel);
              context.push('/search?brand=$q');
            },
          );
        },
        ),
      ),
    );
  }
}

// ✅ شبكة الأقسام
class _LuxuryCategoryGrid extends StatelessWidget {
  const _LuxuryCategoryGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.90),
      itemCount: kSharedSpareCategories.length,
      itemBuilder: (ctx, i) {
        final c = kSharedSpareCategories[i];
        return _LuxuryCategoryCard(
          id: c.id,
          iconAsset: c.iconAsset,
          icon: c.icon,
          name: c.name,
          color: c.color,
          index: i,
          onTap: () => context.push('/category/${c.id}?name=${c.name}'),
        );
      },
    );
  }
}

class _LuxuryCategoryCard extends StatelessWidget {
  final String id;
  final String? iconAsset;
  final IconData icon;
  final String name;
  final Color color;
  final int index;
  final VoidCallback onTap;
  const _LuxuryCategoryCard({
    required this.id,
    required this.iconAsset,
    required this.icon,
    required this.name,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.10),
        highlightColor: color.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: iconAsset != null
                      ? Image.asset(
                          iconAsset!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        )
                      : Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (60 + index * 35).ms);
  }
}

class _LuxuryServiceCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _LuxuryServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.bottomMargin = 16,
  });

  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient.map((c) => c.withOpacity(0.15)).toList()),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: gradient[0].withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: gradient[0].withOpacity(0.4),
                              blurRadius: 10)
                        ]),
                    child: Icon(icon, color: Colors.white, size: 32)),
                const SizedBox(width: 20),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.textPrimary)),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ])),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppColors.primary))
              ]))),
    );
  }
}

// 🔍 شاشة البحث
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialBrandStorageLabel});

  /// ماركة مُمرَّرة من الرئيسية (query: ?brand=...)
  final String? initialBrandStorageLabel;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String? _selectedBrandStorageLabel;
  String? _selectedCategoryId;
  String? _selectedModelType;
  String? _selectedCondition;
  int? _priceFrom;
  int? _priceTo;
  bool _isMillionPlus = false;
  int? _filterYearFrom;
  int? _filterYearTo;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBrandStorageLabel?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedBrandStorageLabel = initial;
    }
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _productMatchesYear(Map<String, dynamic> p) {
    if (_filterYearFrom == null && _filterYearTo == null) return true;
    final yf = p['year_from'];
    final yt = p['year_to'];
    final prodLo = yf is num
        ? yf.toInt()
        : int.tryParse(yf?.toString() ?? '') ?? kSearchYearMin;
    final prodHi = yt is num
        ? yt.toInt()
        : int.tryParse(yt?.toString() ?? '') ?? kSearchYearMax;
    final filterLo = _filterYearFrom ?? kSearchYearMin;
    final filterHi = _filterYearTo ?? kSearchYearMax;
    if (yf == null && yt == null) return true;
    return prodLo <= filterHi && prodHi >= filterLo;
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var query = SupabaseService.client
          .from('products')
          .select('*')
          .inFilter('status', ['approved', 'active']);

      if (_selectedBrandStorageLabel != null &&
          _selectedBrandStorageLabel!.trim().isNotEmpty) {
        query = query.eq('brand_id', _selectedBrandStorageLabel!.trim());
      }
      if (_selectedCategoryId != null &&
          _selectedCategoryId!.trim().isNotEmpty) {
        query = query.eq('category_id', _selectedCategoryId!.trim());
      }
      if (_selectedModelType != null && _selectedModelType!.trim().isNotEmpty) {
        query = query.ilike('model', '%${_selectedModelType!.trim()}%');
      }
      if (_selectedCondition != null && _selectedCondition!.isNotEmpty) {
        query = query.eq('condition', _selectedCondition!);
      }
      if (_isMillionPlus) {
        query = query.gt('price', 1000000);
      } else {
        if (_priceFrom != null) query = query.gte('price', _priceFrom!);
        if (_priceTo != null) query = query.lte('price', _priceTo!);
      }

      final searchText = _searchCtrl.text.trim();
      if (searchText.isNotEmpty) {
        query = query.or(
            'model.ilike.%$searchText%,piece_name.ilike.%$searchText%,brand_id.ilike.%$searchText%,description.ilike.%$searchText%');
      }

      final response =
          await query.order('created_at', ascending: false).limit(80);
      final rows = List<Map<String, dynamic>>.from(response as List);
      final filtered = (_filterYearFrom == null && _filterYearTo == null)
          ? rows
          : rows.where(_productMatchesYear).toList();
      if (!mounted) return;
      setState(() {
        _products = filtered;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), _fetchProducts);
    setState(() {});
  }

  String _conditionLabel(String? value) => switch (value) {
        'new' => 'جديد',
        'used' => 'مستعمل',
        'refurbished' => 'مجدد',
        'american_import' => 'وارد امريكي',
        'korean_import' => 'وارد كوري',
        _ => 'الحالة',
      };

  String _priceLabel() {
    if (_isMillionPlus) return '1+ مليون دينار';
    if (_priceFrom == null && _priceTo == null) return 'السعر';
    if (_priceFrom != null && _priceTo != null) {
      return '${formatIqdIraqiAmount(_priceFrom!)} - ${formatIqdIraqiAmount(_priceTo!)}';
    }
    if (_priceFrom != null) return 'من ${formatIqdIraqiAmount(_priceFrom!)}';
    return 'إلى ${formatIqdIraqiAmount(_priceTo!)}';
  }

  Future<void> _openCategoryPicker() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('كل الأقسام')),
          for (final c in kSharedSpareCategories)
            ListTile(
              title: Text(c.name),
              trailing: _selectedCategoryId == c.id
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, c.id),
            ),
          ListTile(
            title: const Text('مسح اختيار القسم'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedCategoryId = selected.isEmpty ? null : selected;
    });
    _fetchProducts();
  }

  Future<void> _openModelPicker() async {
    final models = carModelsForStorageLabel(_selectedBrandStorageLabel);
    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر ماركة أولاً لعرض الفئات')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('كل الفئات'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final model in models)
            ListTile(
              title: Text(model),
              trailing: _selectedModelType == model
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, model),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedModelType = selected.isEmpty ? null : selected);
    _fetchProducts();
  }

  Future<void> _openConditionPicker() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('كل الحالات'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          ListTile(
            title: const Text('جديد'),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          ListTile(
            title: const Text('مستعمل'),
            onTap: () => Navigator.pop(ctx, 'used'),
          ),
          ListTile(
            title: const Text('مجدد'),
            onTap: () => Navigator.pop(ctx, 'refurbished'),
          ),
          ListTile(
            title: const Text('وارد امريكي'),
            onTap: () => Navigator.pop(ctx, 'american_import'),
          ),
          ListTile(
            title: const Text('وارد كوري'),
            onTap: () => Navigator.pop(ctx, 'korean_import'),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedCondition = selected.isEmpty ? null : selected);
    _fetchProducts();
  }

  Future<void> _openPricePicker() async {
    int? from = _priceFrom;
    int? to = _priceTo;
    var plus = _isMillionPlus;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('فلتر السعر',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: from,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('من سعر'),
                  ),
                  ...kSearchPriceSelectableValues.map(
                    (v) => DropdownMenuItem<int?>(
                      value: v,
                      child: Text(formatIqdIraqiAmount(v)),
                    ),
                  ),
                ],
                onChanged: plus
                    ? null
                    : (v) => setModal(() {
                          from = v;
                          if (to != null && v != null && to! < v) to = v;
                        }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: plus ? null : to,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('إلى سعر'),
                  ),
                  ...kSearchPriceSelectableValues.map(
                    (v) => DropdownMenuItem<int?>(
                      value: v,
                      child: Text(formatIqdIraqiAmount(v)),
                    ),
                  ),
                ],
                onChanged: plus ? null : (v) => setModal(() => to = v),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: plus,
                title: const Text('1+ مليون دينار'),
                onChanged: (v) => setModal(() {
                  plus = v ?? false;
                  if (plus) {
                    from = null;
                    to = null;
                  }
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModal(() {
                          from = null;
                          to = null;
                          plus = false;
                        });
                      },
                      child: const Text('مسح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _priceFrom = plus ? null : from;
      _priceTo = plus ? null : to;
      _isMillionPlus = plus;
    });
    _fetchProducts();
  }

  Future<void> _openYearPicker() async {
    int? from = _filterYearFrom;
    int? to = _filterYearTo;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: from,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('السنة من')),
                        ...kSearchYearOptions.map(
                          (y) => DropdownMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModal(() => from = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: to,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('السنة إلى')),
                        ...kSearchYearOptions.map(
                          (y) => DropdownMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModal(() => to = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setModal(() {
                        from = null;
                        to = null;
                      }),
                      child: const Text('مسح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _filterYearFrom = from;
      _filterYearTo = to;
    });
    _fetchProducts();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedBrandStorageLabel = null;
      _selectedCategoryId = null;
      _selectedModelType = null;
      _selectedCondition = null;
      _priceFrom = null;
      _priceTo = null;
      _isMillionPlus = false;
      _filterYearFrom = null;
      _filterYearTo = null;
      _searchCtrl.clear();
    });
    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final canClear = _selectedBrandStorageLabel != null ||
        _selectedCategoryId != null ||
        _selectedModelType != null ||
        _selectedCondition != null ||
        _priceFrom != null ||
        _priceTo != null ||
        _isMillionPlus ||
        _filterYearFrom != null ||
        _filterYearTo != null ||
        _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: kProductListBackground,
      appBar: AppBar(
        backgroundColor: kProductListBackground,
        title: const Text(
          'البحث',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          if (canClear)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('مسح الكل'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kCarBrandsCatalog.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final brand = kCarBrandsCatalog[index];
                      final selected =
                          _selectedBrandStorageLabel == brand.storageLabel;
                      return _BrandCard(
                        brand: brand,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _selectedBrandStorageLabel =
                                selected ? null : brand.storageLabel;
                            _selectedModelType = null;
                          });
                          _fetchProducts();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterActionButton(
                        label: _selectedCategoryId == null
                            ? 'الأقسام'
                            : sparePartCategoryDisplayName(_selectedCategoryId),
                        icon: Icons.category_outlined,
                        onTap: _openCategoryPicker,
                      ),
                      _FilterActionButton(
                        label: _selectedModelType ?? 'الفئة',
                        icon: Icons.grid_view_rounded,
                        onTap: _openModelPicker,
                      ),
                      _FilterActionButton(
                        label: _conditionLabel(_selectedCondition),
                        icon: Icons.verified_outlined,
                        onTap: _openConditionPicker,
                      ),
                      _FilterActionButton(
                        label: _priceLabel(),
                        icon: Icons.payments_outlined,
                        onTap: _openPricePicker,
                      ),
                      _FilterActionButton(
                        label: _filterYearFrom == null && _filterYearTo == null
                            ? 'السنة'
                            : '${_filterYearFrom ?? '...'} - ${_filterYearTo ?? '...'}',
                        icon: Icons.calendar_month_outlined,
                        onTap: _openYearPicker,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.trim().isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              _fetchProducts();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد نتائج',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: kProductCardListSpacing),
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          final images = p['images'];
                          final imageUrl = (images is List && images.isNotEmpty)
                              ? images[0].toString()
                              : null;
                          final categoryName =
                              sparePartCategoryDisplayName(p['category_id']);
                          final modelName = productDisplayTitle(p);
                          final brandStored = p['brand_id']?.toString().trim();
                          final brandLabel =
                              (brandStored != null && brandStored.isNotEmpty)
                                  ? (brandByStorageLabel(brandStored)
                                          ?.displayLine ??
                                      brandStored)
                                  : null;
                          return UserProductListTile(
                            productId: p['id']?.toString() ?? '',
                            imageUrl: imageUrl,
                            title: modelName,
                            subtitle: categoryName,
                            brandLabel: brandLabel,
                            price: p['price'],
                            conditionLabel: productConditionLabelAr(
                              p['condition']?.toString(),
                            ),
                            onTap: () => context.push('/product/${p['id']}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.brand,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final CarBrandEntry brand;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? AppColors.primary.withValues(alpha: 0.16) : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CarBrandIcon(brand: brand, size: compact ? 28 : 30),
              SizedBox(height: compact ? 2 : 4),
              Text(
                brand.nameAr,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterActionButton extends StatelessWidget {
  const _FilterActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.textPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.card,
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// 📦 شاشة القسم
class CategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String? _selectedBrandStorageLabel;
  String? _selectedModelType;
  String? _selectedCondition;
  int? _priceFrom;
  int? _priceTo;
  bool _isMillionPlus = false;
  int? _filterYearFrom;
  int? _filterYearTo;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  int _page = 0;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _productMatchesYear(Map<String, dynamic> p) {
    if (_filterYearFrom == null && _filterYearTo == null) return true;
    final yf = p['year_from'];
    final yt = p['year_to'];
    final prodLo = yf is num
        ? yf.toInt()
        : int.tryParse(yf?.toString() ?? '') ?? kSearchYearMin;
    final prodHi = yt is num
        ? yt.toInt()
        : int.tryParse(yt?.toString() ?? '') ?? kSearchYearMax;
    final filterLo = _filterYearFrom ?? kSearchYearMin;
    final filterHi = _filterYearTo ?? kSearchYearMax;
    if (yf == null && yt == null) return true;
    return prodLo <= filterHi && prodHi >= filterLo;
  }

  Future<void> _fetchProducts() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final from = _page * 20;
      final to = from + 20;

      var query = SupabaseService.client
          .from('products')
          .select('*')
          .eq('category_id', widget.categoryId)
          .inFilter('status', ['approved', 'active']);

      if (_selectedBrandStorageLabel != null &&
          _selectedBrandStorageLabel!.trim().isNotEmpty) {
        query = query.eq('brand_id', _selectedBrandStorageLabel!.trim());
      }
      if (_selectedModelType != null && _selectedModelType!.trim().isNotEmpty) {
        query = query.ilike('model', '%${_selectedModelType!.trim()}%');
      }
      if (_selectedCondition != null && _selectedCondition!.isNotEmpty) {
        query = query.eq('condition', _selectedCondition!);
      }
      if (_isMillionPlus) {
        query = query.gt('price', 1000000);
      } else {
        if (_priceFrom != null) query = query.gte('price', _priceFrom!);
        if (_priceTo != null) query = query.lte('price', _priceTo!);
      }
      final searchText = _searchCtrl.text.trim();
      if (searchText.isNotEmpty) {
        query = query.or(
            'model.ilike.%$searchText%,piece_name.ilike.%$searchText%,brand_id.ilike.%$searchText%,description.ilike.%$searchText%');
      }

      final response =
          await query.order('created_at', ascending: false).range(from, to);
      final list = List<Map<String, dynamic>>.from(response as List);
      final filtered = (_filterYearFrom == null && _filterYearTo == null)
          ? list
          : list.where(_productMatchesYear).toList();

      if (!mounted) return;
      setState(() {
        _hasNext = filtered.length > 20;
        _products = _hasNext ? filtered.sublist(0, 20) : filtered;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _scheduleSearchFetch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _page = 0;
      _fetchProducts();
    });
    setState(() {});
  }

  String _conditionLabel(String? value) => switch (value) {
        'new' => 'جديد',
        'used' => 'مستعمل',
        'refurbished' => 'مجدد',
        'american_import' => 'وارد امريكي',
        'korean_import' => 'وارد كوري',
        _ => 'الحالة',
      };

  String _priceLabel() {
    if (_isMillionPlus) return '1+ مليون دينار';
    if (_priceFrom == null && _priceTo == null) return 'السعر';
    if (_priceFrom != null && _priceTo != null) {
      return '${formatIqdIraqiAmount(_priceFrom!)} - ${formatIqdIraqiAmount(_priceTo!)}';
    }
    if (_priceFrom != null) return 'من ${formatIqdIraqiAmount(_priceFrom!)}';
    return 'إلى ${formatIqdIraqiAmount(_priceTo!)}';
  }

  Future<void> _openModelPicker() async {
    final models = carModelsForStorageLabel(_selectedBrandStorageLabel);
    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر ماركة أولاً لعرض الفئات')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('كل الفئات'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final model in models)
            ListTile(
              title: Text(model),
              trailing: _selectedModelType == model
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, model),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _page = 0;
      _selectedModelType = selected.isEmpty ? null : selected;
    });
    _fetchProducts();
  }

  Future<void> _openConditionPicker() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('كل الحالات'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          ListTile(
            title: const Text('جديد'),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          ListTile(
            title: const Text('مستعمل'),
            onTap: () => Navigator.pop(ctx, 'used'),
          ),
          ListTile(
            title: const Text('مجدد'),
            onTap: () => Navigator.pop(ctx, 'refurbished'),
          ),
          ListTile(
            title: const Text('وارد امريكي'),
            onTap: () => Navigator.pop(ctx, 'american_import'),
          ),
          ListTile(
            title: const Text('وارد كوري'),
            onTap: () => Navigator.pop(ctx, 'korean_import'),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _page = 0;
      _selectedCondition = selected.isEmpty ? null : selected;
    });
    _fetchProducts();
  }

  Future<void> _openPricePicker() async {
    int? from = _priceFrom;
    int? to = _priceTo;
    var plus = _isMillionPlus;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('فلتر السعر',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: from,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('من سعر'),
                  ),
                  ...kSearchPriceSelectableValues.map(
                    (v) => DropdownMenuItem<int?>(
                      value: v,
                      child: Text(formatIqdIraqiAmount(v)),
                    ),
                  ),
                ],
                onChanged: plus
                    ? null
                    : (v) => setModal(() {
                          from = v;
                          if (to != null && v != null && to! < v) to = v;
                        }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: plus ? null : to,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('إلى سعر'),
                  ),
                  ...kSearchPriceSelectableValues.map(
                    (v) => DropdownMenuItem<int?>(
                      value: v,
                      child: Text(formatIqdIraqiAmount(v)),
                    ),
                  ),
                ],
                onChanged: plus ? null : (v) => setModal(() => to = v),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: plus,
                title: const Text('1+ مليون دينار'),
                onChanged: (v) => setModal(() {
                  plus = v ?? false;
                  if (plus) {
                    from = null;
                    to = null;
                  }
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModal(() {
                          from = null;
                          to = null;
                          plus = false;
                        });
                      },
                      child: const Text('مسح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _page = 0;
      _priceFrom = plus ? null : from;
      _priceTo = plus ? null : to;
      _isMillionPlus = plus;
    });
    _fetchProducts();
  }

  Future<void> _openYearPicker() async {
    int? from = _filterYearFrom;
    int? to = _filterYearTo;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: from,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('السنة من')),
                        ...kSearchYearOptions.map(
                          (y) => DropdownMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModal(() => from = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: to,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('السنة إلى')),
                        ...kSearchYearOptions.map(
                          (y) => DropdownMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModal(() => to = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setModal(() {
                        from = null;
                        to = null;
                      }),
                      child: const Text('مسح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _page = 0;
      _filterYearFrom = from;
      _filterYearTo = to;
    });
    _fetchProducts();
  }

  void _clearAllFilters() {
    setState(() {
      _page = 0;
      _selectedBrandStorageLabel = null;
      _selectedModelType = null;
      _selectedCondition = null;
      _priceFrom = null;
      _priceTo = null;
      _isMillionPlus = false;
      _filterYearFrom = null;
      _filterYearTo = null;
      _searchCtrl.clear();
    });
    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final canPrev = _page > 0;
    final canClear = _selectedBrandStorageLabel != null ||
        _selectedModelType != null ||
        _selectedCondition != null ||
        _priceFrom != null ||
        _priceTo != null ||
        _isMillionPlus ||
        _filterYearFrom != null ||
        _filterYearTo != null ||
        _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: kProductListBackground,
      appBar: AppBar(
        backgroundColor: kProductListBackground,
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (canClear)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('مسح الكل'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kCarBrandsCatalog.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final brand = kCarBrandsCatalog[index];
                      final selected =
                          _selectedBrandStorageLabel == brand.storageLabel;
                      return _BrandCard(
                        brand: brand,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _page = 0;
                            _selectedBrandStorageLabel =
                                selected ? null : brand.storageLabel;
                            _selectedModelType = null;
                          });
                          _fetchProducts();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterActionButton(
                        label: _selectedModelType ?? 'الفئة',
                        icon: Icons.grid_view_rounded,
                        onTap: _openModelPicker,
                      ),
                      _FilterActionButton(
                        label: _conditionLabel(_selectedCondition),
                        icon: Icons.verified_outlined,
                        onTap: _openConditionPicker,
                      ),
                      _FilterActionButton(
                        label: _priceLabel(),
                        icon: Icons.payments_outlined,
                        onTap: _openPricePicker,
                      ),
                      _FilterActionButton(
                        label: _filterYearFrom == null && _filterYearTo == null
                            ? 'السنة'
                            : '${_filterYearFrom ?? '...'} - ${_filterYearTo ?? '...'}',
                        icon: Icons.calendar_month_outlined,
                        onTap: _openYearPicker,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _scheduleSearchFetch(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.trim().isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _page = 0);
                              _fetchProducts();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد منتجات في هذا القسم حالياً',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: kProductCardListSpacing),
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          final images = p['images'];
                          final imageUrl = (images is List && images.isNotEmpty)
                              ? images[0].toString()
                              : null;
                          final categoryName =
                              sparePartCategoryDisplayName(p['category_id']);
                          final modelName = productDisplayTitle(p);
                          final brandStored = p['brand_id']?.toString().trim();
                          final brandLabel =
                              (brandStored != null && brandStored.isNotEmpty)
                                  ? (brandByStorageLabel(brandStored)
                                          ?.displayLine ??
                                      brandStored)
                                  : null;
                          return UserProductListTile(
                            productId: p['id']?.toString() ?? '',
                            imageUrl: imageUrl,
                            title: modelName,
                            subtitle: categoryName,
                            brandLabel: brandLabel,
                            price: p['price'],
                            conditionLabel: productConditionLabelAr(
                              p['condition']?.toString(),
                            ),
                            onTap: () => context.push('/product/${p['id']}'),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPrev
                        ? () async {
                            setState(() => _page -= 1);
                            await _fetchProducts();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('السابق'),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'صفحة ${_page + 1}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _hasNext
                        ? () async {
                            setState(() => _page += 1);
                            await _fetchProducts();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('التالي'),
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

// 🛍️ شاشة تفاصيل المنتج - مع نظام التقييمات ✅ (مصحح نهائياً)
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  final PageController _imagePageController = PageController();
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  @override
  void didUpdateWidget(ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _imageIndex = 0;
      if (_imagePageController.hasClients) {
        _imagePageController.jumpToPage(0);
      }
      _fetchProduct();
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _fetchProduct() async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('*')
          .eq('id', widget.productId)
          .maybeSingle();
      setState(() {
        _product = response;
        _isLoading = false;
        _imageIndex = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_imagePageController.hasClients) {
          _imagePageController.jumpToPage(0);
        }
      });
    } catch (e) {
      print('❌ خطأ في جلب التفاصيل: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: kProductListBackground,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_product == null) {
      return Scaffold(
        backgroundColor: kProductListBackground,
        appBar: AppBar(
          backgroundColor: kProductListBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(
          child: Text(
            'المنتج غير موجود',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final p = _product!;
    final pubStatus = p['status']?.toString() ?? '';
    final promoterId = p['promoter_id']?.toString();
    final uid = SupabaseService.currentUserId;
    final isOwner = uid != null && promoterId == uid;
    final isPublicListing = pubStatus == 'approved' || pubStatus == 'active';
    if (!isPublicListing && !isOwner) {
      return Scaffold(
        backgroundColor: kProductListBackground,
        appBar: AppBar(
          backgroundColor: kProductListBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'هذا المنتج غير متاح للعرض حالياً.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    final rawImages = p['images'];
    final imageUrls = <String>[];
    if (rawImages is List) {
      for (final x in rawImages) {
        final s = x?.toString();
        if (s != null && s.isNotEmpty) imageUrls.add(s);
      }
    }

    final brandStored = p['brand_id']?.toString();
    final brandEntry = brandByStorageLabel(brandStored);
    final brandDisplay = brandEntry?.displayLine ??
        (brandStored != null && brandStored.trim().isNotEmpty
            ? brandStored
            : 'غير محدد');
    final categoryName = sparePartCategoryDisplayName(p['category_id']);
    final price = p['price'];
    final priceText = formatIQD(
      price is num ? price : num.tryParse('$price'),
    );
    final titleName = productDisplayTitle(p);
    final pieceNameRow = productPieceNameRaw(p) ?? '—';
    final modelOnly = productDisplayModel(p);
    final descTrimmed = p['description']?.toString().trim() ?? '';
    final description = descTrimmed.isNotEmpty ? descTrimmed : '—';
    final conditionRaw = p['condition']?.toString();
    final conditionLabel = _conditionArabic(conditionRaw);
    final yearFrom = p['year_from'];
    final yearTo = p['year_to'];
    final yearRangeText = _yearRangeText(yearFrom, yearTo);

    final specEntries = <MapEntry<String, String>>[
      MapEntry('الماركة', brandDisplay),
      MapEntry('الفئة', categoryName),
      MapEntry('اسم القطعة', pieceNameRow),
      MapEntry('الموديل / سنة الصنع', modelOnly),
      MapEntry('الحالة', conditionLabel),
      MapEntry('سنوات التوافق', yearRangeText),
    ];

    return Scaffold(
      backgroundColor: kProductListBackground,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProductDetailTopBar(
                            onBack: () => Navigator.of(context).maybePop(),
                            productId: widget.productId,
                            onShare: () => shareProduct(
                              context: context,
                              productId: widget.productId,
                              title: titleName,
                              price: priceText,
                              brand: brandDisplay,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ProductDetailImageGallery(
                            imageUrls: imageUrls,
                            pageController: _imagePageController,
                            currentIndex: _imageIndex,
                            onPageChanged: (i) => setState(() => _imageIndex = i),
                            onTapImage: (i) => _openImageViewer(imageUrls, i),
                            onMove: (delta) =>
                                _moveImage(delta, imageUrls.length),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      88 + bottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ProductDetailMetaChip(
                              icon: Icons.directions_car_filled_outlined,
                              label: brandDisplay,
                            ),
                            _ProductDetailMetaChip(
                              icon: Icons.category_outlined,
                              label: categoryName,
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(duration: 280.ms)
                            .slideY(begin: 0.06, end: 0),
                        const SizedBox(height: 10),
                        Text(
                          titleName,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            letterSpacing: -0.3,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 60.ms, duration: 300.ms)
                            .slideY(begin: 0.05, end: 0),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                priceText,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _ProductDetailConditionBadge(
                              label: conditionLabel,
                              conditionRaw: conditionRaw,
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 300.ms)
                            .slideY(begin: 0.04, end: 0),
                        const SizedBox(height: 18),
                        _ProductDetailSectionHeader(
                          title: 'معلومات المنتج',
                          icon: Icons.tune_rounded,
                        ),
                        const SizedBox(height: 10),
                        _buildSpecGrid(specEntries),
                        const SizedBox(height: 16),
                        _ProductDetailSectionHeader(
                          title: 'الوصف',
                          icon: Icons.description_outlined,
                        ),
                        const SizedBox(height: 10),
                        _ProductDetailDescriptionCard(text: description)
                            .animate()
                            .fadeIn(delay: 180.ms, duration: 320.ms)
                            .slideY(begin: 0.04, end: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ProductDetailAddToCartBar(
                priceText: priceText,
                bottomInset: bottomInset,
                onAdd: () => _addToCart(context, widget.productId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _conditionArabic(String? condition) {
    switch (condition) {
      case 'new':
        return 'جديد';
      case 'used':
        return 'مستعمل';
      case 'refurbished':
        return 'مجدد';
      case 'american_import':
        return 'وارد امريكي';
      case 'korean_import':
        return 'وارد كوري';
      default:
        final s = condition?.toString().trim();
        return (s != null && s.isNotEmpty) ? s : '—';
    }
  }

  String _yearRangeText(dynamic yearFrom, dynamic yearTo) {
    if (yearFrom == null && yearTo == null) return '—';
    final a = yearFrom == null ? null : '$yearFrom';
    final b = yearTo == null ? null : '$yearTo';
    if (a != null && b != null) return '$a – $b';
    if (a != null) return 'من سنة $a';
    return 'حتى سنة $b';
  }

  void _moveImage(int delta, int count) {
    if (count <= 1) return;
    final next = (_imageIndex + delta + count) % count;
    if (_imagePageController.hasClients) {
      _imagePageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _openImageViewer(List<String> images, int initialIndex) async {
    if (images.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProductImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildSpecGrid(List<MapEntry<String, String>> entries) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: _ProductDetailSpecCard(
                    label: entries[i].key,
                    value: entries[i].value,
                    animationDelayMs: 120 + (i ~/ 2) * 40,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: (i + 1) < entries.length
                      ? _ProductDetailSpecCard(
                          label: entries[i + 1].key,
                          value: entries[i + 1].value,
                          animationDelayMs: 140 + (i ~/ 2) * 40,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Product detail — premium UI widgets ───────────────────────────────────

abstract final class _ProductDetailUi {
  static const cardShadow = Color(0x14134A8A);
  static const galleryHeight = 300.0;
}

class _ProductDetailTopBar extends StatelessWidget {
  const _ProductDetailTopBar({
    required this.onBack,
    required this.productId,
    required this.onShare,
  });

  final VoidCallback onBack;
  final String productId;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProductDetailGlassIconButton(
          icon: Icons.arrow_forward_ios_rounded,
          onTap: onBack,
        ),
        const Spacer(),
        _ProductDetailGlassIconButton(
          icon: Icons.share_outlined,
          onTap: onShare,
        ),
        const SizedBox(width: 8),
        Consumer(
          builder: (context, ref, _) {
            final ids = ref.watch(favoriteIdsProvider);
            final isFav = ids.contains(productId);
            return _ProductDetailFavoriteButton(
              isFavorite: isFav,
              onPressed: () =>
                  ref.read(favoriteIdsProvider.notifier).toggle(productId),
            );
          },
        ),
      ],
    );
  }
}

class _ProductDetailGlassIconButton extends StatelessWidget {
  const _ProductDetailGlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.88),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: _ProductDetailUi.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ProductDetailFavoriteButton extends StatefulWidget {
  const _ProductDetailFavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  State<_ProductDetailFavoriteButton> createState() =>
      _ProductDetailFavoriteButtonState();
}

class _ProductDetailFavoriteButtonState
    extends State<_ProductDetailFavoriteButton> {
  bool _popping = false;

  @override
  void didUpdateWidget(_ProductDetailFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      setState(() => _popping = true);
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (mounted) setState(() => _popping = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        customBorder: const CircleBorder(),
        splashColor: AppColors.error.withValues(alpha: 0.12),
        child: AnimatedScale(
          scale: _popping ? 1.06 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isFavorite
                  ? AppColors.error.withValues(alpha: 0.08)
                  : Colors.white,
              border: Border.all(
                color: widget.isFavorite
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.border.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: Icon(
              widget.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: AppColors.error,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailImageGallery extends StatelessWidget {
  const _ProductDetailImageGallery({
    required this.imageUrls,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTapImage,
    required this.onMove,
  });

  final List<String> imageUrls;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTapImage;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _ProductDetailUi.cardShadow,
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: _ProductDetailUi.galleryHeight,
          child: imageUrls.isEmpty
              ? ColoredBox(
                  color: AppColors.inputFill,
                  child: Icon(
                    Icons.image_outlined,
                    size: 72,
                    color: AppColors.muted.withValues(alpha: 0.7),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: pageController,
                      itemCount: imageUrls.length,
                      onPageChanged: onPageChanged,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => onTapImage(i),
                        child: CachedNetworkImage(
                          imageUrl: imageUrls[i],
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => ColoredBox(
                            color: AppColors.inputFill,
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: AppColors.inputFill,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.muted,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (imageUrls.length > 1) ...[
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _ProductDetailGalleryArrow(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => onMove(-1),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _ProductDetailGalleryArrow(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => onMove(1),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: _ProductDetailImageCounter(
                          current: currentIndex + 1,
                          total: imageUrls.length,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(imageUrls.length, (i) {
                            final selected = currentIndex == i;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              width: selected ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.45),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 320.ms)
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _ProductDetailGalleryArrow extends StatelessWidget {
  const _ProductDetailGalleryArrow({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ProductDetailImageCounter extends StatelessWidget {
  const _ProductDetailImageCounter({
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '$current / $total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductDetailMetaChip extends StatelessWidget {
  const _ProductDetailMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: _ProductDetailUi.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailConditionBadge extends StatelessWidget {
  const _ProductDetailConditionBadge({
    required this.label,
    required this.conditionRaw,
  });

  final String label;
  final String? conditionRaw;

  @override
  Widget build(BuildContext context) {
    if (conditionRaw == 'new') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F7CFF), AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final Color accent;
    switch (conditionRaw) {
      case 'used':
        accent = const Color(0xFFD97706);
      case 'refurbished':
        accent = AppColors.accent;
      case 'american_import':
        accent = AppColors.success;
      case 'korean_import':
        accent = const Color(0xFF7C3AED);
      default:
        accent = AppColors.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProductDetailSectionHeader extends StatelessWidget {
  const _ProductDetailSectionHeader({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _ProductDetailSpecCard extends StatelessWidget {
  const _ProductDetailSpecCard({
    required this.label,
    required this.value,
    this.animationDelayMs = 0,
  });

  final String label;
  final String value;
  final int animationDelayMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: _ProductDetailUi.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: animationDelayMs.ms, duration: 280.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _ProductDetailDescriptionCard extends StatelessWidget {
  const _ProductDetailDescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: _ProductDetailUi.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProductDetailAddToCartBar extends StatefulWidget {
  const _ProductDetailAddToCartBar({
    required this.priceText,
    required this.bottomInset,
    required this.onAdd,
  });

  final String priceText;
  final double bottomInset;
  final VoidCallback onAdd;

  @override
  State<_ProductDetailAddToCartBar> createState() =>
      _ProductDetailAddToCartBarState();
}

class _ProductDetailAddToCartBarState extends State<_ProductDetailAddToCartBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + widget.bottomInset,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'السعر',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.priceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Listener(
                onPointerDown: (_) => setState(() => _pressed = true),
                onPointerUp: (_) => setState(() => _pressed = false),
                onPointerCancel: (_) => setState(() => _pressed = false),
                child: AnimatedScale(
                  scale: _pressed ? 0.985 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onAdd,
                      borderRadius: BorderRadius.circular(16),
                      splashColor: Colors.white.withValues(alpha: 0.18),
                      highlightColor: Colors.white.withValues(alpha: 0.08),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _pressed
                                ? [
                                    const Color(0xFF456FEE),
                                    AppColors.primary.withValues(alpha: 0.92),
                                  ]
                                : const [
                                    Color(0xFF4F7CFF),
                                    AppColors.primary,
                                  ],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_shopping_cart_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'أضف إلى السلة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImageViewer extends StatefulWidget {
  const _ProductImageViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<_ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<_ProductImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int delta) {
    if (widget.images.length <= 1) return;
    final next = (_index + delta + widget.images.length) % widget.images.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 3.5,
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ViewerArrow(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => _move(-1),
                ),
              ),
            ),
          if (widget.images.length > 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ViewerArrow(
                  icon: Icons.arrow_forward_ios_rounded,
                  onTap: () => _move(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewerArrow extends StatelessWidget {
  const _ViewerArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
