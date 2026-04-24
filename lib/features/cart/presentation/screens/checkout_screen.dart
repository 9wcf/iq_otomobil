import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _cartItems = [];
  double _totalPrice = 0.0;
  String? _promoterId;

  @override
  void initState() {
    super.initState();
    _loadCartSummary();
  }

  Future<void> _loadCartSummary() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await SupabaseService.client
          .from('cart_items')
          .select(
              'id, quantity, products(id, model, price, promoter_id, images)')
          .eq('user_id', user.id);

      double total = 0.0;
      for (var item in res) {
        final product = item['products'] as Map?;
        if (product != null) {
          total +=
              (product['price'] as num).toDouble() * (item['quantity'] as num);
          if (_promoterId == null) _promoterId = product['promoter_id'];
        }
      }

      setState(() {
        _cartItems = res;
        _totalPrice = total;
      });
    } catch (e) {
      print('❌ خطأ في تحميل ملخص السلة: $e');
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cartItems.isEmpty) return;

    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseService.client;

      // 1. إنشاء الطلب
      final orderRes = await supabase
          .from('orders')
          .insert({
            'user_id': user.id,
            'promoter_id': _promoterId,
            'status': 'pending',
            'total_price': _totalPrice,
            'shipping_address': _addressCtrl.text.trim(),
            'phone_number': _phoneCtrl.text.trim(),
            'notes':
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          })
          .select()
          .single();

      // 2. إضافة عناصر الطلب
      List<Map<String, dynamic>> itemsData = _cartItems
          .map((item) => {
                'order_id': orderRes['id'],
                'product_id': item['product_id'],
                'quantity': item['quantity'],
                'price': (item['products'] as Map)['price'],
              })
          .toList();
      await supabase.from('order_items').insert(itemsData);

      // 3. تفريغ السلة
      await supabase.from('cart_items').delete().eq('user_id', user.id);

      // 4. إشعار للمروج
      await supabase.from('notifications').insert({
        'user_id': _promoterId,
        'title': '📦 طلب جديد وارد!',
        'message':
            'طلب بقيمة \$${_totalPrice.toStringAsFixed(2)} بانتظار موافقتك.',
        'type': 'order',
      });

      // 5. إشعار للمستخدم (تأكيد الاستلام)
      await supabase.from('notifications').insert({
        'user_id': user.id,
        'title': '✅ تم استلام طلبك',
        'message': 'جاري مراجعة طلبك من قبل المروج. سنبلغك فور الموافقة.',
        'type': 'order',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 تم تأكيد الطلب بنجاح!'),
              backgroundColor: Colors.green),
        );
        context.go('/account'); // أو صفحة التتبع لاحقاً
      }
    } catch (e) {
      print('❌ خطأ في إتمام الطلب: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ فشل إتمام الطلب: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      Future.microtask(() => context.go('/auth'));
      return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: CircularProgressIndicator(color: Colors.blue)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('إتمام الطلب',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ملخص الطلب
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.blue.withOpacity(0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📋 ملخص الطلب',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ..._cartItems.map((item) {
                            final product = item['products'] as Map?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          '${product?['model'] ?? 'منتج'} (x${item['quantity']})',
                                          style: const TextStyle(
                                              color: Colors.grey[300]))),
                                  Text(
                                      '\$${((product?['price'] as num?) ?? 0) * (item['quantity'] as num)}',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(color: Colors.grey),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المجموع الكلي',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('\$${_totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(),

                    const SizedBox(height: 24),
                    const Text('📍 معلومات التوصيل',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'عنوان التوصيل الكامل',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon:
                            const Icon(Icons.location_on, color: Colors.blue),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'العنوان مطلوب' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon:
                            const Icon(Icons.phone, color: Colors.green),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.trim().isEmpty
                          ? 'رقم الهاتف مطلوب'
                          : (v.length < 7 ? 'رقم غير صحيح' : null),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.note, color: Colors.amber),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _submitOrder,
                        icon: const Icon(Icons.check_circle, size: 24),
                        label: const Text('تأكيد وإرسال الطلب',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}
