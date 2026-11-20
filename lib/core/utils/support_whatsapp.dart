import 'package:flutter/material.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// رقم واتساب الإدارة — الدعم، طلب قطعة خاصة، طلب لوحة سيارة.
abstract final class SupportContact {
  static const display = '776 099 7799';

  /// wa.me بدون + (964 + 7760997799)
  static const whatsAppDigits = '9647760997799';
}

Future<void> openSupportWhatsApp({
  required BuildContext context,
  required String message,
  bool includeUserPhoneInMessage = false,
}) async {
  final buffer = StringBuffer(message.trim());
  if (includeUserPhoneInMessage) {
    final userPhone = SupabaseService.currentUserInfo?.phone?.trim();
    if (userPhone != null && userPhone.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('رقمي: $userPhone');
    }
  }

  final uri = Uri.parse(
    'https://wa.me/${SupportContact.whatsAppDigits}'
    '?text=${Uri.encodeComponent(buffer.toString())}',
  );

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح واتساب')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح واتساب')),
      );
    }
  }
}
