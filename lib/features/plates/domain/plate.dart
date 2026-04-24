import 'package:freezed_annotation/freezed_annotation.dart';
part 'plate.freezed.dart';
part 'plate.g.dart';

@freezed
class Plate with _$Plate {
  const factory Plate({
    required String id,
    required String plateNumber,
    required String plateType,
    String? governorate,
    String? description,
    double? price,
    required String sellerPhone,
    String? sellerName,
    required String status,
    List<String>? images,
    required String submittedVia,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Plate;

  factory Plate.fromJson(Map<String, dynamic> json) => _$PlateFromJson(json);
}
