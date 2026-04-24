import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

class AdRepository {
  final _client = SupabaseService.client;

  /// جلب الإعلانات النشطة - طريقة بسيطة ومتوافقة مع جميع الإصدارات
  Future<List<Map<String, dynamic>>> getActiveAds({String? position}) async {
    // نجلب كل الإعلانات ثم نفلترها محلياً (أضمن توافقاً)
    var query = _client.from('advertisements').select();

    if (position != null) {
      query = query.eq('position', position);
    }

    final results = await query.order('created_at', ascending: false);

    // فلترة محلية: نشط + لم تنتهِ صلاحيته
    final now = DateTime.now();
    return results.where((ad) {
      final isActive = ad['is_active'] == true;
      final endDate = ad['end_date'];
      final isNotExpired =
          endDate == null || DateTime.parse(endDate).isAfter(now);
      return isActive && isNotExpired;
    }).toList();
  }

  /// زيادة عدد المشاهدات - طريقة Supabase الصحيحة
  Future<void> incrementView(String adId) async {
    // الطريقة 1: استخدام RPC إذا كانت الدالة موجودة في قاعدة البيانات
    try {
      await _client.rpc('increment_ad_view', params: {'ad_id': adId});
      return;
    } catch (_) {
      // الطريقة 2 (بديل): قراءة ثم تحديث (read-modify-write)
      await _incrementField(adId, 'view_count');
    }
  }

  /// زيادة عدد النقرات - طريقة Supabase الصحيحة
  Future<void> incrementClick(String adId) async {
    try {
      await _client.rpc('increment_ad_click', params: {'ad_id': adId});
      return;
    } catch (_) {
      await _incrementField(adId, 'click_count');
    }
  }

  /// دالة مساعدة للزيادة اليدوية (بديل آمن)
  Future<void> _incrementField(String adId, String fieldName) async {
    // 1. جلب القيمة الحالية
    final result = await _client
        .from('advertisements')
        .select(fieldName)
        .eq('id', adId)
        .maybeSingle();

    if (result == null) return;

    // 2. زيادة القيمة وتحديثها
    final currentValue = (result[fieldName] as int?) ?? 0;
    await _client
        .from('advertisements')
        .update({fieldName: currentValue + 1}).eq('id', adId);
  }

  /// إضافة إعلان جديد (للأدمن)
  Future<void> createAd({
    String? title,
    String? content,
    String? imageUrl,
    String? linkUrl,
    required String type,
    required String position,
    DateTime? endDate,
  }) async {
    await _client.from('advertisements').insert({
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'type': type,
      'position': position,
      'end_date': endDate?.toIso8601String(),
      'is_active': true,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  /// تحديث حالة الإعلان
  Future<void> updateAdStatus(String adId, bool isActive) => _client
      .from('advertisements')
      .update({'is_active': isActive}).eq('id', adId);
}
