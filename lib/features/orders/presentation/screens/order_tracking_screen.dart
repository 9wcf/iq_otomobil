import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ استيراد المستودع والخدمة
import 'package:iq_otomobil/core/services/supabase_service.dart';
import '../../data/order_repository.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  late final Stream<Map<String, dynamic>> _stream;

  @override
  void initState() {
    super.initState();
    // ✅ استخدام OrderRepository عبر استيراد صحيح
    _stream = OrderRepository().orderStatusStream(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع الطلب')),
      body: StreamBuilder(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
                child: Text('لم يتم العثور على الطلب',
                    style: theme.textTheme.bodyLarge));
          }

          final order = snapshot.data!;
          final status = order['status'] as String;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusTile(
                title: 'تم استلام الطلب',
                subtitle: _formatDate(order['created_at']),
                isActive: true,
                isCompleted: ['approved', 'processing', 'shipped', 'delivered']
                    .contains(status),
              ),
              _StatusTile(
                title: 'تمت الموافقة من المروج',
                subtitle: status == 'approved'
                    ? _formatDate(DateTime.now())
                    : 'بانتظار المراجعة',
                isActive: ['approved', 'processing', 'shipped', 'delivered']
                    .contains(status),
                isCompleted:
                    ['processing', 'shipped', 'delivered'].contains(status),
              ),
              _StatusTile(
                title: 'جاري التجهيز',
                subtitle:
                    ['processing', 'shipped', 'delivered'].contains(status)
                        ? 'القطعة قيد التجهيز'
                        : 'بانتظار الموافقة',
                isActive:
                    ['processing', 'shipped', 'delivered'].contains(status),
                isCompleted: ['shipped', 'delivered'].contains(status),
              ),
              _StatusTile(
                title: 'تم الشحن',
                subtitle: ['shipped', 'delivered'].contains(status)
                    ? 'في الطريق إليك'
                    : 'بانتظار التجهيز',
                isActive: ['shipped', 'delivered'].contains(status),
                isCompleted: status == 'delivered',
              ),
              _StatusTile(
                title: 'تم التسليم',
                subtitle: status == 'delivered'
                    ? '✅ وصلك الطلب بنجاح'
                    : 'بانتظار الشحن',
                isActive: status == 'delivered',
                isCompleted: status == 'delivered',
                isLast: true,
              ),
              const SizedBox(height: 32),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معلومات الطلب',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _InfoRow('رقم الطلب',
                          '#${order['id'].toString().substring(0, 12)}'),
                      _InfoRow('الحالة الحالية', _getStatusArabic(status)),
                      _InfoRow('العنوان', order['full_address']),
                      _InfoRow('الهاتف', order['phone']),
                      if (order['notes'] != null)
                        _InfoRow('ملاحظات', order['notes']),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn();
        },
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'غير محدد';
    if (date is DateTime) return date.toString().substring(0, 16);
    return date.toString().substring(0, 16);
  }

  String _getStatusArabic(String status) {
    return switch (status) {
      'pending_promoter_review' => 'بانتظار مراجعة المروج',
      'approved' => '✅ تمت الموافقة',
      'rejected' => '❌ تم الرفض',
      'processing' => '🔄 جاري التجهيز',
      'shipped' => '🚚 في الطريق',
      'delivered' => '✅ تم التسليم',
      _ => 'غير معروف',
    };
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
    final theme = Theme.of(context);
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
                    ? Colors.green
                    : (isActive ? Colors.amber : Colors.grey[300]),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green
                      : (isActive ? Colors.amber : Colors.grey),
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
                  color: isActive ? Colors.amber : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive ? null : Colors.grey,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[700])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value, style: TextStyle(color: Colors.grey[800])),
            ],
          ),
        ),
      );
}
