import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iq_otomobil/features/cart/presentation/providers/cart_provider.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سلة المشتريات'), actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep),
          onPressed: () => ref.read(cartActionProvider.notifier).clear(),
          tooltip: 'إفراغ السلة',
        ),
      ]),
      body: itemsAsync.when(
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 80, color: theme.disabledColor),
                    const SizedBox(height: 16),
                    Text('السلة فارغة حالياً',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('تصفح المنتجات'),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (ctx, i) => _CartItemTile(item: items[i])
                    .animate()
                    .fadeIn(delay: (i * 50).ms)
                    .slideX(begin: 0.1, end: 0),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('خطأ: $e',
                style: TextStyle(color: theme.colorScheme.error))),
      ),
      bottomNavigationBar: itemsAsync.maybeWhen(
        data: (items) =>
            items.isEmpty ? null : _CheckoutBar(total: _calculateTotal(items)),
        orElse: () => null,
      ),
    );
  }

  double _calculateTotal(List<Map<String, dynamic>> items) {
    // يمكن إضافة سعر القطعة لاحقاً، حالياً نعرض العدد
    return items.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }
}

class _CartItemTile extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item['products'] as Map<String, dynamic>;
    final brand = (product['car_brands'] as Map?)?['name'] ?? '';
    final images = (product['images'] as List?) ?? [];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // الصورة
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              image: images.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(images.first),
                      fit: BoxFit.cover)
                  : null,
              color: Colors.grey[200],
            ),
            child: images.isEmpty
                ? const Icon(Icons.image_not_supported, color: Colors.grey)
                : null,
          ),
          // التفاصيل
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(productDisplayTitle(product),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(brand,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('الكمية:'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${item['quantity']}',
                            style: theme.textTheme.labelLarge),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // زر الحذف
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => ref
                .read(cartActionProvider.notifier)
                .remove(item['id'] as String),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final double total;
  const _CheckoutBar({required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
        child: Row(
          children: [
            Expanded(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي العناصر: ${total.toInt()}',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('سيتم احتساب السعر النهائي بعد الموافقة',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey)),
              ],
            )),
            ElevatedButton(
              onPressed: () => context.push('/checkout'),
              child: const Text('إتمام الطلب'),
            ),
          ],
        ),
      );
}
