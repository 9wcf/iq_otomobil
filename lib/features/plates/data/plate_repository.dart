import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

class PlateRepository {
  final _client = SupabaseService.client;

  /// جلب اللوحات المعتمدة
  Future<List<Map<String, dynamic>>> getApprovedPlates() => _client
      .from('car_plates')
      .select()
      .eq('status', 'approved')
      .order('created_at', ascending: false);

  /// إرسال لوحة جديدة (نموذج)
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
    List<String> imageUrls = [];

    if (images != null && images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        final ext = images[i].path.split('.').last;
        final path = 'plates/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await _client.storage.from('plates').upload(path, images[i]);
        imageUrls.add(_client.storage.from('plates').getPublicUrl(path));
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
      'submitted_via': 'form',
    });
  }

  /// إنشاء رابط واتساب للإرسال
  String createWhatsAppLink({
    required String plateNumber,
    required String sellerPhone,
    String? description,
    double? price,
  }) {
    final message = '''
🚗 *طلب بيع لوحة سيارات*

📋 *رقم اللوحة:* $plateNumber
📱 *هاتف البائع:* $sellerPhone
💰 *السعر:* ${price != null ? '${price.toString()} دولار' : 'حسب الاتفاق'}
📝 *الوصف:* ${description ?? 'لا يوجد'}

أرسلت عبر تطبيق IQ OTOMBIL
''';
    return 'https://wa.me/9647701234567?text=${Uri.encodeComponent(message)}';
  }
}
