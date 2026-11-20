import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iq_otomobil/core/config/product_share_config.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareProduct({
  required BuildContext context,
  required String productId,
  required String title,
  required String price,
  String? brand,
}) async {
  final id = productId.trim();
  if (id.isEmpty) return;

  final link = ProductShareConfig.httpsProductUrl(id);
  final buffer = StringBuffer()
    ..writeln('🚗 $title');

  final brandTrimmed = brand?.trim();
  if (brandTrimmed != null && brandTrimmed.isNotEmpty) {
    buffer.writeln('الماركة: $brandTrimmed');
  }
  buffer
    ..writeln('السعر: $price')
    ..writeln()
    ..writeln('شاهد المنتج في IQ OTOMBIL:')
    ..writeln(link);

  if (defaultTargetPlatform == TargetPlatform.android) {
    buffer
      ..writeln()
      ..writeln('حمّل التطبيق:')
      ..writeln(ProductShareConfig.defaultPlayStoreUrl);
  }

  try {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await Share.share(
      buffer.toString(),
      subject: title,
      sharePositionOrigin: origin,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّرت مشاركة المنتج')),
      );
    }
  }
}
