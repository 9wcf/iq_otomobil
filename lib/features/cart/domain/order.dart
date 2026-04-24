import 'package:freezed_annotation/freezed_annotation.dart';
part 'order.freezed.dart';
part 'order.g.dart';

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String userId,
    String? promoterId,
    String? productId,
    required int quantity,
    required String fullAddress,
    required String phone,
    String? notes,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Order;
  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}
