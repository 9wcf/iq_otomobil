import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client
          .from('cart_items')
          .select('id, quantity, products(id, model, price, brand_id, images)')
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
    } catch (e) {
      print('❌ خطأ في تحميل السلة: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToCart(String productId) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

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
      if (mounted) {
        _loadCart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ تمت الإضافة للسلة'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateQuantity(String cartId, int newQty) async {
    if (newQty < 1) {
      await _removeItem(cartId);
      return;
    }
    try {
      await SupabaseService.client
          .from('cart_items')
          .update({'quantity': newQty}).eq('id', cartId);
      _loadCart();
    } catch (e) {
      print('❌ خطأ في تعديل الكمية: $e');
    }
  }

  Future<void> _removeItem(String cartId) async {
    try {
      await SupabaseService.client.from('cart_items').delete().eq('id', cartId);
      if (mounted) {
        _loadCart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🗑️ تم الحذف من السلة'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('❌ خطأ في الحذف: $e');
    }
  }

  // ✅ حساب عدد العناصر في السلة (للـ Badge)
  int get cartItemCount => _cartItems.fold<int>(
      0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1));

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      Future.microtask(() {
        if (context.mounted) context.go('/auth');
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('سلة المشتريات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: () async {
                await SupabaseService.client
                    .from('cart_items')
                    .delete()
                    .eq('user_id', user.id);
                _loadCart();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('🧹 تم تفريغ السلة'),
                        backgroundColor: Colors.grey),
                  );
                }
              },
              child: const Text('تفريغ',
                  style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _cartItems.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        itemBuilder: (ctx, index) {
                          final item = _cartItems[index];
                          final product = item['products'] as Map?;
                          if (product == null) return const SizedBox.shrink();

                          final name = product['model'] ?? 'منتج';
                          final brand = product['brand_id'] ?? 'غير محدد';
                          final price =
                              (product['price'] as num? ?? 0).toDouble();
                          final qty = (item['quantity'] as num? ?? 1).toInt();
                          final images = product['images'];
                          final imageUrl = (images is List && images.isNotEmpty)
                              ? images[0].toString()
                              : null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl != null
                                      ? Image.network(
                                          imageUrl,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[800]!,
                                            child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.white),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[800]!,
                                          child: const Icon(Icons.shopping_bag,
                                              color: Colors.white, size: 40),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(brand,
                                          style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                              '\$${(price * qty).toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                          const Spacer(),
                                          Container(
                                            decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                    icon: const Icon(
                                                        Icons.remove,
                                                        color: Colors.white,
                                                        size: 20),
                                                    onPressed: () =>
                                                        _updateQuantity(
                                                            item['id'],
                                                            qty - 1)),
                                                Text('$qty',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                IconButton(
                                                    icon: const Icon(Icons.add,
                                                        color: Colors.white,
                                                        size: 20),
                                                    onPressed: () =>
                                                        _updateQuantity(
                                                            item['id'],
                                                            qty + 1)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () => _removeItem(item['id'])),
                              ],
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms);
                        },
                      ),
                    ),
                    // ✅ ملخص الطلب وزر إتمام الشراء
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, -5))
                          ]),
                      child: Column(
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المجموع الكلي',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                                Text('\$${_totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                              ]),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              // ✅ التعديل هنا: الانتقال الفعلي لصفحة إتمام الطلب
                              onPressed: () => context.push('/checkout'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16))),
                              child: const Text('إتمام الشراء',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 100, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('سلتك فاضية حالياً',
              style: TextStyle(color: Colors.grey[400], fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            label: const Text('تصفح المنتجات'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
