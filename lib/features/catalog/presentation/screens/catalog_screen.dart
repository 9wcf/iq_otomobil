import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/catalog_provider.dart';
import '../../domain/product.dart';
// 👇 إضافة استيراد أيقونة السلة مع الشارة الحمراء
import 'package:iq_otomobil/features/cart/presentation/widgets/cart_badge_icon.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      // 👇 تم تعديل AppBar لإضافة أيقونة السلة في الزاوية
      appBar: AppBar(
        title: const Text('الكتالوج'),
        actions: const [
          CartBadgeIcon(), // 👈 أيقونة السلة مع العداد الأحمر الديناميكي
          SizedBox(width: 8), // مسافة صغيرة للحافة
        ],
      ),
      body: productsAsync.when(
        data: (products) => products.isEmpty
            ? const Center(child: Text('لا توجد قطع متاحة حالياً'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12),
                itemCount: products.length,
                itemBuilder: (context, index) =>
                    _ProductCard(product: products[index])
                        .animate()
                        .fadeIn(delay: (index * 80).ms)
                        .slideY(begin: 0.15, end: 0),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في التحميل: $e')),
      ),
      // 👇 اختياري: زر عائم لإضافة منتج جديد (للمروجين فقط - سيتم تفعيله لاحقاً)
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () => context.push('/add-product'),
      //   child: const Icon(Icons.add),
      // ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CachedNetworkImage(
              imageUrl: product.images.firstOrNull ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) =>
                  const ColoredBox(color: Color(0xFFE2E8F0)),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.brandName ?? 'غير محدد',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    '${product.model ?? 'موديل غير محدد'} • ${product.condition == 'new' ? 'جديد' : product.condition == 'used' ? 'مستعمل' : 'مجدد'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 6),
                if (product.wheelType != null)
                  Text('نوع العجلة: ${product.wheelType}',
                      style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
