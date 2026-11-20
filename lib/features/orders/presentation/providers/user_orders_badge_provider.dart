import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

/// عدد طلبات المستخدم «النشطة» (ليست مكتملة ولا ملغاة) — يُعرض على زر الطلبات في الهوم.
final userActiveOrdersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = SupabaseService.currentUserId;
  if (uid == null) return 0;

  final res = await SupabaseService.client
      .from('orders')
      .select('id')
      .eq('user_id', uid)
      .inFilter('status', [
        'pending',
        'pending_promoter_review',
        'approved',
        'shipped',
      ]);

  return (res as List).length;
});
