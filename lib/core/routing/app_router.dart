import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/products/presentation/screens/add_product_screen.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/auth_provider.dart';

// ✅ استيرادات الشاشات
import 'package:iq_otomobil/features/cart/presentation/screens/cart_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/checkout_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/promoter_dashboard.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/customer_orders_screen.dart';
import 'package:iq_otomobil/features/plates/presentation/screens/plates_screen.dart';
import 'package:iq_otomobil/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:iq_otomobil/features/auth/presentation/screens/auth_screen.dart';
import 'package:iq_otomobil/features/auth/presentation/screens/account_screen.dart';

// ✅ استيراد شاشة إضافة التقييم
import 'package:iq_otomobil/features/reviews/presentation/screens/add_review_screen.dart';
import 'package:iq_otomobil/features/reviews/presentation/screens/my_reviews_screen.dart';

// ✅ دالة مساعدة للتحقق من صلاحية المستخدم
Future<String?> _getUserRole() async {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) return null;
  try {
    final response = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return response?['role'] as String?;
  } catch (e) {
    return 'user';
  }
}

// ✅ دالة إضافة للسلة (مشتركة)
Future<void> _addToCart(BuildContext context, String productId) async {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) {
    if (context.mounted) context.push('/auth');
    return;
  }
  try {
    final existing = await SupabaseService.client
        .from('cart_items')
        .select('id, quantity')
        .eq('user_id', user.id)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) {
      await SupabaseService.client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as num? ?? 0) + 1})
          .eq('user_id', user.id)
          .eq('product_id', productId);
    } else {
      await SupabaseService.client.from('cart_items').insert({
        'user_id': user.id,
        'product_id': productId,
        'quantity': 1,
      });
    }
    if (context.mounted) {
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

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/add-product', builder: (_, __) => const AddProductScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
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
      GoRoute(path: '/plates', builder: (_, __) => const PlatesScreen()),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(),
        redirect: (_, __) {
          final session = SupabaseService.client.auth.currentSession;
          return session != null ? '/' : null;
        },
      ),
      GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(
          path: '/my-orders', builder: (_, __) => const CustomerOrdersScreen()),

      // ✅ مسار إضافة التقييم (جديد)
      GoRoute(
        path: '/add-review',
        builder: (_, state) => AddReviewScreen(
          productId: state.uri.queryParameters['productId']!,
          productName: state.uri.queryParameters['productName']!,
          orderId: state.uri.queryParameters['orderId'],
        ),
      ),

      // ✅ مسار عرض تقييماتي
      GoRoute(
        path: '/my-reviews',
        builder: (_, __) => const MyReviewsScreen(),
      ),

      GoRoute(
        path: '/promoter',
        builder: (_, __) => const PromoterDashboard(),
        redirect: (context, state) async {
          final role = await _getUserRole();
          if (role != 'promoter' && role != 'admin') return '/';
          return null;
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboard(),
        redirect: (context, state) async {
          final role = await _getUserRole();
          if (role != 'admin') return '/';
          return null;
        },
      ),
      GoRoute(
        path: '/track/:orderId',
        builder: (_, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
    ],
    redirect: (context, state) {
      final session = SupabaseService.client.auth.currentSession;
      final isLoggedIn = session != null;
      final restrictedPaths = ['/cart', '/checkout', '/promoter', '/admin'];
      if (!isLoggedIn && restrictedPaths.contains(state.matchedLocation)) {
        return '/auth';
      }
      return null;
    },
    refreshListenable: _AuthRefreshListener(),
  );
}

class _AuthRefreshListener extends ChangeNotifier {
  _AuthRefreshListener() {
    SupabaseService.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }
}

// 🏠 الشاشة الرئيسية
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = true;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _loadCartCount();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('*')
          .inFilter('status', ['approved', 'active']).order('created_at',
              ascending: false);
      if (!mounted) return;
      setState(() {
        _products = response;
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب المنتجات: $e');
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadCartCount() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _cartItemCount = 0);
      return;
    }
    try {
      final response = await SupabaseService.client
          .from('cart_items')
          .select('quantity')
          .eq('user_id', user.id);
      int count = response.fold<int>(
          0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1));
      if (mounted) setState(() => _cartItemCount = count);
    } catch (e) {
      print('❌ خطأ في تحميل عدد السلة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isSmallScreen ? 160 : 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E3A8A),
                      Color(0xFF3B82F6)
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.blue.withOpacity(0.3),
                                Colors.purple.withOpacity(0.3)
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.white24, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2)
                              ],
                            ),
                            child: const Icon(Icons.auto_awesome,
                                size: 44, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFF60A5FA),
                                  Colors.white
                                ]).createShader(bounds),
                            child: const Text('IQ OTOMBIL',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(color: Colors.blue, blurRadius: 10)
                                    ])),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.amber.withOpacity(0.2),
                                Colors.orange.withOpacity(0.2)
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: const Text('أفضل منصة لقطع الغيار في العراق',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              FutureBuilder(
                future: SupabaseService.client.auth.currentSession != null
                    ? SupabaseService.client
                        .from('profiles')
                        .select('role')
                        .eq('id', SupabaseService.client.auth.currentUser!.id)
                        .maybeSingle()
                    : Future.value(null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const SizedBox.shrink();
                  final role = snapshot.data?['role'] as String?;
                  final isLoggedIn =
                      SupabaseService.client.auth.currentSession != null;
                  return Row(
                    children: [
                      if (role == 'admin')
                        IconButton(
                            icon: const Icon(Icons.admin_panel_settings,
                                color: Colors.greenAccent),
                            onPressed: () => context.push('/admin')),
                      if (role == 'promoter' || role == 'admin')
                        IconButton(
                            icon: const Icon(Icons.storefront,
                                color: Colors.amber),
                            onPressed: () => context.push('/promoter')),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined,
                                color: Colors.white),
                            onPressed: () {
                              context.push('/cart');
                              _loadCartCount();
                            },
                          ),
                          if (_cartItemCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                child: Text(
                                  _cartItemCount > 99
                                      ? '99+'
                                      : '$_cartItemCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                          icon: Icon(
                              isLoggedIn ? Icons.person_outline : Icons.login,
                              color: Colors.white),
                          onPressed: () =>
                              context.push(isLoggedIn ? '/account' : '/auth')),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)])),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ]),
                        child: Row(children: [
                          Icon(Icons.search, color: Colors.blue[300], size: 26),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Text('ابحث عن قطعة، ماركة، أو موديل...',
                                  style: TextStyle(
                                      color: Colors.grey[300], fontSize: 16))),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Text('بحث',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)))
                        ]),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 32),
                    Text('الأقسام',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Colors.white)),
                    const SizedBox(height: 20),
                    _LuxuryCategoryGrid(),
                    const SizedBox(height: 32),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('أحدث المنتجات',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                  color: Colors.white)),
                          TextButton(
                              onPressed: () => context.push('/search'),
                              child: const Text('عرض الكل',
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600)))
                        ]),
                    const SizedBox(height: 20),
                    _isLoadingProducts
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.blue))
                        : _products.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Column(children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 64, color: Colors.grey[600]),
                                  const SizedBox(height: 16),
                                  Text('لا توجد منتجات حالياً',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 16))
                                ]))
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.75),
                                itemCount: _products.length,
                                itemBuilder: (ctx, i) {
                                  final product = _products[i];
                                  final images = product['images'];
                                  final imageUrl =
                                      (images is List && images.isNotEmpty)
                                          ? images[0].toString()
                                          : null;
                                  final brandName =
                                      product['brand_id'] ?? 'غير محدد';
                                  final price = product['price'] ?? 0;
                                  final modelName =
                                      product['model'] ?? 'بدون موديل';
                                  return GestureDetector(
                                    onTap: () => context
                                        .push('/product/${product['id']}'),
                                    child: Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.blue.withOpacity(0.1),
                                                  Colors.purple
                                                      .withOpacity(0.05)
                                                ]),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.blue
                                                    .withOpacity(0.3)),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 5))
                                            ]),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                  child: ClipRRect(
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                              top: Radius.circular(
                                                                  20)),
                                                      child: imageUrl != null &&
                                                              imageUrl
                                                                  .isNotEmpty
                                                          ? Image.network(
                                                              imageUrl,
                                                              width: double
                                                                  .infinity,
                                                              height: 150,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context,
                                                                      error,
                                                                      stackTrace) =>
                                                                  Container(
                                                                      color: Colors
                                                                          .grey[800],
                                                                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50)))
                                                          : Container(color: Colors.grey[800], child: const Icon(Icons.shopping_bag, color: Colors.grey, size: 50)))),
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(modelName,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(brandName,
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[400],
                                                                fontSize: 12)),
                                                        const SizedBox(
                                                            height: 8),
                                                        Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                  '\$${price.toString()}',
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .green,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          16)),
                                                              IconButton(
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .add_shopping_cart,
                                                                      color: Colors
                                                                          .blue),
                                                                  onPressed:
                                                                      () {
                                                                    _addToCart(
                                                                        context,
                                                                        product[
                                                                            'id']);
                                                                    _loadCartCount();
                                                                  })
                                                            ])
                                                      ]))
                                            ])),
                                  )
                                      .animate()
                                      .fadeIn(delay: (200 + i * 100).ms)
                                      .scale(begin: const Offset(0.9, 0.9));
                                }),
                    const SizedBox(height: 32),
                    Text('خدماتنا',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Colors.white)),
                    const SizedBox(height: 20),
                    _LuxuryServiceCard(
                            icon: Icons.local_offer,
                            title: 'لوحات السيارات',
                            subtitle: 'بيع وشراء أرقام المركبات',
                            gradient: [Colors.purple, Colors.pink],
                            onTap: () => context.push('/plates'))
                        .animate()
                        .fadeIn(delay: 300.ms),
                    _LuxuryServiceCard(
                            icon: Icons.shopping_bag,
                            title: 'طلباتي',
                            subtitle: 'تتبع حالة طلباتك',
                            gradient: [Colors.green, Colors.teal],
                            onTap: () => context.push('/my-orders'))
                        .animate()
                        .fadeIn(delay: 400.ms),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.grey[900]!, Colors.black]),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)
            ]),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          elevation: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.blue.withOpacity(0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            if (index == 1) context.push('/search');
            if (index == 2) context.push('/plates');
            if (index == 3) context.push('/account');
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'بحث'),
            NavigationDestination(
                icon: Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer),
                label: 'لوحات'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}

// ✅ شبكة الأقسام
class _LuxuryCategoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'id': '1',
        'icon': Icons.engineering,
        'name': 'محركات',
        'color': Colors.red
      },
      {
        'id': '2',
        'icon': Icons.settings,
        'name': 'فرامل',
        'color': Colors.orange
      },
      {
        'id': '3',
        'icon': Icons.electric_bolt,
        'name': 'كهرباء',
        'color': Colors.amber
      },
      {
        'id': '4',
        'icon': Icons.water_drop,
        'name': 'تبريد',
        'color': Colors.cyan
      },
      {
        'id': '5',
        'icon': Icons.car_crash,
        'name': 'هيكل',
        'color': Colors.purple
      },
      {'id': '6', 'icon': Icons.blur_on, 'name': 'زجاج', 'color': Colors.teal},
      {
        'id': '7',
        'icon': Icons.tire_repair,
        'name': 'إطارات',
        'color': Colors.blue
      },
      {
        'id': '8',
        'icon': Icons.filter_vintage,
        'name': 'فلتر',
        'color': Colors.green
      },
      {
        'id': '9',
        'icon': Icons.battery_charging_full,
        'name': 'بطارية',
        'color': Colors.lime
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95),
      itemCount: categories.length,
      itemBuilder: (ctx, i) => _LuxuryCategoryCard(
        id: categories[i]['id'] as String,
        icon: categories[i]['icon'] as IconData,
        name: categories[i]['name'] as String,
        color: categories[i]['color'] as Color,
        index: i,
        onTap: () => context.push(
            '/category/${categories[i]['id']}?name=${categories[i]['name']}'),
      ),
    );
  }
}

// ✅ بطاقة قسم فاخرة - مصححة
class _LuxuryCategoryCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String name;
  final Color color;
  final int index;
  final VoidCallback onTap;
  const _LuxuryCategoryCard(
      {required this.id,
      required this.icon,
      required this.name,
      required this.color,
      required this.index,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.3), color.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 12),
            Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.95),
                    fontSize: 14,
                    shadows: [
                      Shadow(color: color.withOpacity(0.3), blurRadius: 5)
                    ])),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (150 + index * 80).ms)
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }
}

class _LuxuryServiceCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _LuxuryServiceCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.gradient,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient.map((c) => c.withOpacity(0.15)).toList()),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: gradient[0].withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
                color: gradient[0].withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8))
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
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey[300],
                              height: 1.4,
                              fontSize: 14))
                    ])),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.white))
              ]))),
    );
  }
}

// 🔍 شاشة البحث
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'الكل';
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      var query = SupabaseService.client
          .from('products')
          .select('*')
          .inFilter('status', ['approved', 'active']);
      if (_selectedCategory != 'الكل')
        query = query.eq('category_id', _selectedCategory);
      final searchText = _searchCtrl.text.trim();
      if (searchText.isNotEmpty)
        query = query.or(
            'model.ilike.%$searchText%,brand_id.ilike.%$searchText%,description.ilike.%$searchText%');
      final response = await query.order('created_at', ascending: false);
      setState(() {
        _products = response;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في البحث: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title:
              const Text('البحث الذكي', style: TextStyle(color: Colors.white))),
      body: Column(
        children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        labelText: 'ابحث عن قطعة...',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white),
                                onPressed: () {
                                  setState(() => _searchCtrl.clear());
                                  _fetchProducts();
                                })
                            : null),
                    onChanged: (_) => _fetchProducts()),
                const SizedBox(height: 12),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _buildFilterChip('الكل', 'الكل'),
                      _buildFilterChip('محركات', '1'),
                      _buildFilterChip('فرامل', '2'),
                      _buildFilterChip('كهرباء', '3'),
                      _buildFilterChip('تبريد', '4'),
                      _buildFilterChip('بطارية', '9')
                    ])),
              ])),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue))
                : _products.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(Icons.search_off,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('لا توجد نتائج',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white))
                          ]))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.75),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final product = _products[i];
                          final images = product['images'];
                          final imageUrl = (images is List && images.isNotEmpty)
                              ? images[0].toString()
                              : null;
                          final brandName = product['brand_id'] ?? 'غير محدد';
                          final price = product['price'] ?? 0;
                          final modelName = product['model'] ?? 'بدون موديل';
                          return GestureDetector(
                            onTap: () =>
                                context.push('/product/${product['id']}'),
                            child: Container(
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4))
                                    ]),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(16)),
                                              child: imageUrl != null
                                                  ? Image.network(imageUrl,
                                                      width: double.infinity,
                                                      height: 120,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) =>
                                                          Container(
                                                              color: Colors
                                                                  .grey[800],
                                                              child: const Icon(Icons.image_not_supported,
                                                                  color: Colors
                                                                      .grey,
                                                                  size: 40)))
                                                  : Container(
                                                      color: Colors.grey[800],
                                                      child: const Icon(
                                                          Icons.shopping_bag,
                                                          color: Colors.grey,
                                                          size: 40)))),
                                      Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(modelName,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                        color: Colors.white),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text(brandName,
                                                    style: TextStyle(
                                                        color: Colors.grey[400],
                                                        fontSize: 11)),
                                                const SizedBox(height: 8),
                                                Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                          '\$${price.toString()}',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .green[400],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14)),
                                                      IconButton(
                                                          icon: const Icon(
                                                              Icons
                                                                  .add_shopping_cart,
                                                              color:
                                                                  Colors.blue,
                                                              size: 20),
                                                          onPressed: () {
                                                            _addToCart(context,
                                                                product['id']);
                                                          })
                                                    ])
                                              ]))
                                    ])),
                          )
                              .animate()
                              .fadeIn(delay: (100 + i * 50).ms)
                              .scale(begin: const Offset(0.95, 0.95));
                        }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: FilterChip(
            label: Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300])),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedCategory = value);
              _fetchProducts();
            },
            selectedColor: Colors.blue[700],
            backgroundColor: Colors.grey[800]));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// 📦 شاشة القسم
class CategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  const CategoryScreen(
      {super.key, required this.categoryId, required this.categoryName});
  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('*')
          .eq('category_id', widget.categoryId)
          .inFilter('status', ['approved', 'active']).order('created_at',
              ascending: false);
      setState(() {
        _products = response;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب المنتجات: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(widget.categoryName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _products.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text('لا توجد منتجات في هذا القسم حالياً',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white))
                    ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75),
                  itemCount: _products.length,
                  itemBuilder: (ctx, i) {
                    final p = _products[i];
                    final images = p['images'];
                    final imageUrl = (images is List && images.isNotEmpty)
                        ? images[0].toString()
                        : null;
                    final brandName = p['brand_id'] ?? 'غير محدد';
                    final price = p['price'] ?? 0;
                    final modelName = p['model'] ?? 'بدون موديل';
                    return GestureDetector(
                      onTap: () => context.push('/product/${p['id']}'),
                      child: Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.withOpacity(0.1),
                                    Colors.purple.withOpacity(0.05)
                                  ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5))
                              ]),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(20)),
                                        child: imageUrl != null
                                            ? Image.network(imageUrl,
                                                width: double.infinity,
                                                height: 150,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) =>
                                                    Container(
                                                        color: Colors.grey[800],
                                                        child: const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            color: Colors.grey,
                                                            size: 50)))
                                            : Container(
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                    Icons.shopping_bag,
                                                    color: Colors.grey,
                                                    size: 50)))),
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(modelName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(brandName,
                                              style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 12)),
                                          const SizedBox(height: 8),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('\$${price.toString()}',
                                                    style: const TextStyle(
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16)),
                                                IconButton(
                                                    icon: const Icon(
                                                        Icons.add_shopping_cart,
                                                        color: Colors.blue),
                                                    onPressed: () {
                                                      _addToCart(
                                                          context, p['id']);
                                                    })
                                              ])
                                        ]))
                              ])),
                    )
                        .animate()
                        .fadeIn(delay: (100 + i * 100).ms)
                        .scale(begin: const Offset(0.9, 0.9));
                  }),
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
  int _reviewVersion = 0; // لتحديث التقييمات بعد الإضافة

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  // ✅ دالة لتحديث قسم التقييمات فور الرجوع من صفحة الإضافة
  void _refreshReviews() {
    setState(() => _reviewVersion++);
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
      });
    } catch (e) {
      print('❌ خطأ في جلب التفاصيل: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ دالة التحقق من صلاحية التقييم (نفس الكود الصحيح سابقاً)
  Future<bool> _canUserReview(String productId) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return false;
    try {
      final ordersResponse = await SupabaseService.client
          .from('orders')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', 'delivered');
      if (ordersResponse.isEmpty) return false;

      final orderIds = ordersResponse.map((o) => o['id'] as String).toList();
      final orderItemsResponse = await SupabaseService.client
          .from('order_items')
          .select('product_id')
          .inFilter('order_id', orderIds);

      bool hasPurchasedProduct =
          orderItemsResponse.any((item) => item['product_id'] == productId);
      if (!hasPurchasedProduct) return false;

      final reviewResponse = await SupabaseService.client
          .from('reviews')
          .select('id')
          .eq('user_id', user.id)
          .eq('product_id', productId)
          .limit(1);

      return reviewResponse.isEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(backgroundColor: const Color(0xFF0F172A)),
          body: const Center(
              child: CircularProgressIndicator(color: Colors.blue)));
    if (_product == null)
      return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(backgroundColor: const Color(0xFF0F172A)),
          body: const Center(
              child: Text('المنتج غير موجود',
                  style: TextStyle(color: Colors.white))));

    final p = _product!;
    final images = p['images'];
    final imageUrl =
        (images is List && images.isNotEmpty) ? images[0].toString() : null;
    final brandName = p['brand_id'] ?? 'غير محدد';
    final categoryName = p['category_id'] ?? 'غير محدد';
    final price = p['price'] ?? 0;
    final modelName = p['model'] ?? 'بدون موديل';
    final description = p['description'] ?? 'لا يوجد وصف';
    final condition = p['condition'] ?? 'غير محدد';
    final wheelType = p['wheel_type'];
    final yearFrom = p['year_from'];
    final yearTo = p['year_to'];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                  background: imageUrl != null
                      ? Image.network(imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              Container(color: Colors.grey[800]))
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.shopping_bag,
                              size: 100, color: Colors.grey)))),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)])),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(modelName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('$brandName • $categoryName',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 14)),
                    const SizedBox(height: 16),
                    Text('\$${price.toString()}',
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: (condition == 'new'
                                    ? Colors.green
                                    : condition == 'used'
                                        ? Colors.orange
                                        : Colors.blue)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: condition == 'new'
                                    ? Colors.green
                                    : condition == 'used'
                                        ? Colors.orange
                                        : Colors.blue)),
                        child: Text(
                            condition == 'new'
                                ? 'جديد'
                                : condition == 'used'
                                    ? 'مستعمل'
                                    : 'مجدد',
                            style: TextStyle(
                                color: condition == 'new'
                                    ? Colors.green
                                    : condition == 'used'
                                        ? Colors.orange
                                        : Colors.blue,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(height: 24),
                    if (wheelType != null ||
                        yearFrom != null ||
                        yearTo != null) ...[
                      Text('المواصفات',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (wheelType != null)
                        _buildSpecRow('نوع العجلة', wheelType),
                      if (yearFrom != null || yearTo != null)
                        _buildSpecRow('سنوات التوافق',
                            '${yearFrom ?? '?'} - ${yearTo ?? '?'}'),
                      const SizedBox(height: 24),
                    ],
                    Text('الوصف',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(description,
                        style: TextStyle(
                            color: Colors.grey[300],
                            height: 1.6,
                            fontSize: 14)),
                    const SizedBox(height: 32),

                    // ✅ قسم التقييمات (مصحح: تم إزالة الـ Join مع profiles لتجنب الخطأ)
                    FutureBuilder(
                      key: ValueKey('reviews-$_reviewVersion'),
                      future: SupabaseService.client
                          .from('reviews')
                          .select(
                              '*') // ✅ تم التغيير من profiles(full_name) إلى *
                          .eq('product_id', widget.productId)
                          .order('created_at', ascending: false)
                          .limit(5),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue));
                        }
                        if (snapshot.hasError) {
                          print('❌ خطأ في جلب التقييمات: ${snapshot.error}');
                          return Container();
                        }

                        final reviews = snapshot.data as List? ?? [];
                        final avgRating = reviews.isEmpty
                            ? 0.0
                            : reviews.fold<double>(
                                    0, (sum, r) => sum + (r['rating'] as num)) /
                                reviews.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Colors.grey),
                            Row(
                              children: [
                                Text('⭐ التقييمات',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                if (reviews.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                        '${avgRating.toStringAsFixed(1)} (${reviews.length})',
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (reviews.isEmpty)
                              Text('لا توجد تقييمات بعد',
                                  style: TextStyle(color: Colors.grey[400]))
                            else
                              ...reviews.map((review) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                  '⭐' *
                                                      (review['rating'] as int),
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.amber)),
                                              const Spacer(),
                                              // ✅ عرض "مستخدم" مؤقتاً بدلاً من الربط الخاطئ
                                              Text('مستخدم',
                                                  style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 12)),
                                            ],
                                          ),
                                          if (review['comment'] != null &&
                                              (review['comment'] as String)
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(review['comment'] as String,
                                                style: TextStyle(
                                                    color: Colors.grey[300],
                                                    fontSize: 13)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  )),
                            const SizedBox(height: 16),
                            FutureBuilder<bool>(
                              future: _canUserReview(widget.productId),
                              builder: (context, snapshot) {
                                final canReview = snapshot.data ?? false;
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: canReview
                                        ? () async {
                                            await context.push(
                                                '/add-review?productId=${widget.productId}&productName=${Uri.encodeComponent(modelName)}');
                                            _refreshReviews(); // ✅ تحديث القائمة بعد الرجوع
                                          }
                                        : null,
                                    icon: const Icon(Icons.star_outline),
                                    label: Text(
                                        canReview
                                            ? 'أضف تقييمك'
                                            : 'يجب إتمام الشراء للتقييم',
                                        style: const TextStyle(fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canReview
                                          ? Colors.amber
                                          : Colors.grey[700],
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => _addToCart(context, widget.productId),
                        icon: const Icon(Icons.add_shopping_cart, size: 24),
                        label: const Text('أضف إلى السلة',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text('$label: ',
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500))
        ]));
  }
}
