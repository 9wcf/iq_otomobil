import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:iq_otomobil/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';
import 'package:iq_otomobil/features/products/presentation/widgets/car_brand_icon.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'ابحث عن قطعة، موديل، أو نوع عجلة...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    })
                : null,
          ),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list), onPressed: _showFilters),
          const SizedBox(width: 8),
        ],
      ),
      body: resultsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('لا توجد نتائج مطابقة لبحثك',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _controller.clear();
                      resetSearchFilters(ref);
                    },
                    child: const Text('إعادة تعيين الفلاتر'),
                  ),
                ],
              ),
            ).animate().fadeIn().scale();
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            cacheExtent: 800,
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final card = RepaintBoundary(
                child: CatalogProductCard(product: products[i]),
              );
              if (i >= 12) return card;
              return card
                  .animate()
                  .fadeIn(delay: (i * 50).ms)
                  .slideY(begin: 0.08, end: 0);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('حدث خطأ: $e',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error))),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

// 📦 ورقة الفلاتر المنبثقة
class _FilterSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(searchCategoryProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تصفية النتائج', style: theme.textTheme.titleLarge),
              TextButton(
                  onPressed: () {
                    resetSearchFilters(ref);
                    context.pop();
                  },
                  child: const Text('مسح الكل')),
            ],
          ),
          const SizedBox(height: 16),
          // فلترة على مرحلتين: القسم ثم الماركة (ديناميكي من منتجات التاجر)
          _FilterDropdown('القسم', categoriesProvider, searchCategoryProvider,
              onChanged: (_) => ref.read(searchBrandProvider.notifier).state = null),
          const SizedBox(height: 12),
          _BrandFilterDropdown(
            enabled: selectedCategory != null && selectedCategory.isNotEmpty,
            hintText: 'اختر القسم أولاً',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: ref.watch(searchConditionProvider),
            items: const [
              DropdownMenuItem(value: 'new', child: Text('جديد')),
              DropdownMenuItem(value: 'used', child: Text('مستعمل')),
              DropdownMenuItem(value: 'refurbished', child: Text('مجدد')),
            ],
            onChanged: (v) =>
                ref.read(searchConditionProvider.notifier).state = v,
            decoration: const InputDecoration(
                labelText: 'الحالة', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('تطبيق الفلاتر')),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _FilterDropdown(
    String label,
    AutoDisposeFutureProvider<List<Map<String, dynamic>>> provider,
    StateProvider<String?> state,
    {bool enabled = true, String? hintText, void Function(String?)? onChanged}) {
    return Consumer(
      builder: (ctx, ref, _) => ref.watch(provider).when(
            data: (items) => DropdownButtonFormField<String>(
              value: ref.watch(state),
              items: (items as List)
                  .map((i) => DropdownMenuItem(
                      value: i['id'] as String, child: Text(i['name'])))
                  .toList(),
              onChanged: enabled
                  ? (v) {
                      ref.read(state.notifier).state = v;
                      onChanged?.call(v);
                    }
                  : null,
              decoration: InputDecoration(
                labelText: label,
                hintText: enabled ? null : hintText,
                border: const OutlineInputBorder(),
              ),
            ),
            loading: () => const SizedBox(
                height: 60,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) =>
                const SizedBox(height: 60, child: Text('خطأ في التحميل')),
          ),
    );
  }
}

class _BrandFilterDropdown extends ConsumerWidget {
  const _BrandFilterDropdown({
    this.enabled = true,
    this.hintText,
  });

  final bool enabled;
  final String? hintText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<String>(
      value: ref.watch(searchBrandProvider),
      items: kCarBrandsCatalog
          .map(
            (brand) => DropdownMenuItem(
              value: brand.storageLabel,
              child: carBrandDropdownRow(brand),
            ),
          )
          .toList(),
      onChanged: enabled
          ? (v) => ref.read(searchBrandProvider.notifier).state = v
          : null,
      decoration: InputDecoration(
        labelText: 'الماركة',
        hintText: enabled ? null : hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
