import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/catalog/data/shared_spare_categories.dart';
import 'package:iq_otomobil/features/catalog/presentation/widgets/user_product_list_tile.dart';
import 'package:iq_otomobil/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(favoriteProductsProvider);
    return Scaffold(
      backgroundColor: kProductListBackground,
      appBar: AppBar(
        backgroundColor: kProductListBackground,
        title: const Text(
          'المفضلة',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: productsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'تعذر تحميل المفضلة: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'لا توجد عناصر في المفضلة بعد',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(favoriteIdsProvider.notifier).reload();
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: kProductCardListSpacing),
              itemBuilder: (context, i) {
                final p = items[i];
                final pid = p['id']?.toString() ?? '';
                final images = p['images'];
                final imageUrl = (images is List && images.isNotEmpty)
                    ? images.first.toString()
                    : null;
                final brandStored = p['brand_id']?.toString().trim();
                final brandLabel = (brandStored != null && brandStored.isNotEmpty)
                    ? (brandByStorageLabel(brandStored)?.displayLine ?? brandStored)
                    : null;
                return UserProductListTile(
                  productId: pid,
                  imageUrl: imageUrl,
                  title: productDisplayTitle(p),
                  subtitle: sparePartCategoryDisplayName(p['category_id']),
                  brandLabel: brandLabel,
                  price: p['price'],
                  conditionLabel: productConditionLabelAr(p['condition']?.toString()),
                  onTap: () => context.push('/product/$pid'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

