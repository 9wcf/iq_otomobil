import 'dart:io';

import 'package:iq_otomobil/core/services/supabase_service.dart';

class PlateRepository {
  final _client = SupabaseService.client;

  /// جلب اللوحات المعتمدة
  Future<List<Map<String, dynamic>>> getApprovedPlates() => _client
      .from('car_plates')
      .select()
      .eq('status', 'approved')
      .order('created_at', ascending: false);

  /// رفع صورة اللوحة — نفس bucket المنتجات لتفادي إعداد تخزين إضافي
  Future<String> _uploadPlateImage(File file, int index) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = ext.length <= 5 ? ext : 'jpg';
    final uid = SupabaseService.currentUserId ?? 'guest';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'car_plates/$uid/${ts}_$index.$safeExt';
    await _client.storage.from('products').uploadBinary(path, bytes);
    return _client.storage.from('products').getPublicUrl(path);
  }

  /// إرسال لوحة جديدة → تنتظر موافقة الأدمن (status: pending)
  Future<void> submitPlate({
    required String plateNumber,
    required String plateType,
    String? governorate,
    String? description,
    double? price,
    required String sellerPhone,
    String? sellerName,
    List<File>? images,
  }) async {
    final imageUrls = <String>[];
    if (images != null && images.isNotEmpty) {
      for (var i = 0; i < images.length; i++) {
        imageUrls.add(await _uploadPlateImage(images[i], i));
      }
    }

    await _client.from('car_plates').insert({
      'plate_number': plateNumber,
      'plate_type': plateType,
      'governorate': governorate,
      'description': description,
      'price': price,
      'seller_phone': sellerPhone,
      'seller_name': sellerName,
      'status': 'pending',
      'images': imageUrls,
      // يجب أن تطابق قيم check constraint car_plates_submitted_via_check في Supabase
      'submitted_via': 'form',
    });
  }
}
