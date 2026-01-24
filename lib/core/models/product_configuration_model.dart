import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_configuration_model.freezed.dart';
part 'product_configuration_model.g.dart';

@freezed
class ProductConfigurationModel with _$ProductConfigurationModel {
  const factory ProductConfigurationModel({
    @Default(false) bool allowSizeSelection,
    String? defaultSizeId,
    @Default(false) bool allowIngredients,
    int? maxIngredients,
    @Default([]) List<SpecialOption> specialOptions,
  }) = _ProductConfigurationModel;

  factory ProductConfigurationModel.fromJson(Map<String, dynamic> json) =>
      _$ProductConfigurationModelFromJson(json);

  /// Create empty configuration
  factory ProductConfigurationModel.empty() =>
      const ProductConfigurationModel();
}

@freezed
class SpecialOption with _$SpecialOption {
  const factory SpecialOption({
    required String id,
    required String name,
    required double price,
    String? description,
    // For split products: store the product ID and image URL
    String? productId,
    String? imageUrl,
  }) = _SpecialOption;

  factory SpecialOption.fromJson(Map<String, dynamic> json) =>
      _$SpecialOptionFromJson(json);
}

extension ProductConfigurationModelX on ProductConfigurationModel {
  /// Check if product has any customization options
  bool get hasCustomization {
    return allowSizeSelection || allowIngredients || specialOptions.isNotEmpty;
  }

  /// Check if ingredients are enabled with no limit
  bool get hasUnlimitedIngredients {
    return allowIngredients && maxIngredients == null;
  }

  // Backward compatibility
  @Deprecated('Use allowIngredients instead')
  bool get allowSupplements => allowIngredients;

  @Deprecated('Use maxIngredients instead')
  int? get maxSupplements => maxIngredients;
}
