import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/core/widgets/user_flow_ui.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/orders/domain/order_status_display.dart';

class CustomerOrdersScreen extends ConsumerStatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  ConsumerState<CustomerOrdersScreen> createState() =>
      _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends ConsumerState<CustomerOrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.currentUserInfo;
      if (user == null) return;

      final response = await SupabaseService.client
          .from('orders')
          .select(
              'id, status, total_price, created_at, shipping_address, phone_number, notes, order_items(quantity, price, products(id, model, piece_name, price, images, promoter_id))')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _orders = response;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String? _formatOrderDate(dynamic createdAt) {
    if (createdAt == null) return null;
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y • $h:$min';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: UserFlowAppBar(
        title: 'طلباتي',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _orders.isEmpty
              ? const UserFlowEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'لا توجد طلبات حالياً',
                  subtitle: 'عند إتمام أي طلب سيظهر هنا مع حالة التوصيل',
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchOrders,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      userFlowScreenScrollBottomPadding(context),
                    ),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final status =
                          (order['status'] ?? 'pending').toString();
                      final total =
                          (order['total_price'] as num? ?? 0).toDouble();
                      final items =
                          order['order_items'] as List? ?? const [];
                      final dateStr =
                          _formatOrderDate(order['created_at']);

                      Map<String, dynamic>? firstProduct;
                      if (items.isNotEmpty) {
                        final first = items.first;
                        if (first is Map && first['products'] is Map) {
                          firstProduct = Map<String, dynamic>.from(
                              first['products'] as Map);
                        }
                      }
                      final title = firstProduct != null
                          ? productDisplayTitle(firstProduct)
                          : (items.isNotEmpty
                              ? 'طلب (${items.length} منتجات)'
                              : 'طلب');
                      final images = firstProduct?['images'];
                      final imageUrl =
                          (images is List && images.isNotEmpty)
                              ? images.first?.toString()
                              : null;
                      final statusColor =
                          OrderStatusDisplay.accentColor(status);
                      final itemCount = items.length;

                      return _OrderListCard(
                        title: title,
                        subtitle: OrderStatusDisplay.userListDescription(
                            status),
                        totalText: formatIQD(total),
                        dateText: dateStr,
                        statusLabel: OrderStatusDisplay.label(status),
                        statusColor: statusColor,
                        imageUrl: imageUrl,
                        itemCount: itemCount,
                        onTap: () => context.push('/track/${order['id']}'),
                      );
                    },
                  ),
                ),
    );
  }
}

class _OrderListCard extends StatelessWidget {
  const _OrderListCard({
    required this.title,
    required this.subtitle,
    required this.totalText,
    required this.dateText,
    required this.statusLabel,
    required this.statusColor,
    required this.imageUrl,
    required this.itemCount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String totalText;
  final String? dateText;
  final String statusLabel;
  final Color statusColor;
  final String? imageUrl;
  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: userFlowCardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    UserOrderStatusChip(
                      label: statusLabel,
                      color: statusColor,
                    ),
                    const Spacer(),
                    if (dateText != null)
                      Text(
                        dateText!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 144,
                                memCacheHeight: 144,
                                placeholder: (_, __) =>
                                    const _OrderImgPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    const _OrderImgPlaceholder(),
                              )
                            : const _OrderImgPlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                          if (itemCount > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$itemCount منتجات',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            totalText,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      size: 28,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderImgPlaceholder extends StatelessWidget {
  const _OrderImgPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.inputFill,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.muted.withValues(alpha: 0.8),
        size: 28,
      ),
    );
  }
}
