import 'package:flutter/material.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/category_model.dart';

/// Horizontal scrollable category filter for cashier screen
class CashierCategoryFilter extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final Function(String?) onCategorySelected;

  const CashierCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // All categories chip
          _buildCategoryChip(
            label: 'Tutti',
            isSelected: selectedCategoryId == null,
            onTap: () => onCategorySelected(null),
          ),
          
          const SizedBox(width: AppSpacing.sm),
          
          // Individual category chips
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _buildCategoryChip(
                label: category.nome,
                isSelected: selectedCategoryId == category.id,
                onTap: () => onCategorySelected(category.id),
                color: _getCategoryColor(category.nome),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLG,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (color ?? AppColors.primary)
                : AppColors.surfaceLight,
            borderRadius: AppRadius.radiusLG,
            border: Border.all(
              color: isSelected
                  ? (color ?? AppColors.primary)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: isSelected
                  ? Colors.white
                  : AppColors.textPrimary,
              fontWeight: isSelected
                  ? AppTypography.bold
                  : AppTypography.medium,
            ),
          ),
        ),
      ),
    );
  }

  Color? _getCategoryColor(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('pizza')) return const Color(0xFFFF6B6B);
    if (name.contains('fritt')) return const Color(0xFFFFA726);
    if (name.contains('bevand')) return const Color(0xFF42A5F5);
    if (name.contains('dolc')) return const Color(0xFFAB47BC);
    return null;
  }
}
