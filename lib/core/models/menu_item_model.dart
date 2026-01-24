// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'product_configuration_model.dart';

part 'menu_item_model.freezed.dart';
part 'menu_item_model.g.dart';

@freezed
class MenuItemModel with _$MenuItemModel {
  const factory MenuItemModel({
    required String id,
    @JsonKey(name: 'categoria_id') String? categoriaId,
    required String nome,
    String? descrizione,
    required double prezzo,
    @JsonKey(name: 'prezzo_scontato') double? prezzoScontato,
    @JsonKey(name: 'immagine_url') String? immagineUrl,
    @Default([]) List<String> ingredienti,
    @Default([]) List<String> allergeni,
    @JsonKey(name: 'valori_nutrizionali')
    Map<String, dynamic>? valoriNutrizionali,
    @Default(true) bool disponibile,
    @JsonKey(name: 'in_evidenza') @Default(false) bool inEvidenza,
    @Default(0) int ordine,
    @JsonKey(name: 'product_configuration')
    ProductConfigurationModel? productConfiguration,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _MenuItemModel;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemModelFromJson(json);
}

extension MenuItemModelX on MenuItemModel {
  double get prezzoEffettivo => prezzoScontato ?? prezzo;

  bool get hasSconto => prezzoScontato != null && prezzoScontato! < prezzo;

  double get percentualeSconto {
    if (!hasSconto || prezzo == 0) return 0;
    return ((prezzo - prezzoScontato!) / prezzo) * 100;
  }

  /// Check if this item has any customization options
  bool get hasCustomization {
    return productConfiguration?.hasCustomization ?? false;
  }

  /// Check if size selection is enabled
  bool get allowsSizeSelection {
    return productConfiguration?.allowSizeSelection ?? false;
  }

  /// Check if ingredients are enabled
  bool get allowsIngredients {
    return productConfiguration?.allowIngredients ?? false;
  }

  /// Check if supplements are enabled (backward compatibility)
  @Deprecated('Use allowsIngredients instead')
  bool get allowsSupplements {
    return allowsIngredients;
  }

  /// Get product configuration or create empty one
  ProductConfigurationModel get config {
    return productConfiguration ?? ProductConfigurationModel.empty();
  }
}
