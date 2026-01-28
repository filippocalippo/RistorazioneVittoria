// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'size_variant_model.freezed.dart';
part 'size_variant_model.g.dart';

@freezed
class SizeVariantModel with _$SizeVariantModel {
  const factory SizeVariantModel({
    @JsonKey(name: 'organization_id') String? organizationId,
    required String id,
    required String nome,
    required String slug,
    String? descrizione,
    @JsonKey(name: 'price_multiplier') @Default(1.0) double priceMultiplier,
    @Default(0) int ordine,
    @Default(true) bool attivo,
    @JsonKey(name: 'permetti_divisioni') @Default(false) bool permittiDivisioni,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _SizeVariantModel;

  factory SizeVariantModel.fromJson(Map<String, dynamic> json) =>
      _$SizeVariantModelFromJson(json);
}

extension SizeVariantModelX on SizeVariantModel {
  /// Calculate price for this size given a base price
  double calculatePrice(double basePrice) {
    return basePrice * priceMultiplier;
  }

  /// Get formatted display name (e.g., "Media (30cm)")
  String get displayName {
    if (descrizione != null && descrizione!.isNotEmpty) {
      return '$nome ($descrizione)';
    }
    return nome;
  }
}
