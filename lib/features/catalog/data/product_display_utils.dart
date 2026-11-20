/// عناوين المنتج من `products` (حقل [piece_name] اختياري + [model]).
String productDisplayTitle(Map<String, dynamic> p) {
  final piece = p['piece_name']?.toString().trim();
  if (piece != null && piece.isNotEmpty) return piece;
  final m = p['model']?.toString().trim();
  if (m != null && m.isNotEmpty) return m;
  return 'بدون اسم';
}

/// حقل الموديل / سنة الصنع كما أدخل التاجر (قد يكون فارغاً).
String productDisplayModel(Map<String, dynamic> p) {
  final m = p['model']?.toString().trim();
  if (m != null && m.isNotEmpty) return m;
  return '—';
}

/// اسم القطعة المخزّن فقط (للتحرير والصفوف التفصيلية).
String? productPieceNameRaw(Map<String, dynamic> p) {
  final s = p['piece_name']?.toString().trim();
  if (s == null || s.isEmpty) return null;
  return s;
}
