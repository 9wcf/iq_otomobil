import 'package:flutter/material.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

/// محتوى تبويب الرئيسية للمروج (إحصائيات فقط — الـ AppBar في [PromoterMainScreen]).
class PromoterHubBody extends StatefulWidget {
  const PromoterHubBody({super.key});

  @override
  State<PromoterHubBody> createState() => PromoterHubBodyState();
}

class PromoterHubBodyState extends State<PromoterHubBody> {
  bool _loadingStats = true;
  int _productCount = 0;
  int _orderCount = 0;
  int _pipelineCount = 0;
  int _deliveredCount = 0;
  int _cancelledCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// استدعاء من الشريط السفلي عند العودة للرئيسية.
  void refresh() => _loadStats();

  Future<void> _loadStats() async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) {
      if (mounted) setState(() => _loadingStats = false);
      return;
    }

    setState(() => _loadingStats = true);

    try {
      final products = await SupabaseService.client
          .from('products')
          .select('id')
          .eq('promoter_id', user.id);

      final orders = await SupabaseService.client
          .from('orders')
          .select('id, status')
          .eq('promoter_id', user.id);

      var delivered = 0;
      var cancelled = 0;
      var pipeline = 0;

      for (final o in orders) {
        final s = o['status']?.toString() ?? '';
        if (s == 'delivered') {
          delivered++;
        } else if (s == 'rejected' || s == 'cancelled') {
          cancelled++;
        } else {
          pipeline++;
        }
      }

      if (!mounted) return;
      setState(() {
        _productCount = products.length;
        _orderCount = orders.length;
        _pipelineCount = pipeline;
        _deliveredCount = delivered;
        _cancelledCount = cancelled;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);

    return ColoredBox(
      color: bg,
      child: RefreshIndicator(
        color: Colors.lightBlueAccent,
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مرحباً بك في لوحة التاجر',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'إحصائيات سريعة ثم انتقل لإدارة المنتجات والطلبات من الأعلى.',
                style: TextStyle(color: Colors.grey[400], height: 1.5),
              ),
              const SizedBox(height: 20),
              if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Colors.lightBlueAccent),
                  ),
                )
              else ...[
                LayoutBuilder(
                  builder: (ctx, c) {
                    final w = (c.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          width: w,
                          icon: Icons.inventory_2_outlined,
                          label: 'المنتجات',
                          value: '$_productCount',
                          accent: const Color(0xFF38BDF8),
                        ),
                        _StatCard(
                          width: w,
                          icon: Icons.receipt_long_rounded,
                          label: 'إجمالي الطلبات',
                          value: '$_orderCount',
                          accent: const Color(0xFFA78BFA),
                        ),
                        _StatCard(
                          width: w,
                          icon: Icons.hourglass_top_rounded,
                          label: 'قيد التنفيذ',
                          value: '$_pipelineCount',
                          accent: const Color(0xFFFBBF24),
                        ),
                        _StatCard(
                          width: w,
                          icon: Icons.check_circle_outline_rounded,
                          label: 'تم التسليم',
                          value: '$_deliveredCount',
                          accent: const Color(0xFF34D399),
                        ),
                        _StatCard(
                          width: c.maxWidth,
                          icon: Icons.cancel_outlined,
                          label: 'مرفوض / ملغي',
                          value: '$_cancelledCount',
                          accent: const Color(0xFFF87171),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded,
                        size: 40, color: Colors.blue[300]),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'من «منتجاتي» شاهد كم مرة طُلب كل منتج وحالات الطلب. من «طلبات المروج» حدّث حالة الطلب.',
                        style: TextStyle(color: Colors.grey[300], height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 26),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
