import 'dart:io';
import 'package:iq_otomobil/core/services/supabase_service.dart';

class AdminRepository {
  final _client = SupabaseService.client;

  /// التحقق من صلاحية الأدمن
  Future<bool> isAdmin(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] == 'admin';
    } catch (e) {
      print('خطأ في التحقق من الصلاحية: $e');
      return false;
    }
  }

  /// إحصائيات عامة
  Future<Map<String, dynamic>> getDashboardStats() async {
    final users = await _client.from('profiles').select('id');
    final orders = await _client.from('orders').select('id');
    final products = await _client.from('products').select('id');
    final plates = await _client.from('car_plates').select('id');

    return {
      'totalUsers': users.length,
      'totalOrders': orders.length,
      'totalProducts': products.length,
      'totalPlates': plates.length,
    };
  }

  /// جلب جميع المنتجات
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final response = await _client
        .from('products')
        .select('*, car_brands(name), categories(name)')
        .order('created_at', ascending: false);

    return response;
  }

  /// تغيير حالة منتج (`suspension_source` يُمسح تلقائياً إلا عند التعليق).
  Future<void> updateProductStatus(
    String productId,
    String newStatus, {
    String? suspensionSource,
  }) async {
    final patch = <String, dynamic>{'status': newStatus};
    if (newStatus == 'suspended') {
      patch['suspension_source'] = suspensionSource ?? 'admin';
    } else {
      patch['suspension_source'] = null;
    }
    await _client.from('products').update(patch).eq('id', productId);
  }

  /// حذف منتج
  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  /// إحصاءات المنتجات حسب الحالة
  Future<Map<String, int>> getProductsStats() async {
    final allProducts = await _client.from('products').select('status');

    final stats = {
      'pending': 0,
      'active': 0,
      'approved': 0,
      'rejected': 0,
      'sold': 0,
      'suspended': 0,
      'total': allProducts.length,
    };

    for (var product in allProducts) {
      final status = product['status'] as String? ?? 'pending';
      if (stats.containsKey(status)) {
        stats[status] = (stats[status] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// ==================== دوال إضافة المنتج ====================

  /// رفع صورة إلى التخزين
  Future<String> uploadImage(File imageFile, String userId) async {
    final bytes = await imageFile.readAsBytes();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'admin_${userId}_${timestamp}.jpg';
    final filePath = 'products/$fileName';

    await _client.storage.from('products').uploadBinary(filePath, bytes);
    return _client.storage.from('products').getPublicUrl(filePath);
  }

  /// إضافة منتج جديد
  Future<void> addProduct({
    required String name,
    required String brandId,
    required String categoryId,
    required String model,
    required String condition,
    required double price,
    String? wheelType,
    String? description,
    int? yearFrom,
    int? yearTo,
    required List<File> images,
  }) async {
    final adminId = SupabaseService.currentUserId!;

    // رفع الصور
    final imageUrls = <String>[];
    for (var image in images) {
      final url = await uploadImage(image, adminId);
      imageUrls.add(url);
    }

    // إضافة المنتج
    await _client.from('products').insert({
      'promoter_id': adminId,
      'brand_id': brandId,
      'category_id': categoryId,
      'name': name,
      'model': model,
      'condition': condition,
      'wheel_type': wheelType,
      'description': description,
      'price': price,
      'year_from': yearFrom,
      'year_to': yearTo,
      'images': imageUrls,
      'status': 'active', // منتجات الأدمن تكون active مباشرة
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// جلب الماركات
  Future<List<Map<String, dynamic>>> getBrands() async {
    return await _client.from('car_brands').select('id, name');
  }

  /// جلب الأقسام
  Future<List<Map<String, dynamic>>> getCategories() async {
    return await _client.from('categories').select('id, name');
  }

  /// منتجات مروج محدد (للأدمن)
  Future<List<Map<String, dynamic>>> getProductsByPromoter(String promoterId) async {
    final response = await _client
        .from('products')
        .select('*')
        .eq('promoter_id', promoterId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// تحديث تعليق الأدمن على منتج
  Future<void> updateProductAdminComment(
    String productId,
    String? comment,
  ) async {
    final t = comment?.trim();
    await _client.from('products').update({
      'admin_comment': (t == null || t.isEmpty) ? null : t,
    }).eq('id', productId);
  }

  /// موافقة تلقائية لمنتجات المروج الجديدة (عمود profiles + trigger في SQL)
  Future<void> setPromoterAutoApprove(String promoterId, bool enabled) async {
    await _client.from('profiles').update({
      'auto_approve_products': enabled,
    }).eq('id', promoterId);
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await _client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
