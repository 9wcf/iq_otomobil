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

  // ✅ دالة substring آمنة
  String _safeSubstring(String text, int start, int end) {
    if (text.isEmpty || text.length <= start) return '';
    return text.substring(start, text.length < end ? text.length : end);
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

      print('🛒 عناصر السلة: ${res.length}');

      double total = 0.0;
      for (var item in res) {
        final product = item['products'] as Map?;
        if (product != null) {
          total +=
              (product['price'] as num).toDouble() * (item['quantity'] as num);
          if (_promoterId == null && product['promoter_id'] != null) {
            _promoterId = product['promoter_id'] as String;
            print('🎯 promoter_id: $_promoterId');
          }
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ يرجى ملء جميع الحقول المطلوبة'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ السلة فارغة'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_promoterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ لم يتم تحديد المروج'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ يرجى تسجيل الدخول'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseService.client;

      print('📦 جاري إنشاء الطلب...');

      // 1. إنشاء الطلب الرئيسي
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

      print('✅ تم إنشاء الطلب: ${orderRes['id']}');

      // 2. إضافة عناصر الطلب (كل عنصر على حدة لتجنب مشاكل RLS)
      for (var item in _cartItems) {
        final product = item['products'] as Map;
        final orderItemData = {
          'order_id': orderRes['id'],
          'product_id': product['id'],
          'quantity': item['quantity'],
          'price': product['price'],
        };

        print('➕ إضافة عنصر: ${product['model']}');

        final result =
            await supabase.from('order_items').insert(orderItemData).select();

        if (result.isEmpty) {
          throw Exception('فشل إضافة المنتج: ${product['model']}');
        }
      }

      print('✅ تمت إضافة ${_cartItems.length} عناصر للطلب');

      // 3. تفريغ السلة
      await supabase.from('cart_items').delete().eq('user_id', user.id);
      print('🧹 تم تفريغ السلة');

      // 4. إشعار للمروج
      final addressPreview = _safeSubstring(_addressCtrl.text.trim(), 0, 20);
      await supabase.from('notifications').insert({
        'user_id': _promoterId,
        'title': '📦 طلب جديد وارد!',
        'message':
            'طلب بقيمة \$${_totalPrice.toStringAsFixed(2)} من ${addressPreview.isNotEmpty ? "$addressPreview..." : "مستخدم جديد"}',
        'type': 'order',
      });
      print('🔔 إشعار مرسل للمروج');

      // 5. إشعار للمستخدم
      final orderIdShort = _safeSubstring(orderRes['id'].toString(), 0, 8);
      await supabase.from('notifications').insert({
        'user_id': user.id,
        'title': '✅ تم استلام طلبك',
        'message':
            'طلبك #${orderIdShort.isNotEmpty ? orderIdShort : "جديد"} جاري المراجعة.',
        'type': 'order',
      });
      print('🔔 إشعار تأكيد مرسل للمستخدم');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 تم تأكيد الطلب بنجاح!'),
              backgroundColor: Colors.green),
        );
        // انتظر قليلاً ثم ارجع
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          context.go('/account');
        }
      }
    } catch (e) {
      print('❌ خطأ فادح في إتمام الطلب: $e');
      print('❌ تفاصيل الخطأ: ${e.toString()}');

      if (mounted) {
        String errorMsg = 'حدث خطأ غير متوقع';

        if (e.toString().contains('row-level security')) {
          errorMsg = '❌ مشكلة في الصلاحيات - يرجى التأكد من تسجيل الدخول';
        } else if (e.toString().contains('promoter_id')) {
          errorMsg = '❌ لم يتم تحديد المروج - تأكد أن المنتجات لها مروج';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
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
                                      style: TextStyle(color: Colors.grey[300]),
                                    ),
                                  ),
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
                        labelText: 'عنوان التوصيل الكامل *',
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
                        labelText: 'رقم الهاتف *',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon:
                            const Icon(Icons.phone, color: Colors.green),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'رقم الهاتف مطلوب';
                        if (v.length < 7) return 'رقم غير صحيح';
                        return null;
                      },
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
                        onPressed: _isLoading ? null : _submitOrder,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle, size: 24),
                        label: Text(
                            _isLoading
                                ? 'جاري الإرسال...'
                                : 'تأكيد وإرسال الطلب',
                            style: const TextStyle(
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
