import 'package:iq_otomobil/core/services/supabase_service.dart';

class OrderRepository {
  final _client = SupabaseService.client;

  Future<void> checkout({
    required List<Map<String, dynamic>> cartItems,
    required String address,
    required String phone,
    String? notes,
  }) async {
    final userId = SupabaseService.currentUserId!;
    final orders = cartItems
        .map((item) => {
              'user_id': userId,
              'promoter_id': item['products']['promoter_id'],
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'full_address': address,
              'phone': phone,
              'notes': notes,
              'status': 'pending_promoter_review',
            })
        .toList();

    await _client.from('orders').insert(orders);
    await _client.from('cart_items').delete().eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getOrders(
      {String? userId, String? promoterId}) {
    var q = _client.from('orders').select('*, products(*, car_brands(name))');
    if (userId != null) q = q.eq('user_id', userId);
    if (promoterId != null) q = q.eq('promoter_id', promoterId);
    return q.order('created_at', ascending: false);
  }

  Future<void> updateStatus(String orderId, String status) =>
      _client.from('orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', orderId);
}
