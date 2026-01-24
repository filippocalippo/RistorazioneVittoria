import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/category_model.dart';
import '../../../core/providers/global_search_provider.dart';
import '../../../providers/menu_provider.dart';
import 'banner_carousel.dart';
import 'category_card.dart';

/// Menu header section combining banner and category grid
/// Matches design concept layout and styling
class MenuHeaderSection extends ConsumerWidget {
  final bool isMobile;
  final bool isDesktop;
  final List<CategoryModel> categories;
  final Function(String categoryId, String categoryName) onCategorySelected;
  final bool Function(CategoryModel) isCategoryDeactivated;

  const MenuHeaderSection({
    super.key,
    required this.isMobile,
    required this.isDesktop,
    required this.categories,
    required this.onCategorySelected,
    required this.isCategoryDeactivated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(globalSearchQueryProvider);
    final horizontalPadding = AppBreakpoints.responsive(
      context: context,
      mobile: AppSpacing.lg,
      tablet: AppSpacing.massive,
      desktop: AppSpacing.xxl,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner Carousel - full width with rounded bottom
        BannerCarousel(isMobile: isMobile),

        // Section header - "Esplora il menù" with improved styling
        if (searchQuery.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.xl, // More space after banner
              horizontalPadding,
              AppSpacing.xs, // Minimal space before category grid
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main title with elegant serif-inspired styling
                Text(
                  'Esplora il menù',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isMobile ? 26 : 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtle accent line
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),

        // Category Grid - immediately after title
        if (searchQuery.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppBreakpoints.responsive(
                context: context,
                mobile: AppSpacing.md,
                tablet: AppSpacing.massive,
                desktop: AppSpacing.xxl,
              ),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 2 : (isDesktop ? 4 : 3),
                childAspectRatio: isMobile ? 0.95 : 1.0,
                crossAxisSpacing: AppBreakpoints.responsive(
                  context: context,
                  mobile: AppSpacing.sm,
                  tablet: AppSpacing.lg,
                  desktop: AppSpacing.lg,
                ),
                mainAxisSpacing: AppBreakpoints.responsive(
                  context: context,
                  mobile: AppSpacing.sm,
                  tablet: AppSpacing.lg,
                  desktop: AppSpacing.lg,
                ),
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isDeactivated = isCategoryDeactivated(category);
                // Get item count for this category
                final itemCount = ref.watch(menuByCategoryProvider(category.id)).length;
                return CategoryCard(
                  category: category,
                  isDeactivated: isDeactivated,
                  itemCount: itemCount,
                  onTap: () => onCategorySelected(category.id, category.nome),
                );
              },
            ),
          ),

        // Disclaimer text
        if (searchQuery.isEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              left: horizontalPadding,
              right: horizontalPadding,
            ),
            child: Center(
              child: Text(
                'Immagini solo a scopo illustrativo',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

        // Bottom spacing - accounts for bottom nav bar dynamically
        if (searchQuery.isEmpty)
          SizedBox(
            height: isMobile
                ? MediaQuery.of(context).padding.bottom + 100
                : AppSpacing.massive + 40,
          ),
      ],
    );
  }
}
