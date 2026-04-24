// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductImpl _$$ProductImplFromJson(Map<String, dynamic> json) =>
    _$ProductImpl(
      id: json['id'] as String,
      promoterId: json['promoterId'] as String,
      categoryId: json['categoryId'] as String?,
      brandId: json['brandId'] as String?,
      brandName: json['brandName'] as String?,
      modelName: json['modelName'] as String?,
      condition: json['condition'] as String?,
      wheelType: json['wheelType'] as String?,
      description: json['description'] as String?,
      images:
          (json['images'] as List<dynamic>).map((e) => e as String).toList(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ProductImplToJson(_$ProductImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'promoterId': instance.promoterId,
      'categoryId': instance.categoryId,
      'brandId': instance.brandId,
      'brandName': instance.brandName,
      'modelName': instance.modelName,
      'condition': instance.condition,
      'wheelType': instance.wheelType,
      'description': instance.description,
      'images': instance.images,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
    };
