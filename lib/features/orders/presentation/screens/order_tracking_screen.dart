import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/orders/domain/order_status_display.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';

import '../../data/order_repository.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  static const Color _bg = AppColors.background;
  static const Color _card = AppColors.card;

  late final Stream<Map<String, dynamic>> _stream;
  Map<String, dynamic>? _orderDetails;
  bool _loadingDetails = true;
  List<Map<String, dynamic>> _orderItems = const [];

  @override
  void initState() {
    super.initState();
    _stream = OrderRepository().orderStatusStream(widget.orderId);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _loadingDetails = true);
    try {
      final res = await SupabaseService.client
          .from('orders')
          .select(
            '*, order_items(quantity, price, products(id, model, piece_name, price, images, promoter_id, description))',
          )
          .eq('id', widget.orderId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _orderDetails = res == null ? null : Map<String, dynamic>.from(res);
        final itemsRaw = (_orderDetails?['order_items'] as List?) ?? const [];
        _orderItems = itemsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        _loadingDetails = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orderDetails = null;
        _orderItems = const [];
        _loadingDetails = false;
      });
    }
  }

  String _shippingAddress(Map<String, dynamic>? details) {
    if (details == null) return '—';
    final v = details['shipping_address'] ?? details['full_address'];
    if (v == null) return '—';
    return v.toString().trim().isEmpty ? '—' : v.toString();
  }

  String _phone(Map<String, dynamic>? details) {
    if (details == null) return '—';
    final v = details['phone_number'] ?? details['phone'];
    if (v == null) return '—';
    return v.toString().trim().isEmpty ? '—' : v.toString();
  }

  String _money(num? n) {
    return formatIQD(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('تتبع الطلب'),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                'لم يتم العثور على الطلب',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            );
          }

          final order = snapshot.data!;
          final status = order['status']?.toString() ?? 'pending';
          final details = _orderDetails;
          final cancelled = OrderStatusDisplay.isCancelledOrRejected(status);
          final pending =
              status == 'pending' || status == 'pending_promoter_review';
          final shippedPlus = status == 'shipped' || status == 'delivered';
          final delivered = status == 'delivered';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (_loadingDetails)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else ...[
                Text(
                  'المنتجات',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_orderItems.isEmpty)
                  _emptyCard()
                else
                  ..._orderItems.map(_productLineCard),
                const SizedBox(height: 20),
                Text(
                  'التوصيل',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _darkInfoRow('العنوان', _shippingAddress(details)),
                      const SizedBox(height: 12),
                      _darkInfoRow('رقم الهاتف', _phone(details)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (cancelled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded,
                          color: Colors.orange[200], size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          OrderStatusDisplay.label(status),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'حالة الطلب',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusTile(
                  title: 'قيد الانتظار',
                  subtitle: pending
                      ? 'بانتظار موافقة التاجر'
                      : 'تم الانتقال للخطوة التالية',
                  isActive: pending,
                  isCompleted: !pending,
                ),
                _StatusTile(
                  title: 'تم القبول',
                  subtitle: status == 'approved'
                      ? 'جاري التجهيز للشحن'
                      : (shippedPlus
                          ? 'تم قبول الطلب'
                          : 'بانتظار قبول التاجر'),
                  isActive: status == 'approved',
                  isCompleted: shippedPlus,
                ),
                _StatusTile(
                  title: 'يتم الشحن',
                  subtitle: status == 'shipped'
                      ? 'الطلب في الطريق إليك'
                      : (delivered
                          ? 'اكتمل الشحن'
                          : 'بانتظار الشحن من التاجر'),
                  isActive: status == 'shipped',
                  isCompleted: delivered,
                ),
                _StatusTile(
                  title: 'تم التسليم',
                  subtitle: delivered
                      ? 'وصلك الطلب بنجاح'
                      : 'بانتظار التسليم',
                  isActive: delivered,
                  isCompleted: delivered,
                  isLast: true,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ).animate().fadeIn();
        },
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'لا تتوفر تفاصيل المنتجات لهذا الطلب.',
        style: TextStyle(color: Colors.grey[400], height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _productLineCard(Map<String, dynamic> item) {
    final productRaw = item['products'];
    final product = productRaw is Map
        ? Map<String, dynamic>.from(productRaw)
        : <String, dynamic>{};
    final title = product.isNotEmpty
        ? productDisplayTitle(product)
        : 'منتج';
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final unit = (item['price'] as num?)?.toDouble() ??
        (product['price'] as num?)?.toDouble() ??
        0.0;
    final lineTotal = unit * qty;
    final desc = product['description']?.toString().trim() ?? '';
    final images = product['images'];
    final imageUrl = (images is List && images.isNotEmpty)
        ? images.first?.toString()
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          color: AppColors.inputFill,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.muted,
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.inputFill,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricBlock('سعر الوحدة', _money(unit)),
              ),
              Expanded(
                child: _metricBlock('الكمية', '$qty'),
              ),
              Expanded(
                child: _metricBlock('المجموع', _money(lineTotal)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.success,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _darkInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title, subtitle;
  final bool isActive, isCompleted, isLast;
  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isCompleted,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success
                    : (isActive
                        ? const Color(0xFFF59E0B)
                        : AppColors.muted),
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success
                      : (isActive
                          ? const Color(0xFFF59E0B)
                          : AppColors.muted),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isActive || isCompleted
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
