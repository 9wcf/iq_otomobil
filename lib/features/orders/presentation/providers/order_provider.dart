import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/features/orders/data/order_repository.dart';

final orderRepoProvider = Provider((ref) => OrderRepository());

// طلبات الزبون
final userOrdersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, userId) => ref.watch(orderRepoProvider).getUserOrders(userId),
);

// ✅ تصحيح: جلب طلبات المروج مع تحديد العلاقة بشكل صحيح
final promoterOrdersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, promoterId) =>
      ref.watch(orderRepoProvider).getPromoterOrders(promoterId),
);

// الإشعارات
final unreadNotificationsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, userId) => ref.watch(orderRepoProvider).getUnreadNotifications(userId),
);

// تحديث حالة الطلب
class OrderActionNotifier extends StateNotifier<AsyncValue<void>> {
  final OrderRepository _repo;
  OrderActionNotifier(this._repo) : super(const AsyncData(null));

  Future<void> updateStatus(String orderId, String status) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _repo.updateOrderStatus(orderId, status));
  }

  Future<void> markNotificationRead(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.markNotificationAsRead(id));
  }
}

final orderActionProvider =
    StateNotifierProvider<OrderActionNotifier, AsyncValue<void>>(
  (ref) => OrderActionNotifier(ref.watch(orderRepoProvider)),
);
