// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'bulk_operation_state.freezed.dart';

/// Types of bulk operations available
enum BulkOperationType {
  addIncluded,
  removeIncluded,
  addExtra,
  removeExtra,
}

extension BulkOperationTypeX on BulkOperationType {
  String get displayName {
    switch (this) {
      case BulkOperationType.addIncluded:
        return 'Aggiungi Ingredienti Inclusi';
      case BulkOperationType.removeIncluded:
        return 'Rimuovi Ingredienti Inclusi';
      case BulkOperationType.addExtra:
        return 'Aggiungi Ingredienti Extra';
      case BulkOperationType.removeExtra:
        return 'Rimuovi Ingredienti Extra';
    }
  }

  String get description {
    switch (this) {
      case BulkOperationType.addIncluded:
        return 'Aggiungi ingredienti base ai prodotti selezionati';
      case BulkOperationType.removeIncluded:
        return 'Rimuovi ingredienti base dai prodotti selezionati';
      case BulkOperationType.addExtra:
        return 'Aggiungi ingredienti extra con prezzo personalizzabile';
      case BulkOperationType.removeExtra:
        return 'Rimuovi ingredienti extra dai prodotti selezionati';
    }
  }

  bool get isAddOperation =>
      this == BulkOperationType.addIncluded || this == BulkOperationType.addExtra;

  bool get isExtraOperation =>
      this == BulkOperationType.addExtra || this == BulkOperationType.removeExtra;
}

/// Selected ingredient with optional price override (for extras)
@freezed
class SelectedBulkIngredient with _$SelectedBulkIngredient {
  const factory SelectedBulkIngredient({
    required String ingredientId,
    required String ingredientName,
    required double basePrice,
    double? priceOverride,
  }) = _SelectedBulkIngredient;
}

/// Current step in the bulk operation wizard
enum BulkOperationStep {
  selectProducts,
  selectOperation,
  selectIngredients,
  preview,
}

/// State for the bulk operations feature
@freezed
class BulkOperationState with _$BulkOperationState {
  const factory BulkOperationState({
    required BulkOperationStep currentStep,
    required Set<String> selectedProductIds,
    required BulkOperationType? operationType,
    required List<SelectedBulkIngredient> selectedIngredients,
    required bool isProcessing,
    String? errorMessage,
    String? successMessage,
  }) = _BulkOperationState;

  factory BulkOperationState.initial() => const BulkOperationState(
        currentStep: BulkOperationStep.selectProducts,
        selectedProductIds: {},
        operationType: null,
        selectedIngredients: [],
        isProcessing: false,
        errorMessage: null,
        successMessage: null,
      );
}

/// Result of a bulk operation
@freezed
class BulkOperationResult with _$BulkOperationResult {
  const factory BulkOperationResult.success({
    required int affectedProducts,
    required int affectedIngredients,
  }) = BulkOperationResultSuccess;

  const factory BulkOperationResult.partialSuccess({
    required int affectedProducts,
    required int affectedIngredients,
    required int skippedDuplicates,
  }) = BulkOperationResultPartial;

  const factory BulkOperationResult.failure({
    required String message,
  }) = BulkOperationResultFailure;
}
