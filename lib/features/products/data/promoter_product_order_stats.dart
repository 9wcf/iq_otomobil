/// تجميع طلبات المنتج (عدد الطلبات حسب الحالة + إجمالي الكمية).
class PromoterProductOrderStats {
  PromoterProductOrderStats({
    required this.totalUnits,
    required this.ordersByStatus,
  });

  /// مجموع الكميات في order_items لهذا المنتج.
  final int totalUnits;

  /// لكل حالة طلب: عدد الطلبات التي تضم هذا المنتج (الطلب له حالة واحدة).
  final Map<String, int> ordersByStatus;

  /// إجمالي عدد الطلبات التي ضمنت هذا المنتج.
  int get totalOrders =>
      ordersByStatus.values.fold<int>(0, (a, b) => a + b);
}

/// تجميع من صفوف order_items + حالات orders.
Map<String, PromoterProductOrderStats> aggregateProductOrderStats({
  required List<Map<String, dynamic>> orders,
  required List<Map<String, dynamic>> orderItems,
}) {
  final orderStatusById = <String, String>{};
  for (final o in orders) {
    final id = o['id']?.toString();
    if (id == null) continue;
    orderStatusById[id] = o['status']?.toString() ?? 'unknown';
  }

  /// productId -> status -> set(orderId)
  final acc = <String, Map<String, Set<String>>>{};
  final units = <String, int>{};

  for (final row in orderItems) {
    final pid = row['product_id']?.toString();
    final oid = row['order_id']?.toString();
    if (pid == null || oid == null) continue;
    final st = orderStatusById[oid] ?? 'unknown';
    final q = (row['quantity'] as num?)?.toInt() ?? 0;

    units[pid] = (units[pid] ?? 0) + q;
    acc.putIfAbsent(pid, () => {});
    acc[pid]!.putIfAbsent(st, () => <String>{});
    acc[pid]![st]!.add(oid);
  }

  final out = <String, PromoterProductOrderStats>{};
  for (final entry in acc.entries) {
    final byStatus = <String, int>{};
    for (final e2 in entry.value.entries) {
      byStatus[e2.key] = e2.value.length;
    }
    out[entry.key] = PromoterProductOrderStats(
      totalUnits: units[entry.key] ?? 0,
      ordersByStatus: byStatus,
    );
  }
  return out;
}

String orderStatusLabelAr(String status) {
  return switch (status) {
    'pending' => 'قيد الانتظار',
    'pending_promoter_review' => 'بانتظار المروج',
    'approved' => 'مقبول',
    'rejected' => 'مرفوض',
    'processing' => 'قيد التجهيز',
    'shipped' => 'تم الشحن',
    'delivered' => 'تم التسليم',
    'cancelled' => 'ملغي',
    'unknown' => 'غير معروف',
    _ => status,
  };
}

/// تلخيص حالات **الطلب** لعرض ثابت في واجهة المروج: ملغي / قيد الانتظار / تم التسليم.
class ProductOrderBuckets {
  const ProductOrderBuckets({
    required this.cancelled,
    required this.pending,
    required this.delivered,
    required this.totalUnits,
  });

  /// طلبات ملغاة + مرفوضة.
  final int cancelled;

  /// باقي الطلبات (بانتظار المروج، تجهيز، شحن…).
  final int pending;

  final int delivered;
  final int totalUnits;
}

ProductOrderBuckets bucketProductOrderStats(PromoterProductOrderStats? s) {
  if (s == null || s.ordersByStatus.isEmpty) {
    return const ProductOrderBuckets(
      cancelled: 0,
      pending: 0,
      delivered: 0,
      totalUnits: 0,
    );
  }
  final m = s.ordersByStatus;
  final d = m['delivered'] ?? 0;
  final c = (m['cancelled'] ?? 0) + (m['rejected'] ?? 0);
  var p = s.totalOrders - d - c;
  if (p < 0) p = 0;
  return ProductOrderBuckets(
    cancelled: c,
    pending: p,
    delivered: d,
    totalUnits: s.totalUnits,
  );
}
