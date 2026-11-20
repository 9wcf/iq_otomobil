import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../data/catalog_repository.dart';
import '../../domain/product.dart';

final catalogRepoProvider = Provider((ref) => CatalogRepository());

final categoriesProvider = FutureProvider.autoDispose(
  (ref) {
    // Prevent refetching on quick route changes.
    ref.keepAlive();
    return ref.watch(catalogRepoProvider).getSearchCategoriesFromProducts();
  },
);

final brandsProvider = FutureProvider.autoDispose((ref) {
  // Prevent refetching on quick route changes.
  ref.keepAlive();
  final cat = ref.watch(searchCategoryProvider);
  return ref
      .watch(catalogRepoProvider)
      .getSearchBrandsFromProducts(categoryId: cat);
});

final productsProvider = FutureProvider.autoDispose((ref) {
  // Prevent refetching when navigating away/back to catalog.
  ref.keepAlive();
  return ref.watch(catalogRepoProvider).getActiveProducts();
});

/// Latest products for home screen with pagination.
final latestProductsPageProvider = FutureProvider.autoDispose
    .family<({List<Map<String, dynamic>> items, bool hasNext}), int>(
  (ref, page) {
    ref.keepAlive();
    return ref.watch(catalogRepoProvider).getLatestProductsPageRaw(page: page);
  },
);

class ProductUploadNotifier extends StateNotifier<AsyncValue<void>> {
  final CatalogRepository _repo;
  ProductUploadNotifier(this._repo) : super(const AsyncData(null));

  Future<void> upload({
    required String brandId,
    required String categoryId,
    String? model,
    required String condition,
    String? wheelType,
    String? description,
    required List<File> images,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.uploadProduct(
          brandId: brandId,
          categoryId: categoryId,
          model: model,
          condition: condition,
          wheelType: wheelType,
          description: description,
          images: images,
        ));
  }
}

final productUploadProvider =
    StateNotifierProvider<ProductUploadNotifier, AsyncValue<void>>(
  (ref) => ProductUploadNotifier(ref.watch(catalogRepoProvider)),
);
// حالة الفلاتر
final searchBrandProvider = StateProvider<String?>((_) => null);
final searchCategoryProvider = StateProvider<String?>((_) => null);
final searchConditionProvider = StateProvider<String?>((_) => null);
final searchQueryProvider = StateProvider<String>((_) => '');

// جلب النتائج تلقائياً عند تغيير أي فلتر أو نص بحث
final searchResultsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final brandId = ref.watch(searchBrandProvider);
  final categoryId = ref.watch(searchCategoryProvider);
  final condition = ref.watch(searchConditionProvider);

  final repo = ref.watch(catalogRepoProvider);
  return repo.searchProducts(
    query: query.isEmpty ? null : query,
    brandId: brandId,
    categoryId: categoryId,
    condition: condition,
  );
});

// إعادة تعيين الفلاتر
void resetSearchFilters(WidgetRef ref) {
  ref.read(searchBrandProvider.notifier).state = null;
  ref.read(searchCategoryProvider.notifier).state = null;
  ref.read(searchConditionProvider.notifier).state = null;
  ref.read(searchQueryProvider.notifier).state = '';
}
