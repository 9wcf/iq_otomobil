/// ماركات معتمدة في التطبيق — للعرض ثنائي اللغة وحفظ نص واضح في قاعدة البيانات
class CarBrandEntry {
  final String id;
  final String nameAr;
  final String nameEn;
  final String iconAsset;

  const CarBrandEntry({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.iconAsset,
  });

  /// للقوائم المنسدلة سطر واحد
  String get displayLine => '$nameAr · $nameEn';

  /// قيمة مختزنة في الحقل النصي (مثل brand_id) للبحث والعرض
  String get storageLabel => '$nameAr ($nameEn)';
}

/// الماركات المعتمدة فقط — بالترتيب المطلوب
const kCarBrandsCatalog = <CarBrandEntry>[
  CarBrandEntry(
      id: 'toyota',
      nameAr: 'تويوتا',
      nameEn: 'Toyota',
      iconAsset: 'assets/brands/toyota.png'),
  CarBrandEntry(
      id: 'kia', nameAr: 'كيا', nameEn: 'Kia', iconAsset: 'assets/brands/kia.png'),
  CarBrandEntry(
      id: 'hyundai',
      nameAr: 'هيونداي',
      nameEn: 'Hyundai',
      iconAsset: 'assets/brands/hyundai.webp'),
  CarBrandEntry(
      id: 'nissan',
      nameAr: 'نيسان',
      nameEn: 'Nissan',
      iconAsset: 'assets/brands/nissan.webp'),
  CarBrandEntry(
      id: 'chevrolet',
      nameAr: 'شيفروليه',
      nameEn: 'Chevrolet',
      iconAsset: 'assets/brands/chevrolet.png'),
  CarBrandEntry(
      id: 'ford',
      nameAr: 'فورد',
      nameEn: 'Ford',
      iconAsset: 'assets/brands/ford.webp'),
  CarBrandEntry(
      id: 'lexus',
      nameAr: 'لكزس',
      nameEn: 'Lexus',
      iconAsset: 'assets/brands/lexus.webp'),
  CarBrandEntry(
      id: 'mg', nameAr: 'ام جي', nameEn: 'MG', iconAsset: 'assets/brands/mg.webp'),
  CarBrandEntry(
      id: 'mitsubishi',
      nameAr: 'ميتسوبيشي',
      nameEn: 'Mitsubishi',
      iconAsset: 'assets/brands/mitsubishi.png'),
  CarBrandEntry(
      id: 'honda',
      nameAr: 'هوندا',
      nameEn: 'Honda',
      iconAsset: 'assets/brands/honda.webp'),
  CarBrandEntry(
      id: 'vw',
      nameAr: 'فولكس فاغن',
      nameEn: 'Volkswagen',
      iconAsset: 'assets/brands/vw.png'),
  CarBrandEntry(
      id: 'gmc',
      nameAr: 'جي ام سي',
      nameEn: 'GMC',
      iconAsset: 'assets/brands/gmc.png'),
  CarBrandEntry(
      id: 'cadillac',
      nameAr: 'كاديلاك',
      nameEn: 'Cadillac',
      iconAsset: 'assets/brands/cadillac.png'),
  CarBrandEntry(
      id: 'byd',
      nameAr: 'بي واي دي',
      nameEn: 'BYD',
      iconAsset: 'assets/brands/byd.webp'),
  CarBrandEntry(
      id: 'bmw',
      nameAr: 'بي ام دبليو',
      nameEn: 'BMW',
      iconAsset: 'assets/brands/bmw.webp'),
  CarBrandEntry(
      id: 'mercedes',
      nameAr: 'مرسيدس بنز',
      nameEn: 'Mercedes-Benz',
      iconAsset: 'assets/brands/mercedes.webp'),
  CarBrandEntry(
      id: 'audi',
      nameAr: 'اودي',
      nameEn: 'Audi',
      iconAsset: 'assets/brands/audi.webp'),
  CarBrandEntry(
      id: 'land_rover',
      nameAr: 'لاند روفر',
      nameEn: 'Land Rover',
      iconAsset: 'assets/brands/land_rover.webp'),
  CarBrandEntry(
      id: 'infiniti',
      nameAr: 'إنفينيتي',
      nameEn: 'Infiniti',
      iconAsset: 'assets/brands/infiniti.png'),
  CarBrandEntry(
      id: 'genesis',
      nameAr: 'جينيسس',
      nameEn: 'Genesis',
      iconAsset: 'assets/brands/genesis.png'),
  CarBrandEntry(
      id: 'jeep',
      nameAr: 'جيب',
      nameEn: 'Jeep',
      iconAsset: 'assets/brands/jeep.webp'),
  CarBrandEntry(
      id: 'ram', nameAr: 'رام', nameEn: 'Ram', iconAsset: 'assets/brands/ram.png'),
  CarBrandEntry(
      id: 'chrysler',
      nameAr: 'كرايسلر',
      nameEn: 'Chrysler',
      iconAsset: 'assets/brands/chrysler.png'),
  CarBrandEntry(
      id: 'dodge',
      nameAr: 'دودج',
      nameEn: 'Dodge',
      iconAsset: 'assets/brands/dodge.webp'),
  CarBrandEntry(
      id: 'tesla',
      nameAr: 'تسلا',
      nameEn: 'Tesla',
      iconAsset: 'assets/brands/tesla.webp'),
  CarBrandEntry(
      id: 'jetour',
      nameAr: 'جيتور',
      nameEn: 'Jetour',
      iconAsset: 'assets/brands/jetour.png'),
  CarBrandEntry(
      id: 'geely',
      nameAr: 'جيلي',
      nameEn: 'Geely',
      iconAsset: 'assets/brands/geely.png'),
  CarBrandEntry(
      id: 'changan',
      nameAr: 'شانجان',
      nameEn: 'Changan',
      iconAsset: 'assets/brands/changan.png'),
  CarBrandEntry(
      id: 'chery',
      nameAr: 'شيري',
      nameEn: 'Chery',
      iconAsset: 'assets/brands/chery.webp'),
  CarBrandEntry(
      id: 'haval',
      nameAr: 'هافال',
      nameEn: 'Haval',
      iconAsset: 'assets/brands/haval.png'),
  CarBrandEntry(
      id: 'tank',
      nameAr: 'تانك',
      nameEn: 'Tank',
      iconAsset: 'assets/brands/tank.png'),
];

CarBrandEntry? brandById(String? id) {
  if (id == null) return null;
  for (final b in kCarBrandsCatalog) {
    if (b.id == id) return b;
  }
  return null;
}

/// مطابقة القيمة المخزّنة في `products.brand_id` (مثل `تويوتا (Toyota)`).
CarBrandEntry? brandByStorageLabel(String? label) {
  if (label == null || label.isEmpty) return null;
  for (final b in kCarBrandsCatalog) {
    if (b.storageLabel == label) return b;
  }
  for (final b in kCarBrandsCatalog) {
    if (label.contains(b.nameAr) || label.contains(b.nameEn)) return b;
  }
  // أسماء قديمة في البيانات
  if (label.contains('فولكس فاجن') || label.contains('Volkswagen')) {
    return brandById('vw');
  }
  if (label.contains('مرسيدس') || label.contains('Mercedes')) {
    return brandById('mercedes');
  }
  if (label.contains('أودي')) {
    return brandById('audi');
  }
  return null;
}
