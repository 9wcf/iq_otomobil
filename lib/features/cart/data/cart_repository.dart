import 'package:iq_otomobil/core/services/supabase_service.dart';

class CartRepository {
  final _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getCartWithProducts() => _client
      .from('cart_items')
      .select('*, products(*, car_brands(name), categories(name))')
      .eq('user_id', SupabaseService.currentUserId!);

  /// مجموع **الكميات** في السلة (نفس منطق badge الشاشة الرئيسية).
  Future<int> getCartCount() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return 0;
    final res = await _client
        .from('cart_items')
        .select('quantity')
        .eq('user_id', uid);
    return res.fold<int>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1),
    );
  }

  Future<void> addToCart(String productId, int quantity) =>
      _client.from('cart_items').upsert({
        'user_id': SupabaseService.currentUserId!,
        'product_id': productId,
        'quantity': quantity
      }, onConflict: 'user_id,product_id');

  Future<void> removeFromCart(String itemId) =>
      _client.from('cart_items').delete().eq('id', itemId);
  Future<void> clearCart() => _client
      .from('cart_items')
      .delete()
      .eq('user_id', SupabaseService.currentUserId!);
}
