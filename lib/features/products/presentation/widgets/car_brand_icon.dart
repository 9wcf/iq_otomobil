import 'package:flutter/material.dart';
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';

/// أيقونة ماركة السيارة من الأصول المحلية.
class CarBrandIcon extends StatelessWidget {
  final CarBrandEntry? brand;
  final String? storageLabel;
  final double size;
  final BoxFit fit;

  const CarBrandIcon({
    super.key,
    this.brand,
    this.storageLabel,
    this.size = 28,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final entry = brand ?? brandByStorageLabel(storageLabel);
    if (entry == null) {
      return Icon(Icons.directions_car_outlined, size: size * 0.85);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset(
        entry.iconAsset,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.directions_car_outlined, size: size * 0.85),
      ),
    );
  }
}

Widget carBrandDropdownRow(CarBrandEntry brand, {double iconSize = 26}) {
  return Row(
    children: [
      CarBrandIcon(brand: brand, size: iconSize),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          brand.displayLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
