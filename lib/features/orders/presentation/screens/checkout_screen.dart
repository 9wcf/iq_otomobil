import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/core/widgets/user_flow_ui.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/cart/presentation/providers/cart_provider.dart';
import 'package:iq_otomobil/features/orders/presentation/providers/user_orders_badge_provider.dart';

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
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadCartSummary();
  }

  String _safeSubstring(String text, int start, int end) {
    if (text.isEmpty || text.length <= start) return '';
    return text.substring(start, text.length < end ? text.length : end);
  }

  Future<void> _loadCartSummary() async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) return;

    try {
      final res = await SupabaseService.client
          .from('cart_items')
          .select(
              'id, quantity, products(id, model, piece_name, price, promoter_id, images)')
          .eq('user_id', user.id);

      double total = 0.0;
      for (var item in res) {
        final product = item['products'] as Map?;
        if (product != null) {
          total +=
              (product['price'] as num).toDouble() * (item['quantity'] as num);
        }
      }

      setState(() {
        _cartItems = res;
        _totalPrice = total;
        _loadedOnce = true;
      });
    } catch (_) {
      setState(() => _loadedOnce = true);
    }
  }

  String _money(num n) => formatIQD(n);

  InputDecoration _fieldDec({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: AppColors.muted.withValues(alpha: 0.9),
        fontSize: 13,
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('السلة فارغة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = SupabaseService.currentUserInfo;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseService.client;

      final Map<String, List<Map<String, dynamic>>> itemsByPromoter = {};
      for (final item in _cartItems) {
        final productRaw = item['products'];
        if (productRaw is! Map) continue;
        final product = Map<String, dynamic>.from(productRaw);
        final promoterId = product['promoter_id']?.toString();
        if (promoterId == null || promoterId.trim().isEmpty) {
          throw Exception('منتج بدون تاجر (promoter_id)');
        }
        (itemsByPromoter[promoterId] ??= []).add({
          'cart_item': item,
          'product': product,
        });
      }

      if (itemsByPromoter.isEmpty) {
        throw Exception('لا توجد عناصر قابلة للطلب');
      }

      for (final entry in itemsByPromoter.entries) {
        final promoterId = entry.key;
        final rows = entry.value;

        double promoterTotal = 0.0;
        for (final row in rows) {
          final product = row['product'] as Map<String, dynamic>;
          final cartItem = row['cart_item'] as Map<String, dynamic>;
          final qty = (cartItem['quantity'] as num?)?.toInt() ?? 0;
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          promoterTotal += price * qty;
        }

        final orderRes = await supabase
            .from('orders')
            .insert({
              'user_id': user.id,
              'promoter_id': promoterId,
              'status': 'pending_promoter_review',
              'total_price': promoterTotal,
              'shipping_address': _addressCtrl.text.trim(),
              'phone_number': _phoneCtrl.text.trim(),
              'notes': _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            })
            .select()
            .single();

        for (final row in rows) {
          final product = row['product'] as Map<String, dynamic>;
          final cartItem = row['cart_item'] as Map<String, dynamic>;
          final qty = (cartItem['quantity'] as num?)?.toInt() ?? 0;
          if (qty <= 0) continue;

          final orderItemData = {
            'order_id': orderRes['id'],
            'product_id': product['id'],
            'quantity': qty,
            'price': product['price'],
          };

          final result =
              await supabase.from('order_items').insert(orderItemData).select();
          if (result.isEmpty) {
            throw Exception(
                'فشل إضافة المنتج: ${productDisplayTitle(product)}');
          }
        }

        final addressPreview = _safeSubstring(_addressCtrl.text.trim(), 0, 20);
        await supabase.from('notifications').insert({
          'user_id': promoterId,
          'title': 'طلب جديد وارد!',
          'message':
              'طلب بقيمة ${_money(promoterTotal)} من ${addressPreview.isNotEmpty ? "$addressPreview..." : "مستخدم جديد"}',
          'type': 'order',
        });
      }

      await supabase.from('cart_items').delete().eq('user_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد الطلب بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            container.read(cartCountNotifierProvider.notifier).reload();
            container.invalidate(userActiveOrdersCountProvider);
          } catch (_) {}
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'حدث خطأ غير متوقع';

        if (e.toString().contains('row-level security')) {
          errorMsg = 'مشكلة في الصلاحيات — تأكد من تسجيل الدخول';
        } else if (e.toString().contains('promoter_id') ||
            e.toString().contains('بدون تاجر')) {
          errorMsg = 'بعض المنتجات غير مرتبطة بتاجر';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
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
    final user = SupabaseService.currentUserInfo;
    if (user == null) {
      Future.microtask(() => context.go('/auth'));
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const UserFlowAppBar(title: 'إتمام الطلب'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UserFlowSectionCard(
                      title: 'ملخص الطلب',
                      icon: Icons.receipt_long_rounded,
                      child: !_loadedOnce
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : _cartItems.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'السلة فارغة حالياً',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    ..._cartItems.map((item) {
                                      final productRaw = item['products'];
                                      final productMap = productRaw is Map
                                          ? Map<String, dynamic>.from(
                                              productRaw)
                                          : <String, dynamic>{};
                                      final titleLine = productRaw is Map
                                          ? productDisplayTitle(productMap)
                                          : 'منتج';
                                      final qty = (item['quantity'] as num?)
                                              ?.toInt() ??
                                          0;
                                      final unit =
                                          (productMap['price'] as num?) ?? 0;
                                      final lineTotal = unit * qty;

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '$titleLine (×$qty)',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _money(lineTotal.toDouble()),
                                              style: const TextStyle(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    Divider(
                                      height: 20,
                                      color: AppColors.border
                                          .withValues(alpha: 0.6),
                                    ),
                                    Row(
                                      children: [
                                        const Text(
                                          'المجموع الكلي',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _money(_totalPrice),
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                    ),
                    const SizedBox(height: 14),
                    UserFlowSectionCard(
                      title: 'معلومات التوصيل',
                      icon: Icons.local_shipping_rounded,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _addressCtrl,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDec(
                              label: 'عنوان التوصيل الكامل *',
                              hint: 'مثال: بغداد - الكرادة - شارع ...',
                              icon: Icons.location_on_outlined,
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'العنوان مطلوب'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDec(
                              label: 'رقم الهاتف *',
                              hint: 'مثال: 07xxxxxxxx',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'رقم الهاتف مطلوب';
                              if (s.length < 7) return 'رقم غير صحيح';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textInputAction: TextInputAction.done,
                            decoration: _fieldDec(
                              label: 'ملاحظات إضافية (اختياري)',
                              hint: 'مثال: وقت مناسب للتسليم…',
                              icon: Icons.sticky_note_2_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: UserFlowSummaryBar(
              totalLabel: 'الإجمالي',
              totalValue: _money(_totalPrice),
              buttonLabel:
                  _isLoading ? 'جاري الإرسال...' : 'تأكيد وإرسال الطلب',
              icon: Icons.check_circle_outline_rounded,
              loading: _isLoading,
              onPressed: _isLoading ? null : _submitOrder,
            ),
          ),
        ],
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
