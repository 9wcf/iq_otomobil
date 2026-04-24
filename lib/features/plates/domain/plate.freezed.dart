// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Plate _$PlateFromJson(Map<String, dynamic> json) {
  return _Plate.fromJson(json);
}

/// @nodoc
mixin _$Plate {
  String get id => throw _privateConstructorUsedError;
  String get plateNumber => throw _privateConstructorUsedError;
  String get plateType => throw _privateConstructorUsedError;
  String? get governorate => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  double? get price => throw _privateConstructorUsedError;
  String get sellerPhone => throw _privateConstructorUsedError;
  String? get sellerName => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  List<String>? get images => throw _privateConstructorUsedError;
  String get submittedVia => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Plate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Plate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlateCopyWith<Plate> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlateCopyWith<$Res> {
  factory $PlateCopyWith(Plate value, $Res Function(Plate) then) =
      _$PlateCopyWithImpl<$Res, Plate>;
  @useResult
  $Res call(
      {String id,
      String plateNumber,
      String plateType,
      String? governorate,
      String? description,
      double? price,
      String sellerPhone,
      String? sellerName,
      String status,
      List<String>? images,
      String submittedVia,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$PlateCopyWithImpl<$Res, $Val extends Plate>
    implements $PlateCopyWith<$Res> {
  _$PlateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Plate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? plateNumber = null,
    Object? plateType = null,
    Object? governorate = freezed,
    Object? description = freezed,
    Object? price = freezed,
    Object? sellerPhone = null,
    Object? sellerName = freezed,
    Object? status = null,
    Object? images = freezed,
    Object? submittedVia = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      plateNumber: null == plateNumber
          ? _value.plateNumber
          : plateNumber // ignore: cast_nullable_to_non_nullable
              as String,
      plateType: null == plateType
          ? _value.plateType
          : plateType // ignore: cast_nullable_to_non_nullable
              as String,
      governorate: freezed == governorate
          ? _value.governorate
          : governorate // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      price: freezed == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double?,
      sellerPhone: null == sellerPhone
          ? _value.sellerPhone
          : sellerPhone // ignore: cast_nullable_to_non_nullable
              as String,
      sellerName: freezed == sellerName
          ? _value.sellerName
          : sellerName // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      images: freezed == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      submittedVia: null == submittedVia
          ? _value.submittedVia
          : submittedVia // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlateImplCopyWith<$Res> implements $PlateCopyWith<$Res> {
  factory _$$PlateImplCopyWith(
          _$PlateImpl value, $Res Function(_$PlateImpl) then) =
      __$$PlateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String plateNumber,
      String plateType,
      String? governorate,
      String? description,
      double? price,
      String sellerPhone,
      String? sellerName,
      String status,
      List<String>? images,
      String submittedVia,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$PlateImplCopyWithImpl<$Res>
    extends _$PlateCopyWithImpl<$Res, _$PlateImpl>
    implements _$$PlateImplCopyWith<$Res> {
  __$$PlateImplCopyWithImpl(
      _$PlateImpl _value, $Res Function(_$PlateImpl) _then)
      : super(_value, _then);

  /// Create a copy of Plate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? plateNumber = null,
    Object? plateType = null,
    Object? governorate = freezed,
    Object? description = freezed,
    Object? price = freezed,
    Object? sellerPhone = null,
    Object? sellerName = freezed,
    Object? status = null,
    Object? images = freezed,
    Object? submittedVia = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$PlateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      plateNumber: null == plateNumber
          ? _value.plateNumber
          : plateNumber // ignore: cast_nullable_to_non_nullable
              as String,
      plateType: null == plateType
          ? _value.plateType
          : plateType // ignore: cast_nullable_to_non_nullable
              as String,
      governorate: freezed == governorate
          ? _value.governorate
          : governorate // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      price: freezed == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double?,
      sellerPhone: null == sellerPhone
          ? _value.sellerPhone
          : sellerPhone // ignore: cast_nullable_to_non_nullable
              as String,
      sellerName: freezed == sellerName
          ? _value.sellerName
          : sellerName // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      images: freezed == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      submittedVia: null == submittedVia
          ? _value.submittedVia
          : submittedVia // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlateImpl implements _Plate {
  const _$PlateImpl(
      {required this.id,
      required this.plateNumber,
      required this.plateType,
      this.governorate,
      this.description,
      this.price,
      required this.sellerPhone,
      this.sellerName,
      required this.status,
      final List<String>? images,
      required this.submittedVia,
      required this.createdAt,
      required this.updatedAt})
      : _images = images;

  factory _$PlateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlateImplFromJson(json);

  @override
  final String id;
  @override
  final String plateNumber;
  @override
  final String plateType;
  @override
  final String? governorate;
  @override
  final String? description;
  @override
  final double? price;
  @override
  final String sellerPhone;
  @override
  final String? sellerName;
  @override
  final String status;
  final List<String>? _images;
  @override
  List<String>? get images {
    final value = _images;
    if (value == null) return null;
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String submittedVia;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Plate(id: $id, plateNumber: $plateNumber, plateType: $plateType, governorate: $governorate, description: $description, price: $price, sellerPhone: $sellerPhone, sellerName: $sellerName, status: $status, images: $images, submittedVia: $submittedVia, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.plateNumber, plateNumber) ||
                other.plateNumber == plateNumber) &&
            (identical(other.plateType, plateType) ||
                other.plateType == plateType) &&
            (identical(other.governorate, governorate) ||
                other.governorate == governorate) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.sellerPhone, sellerPhone) ||
                other.sellerPhone == sellerPhone) &&
            (identical(other.sellerName, sellerName) ||
                other.sellerName == sellerName) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.submittedVia, submittedVia) ||
                other.submittedVia == submittedVia) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      plateNumber,
      plateType,
      governorate,
      description,
      price,
      sellerPhone,
      sellerName,
      status,
      const DeepCollectionEquality().hash(_images),
      submittedVia,
      createdAt,
      updatedAt);

  /// Create a copy of Plate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlateImplCopyWith<_$PlateImpl> get copyWith =>
      __$$PlateImplCopyWithImpl<_$PlateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlateImplToJson(
      this,
    );
  }
}

abstract class _Plate implements Plate {
  const factory _Plate(
      {required final String id,
      required final String plateNumber,
      required final String plateType,
      final String? governorate,
      final String? description,
      final double? price,
      required final String sellerPhone,
      final String? sellerName,
      required final String status,
      final List<String>? images,
      required final String submittedVia,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$PlateImpl;

  factory _Plate.fromJson(Map<String, dynamic> json) = _$PlateImpl.fromJson;

  @override
  String get id;
  @override
  String get plateNumber;
  @override
  String get plateType;
  @override
  String? get governorate;
  @override
  String? get description;
  @override
  double? get price;
  @override
  String get sellerPhone;
  @override
  String? get sellerName;
  @override
  String get status;
  @override
  List<String>? get images;
  @override
  String get submittedVia;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Plate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlateImplCopyWith<_$PlateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
