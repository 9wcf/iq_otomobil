import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

class CartRepository {
  final _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getCartWithProducts() => _client
      .from('cart_items')
      .select('*, products(*, car_brands(name), categories(name))')
      .eq('user_id', _client.auth.currentUser!.id);

  Future<int> getCartCount() async {
    final res = await _client
        .from('cart_items')
        .select('id')
        .eq('user_id', _client.auth.currentUser!.id);
    return res.length;
  }

  Future<void> addToCart(String productId, int quantity) =>
      _client.from('cart_items').upsert({
        'user_id': _client.auth.currentUser!.id,
        'product_id': productId,
        'quantity': quantity
      }, onConflict: 'user_id,product_id');

  Future<void> removeFromCart(String itemId) =>
      _client.from('cart_items').delete().eq('id', itemId);
  Future<void> clearCart() => _client
      .from('cart_items')
      .delete()
      .eq('user_id', _client.auth.currentUser!.id);
}
