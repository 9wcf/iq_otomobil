import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/config/app_config.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

final plateRepoProvider = Provider((ref) => PlateRepository());

final approvedPlatesProvider = FutureProvider.autoDispose((ref) async {
  try {
    return await ref.watch(plateRepoProvider).getApprovedPlates();
  } catch (e) {
    return <Map<String, dynamic>>[]; // إرجاع قائمة فارغة في حال الخطأ
  }
});

class PlateRepository {
  final _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getApprovedPlates() async {
    try {
      final response = await _client
          .from('car_plates')
          .select()
          .eq('status', 'approved')
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      print('Error fetching plates: $e');
      return [];
    }
  }

  Future<void> submitPlate({
    required String plateNumber,
    required String plateType,
    String? governorate,
    String? description,
    double? price,
    required String sellerPhone,
    String? sellerName,
  }) async {
    await _client.from('car_plates').insert({
      'plate_number': plateNumber,
      'plate_type': plateType,
      'governorate': governorate,
      'description': description,
      'price': price,
      'seller_phone': sellerPhone,
      'seller_name': sellerName,
      'status': 'pending',
      'submitted_via': 'form',
    });
  }

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
    return 'https://wa.me/${AppConfig.ownerWhatsAppNumber}?text=${Uri.encodeComponent(message)}';
  }
}

class PlateActionNotifier extends StateNotifier<AsyncValue<void>> {
  final PlateRepository _repo;
  PlateActionNotifier(this._repo) : super(const AsyncData(null));

  Future<void> submit(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await _repo.submitPlate(
        plateNumber: data['plateNumber'],
        plateType: data['plateType'],
        governorate: data['governorate'],
        description: data['description'],
        price: data['price'],
        sellerPhone: data['sellerPhone'],
        sellerName: data['sellerName'],
      );
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  String getWhatsAppLink(Map<String, dynamic> data) {
    return _repo.createWhatsAppLink(
      plateNumber: data['plateNumber'],
      sellerPhone: data['sellerPhone'],
      description: data['description'],
      price: data['price'],
    );
  }
}

final plateActionProvider =
    StateNotifierProvider<PlateActionNotifier, AsyncValue<void>>(
  (ref) => PlateActionNotifier(ref.watch(plateRepoProvider)),
);
