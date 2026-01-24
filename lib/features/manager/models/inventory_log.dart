// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_log.freezed.dart';
part 'inventory_log.g.dart';

@freezed
class InventoryLog with _$InventoryLog {
  const factory InventoryLog({
    required String id,
    @JsonKey(name: 'ingredient_id') required String ingredientId,
    @JsonKey(name: 'quantity_change') required double quantityChange,
    required String reason, // 'order', 'restock', 'correction', 'waste'
    @JsonKey(name: 'reference_id') String? referenceId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _InventoryLog;

  factory InventoryLog.fromJson(Map<String, dynamic> json) =>
      _$InventoryLogFromJson(json);
}
