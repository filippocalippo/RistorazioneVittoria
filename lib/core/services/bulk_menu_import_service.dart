import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a bulk import operation
class ImportResult {
  final int categoriesCreated;
  final int ingredientsCreated;
  final int sizesCreated;
  final int productsCreated;
  final List<String> errors;

  ImportResult({
    required this.categoriesCreated,
    required this.ingredientsCreated,
    required this.sizesCreated,
    required this.productsCreated,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => !hasErrors;
}

/// Service for bulk importing menu items from formatted text
class BulkMenuImportService {
  final _supabase = Supabase.instance.client;
  final String? _organizationId;

  BulkMenuImportService({String? organizationId})
      : _organizationId = organizationId;

  /// Parse and import menu items from formatted text
  Future<ImportResult> importFromText(
    String text,
  ) async {
    int categoriesCreated = 0;
    int ingredientsCreated = 0;
    int sizesCreated = 0;
    int productsCreated = 0;
    final List<String> errors = [];

    try {
      // Fetch existing data
      final existingCategories = await _fetchExistingCategories();
      final existingIngredients = await _fetchExistingIngredients();
      final existingSizes = await _fetchExistingSizes();

      // Parse the text
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      String? currentCategory;
      int productOrder = 0;

      for (var line in lines) {
        try {
          // Check if it's a category line (no comma)
          if (!line.contains(',')) {
            currentCategory = line;
            
            // Create category if it doesn't exist
            if (!existingCategories.containsKey(currentCategory.toLowerCase())) {
              await _createCategory(
                currentCategory,
                existingCategories.length + categoriesCreated,
              );
              existingCategories[currentCategory.toLowerCase()] = currentCategory;
              categoriesCreated++;
            }
            productOrder = 0; // Reset product order for new category
          } 
          // Product line
          else {
            if (currentCategory == null) {
              errors.add('Product found without category: $line');
              continue;
            }
            
            // Parse product with new format: Name, (ingredients), sizes, price1, price2
            // Extract ingredients in parentheses
            final ingredientsMatch = RegExp(r'\(([^)]*)\)').firstMatch(line);
            String ingredientsText = '';
            String lineWithoutIngredients = line;
            
            if (ingredientsMatch != null) {
              ingredientsText = ingredientsMatch.group(1) ?? '';
              // Remove the parentheses part from the line
              lineWithoutIngredients = line.replaceFirst(RegExp(r'\s*\([^)]*\)\s*'), ', ');
            }
            
            // Now split by comma
            final parts = lineWithoutIngredients.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
            
            if (parts.isEmpty) {
              errors.add('Invalid product format: $line');
              continue;
            }

            final productName = parts[0];
            
            // Find sizes and prices
            // Format: Name, sizes, price1, price2...
            // or: Name, price (no sizes)
            String sizesText = '';
            final prices = <double>[];
            
            // Try to parse each part after name
            for (int i = 1; i < parts.length; i++) {
              final part = parts[i];
              final priceText = part.replaceAll('€', '').replaceAll(',', '.').trim();
              final price = double.tryParse(priceText);
              
              if (price != null) {
                prices.add(price);
              } else if (prices.isEmpty) {
                // This must be the sizes part (comes before prices)
                sizesText = part;
              }
            }

            if (prices.isEmpty) {
              errors.add('No valid prices found for: $productName');
              continue;
            }

            // Parse and create ingredients
            final ingredientsList = ingredientsText
                .split(',')
                .map((i) => i.trim())
                .where((i) => i.isNotEmpty)
                .toList();

            final ingredientIds = <String>[];
            for (var ingredient in ingredientsList) {
              final ingredientKey = ingredient.toLowerCase();
              if (!existingIngredients.containsKey(ingredientKey)) {
                final id = await _createIngredient(
                  ingredient,
                  existingIngredients.length + ingredientsCreated,
                );
                existingIngredients[ingredientKey] = id;
                ingredientsCreated++;
              }
              ingredientIds.add(existingIngredients[ingredientKey]!);
            }

            // Parse and create sizes
            final sizeIds = <String>[];
            if (sizesText.isNotEmpty) {
              final sizesList = sizesText
                  .split('/')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

              for (int i = 0; i < sizesList.length; i++) {
                final sizeName = sizesList[i];
                final sizeKey = sizeName.toLowerCase();
                
                if (!existingSizes.containsKey(sizeKey)) {
                  final priceMultiplier = i < prices.length 
                      ? (prices[i] / prices[0]) 
                      : 1.0;
                  
                  final id = await _createSize(
                    sizeName,
                    priceMultiplier,
                    existingSizes.length + sizesCreated,
                    i == 0, // First size is default
                  );
                  existingSizes[sizeKey] = id;
                  sizesCreated++;
                }
                sizeIds.add(existingSizes[sizeKey]!);
              }
            }

            // Get category ID
            final categoryId = await _getCategoryId(
              currentCategory,
            );

            if (categoryId == null) {
              errors.add('Category not found: $currentCategory');
              continue;
            }

            // Create the product
            await _createProduct(
              categoryId: categoryId,
              name: productName,
              basePrice: prices[0],
              ingredientIds: ingredientIds,
              sizeIds: sizeIds,
              prices: prices,
              order: productOrder++,
            );
            productsCreated++;
          }
        } catch (e) {
          errors.add('Error processing line "$line": $e');
        }
      }

      return ImportResult(
        categoriesCreated: categoriesCreated,
        ingredientsCreated: ingredientsCreated,
        sizesCreated: sizesCreated,
        productsCreated: productsCreated,
        errors: errors,
      );
    } catch (e) {
      errors.add('Fatal error during import: $e');
      return ImportResult(
        categoriesCreated: categoriesCreated,
        ingredientsCreated: ingredientsCreated,
        sizesCreated: sizesCreated,
        productsCreated: productsCreated,
        errors: errors,
      );
    }
  }

  Future<Map<String, String>> _fetchExistingCategories() async {
    var query = _supabase
        .from('categorie_menu')
        .select('id, nome');
    if (_organizationId != null) {
      query = query.eq('organization_id', _organizationId);
    }
    final response = await query;

    final Map<String, String> categories = {};
    for (var item in response as List) {
      categories[(item['nome'] as String).toLowerCase()] = item['id'] as String;
    }
    return categories;
  }

  Future<Map<String, String>> _fetchExistingIngredients() async {
    var query = _supabase
        .from('ingredients')
        .select('id, nome');
    if (_organizationId != null) {
      query = query.eq('organization_id', _organizationId);
    }
    final response = await query;

    final Map<String, String> ingredients = {};
    for (var item in response as List) {
      ingredients[(item['nome'] as String).toLowerCase()] = item['id'] as String;
    }
    return ingredients;
  }

  Future<Map<String, String>> _fetchExistingSizes() async {
    var query = _supabase
        .from('sizes_master')
        .select('id, nome');
    if (_organizationId != null) {
      query = query.eq('organization_id', _organizationId);
    }
    final response = await query;

    final Map<String, String> sizes = {};
    for (var item in response as List) {
      sizes[(item['nome'] as String).toLowerCase()] = item['id'] as String;
    }
    return sizes;
  }

  Future<void> _createCategory(
    String name,
    int order,
  ) async {
    await _supabase.from('categorie_menu').insert({
      if (_organizationId != null) 'organization_id': _organizationId,
      'nome': name,
      'ordine': order,
      'attiva': true,
    });
  }

  Future<String> _createIngredient(
    String name,
    int order,
  ) async {
    final response = await _supabase
        .from('ingredients')
        .insert({
          if (_organizationId != null) 'organization_id': _organizationId,
          'nome': name,
          'prezzo': 0.0,
          'ordine': order,
          'attivo': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<String> _createSize(
    String name,
    double priceMultiplier,
    int order,
    bool isDefault,
  ) async {
    final slug = name.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9-]'), '');
    
    final response = await _supabase
        .from('sizes_master')
        .insert({
          if (_organizationId != null) 'organization_id': _organizationId,
          'nome': name,
          'slug': slug,
          'price_multiplier': priceMultiplier,
          'ordine': order,
          'attivo': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  String _sanitizeLikePattern(String query) {
    return query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  Future<String?> _getCategoryId(String categoryName) async {
    var query = _supabase
        .from('categorie_menu')
        .select('id')
        .ilike('nome', _sanitizeLikePattern(categoryName));
    if (_organizationId != null) {
      query = query.eq('organization_id', _organizationId);
    }
    final response = await query.maybeSingle();

    return response?['id'] as String?;
  }

  Future<void> _createProduct({
    required String categoryId,
    required String name,
    required double basePrice,
    required List<String> ingredientIds,
    required List<String> sizeIds,
    required List<double> prices,
    required int order,
  }) async {
    // Create the menu item
    final menuItemResponse = await _supabase
        .from('menu_items')
        .insert({
          if (_organizationId != null) 'organization_id': _organizationId,
          'categoria_id': categoryId,
          'nome': name,
          'prezzo': basePrice,
          'disponibile': true,
          'in_evidenza': false,
          'ordine': order,
          'ingredienti': [], // Legacy field, kept empty as we use relations
          'allergeni': [], // Legacy field, kept empty
          'product_configuration': {
            'allowSizeSelection': sizeIds.length > 1,
            'defaultSizeId': sizeIds.isNotEmpty ? sizeIds[0] : null,
            'allowIngredients': true,
            'maxIngredients': null,
            'specialOptions': [],
          },
        })
        .select('id')
        .single();

    final menuItemId = menuItemResponse['id'] as String;

    // Link ingredients
    if (ingredientIds.isNotEmpty) {
      final ingredientInserts = ingredientIds.asMap().entries.map((entry) {
        return {
          if (_organizationId != null) 'organization_id': _organizationId,
          'menu_item_id': menuItemId,
          'ingredient_id': entry.value,
          'ordine': entry.key,
        };
      }).toList();

      await _supabase
          .from('menu_item_included_ingredients')
          .insert(ingredientInserts);
    }

    // Link sizes with their specific prices
    if (sizeIds.isNotEmpty) {
      final sizeInserts = sizeIds.asMap().entries.map((entry) {
        final index = entry.key;
        return {
          if (_organizationId != null) 'organization_id': _organizationId,
          'menu_item_id': menuItemId,
          'size_id': entry.value,
          'ordine': index,
          'is_default': index == 0,
        };
      }).toList();

      await _supabase.from('menu_item_sizes').insert(sizeInserts);
    }
  }
}
