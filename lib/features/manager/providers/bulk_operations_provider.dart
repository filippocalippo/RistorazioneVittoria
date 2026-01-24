import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/product_included_ingredients_provider.dart';
import '../../../providers/product_extra_ingredients_provider.dart';
import '../models/bulk_operation_state.dart';

part 'bulk_operations_provider.g.dart';

@riverpod
class BulkOperations extends _$BulkOperations {
  @override
  BulkOperationState build() => BulkOperationState.initial();

  // ========== NAVIGATION ==========

  void goToStep(BulkOperationStep step) {
    state = state.copyWith(currentStep: step, errorMessage: null);
  }

  void nextStep() {
    final nextStepIndex = BulkOperationStep.values.indexOf(state.currentStep) + 1;
    if (nextStepIndex < BulkOperationStep.values.length) {
      state = state.copyWith(
        currentStep: BulkOperationStep.values[nextStepIndex],
        errorMessage: null,
      );
    }
  }

  void previousStep() {
    final prevStepIndex = BulkOperationStep.values.indexOf(state.currentStep) - 1;
    if (prevStepIndex >= 0) {
      state = state.copyWith(
        currentStep: BulkOperationStep.values[prevStepIndex],
        errorMessage: null,
      );
    }
  }

  // ========== PRODUCT SELECTION ==========

  void toggleProduct(String productId) {
    final newSet = Set<String>.from(state.selectedProductIds);
    if (newSet.contains(productId)) {
      newSet.remove(productId);
    } else {
      newSet.add(productId);
    }
    state = state.copyWith(selectedProductIds: newSet);
  }

  void selectProduct(String productId) {
    if (!state.selectedProductIds.contains(productId)) {
      state = state.copyWith(
        selectedProductIds: {...state.selectedProductIds, productId},
      );
    }
  }

  void deselectProduct(String productId) {
    if (state.selectedProductIds.contains(productId)) {
      final newSet = Set<String>.from(state.selectedProductIds);
      newSet.remove(productId);
      state = state.copyWith(selectedProductIds: newSet);
    }
  }

  void selectProducts(List<String> productIds) {
    state = state.copyWith(
      selectedProductIds: {...state.selectedProductIds, ...productIds},
    );
  }

  void deselectProducts(List<String> productIds) {
    final newSet = Set<String>.from(state.selectedProductIds);
    newSet.removeAll(productIds);
    state = state.copyWith(selectedProductIds: newSet);
  }

  void selectAll(List<String> allProductIds) {
    state = state.copyWith(selectedProductIds: allProductIds.toSet());
  }

  void clearProductSelection() {
    state = state.copyWith(selectedProductIds: {});
  }

  // ========== OPERATION TYPE ==========

  void setOperationType(BulkOperationType type) {
    state = state.copyWith(
      operationType: type,
      selectedIngredients: [], // Clear ingredients when changing operation
    );
  }

  void clearOperationType() {
    state = state.copyWith(
      operationType: null,
      selectedIngredients: [],
    );
  }

  // ========== INGREDIENT SELECTION ==========

  void addIngredient({
    required String ingredientId,
    required String ingredientName,
    required double basePrice,
    double? priceOverride,
  }) {
    // Don't add duplicates
    if (state.selectedIngredients.any((i) => i.ingredientId == ingredientId)) {
      return;
    }

    state = state.copyWith(
      selectedIngredients: [
        ...state.selectedIngredients,
        SelectedBulkIngredient(
          ingredientId: ingredientId,
          ingredientName: ingredientName,
          basePrice: basePrice,
          priceOverride: priceOverride,
        ),
      ],
    );
  }

  void removeIngredient(String ingredientId) {
    state = state.copyWith(
      selectedIngredients: state.selectedIngredients
          .where((i) => i.ingredientId != ingredientId)
          .toList(),
    );
  }

  void toggleIngredient({
    required String ingredientId,
    required String ingredientName,
    required double basePrice,
  }) {
    if (state.selectedIngredients.any((i) => i.ingredientId == ingredientId)) {
      removeIngredient(ingredientId);
    } else {
      addIngredient(
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        basePrice: basePrice,
      );
    }
  }

  void setPriceOverride(String ingredientId, double? price) {
    state = state.copyWith(
      selectedIngredients: state.selectedIngredients.map((i) {
        if (i.ingredientId == ingredientId) {
          return i.copyWith(priceOverride: price);
        }
        return i;
      }).toList(),
    );
  }

  void clearIngredientSelection() {
    state = state.copyWith(selectedIngredients: []);
  }

  // ========== APPLY CHANGES ==========

  Future<BulkOperationResult> applyChanges() async {
    if (state.selectedProductIds.isEmpty) {
      return const BulkOperationResult.failure(
        message: 'Nessun prodotto selezionato',
      );
    }

    if (state.operationType == null) {
      return const BulkOperationResult.failure(
        message: 'Nessuna operazione selezionata',
      );
    }

    if (state.selectedIngredients.isEmpty) {
      return const BulkOperationResult.failure(
        message: 'Nessun ingrediente selezionato',
      );
    }

    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final supabase = Supabase.instance.client;
      final productIds = state.selectedProductIds.toList();
      final ingredientIds =
          state.selectedIngredients.map((i) => i.ingredientId).toList();

      switch (state.operationType!) {
        case BulkOperationType.addIncluded:
          await _bulkAddIncludedIngredients(supabase, productIds, ingredientIds);
          break;

        case BulkOperationType.removeIncluded:
          await _bulkRemoveIncludedIngredients(supabase, productIds, ingredientIds);
          break;

        case BulkOperationType.addExtra:
          await _bulkAddExtraIngredients(supabase, productIds);
          break;

        case BulkOperationType.removeExtra:
          await _bulkRemoveExtraIngredients(supabase, productIds, ingredientIds);
          break;
      }

      // Invalidate caches for affected products
      for (final productId in productIds) {
        ref.invalidate(productIncludedIngredientsProvider(productId));
        ref.invalidate(productExtraIngredientsProvider(productId));
      }

      state = state.copyWith(
        isProcessing: false,
        successMessage:
            'Operazione completata su ${productIds.length} prodotti',
      );

      return BulkOperationResult.success(
        affectedProducts: productIds.length,
        affectedIngredients: ingredientIds.length,
      );
    } catch (e) {
      debugPrint('Bulk operation error: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Errore durante l\'operazione: $e',
      );
      return BulkOperationResult.failure(message: e.toString());
    }
  }

  Future<void> _bulkAddIncludedIngredients(
    SupabaseClient supabase,
    List<String> productIds,
    List<String> ingredientIds,
  ) async {
    final records = <Map<String, dynamic>>[];

    for (final productId in productIds) {
      for (final ingredientId in ingredientIds) {
        records.add({
          'menu_item_id': productId,
          'ingredient_id': ingredientId,
          'ordine': 0,
        });
      }
    }

    // Use upsert to handle duplicates gracefully
    await supabase.from('menu_item_included_ingredients').upsert(
          records,
          onConflict: 'menu_item_id, ingredient_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> _bulkRemoveIncludedIngredients(
    SupabaseClient supabase,
    List<String> productIds,
    List<String> ingredientIds,
  ) async {
    await supabase
        .from('menu_item_included_ingredients')
        .delete()
        .inFilter('menu_item_id', productIds)
        .inFilter('ingredient_id', ingredientIds);
  }

  Future<void> _bulkAddExtraIngredients(
    SupabaseClient supabase,
    List<String> productIds,
  ) async {
    final records = <Map<String, dynamic>>[];

    for (final productId in productIds) {
      for (final ingredient in state.selectedIngredients) {
        records.add({
          'menu_item_id': productId,
          'ingredient_id': ingredient.ingredientId,
          'price_override': ingredient.priceOverride,
          'max_quantity': 1,
          'ordine': 0,
        });
      }
    }

    // Use upsert to handle duplicates gracefully
    await supabase.from('menu_item_extra_ingredients').upsert(
          records,
          onConflict: 'menu_item_id, ingredient_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> _bulkRemoveExtraIngredients(
    SupabaseClient supabase,
    List<String> productIds,
    List<String> ingredientIds,
  ) async {
    await supabase
        .from('menu_item_extra_ingredients')
        .delete()
        .inFilter('menu_item_id', productIds)
        .inFilter('ingredient_id', ingredientIds);
  }

  // ========== RESET ==========

  void reset() {
    state = BulkOperationState.initial();
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}
