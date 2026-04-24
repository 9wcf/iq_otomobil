import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/catalog/domain/product.dart';

class CatalogRepository {
  final _client = SupabaseService.client;

  /// جلب العلامات التجارية
  Future<List<Map<String, dynamic>>> getBrands() =>
      _client.from('car_brands').select('id, name');

  /// جلب الأقسام
  Future<List<Map<String, dynamic>>> getCategories() =>
      _client.from('categories').select('id, name');

  /// جلب المنتجات النشطة (تشمل approved و pending)
  Future<List<Product>> getActiveProducts() async {
    final res = await _client
        .from('products')
        .select('*, car_brands(name), categories(name)')
        .inFilter('status', ['approved', 'pending']).order('created_at',
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

  /// البحث الذكي مع الفلاتر المركبة (تشمل approved و pending)
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
        .inFilter('status', ['approved', 'pending']);

    if (brandId != null) q = q.eq('brand_id', brandId);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (condition != null) q = q.eq('condition', condition);

    // بحث نصي ذكي يغطي الوصف، الموديل، ونوع العجلة
    if (query != null && query.isNotEmpty) {
      q = q.or(
          'description.ilike.%$query%,model.ilike.%$query%,wheel_type.ilike.%$query%');
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
    final promoterId = _client.auth.currentUser!.id;
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
