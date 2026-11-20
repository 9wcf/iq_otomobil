import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/orders/domain/order_status_display.dart';

/// قائمة طلبات المروج (صفحة منفصلة عن لوحة التاجر).
class PromoterRequestsScreen extends StatefulWidget {
  const PromoterRequestsScreen({super.key});

  @override
  State<PromoterRequestsScreen> createState() => _PromoterRequestsScreenState();
}

class _PromoterRequestsScreenState extends State<PromoterRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final ordersRes = await SupabaseService.client
          .from('orders')
          .select(
              '*, user_profiles:profiles!user_id(full_name), order_items(*, products(id, model, piece_name, price, images, description))')
          .eq('promoter_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(ordersRes);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الطلبات: $e')),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await SupabaseService.client
          .from('orders')
          .update({'status': newStatus}).eq('id', orderId);

      final order = _orders.firstWhere((o) => o['id'] == orderId);
      await SupabaseService.client.from('notifications').insert({
        'user_id': order['user_id'],
        'title': 'تحديث الطلب',
        'message':
            'حالة طلبك الآن: ${OrderStatusDisplay.label(newStatus)}',
        'type': 'order',
      });

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم تغيير الحالة إلى: ${OrderStatusDisplay.label(newStatus)}'),
            backgroundColor: OrderStatusDisplay.accentColor(newStatus),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  static String _shortOrderId(dynamic id) {
    final s = id?.toString() ?? '';
    if (s.length <= 8) return s;
    return s.substring(0, 8);
  }

  static String _formatAddress(dynamic raw) {
    if (raw == null) return '—';
    if (raw is Map) {
      final g = raw['governorate']?.toString();
      final c = raw['city']?.toString();
      final d = raw['details']?.toString() ?? raw['detail']?.toString();
      final dist = raw['district']?.toString();
      final parts = <String>[];
      if (g != null && g.isNotEmpty) parts.add(g);
      if (c != null && c.isNotEmpty) parts.add(c);
      if (dist != null && dist.isNotEmpty) parts.add(dist);
      if (d != null && d.isNotEmpty) parts.add(d);
      return parts.isEmpty ? '—' : parts.join(' · ');
    }
    final str = raw.toString().trim();
    if (str.startsWith('{')) {
      try {
        final m = jsonDecode(str);
        if (m is Map<String, dynamic>) return _formatAddress(m);
      } catch (_) {}
    }
    return str.isEmpty ? '—' : str;
  }

  static String _resolvePhone(Map<String, dynamic> order) {
    final direct = order['phone_number'];
    if (direct != null &&
        direct.toString().trim().isNotEmpty &&
        direct.toString() != 'بدون هاتف') {
      return direct.toString();
    }
    final addr = order['shipping_address'];
    if (addr is Map && addr['phone'] != null) {
      return addr['phone'].toString();
    }
    if (addr is String && addr.trim().startsWith('{')) {
      try {
        final m = jsonDecode(addr) as Map<String, dynamic>;
        if (m['phone'] != null) return m['phone'].toString();
      } catch (_) {}
    }
    return 'بدون هاتف';
  }

  static double _computeTotal(
      Map<String, dynamic> order, List<dynamic> orderItems) {
    final tp = order['total_price'];
    if (tp != null) {
      final n = (tp as num?)?.toDouble();
      if (n != null && n > 0) return n;
    }
    double sum = 0;
    for (final item in orderItems) {
      final map = item as Map<String, dynamic>;
      final price = (map['price'] as num?)?.toDouble() ?? 0;
      final qty = (map['quantity'] as num?)?.toInt() ?? 1;
      sum += price * qty;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/promoter'),
        ),
        title: const Text(
          'طلبات المروج',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 80, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد طلبات حالياً',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'عند وصول طلب جديد سيظهر هنا',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _orders.length,
                  itemBuilder: (ctx, index) =>
                      _buildOrderCard(_orders[index], index),
                ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final status = order['status']?.toString() ?? 'pending';
    final orderItems = order['order_items'] as List? ?? [];
    final total = _computeTotal(order, orderItems);
    final addressRaw = order['shipping_address'];
    final address = _formatAddress(addressRaw);
    final phone = _resolvePhone(order);
    final userProfile = order['user_profiles'] as Map?;
    final customerName =
        (userProfile?['full_name'] ?? '').toString().trim();
    final notes = (order['notes'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: OrderStatusDisplay.accentColor(status), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'طلب #${_shortOrderId(order['id'])}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: OrderStatusDisplay.accentColor(status)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: OrderStatusDisplay.accentColor(status)),
                  ),
                  child: Text(
                    OrderStatusDisplay.label(status),
                    style: TextStyle(
                      color: OrderStatusDisplay.accentColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'معلومات العميل',
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (customerName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '👤 $customerName',
                      style: TextStyle(color: Colors.grey[300], fontSize: 13),
                    ),
                  ),
                Text(
                  '📱 $phone',
                  style: TextStyle(color: Colors.grey[300], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 $address',
                  style: TextStyle(color: Colors.grey[300], fontSize: 13),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '📝 ملاحظة العميل: $notes',
                    style: TextStyle(
                      color: Colors.amber[100],
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'المنتجات',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...orderItems.map((item) {
            final map = item as Map<String, dynamic>;
            final product = map['products'] as Map?;
            final productMap = product != null
                ? Map<String, dynamic>.from(product)
                : <String, dynamic>{};
            final qty = (map['quantity'] as num?)?.toInt() ?? 1;
            final unit = (map['price'] as num?)?.toDouble() ??
                (productMap['price'] as num?)?.toDouble() ??
                0.0;
            final line = unit * qty;
            final title = productMap.isNotEmpty
                ? productDisplayTitle(productMap)
                : 'منتج';
            final desc =
                productMap['description']?.toString().trim() ?? '';
            final images = productMap['images'];
            final imageUrl = (images is List && images.isNotEmpty)
                ? images.first?.toString()
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: imageUrl == null || imageUrl.isEmpty
                            ? Container(
                                color: Colors.white.withValues(alpha: 0.06),
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.white38,
                                  size: 22,
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, __, ___) => Container(
                                  color:
                                      Colors.white.withValues(alpha: 0.06),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white38,
                                    size: 22,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                                height: 1.25,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'السعر: ${formatIQD(unit)}  ·  الكمية: $qty  ·  المجموع: ${formatIQD(line)}',
                            style: const TextStyle(
                              color: Color(0xFF86EFAC),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(color: Colors.white24, height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المجموع الكلي',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                formatIQD(total),
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionButtons(order),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms, delay: (40 * index).ms);
  }

  Widget _buildActionButtons(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final orderId = order['id'];

    switch (status) {
      case 'cancelled':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.grey[300], size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  OrderStatusDisplay.label('cancelled'),
                  style: TextStyle(
                    color: Colors.grey[200],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'pending':
      case 'pending_promoter_review':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(orderId, 'approved'),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('موافقة', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(orderId, 'rejected'),
                icon: const Icon(Icons.cancel, size: 20),
                label: const Text('رفض', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );

      case 'approved':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'shipped'),
              icon: const Icon(Icons.local_shipping, size: 20),
              label: const Text('تم الشحن', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'cancelled'),
              icon: const Icon(Icons.block_rounded, size: 20),
              label: const Text('إلغاء الطلب', style: TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );

      case 'shipped':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'delivered'),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('تم التسليم', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case 'rejected':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined,
                  color: Colors.redAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  OrderStatusDisplay.label('rejected'),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  OrderStatusDisplay.label('delivered'),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            'حالة غير متوقعة: $status',
            style: const TextStyle(color: Colors.white70),
          ),
        );
    }
  }
}
