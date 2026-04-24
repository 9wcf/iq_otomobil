import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

class OrderRepository {
  final _client = SupabaseService.client;

  /// إتمام الطلب (Checkout)
  Future<void> checkout({
    required List<Map<String, dynamic>> cartItems,
    required String address,
    required String phone,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final orders = cartItems.map((item) {
      final product = item['products'] as Map<String, dynamic>;
      return {
        'user_id': userId,
        'promoter_id': product['promoter_id'],
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'full_address': address,
        'phone': phone,
        'notes': notes,
        'status': 'pending_promoter_review',
      };
    }).toList();

    await _client.from('orders').insert(orders);
    await _client.from('cart_items').delete().eq('user_id', userId);
  }

  /// جلب طلبات الزبون
  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final ordersResponse = await _client
        .from('orders')
        .select('*, products(*, car_brands(name))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    // جلب بيانات المستخدمين بشكل منفصل
    final orders = ordersResponse;
    for (var order in orders) {
      final profileResponse = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', order['user_id'])
          .maybeSingle();

      if (profileResponse != null) {
        order['user_profile'] = profileResponse;
      }
    }

    return orders;
  }

  /// ✅ تصحيح: جلب طلبات المروج بدون استخدام العلاقات المضمنة
  Future<List<Map<String, dynamic>>> getPromoterOrders(
      String promoterId) async {
    // جلب الطلبات أولاً
    final ordersResponse = await _client
        .from('orders')
        .select('*, products(*, car_brands(name))')
        .eq('promoter_id', promoterId)
        .eq('status', 'pending_promoter_review')
        .order('created_at', ascending: false);

    // جلب بيانات الزبائن بشكل منفصل
    final orders = ordersResponse;
    for (var order in orders) {
      final profileResponse = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', order['user_id'])
          .maybeSingle();

      if (profileResponse != null) {
        order['user_profile'] = profileResponse;
      }
    }

    return orders;
  }

  /// تحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _client.from('orders').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', orderId);
  }

  /// الاستماع للتحديثات الفورية (Realtime)
  Stream<Map<String, dynamic>> orderStatusStream(String orderId) => _client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('id', orderId)
      .map((event) => event.first);

  /// جلب الإشعارات غير المقروءة
  Future<List<Map<String, dynamic>>> getUnreadNotifications(String userId) =>
      _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('read', false)
          .order('created_at', ascending: false);

  /// وضع علامة "مقروء" على الإشعار
  Future<void> markNotificationAsRead(String notificationId) => _client
      .from('notifications')
      .update({'read': true}).eq('id', notificationId);
}
