// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlateImpl _$$PlateImplFromJson(Map<String, dynamic> json) => _$PlateImpl(
      id: json['id'] as String,
      plateNumber: json['plateNumber'] as String,
      plateType: json['plateType'] as String,
      governorate: json['governorate'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      sellerPhone: json['sellerPhone'] as String,
      sellerName: json['sellerName'] as String?,
      status: json['status'] as String,
      images:
          (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
      submittedVia: json['submittedVia'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PlateImplToJson(_$PlateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'plateNumber': instance.plateNumber,
      'plateType': instance.plateType,
      'governorate': instance.governorate,
      'description': instance.description,
      'price': instance.price,
      'sellerPhone': instance.sellerPhone,
      'sellerName': instance.sellerName,
      'status': instance.status,
      'images': instance.images,
      'submittedVia': instance.submittedVia,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
