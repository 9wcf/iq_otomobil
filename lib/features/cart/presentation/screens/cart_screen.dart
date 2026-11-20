import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/core/widgets/user_flow_ui.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/cart/presentation/providers/cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  double _totalPrice = 0.0;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client
          .from('cart_items')
          .select(
              'id, quantity, products(id, model, piece_name, price, brand_id, images)')
          .eq('user_id', user.id);

      double total = 0.0;
      for (var item in response) {
        final product = item['products'] as Map?;
        if (product != null) {
          final price = (product['price'] as num? ?? 0).toDouble();
          final qty = (item['quantity'] as num? ?? 1).toInt();
          total += price * qty;
        }
      }

      if (!mounted) return;
      setState(() {
        _cartItems = response;
        _totalPrice = total;
        _isLoading = false;
      });
      ref.read(cartCountNotifierProvider.notifier).reload();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateQuantity(String cartId, int oldQty, int newQty) async {
    if (newQty < 1) {
      await _removeItem(cartId, oldQty);
      return;
    }
    ref.read(cartCountNotifierProvider.notifier).applyDelta(newQty - oldQty);
    try {
      await SupabaseService.client
          .from('cart_items')
          .update({'quantity': newQty}).eq('id', cartId);
      _loadCart();
    } catch (_) {
      ref.read(cartCountNotifierProvider.notifier).reload();
    }
  }

  Future<void> _removeItem(String cartId, int qty) async {
    ref.read(cartCountNotifierProvider.notifier).applyDelta(-qty);
    try {
      await SupabaseService.client.from('cart_items').delete().eq('id', cartId);
      if (mounted) {
        _loadCart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف من السلة'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (_) {
      ref.read(cartCountNotifierProvider.notifier).reload();
    }
  }

  Future<void> _clearCart(String userId) async {
    setState(() => _clearing = true);
    ref.read(cartCountNotifierProvider.notifier).set(0);
    await SupabaseService.client
        .from('cart_items')
        .delete()
        .eq('user_id', userId);
    await _loadCart();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفريغ السلة'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
      setState(() => _clearing = false);
    }
  }

  String _money(num n) => formatIQD(n);

  @override
  Widget build(BuildContext context) {
    // هذه الشاشة تبقى حيّة كتبويب دائم (IndexedStack)، فـ initState لا يُعاد تشغيله
    // عند التبديل إليها. نستمع لإبطال cartItemsProvider (يحدث عند الإضافة من أي
    // صفحة أخرى) لإعادة تحميل قائمة السلة فوراً بدل انتظار إعادة فتح التطبيق.
    ref.listen(cartItemsProvider, (previous, next) {
      if (mounted) _loadCart();
    });

    final user = SupabaseService.currentUserInfo;
    if (user == null) {
      Future.microtask(() {
        if (context.mounted) context.go('/auth');
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final hasItems = !_isLoading && _cartItems.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: UserFlowAppBar(
        title: 'سلة الطلبات',
        actions: hasItems
            ? [
                TextButton.icon(
                  onPressed: _clearing ? null : () => _clearCart(user.id),
                  icon: _clearing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                        ),
                  label: Text(_clearing ? '...' : 'تفريغ'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ]
            : null,
      ),
      body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _cartItems.isEmpty
                ? UserFlowEmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'سلتك فارغة حالياً',
                    subtitle: 'تصفّح المنتجات وأضف ما تحتاجه للسلة',
                    actionLabel: 'تصفح المنتجات',
                    onAction: () => context.push('/search'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            userFlowScreenScrollBottomPadding(context) + 8,
                          ),
                        itemCount: _cartItems.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final item = _cartItems[index];
                          final product = item['products'] as Map?;
                          if (product == null) {
                            return const SizedBox.shrink();
                          }

                          final productMap =
                              Map<String, dynamic>.from(product);
                          final name = productDisplayTitle(productMap);
                          final brand =
                              (productMap['brand_id'] ?? 'غير محدد')
                                  .toString();
                          final price =
                              (productMap['price'] as num? ?? 0).toDouble();
                          final qty =
                              (item['quantity'] as num? ?? 1).toInt();
                          final images = productMap['images'];
                          final imageUrl =
                              (images is List && images.isNotEmpty)
                                  ? images[0].toString()
                                  : null;

                          return _CartItemCard(
                            name: name,
                            brand: brand,
                            lineTotal: _money(price * qty),
                            imageUrl: imageUrl,
                            qty: qty,
                            onMinus: () =>
                                _updateQuantity(item['id'], qty, qty - 1),
                            onPlus: () =>
                                _updateQuantity(item['id'], qty, qty + 1),
                            onRemove: () => _removeItem(item['id'], qty),
                          );
                        },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: UserFlowSummaryBar(
                          totalLabel: 'المجموع الكلي',
                          totalValue: _money(_totalPrice),
                          buttonLabel: 'إتمام الشراء',
                          icon: Icons.shopping_bag_outlined,
                          onPressed: () => context.push('/checkout'),
                        ),
                      ),
                    ],
                  ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.name,
    required this.brand,
    required this.lineTotal,
    required this.imageUrl,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final String name;
  final String brand;
  final String lineTotal;
  final String? imageUrl;
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: userFlowCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      memCacheHeight: 160,
                      placeholder: (_, __) => const _ImgPlaceholder(),
                      errorWidget: (_, __, ___) => const _ImgPlaceholder(),
                    )
                  : const _ImgPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  lineTotal,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyControl(
                      qty: qty,
                      onMinus: onMinus,
                      onPlus: onPlus,
                    ),
                    const Spacer(),
                    Material(
                      color: AppColors.error.withValues(alpha: 0.08),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onRemove,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.inputFill,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.muted.withValues(alpha: 0.8),
        size: 28,
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: AppColors.primary,
            onPressed: onMinus,
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.add_rounded, size: 18),
            color: AppColors.primary,
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}
