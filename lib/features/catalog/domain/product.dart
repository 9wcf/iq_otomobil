import 'package:freezed_annotation/freezed_annotation.dart';
part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String promoterId,
    String? categoryId,
    String? brandId,
    String? brandName,
    String? modelName,
    String? condition,
    String? wheelType,
    String? description,
    required List<String> images,
    required String status,
    required DateTime createdAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}
