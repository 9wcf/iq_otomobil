import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class PromoterDashboard extends StatefulWidget {
  const PromoterDashboard({super.key});

  @override
  State<PromoterDashboard> createState() => _PromoterDashboardState();
}

class _PromoterDashboardState extends State<PromoterDashboard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _printUserInfo();
    _loadData();
  }

  // ✅ طباعة معلومات المستخدم للتأكد من الصلاحية
  void _printUserInfo() {
    final user = SupabaseService.client.auth.currentUser;
    print('👤 المستخدم الحالي: ${user?.id}');
    print('📧 البريد: ${user?.email}');
  }

  Future<void> _loadData() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      print('❌ المستخدم غير مسجل دخول');
      return;
    }

    print('🔄 جاري جلب الطلبات للمروج: ${user.id}');
    setState(() => _isLoading = true);

    try {
      // جلب الطلبات
      final ordersRes = await SupabaseService.client
          .from('orders')
          .select(
              '*, user_profiles:profiles!user_id(full_name, email), order_items(*, products(model, price))')
          .eq('promoter_id', user.id)
          .order('created_at', ascending: false);

      print('✅ عدد الطلبات: ${ordersRes.length}');

      // جلب الإشعارات
      final notificationsRes = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      setState(() {
        _orders = ordersRes;
        _notificationCount = notificationsRes.length;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب البيانات: $e');
      setState(() {
        _orders = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await SupabaseService.client
          .from('orders')
          .update({'status': newStatus}).eq('id', orderId);

      // إشعار المستخدم
      final order = _orders.firstWhere((o) => o['id'] == orderId);
      await SupabaseService.client.from('notifications').insert({
        'user_id': order['user_id'],
        'title': '📦 تحديث الطلب',
        'message': 'تم ${_getStatusText(newStatus)} طلبك',
        'type': 'order',
      });

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تغيير الحالة إلى: ${_getStatusText(newStatus)}'),
            backgroundColor: _getStatusColor(newStatus),
          ),
        );
      }
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      // ✅ AppBar مع الأزرار
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'طلبات المروج',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          // زر الإشعارات
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white, size: 28),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(' لديك $_notificationCount إشعارات جديدة')),
                  );
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // زر التحديث
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),

      // ✅ جسم الصفحة
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 100,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'لا توجد طلبات حالياً',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'بمجرد وصول طلب جديد، سيظهر هنا',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (ctx, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order, index);
                  },
                ),

      // ✅ زر إضافة المنتج العائم - مهم جداً!
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print('🔘 الضغط على زر إضافة منتج');
          context.push('/add-product');
        },
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_business, size: 24),
        label: const Text(
          'إضافة منتج',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 8,
      ),
    );
  }

  // ✅ بناء بطاقة الطلب
  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final status = order['status'] ?? 'pending';
    final total = order['total_price'] ?? 0;
    final address = order['shipping_address'] ?? 'بدون عنوان';
    final phone = order['phone_number'] ?? 'بدون هاتف';
    final orderItems = order['order_items'] as List? ?? [];
    final userProfile = order['user_profiles'] as Map?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(status), width: 2),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رقم الطلب والحالة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلب #${order['id'].toString().substring(0, 8)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(status)),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // معلومات العميل
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'معلومات العميل',
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('📧 ${userProfile?['email'] ?? "غير متوفر"}',
                    style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                Text('📱 $phone',
                    style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                Text('📍 $address',
                    style: TextStyle(color: Colors.grey[300], fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // المنتجات
          const Text('📦 المنتجات',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          ...orderItems.map((item) {
            final product = item['products'] as Map?;
            final qty = item['quantity'] as num? ?? 1;
            final price = item['price'] as num? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${product?['model'] ?? 'منتج'} (x$qty)',
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                  ),
                  Text(
                    '\$${(price * qty).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(color: Colors.grey, height: 32),

          // المجموع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع الكلي',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // أزرار التحكم
          _buildActionButtons(order),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
  }

  // ✅ أزرار التحكم بالحالة
  Widget _buildActionButtons(Map<String, dynamic> order) {
    final status = order['status'];
    final orderId = order['id'];

    switch (status) {
      case 'pending':
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
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'processing'),
            icon: const Icon(Icons.local_shipping, size: 20),
            label: const Text('بدء التجهيز', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      case 'processing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'shipped'),
            icon: const Icon(Icons.delivery_dining, size: 20),
            label: const Text('تم الشحن', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
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

      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Text(
                'تم إكمال الطلب بنجاح ✅',
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
        );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      case 'processing':
        return 'قيد التجهيز';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      default:
        return status;
    }
  }
}
