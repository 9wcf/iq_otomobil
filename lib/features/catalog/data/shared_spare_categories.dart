import 'package:flutter/material.dart';

/// تعريف موحّد لأقسام قطع الغيار بين تطبيق المستخدم والتاجر.
/// **`products.category_id` يُخزَّن كمعرّف نصي `"1"` … `"9"`** ليتطابق مع الفلترة في الأقسام والبحث.
class SharedSpareCategory {
  const SharedSpareCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.iconAsset,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  /// أيقونة مخصّصة في تطبيق المستخدم (الشاشة الرئيسية).
  final String? iconAsset;
}

/// نفس الترتيب والمعرفات في الشاشة الرئيسية وإضافة المنتج.
const kSharedSpareCategories = <SharedSpareCategory>[
  SharedSpareCategory(
    id: '1',
    name: 'بدي',
    icon: Icons.car_crash,
    color: Color(0xFFE53935),
    iconAsset: 'assets/categories/car.png',
  ),
  SharedSpareCategory(
    id: '2',
    name: 'هيكل',
    icon: Icons.architecture_outlined,
    color: Color(0xFFFF9800),
    iconAsset: 'assets/categories/body.png',
  ),
  SharedSpareCategory(
    id: '3',
    name: 'غرفة قيادة',
    icon: Icons.settings,
    color: Color(0xFFFFC107),
    iconAsset: 'assets/categories/steering-wheel.png',
  ),
  SharedSpareCategory(
    id: '4',
    name: 'محرك',
    icon: Icons.engineering,
    color: Color(0xFF2196F3),
    iconAsset: 'assets/categories/engine.png',
  ),
  SharedSpareCategory(
    id: '5',
    name: 'لايتات',
    icon: Icons.lightbulb_outline,
    color: Color(0xFF9C27B0),
    iconAsset: 'assets/categories/lights.png',
  ),
  SharedSpareCategory(
    id: '6',
    name: 'تبريد',
    icon: Icons.blur_on,
    color: Color(0xFF009688),
    iconAsset: 'assets/categories/frozen.png',
  ),
  SharedSpareCategory(
    id: '7',
    name: 'كهربائيات',
    icon: Icons.electric_bolt,
    color: Color(0xFF4CAF50),
    iconAsset: 'assets/categories/electric.png',
  ),
  SharedSpareCategory(
    id: '8',
    name: 'فلاتر و زيوت',
    icon: Icons.oil_barrel_outlined,
    color: Color(0xFFFFEB3B),
    iconAsset: 'assets/categories/oil_filters.png',
  ),
  SharedSpareCategory(
    id: '9',
    name: 'ويل',
    icon: Icons.album_outlined,
    color: Color(0xFFCDDC39),
    iconAsset: 'assets/categories/wheel.png',
  ),
];

/// للقوائم المنسدلة في التاجر: خرائط id → name فقط.
List<Map<String, String>> get sharedCategoryDropdownMaps =>
    kSharedSpareCategories.map((c) => {'id': c.id, 'name': c.name}).toList();

const _deprecatedCategoryIds = {'10'};
const _deprecatedCategoryNames = {
  'تعليق',
  'إطارات',
  'فلتر',
};

/// اسم القسم المعروض للمستخدم (عربي) من المعرّف أو من قيم قديمة كانت تُخزَّن كنص عربي.
String sparePartCategoryDisplayName(dynamic categoryField) {
  final s = categoryField?.toString().trim() ?? '';
  if (s.isEmpty) return 'غير محدد';

  if (_deprecatedCategoryIds.contains(s) ||
      _deprecatedCategoryNames.contains(s)) {
    return 'غير محدد';
  }

  for (final c in kSharedSpareCategories) {
    if (c.id == s) return c.name;
  }
  for (final c in kSharedSpareCategories) {
    if (c.name == s) return c.name;
  }
  return s;
}
