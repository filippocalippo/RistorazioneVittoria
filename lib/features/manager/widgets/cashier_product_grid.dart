import 'package:flutter/material.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/widgets/item_card.dart';

/// Grid display of products for cashier screen
/// Reuses existing PizzaCard component
class CashierProductGrid extends StatelessWidget {
  final List<MenuItemModel> items;
  final Function(MenuItemModel) onProductTap;

  const CashierProductGrid({
    super.key,
    required this.items,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = AppBreakpoints.isMobile(context);
    
    // Calculate cross axis count based on screen width
    // Aim for at least 7 on large screens, with minimum card width of ~140px
    int crossAxisCount;
    if (isMobile) {
      crossAxisCount = 2;
    } else if (screenWidth >= 1800) {
      crossAxisCount = 8;
    } else if (screenWidth >= 1400) {
      crossAxisCount = 7;
    } else if (screenWidth >= 1100) {
      crossAxisCount = 6;
    } else if (screenWidth >= 900) {
      crossAxisCount = 5;
    } else {
      crossAxisCount = 4;
    }

    return GridView.builder(
      padding: EdgeInsets.all(
        isMobile ? AppSpacing.md : AppSpacing.lg,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return PizzaCard(
          item: item,
          onTap: () => onProductTap(item),
        );
      },
    );
  }
}
