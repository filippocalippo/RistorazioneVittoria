import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_item_model.freezed.dart';
part 'order_item_model.g.dart';

@freezed
class OrderItemModel with _$OrderItemModel {
  const factory OrderItemModel({
    required String id,
    required String ordineId,
    String? menuItemId,
    required String nomeProdotto,
    @Default(1) int quantita,
    required double prezzoUnitario,
    required double subtotale,
    String? note,
    Map<String, dynamic>? varianti,
    required DateTime createdAt,
  }) = _OrderItemModel;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) =>
      _$OrderItemModelFromJson(json);
}

/// Safe accessors for variant data to prevent crashes from malformed JSON
extension OrderItemVariantX on OrderItemModel {
  String get category {
    try {
      return (varianti?['category'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  String get sizeName {
    try {
      final size = varianti?['size'];
      if (size is Map) {
        return (size['name'] as String?) ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> get addedIngredients {
    try {
      final added = varianti?['addedIngredients'];
      if (added is List) {
        return added.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> get removedIngredients {
    try {
      final removed = varianti?['removedIngredients'];
      if (removed is List) {
        return removed.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  String get variantNote {
    try {
      return (varianti?['note'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  String get displayName {
    final parts = <String>[];
    if (category.isNotEmpty) parts.add(category);
    parts.add(nomeProdotto);
    if (sizeName.isNotEmpty) parts.add(sizeName);
    return parts.join(' - ');
  }

  /// Check if this is a split product
  bool get isSplitProduct {
    try {
      final specialOptions = varianti?['specialOptions'];
      if (specialOptions is List && specialOptions.length == 2) {
        final first = specialOptions[0] as Map<String, dynamic>?;
        final second = specialOptions[1] as Map<String, dynamic>?;
        return first?['id'] == 'split_first' && second?['id'] == 'split_second';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get split product details for kitchen display
  List<Map<String, dynamic>> get splitProducts {
    try {
      if (!isSplitProduct) return [];
      final specialOptions = varianti?['specialOptions'] as List;
      return specialOptions.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get formatted split product names for display
  String get splitProductNames {
    if (!isSplitProduct) return '';
    final products = splitProducts;
    if (products.length != 2) return '';
    
    final first = products[0]['name'] as String? ?? '';
    final second = products[1]['name'] as String? ?? '';
    return '$first + $second';
  }
  
  /// Get split product image URLs (first, second)
  (String?, String?) get splitProductImages {
    if (!isSplitProduct) return (null, null);
    final products = splitProducts;
    if (products.length != 2) return (null, null);
    
    final firstImage = products[0]['imageUrl'] as String?;
    final secondImage = products[1]['imageUrl'] as String?;
    return (firstImage, secondImage);
  }
}
