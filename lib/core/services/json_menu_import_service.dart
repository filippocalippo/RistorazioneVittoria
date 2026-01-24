import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bulk_menu_import_service.dart';

class JsonMenuImportService {
  final _supabase = Supabase.instance.client;
  final String? _organizationId;

  JsonMenuImportService({String? organizationId})
      : _organizationId = organizationId;

  Future<ImportResult> importFromJson(String jsonString) async {
    final List<String> errors = [];
    int categoriesCreated = 0;
    int ingredientsCreated = 0;
    int sizesCreated = 0;
    int productsCreated = 0;

    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // 1. Process Categories
      if (data.containsKey('categories')) {
        final categories = data['categories'] as List;
        final existingCategories = await _fetchExistingMap('categorie_menu', 'nome', 'id');

        for (var cat in categories) {
          final name = cat['name'] as String;
          final order = cat['order'] as int? ?? 0;
          final categoryKey = name.toLowerCase();

          if (!existingCategories.containsKey(categoryKey)) {
            await _supabase.from('categorie_menu').insert({
              if (_organizationId != null) 'organization_id': _organizationId,
              'nome': name,
              'ordine': order,
              'attiva': true,
            });
            categoriesCreated++;
            // Refresh map for subsequent lookups
            existingCategories[categoryKey] = 'placeholder'; // Real ID not needed for just checking existence here, but implies we should refetch if we needed IDs now
          }
        }
      }

      // 2. Process Ingredients
      if (data.containsKey('ingredients')) {
        final ingredients = data['ingredients'] as List;
        final existingIngredients = await _fetchExistingMap('ingredients', 'nome', 'id');

        for (var ing in ingredients) {
          final name = ing['name'] as String;
          final ingredientKey = name.toLowerCase();

          if (!existingIngredients.containsKey(ingredientKey)) {
            await _supabase.from('ingredients').insert({
              if (_organizationId != null) 'organization_id': _organizationId,
              'nome': name,
              'prezzo': ing['price'] as num? ?? 0.0,
              'categoria': ing['category'] as String?, // Optional category tag
              'attivo': true,
            });
            ingredientsCreated++;
            existingIngredients[ingredientKey] = 'placeholder';
          }
        }
      }

      // 3. Process Sizes
      if (data.containsKey('sizes')) {
        final sizes = data['sizes'] as List;
        final existingSizes = await _fetchExistingMap('sizes_master', 'nome', 'id');

        for (var size in sizes) {
          final name = size['name'] as String;
          final sizeKey = name.toLowerCase();

          if (!existingSizes.containsKey(sizeKey)) {
            final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
            await _supabase.from('sizes_master').insert({
              if (_organizationId != null) 'organization_id': _organizationId,
              'nome': name,
              'slug': slug,
              'price_multiplier': size['price_multiplier'] as num? ?? 1.0,
              'attivo': true,
            });
            sizesCreated++;
            existingSizes[sizeKey] = 'placeholder';
          }
        }
      }

      // Refresh all maps with actual IDs for Product creation
      final categoryMap = await _fetchExistingMap('categorie_menu', 'nome', 'id');
      final ingredientMap = await _fetchExistingMap('ingredients', 'nome', 'id');
      final sizeMap = await _fetchExistingMap('sizes_master', 'nome', 'id');
      
      // Helper to find ingredient ID (case-insensitive)
      String? findIngredientId(String name) => ingredientMap[name.toLowerCase()];
      // Helper to find size ID
      String? findSizeId(String name) => sizeMap[name.toLowerCase()];

      // 4. Process Products
      if (data.containsKey('products')) {
        final products = data['products'] as List;

        for (var prod in products) {
          try {
            final name = prod['name'] as String;
            final categoryName = prod['category'] as String;
            final price = (prod['price'] as num).toDouble();
            final description = prod['description'] as String?;
            final order = prod['order'] as int? ?? productsCreated;

            final categoryId = categoryMap[categoryName.toLowerCase()];
            if (categoryId == null) {
              errors.add('Category not found for product "$name": $categoryName');
              continue;
            }

            // Create Menu Item
            final menuItemResponse = await _supabase.from('menu_items').insert({
              if (_organizationId != null) 'organization_id': _organizationId,
              'nome': name,
              'categoria_id': categoryId,
              'prezzo': price,
              'descrizione': description,
              'ordine': order,
              'disponibile': true,
              'allergeni': (prod['allergens'] as List?)?.cast<String>() ?? [],
              'product_configuration': {
                'allowSizeSelection': (prod['sizes'] as List?)?.isNotEmpty ?? false,
                'allowIngredients': true, // Default to true
              }
            }).select('id').single();
            
            final menuItemId = menuItemResponse['id'] as String;
            productsCreated++;

            // Included Ingredients
            if (prod.containsKey('included_ingredients')) {
              final included = prod['included_ingredients'] as List;
              for (var i = 0; i < included.length; i++) {
                final ingName = included[i] as String;
                final ingId = findIngredientId(ingName);
                if (ingId != null) {
                  await _supabase.from('menu_item_included_ingredients').insert({
                    if (_organizationId != null) 'organization_id': _organizationId,
                    'menu_item_id': menuItemId,
                    'ingredient_id': ingId,
                    'ordine': i,
                  });
                } else {
                  errors.add('Included ingredient not found: $ingName in product $name');
                }
              }
            }

            // Extra Ingredients (The Powerful Part)
            if (prod.containsKey('extra_ingredients')) {
              final extras = prod['extra_ingredients'];
              List<Map<String, dynamic>> extrasToInsert = [];

              if (extras is String && extras == "ALL") {
                 // Add ALL existing ingredients
                 ingredientMap.forEach((key, id) {
                   extrasToInsert.add({
                     'menu_item_id': menuItemId,
                     'ingredient_id': id,
                     'price_override': null, // Use ingredient default
                   });
                 });
              } else if (extras is List) {
                for (var extra in extras) {
                   if (extra is String) {
                     if (extra == 'ALL') {
                       // Add ALL existing ingredients
                       ingredientMap.forEach((key, id) {
                         extrasToInsert.add({
                           'menu_item_id': menuItemId,
                           'ingredient_id': id,
                           'price_override': null,
                         });
                       });
                       continue;
                     }

                     // Just a name
                     final ingId = findIngredientId(extra);
                     if (ingId != null) {
                       extrasToInsert.add({
                         'menu_item_id': menuItemId,
                         'ingredient_id': ingId,
                       });
                     } else {
                        // Check if it is a shortcut like "CATEGORY:Vegetables"
                        if (extra.startsWith("CATEGORY:")) {
                           final catName = extra.substring(9).trim();
                           // We need to fetch ingredients by category
                           final catIngredients = await _supabase
                               .from('ingredients')
                               .select('id')
                               .eq('categoria', catName); // Assuming 'categoria' column exists on ingredients
                           
                           for (var item in catIngredients) {
                             extrasToInsert.add({
                               'menu_item_id': menuItemId,
                               'ingredient_id': item['id'],
                             });
                           }
                        } else {
                           errors.add('Extra ingredient not found: $extra in product $name');
                        }
                     }
                   } else if (extra is Map) {
                     // Complex object: { "name": "X", "price_override": 1.0 }
                     // OR Shortcut: { "category": "Veg", "price_override": 0.5 }
                     
                     if (extra.containsKey('category')) {
                        // Category shortcut
                        final catName = extra['category'];
                        final override = extra['price_override'] as num?;
                        
                        final catIngredients = await _supabase
                             .from('ingredients')
                             .select('id')
                             .eq('categoria', catName);
                             
                        for (var item in catIngredients) {
                           extrasToInsert.add({
                             'menu_item_id': menuItemId,
                             'ingredient_id': item['id'],
                             'price_override': override,
                           });
                        }
                     } else if (extra.containsKey('name')) {
                        final ingName = extra['name'];
                        final ingId = findIngredientId(ingName);
                        if (ingId != null) {
                          extrasToInsert.add({
                            'menu_item_id': menuItemId,
                            'ingredient_id': ingId,
                            'price_override': extra['price_override'],
                            'max_quantity': extra['max_quantity'] ?? 1,
                          });
                        } else {
                           errors.add('Extra ingredient not found: $ingName in product $name');
                        }
                     }
                   }
                }
              }

              // Batch insert extras
              if (extrasToInsert.isNotEmpty) {
                 // Remove duplicates if any (same ingredient ID)
                 final uniqueExtras = <String, Map<String, dynamic>>{};
                 for(var e in extrasToInsert) {
                   uniqueExtras[e['ingredient_id']] = e;
                 }
                 final extrasPayload = uniqueExtras.values.map((e) {
                   return {
                     if (_organizationId != null) 'organization_id': _organizationId,
                     ...e,
                   };
                 }).toList();
                 await _supabase.from('menu_item_extra_ingredients').insert(extrasPayload);
              }
            }

            // Sizes
            if (prod.containsKey('sizes')) {
              final sizes = prod['sizes'] as List;
              for (var i = 0; i < sizes.length; i++) {
                final sizeItem = sizes[i];
                String sizeName = '';
                double? priceOverride;

                if (sizeItem is String) {
                  sizeName = sizeItem;
                } else if (sizeItem is Map) {
                  sizeName = sizeItem['name'];
                  priceOverride = (sizeItem['price_override'] as num?)?.toDouble();
                }

                final sizeId = findSizeId(sizeName);
                if (sizeId != null) {
                  await _supabase.from('menu_item_sizes').insert({
                    if (_organizationId != null) 'organization_id': _organizationId,
                    'menu_item_id': menuItemId,
                    'size_id': sizeId,
                    'ordine': i,
                    'is_default': i == 0,
                    'price_override': priceOverride
                  });
                } else {
                  errors.add('Size not found: $sizeName in product $name');
                }
              }
            }

          } catch (e) {
            errors.add('Error creating product ${prod['name']}: $e');
          }
        }
      }

    } catch (e) {
      errors.add('JSON Import critical error: $e');
    }

    return ImportResult(
      categoriesCreated: categoriesCreated,
      ingredientsCreated: ingredientsCreated,
      sizesCreated: sizesCreated,
      productsCreated: productsCreated,
      errors: errors,
    );
  }

  Future<Map<String, String>> _fetchExistingMap(String table, String labelCol, String idCol) async {
    var query = _supabase.from(table).select('$labelCol, $idCol');
    if (_organizationId != null) {
      query = query.eq('organization_id', _organizationId);
    }
    final response = await query;
    final map = <String, String>{};
    for (var item in response as List) {
      if (item[labelCol] != null) {
        map[(item[labelCol] as String).toLowerCase()] = item[idCol] as String;
      }
    }
    return map;
  }
}
