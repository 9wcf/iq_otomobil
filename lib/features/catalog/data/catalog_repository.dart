import 'dart:io';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/catalog/domain/product.dart';
import 'package:iq_otomobil/features/catalog/data/shared_spare_categories.dart';
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';

class CatalogRepository {
  final _client = SupabaseService.client;

  /// يُعرض للزبائن فقط (لا يشمل قيد المراجعة أو المعلّق).
  static const publicListingStatuses = ['approved', 'active'];

  /// الأقسام/الماركات ديناميكية من بيانات التاجر (جدول المنتجات).
  /// لأن `products.brand_id` مخزن كنص (storageLabel) وليس FK.
  Future<List<Map<String, dynamic>>> getSearchCategoriesFromProducts() async {
    final res = await _client
        .from('products')
        .select('category_id')
        .inFilter('status', publicListingStatuses);

    final ids = <String>{};
    for (final row in (res as List)) {
      final raw = row['category_id']?.toString().trim();
      if (raw == null || raw.isEmpty) continue;
      if (raw == '10' ||
          raw == 'إطارات' ||
          raw == 'فلتر') continue;
      ids.add(raw);
    }

    final items = <Map<String, dynamic>>[];
    for (final id in ids) {
      final name = sparePartCategoryDisplayName(id);
      if (name == 'غير محدد') continue;
      items.add({'id': id, 'name': name});
    }
    items.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return items;
  }

  Future<List<Map<String, dynamic>>> getSearchBrandsFromProducts({
    String? categoryId,
  }) async {
    // الماركات ثابتة من الكتالوج المعتمد فقط — لا دمج مع بيانات قديمة.
    return [
      for (final b in kCarBrandsCatalog)
        {
          'id': b.storageLabel,
          'name': b.displayLine,
          'iconAsset': b.iconAsset,
        },
    ];
  }

  /// جلب المنتجات المعروضة للزبائن (approved / active فقط)
  Future<List<Product>> getActiveProducts() async {
    final res = await _client
        .from('products')
        .select('*, car_brands(name), categories(name)')
        .inFilter('status', publicListingStatuses).order('created_at',
            ascending: false);

    return res.map((json) {
      final brandName = (json['car_brands'] as Map?)?['name'] as String?;
      final categoryName = (json['categories'] as Map?)?['name'] as String?;
      return Product.fromJson({
        ...json,
        'brandName': brandName,
        'categoryName': categoryName,
      });
    }).toList();
  }

  /// البحث الذكي مع الفلاتر المركبة (معروض للزبائن فقط)
  Future<List<Product>> searchProducts({
    String? query,
    String? brandId,
    String? categoryId,
    String? condition,
    int limit = 50,
  }) async {
    var q = _client
        .from('products')
        .select('*, car_brands(name), categories(name)')
        .inFilter('status', publicListingStatuses);

    if (brandId != null) q = q.eq('brand_id', brandId);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (condition != null) q = q.eq('condition', condition);

    // بحث نصي ذكي يغطي الوصف، الموديل، ونوع العجلة
    if (query != null && query.isNotEmpty) {
      q = q.or(
          'description.ilike.%$query%,model.ilike.%$query%,piece_name.ilike.%$query%,wheel_type.ilike.%$query%');
    }

    final res = await q.order('created_at', ascending: false).limit(limit);

    return res.map((json) {
      final brandName = (json['car_brands'] as Map?)?['name'] as String?;
      final categoryName = (json['categories'] as Map?)?['name'] as String?;
      return Product.fromJson({
        ...json,
        'brandName': brandName,
        'categoryName': categoryName,
      });
    }).toList();
  }

  /// أحدث المنتجات (صفحات) لاستخدامها في الرئيسية بدون تحميل ضخم.
  /// نُرجع raw maps لأن شاشة الرئيسية تستخدم دوال العرض المبنية على Map.
  Future<({List<Map<String, dynamic>> items, bool hasNext})>
      getLatestProductsPageRaw({
    required int page,
    int pageSize = 16,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize; // fetch pageSize + 1 to detect next

    final res = await _client
        .from('products')
        .select('*')
        .inFilter('status', publicListingStatuses)
        .order('created_at', ascending: false)
        .range(from, to);

    final list = List<Map<String, dynamic>>.from(res as List);
    final hasNext = list.length > pageSize;
    final items = hasNext ? list.sublist(0, pageSize) : list;
    return (items: items, hasNext: hasNext);
  }

  /// رفع منتج جديد مع الصور (حالته approved مباشرة)
  Future<void> uploadProduct({
    required String brandId,
    required String categoryId,
    String? model,
    required String condition,
    String? wheelType,
    String? description,
    required List<File> images,
  }) async {
    final promoterId = SupabaseService.currentUserId!;
    final imageUrls = <String>[];

    for (int i = 0; i < images.length; i++) {
      final ext = images[i].path.split('.').last;
      final path =
          'products/${promoterId}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      await _client.storage.from('products').upload(path, images[i]);
      final url = _client.storage.from('products').getPublicUrl(path);
      imageUrls.add(url);
    }

    await _client.from('products').insert({
      'promoter_id': promoterId,
      'brand_id': brandId,
      'category_id': categoryId,
      'model': model,
      'condition': condition,
      'wheel_type': wheelType,
      'description': description,
      'images': imageUrls,
      'status': 'approved',
    });
  }
}
