// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'size_variant_model.dart';

part 'menu_item_size_assignment_model.freezed.dart';
part 'menu_item_size_assignment_model.g.dart';

@freezed
class MenuItemSizeAssignmentModel with _$MenuItemSizeAssignmentModel {
  const factory MenuItemSizeAssignmentModel({
    required String id,
    @JsonKey(name: 'menu_item_id') required String menuItemId,
    @JsonKey(name: 'size_id') required String sizeId,
    @JsonKey(name: 'display_name_override') String? displayNameOverride,
    @JsonKey(name: 'is_default') @Default(false) bool isDefault,
    @JsonKey(name: 'price_override') double? priceOverride,
    @Default(0) int ordine,
    @JsonKey(name: 'created_at') required DateTime createdAt,

    // Joined size data (when fetching with join)
    @JsonKey(name: 'sizes_master') SizeVariantModel? sizeData,
  }) = _MenuItemSizeAssignmentModel;

  factory MenuItemSizeAssignmentModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemSizeAssignmentModelFromJson(json);
}

extension MenuItemSizeAssignmentModelX on MenuItemSizeAssignmentModel {
  /// Get the effective display name (override or original)
  String getDisplayName() {
    if (displayNameOverride != null && displayNameOverride!.isNotEmpty) {
      return displayNameOverride!;
    }
    return sizeData?.nome ?? '';
  }

  /// Get the effective display name with description
  String getFullDisplayName() {
    final name = getDisplayName();
    final desc = sizeData?.descrizione;
    if (desc != null && desc.isNotEmpty) {
      return '$name ($desc)';
    }
    return name;
  }

  /// Get price multiplier from size data
  double get priceMultiplier => sizeData?.priceMultiplier ?? 1.0;

  /// Calculate effective price for this size given a base price
  /// Uses the per-product price_override when present, otherwise
  /// falls back to applying the size multiplier.
  double calculateEffectivePrice(double basePrice) {
    if (priceOverride != null) {
      return priceOverride!;
    }
    return basePrice * priceMultiplier;
  }
}
