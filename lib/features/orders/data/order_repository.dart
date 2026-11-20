import 'package:iq_otomobil/core/services/supabase_service.dart';

class OrderRepository {
  final _client = SupabaseService.client;

  /// جلب طلبات الزبون
  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final res = await _client
        .from('orders')
        .select(
            '*, order_items(quantity, price, products(*, car_brands(name)))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// جلب طلبات المروج (المعلقة أولاً)
  Future<List<Map<String, dynamic>>> getPromoterOrders(String promoterId) async {
    final res = await _client
        .from('orders')
        .select(
            '*, user_profiles:profiles!user_id(full_name, phone, email), order_items(quantity, price, products(*, car_brands(name)))')
        .eq('promoter_id', promoterId)
        .inFilter('status', ['pending', 'pending_promoter_review'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
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
          .eq('is_read', false)
          .order('created_at', ascending: false);

  /// وضع علامة "مقروء" على الإشعار
  Future<void> markNotificationAsRead(String notificationId) => _client
      .from('notifications')
      .update({'is_read': true}).eq('id', notificationId);
}
