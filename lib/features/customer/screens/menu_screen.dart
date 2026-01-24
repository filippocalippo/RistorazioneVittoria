import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/filtered_menu_provider.dart';
import '../../../providers/banner_navigation_provider.dart';
import '../../../providers/menu_navigation_provider.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/providers/global_search_provider.dart';
import '../../../core/models/category_model.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/widgets/item_card.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../widgets/product_customization_modal.dart';
import '../widgets/product_list_card.dart';
import '../widgets/menu_header_section.dart';

/// Modern menu screen with advanced filtering, search, and category navigation
class MenuScreen extends ConsumerStatefulWidget {
  final bool selectionMode;
  final String? forcedCategoryId;
  final void Function(MenuItemModel)? onProductSelected;
  final VoidCallback? onCancel;

  const MenuScreen({
    super.key,
    this.selectionMode = false,
    this.forcedCategoryId,
    this.onProductSelected,
    this.onCancel,
  });

  /// Show menu screen in selection mode for picking a product from a specific category
  static Future<MenuItemModel?> showForSelection(
    BuildContext context, {
    required String categoryId,
  }) async {
    return Navigator.of(context).push<MenuItemModel>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MenuScreen(
          selectionMode: true,
          forcedCategoryId: categoryId,
          onProductSelected: (product) => Navigator.pop(context, product),
          onCancel: () => Navigator.pop(context),
        ),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide up from bottom with fade
          const begin = Offset(0.0, 0.15);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          // Fade animation
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ),
          );

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with TickerProviderStateMixin {
  String? _selectedCategory;
  // Removed local search state in favor of global provider
  late ScrollController _scrollController;
  late AnimationController _backButtonController;
  late Animation<double> _backButtonAnimation;

  // Static lookup for day names - avoids allocation per call
  static const _dayNamesMap = {
    1: 'monday',
    2: 'tuesday',
    3: 'wednesday',
    4: 'thursday',
    5: 'friday',
    6: 'saturday',
    7: 'sunday',
  };

  // Cached filter options - only recreated when dependencies change
  MenuFilterOptions? _cachedFilterOptions;
  String? _lastCategoryId;
  String? _lastSearchQuery;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _backButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _backButtonAnimation = CurvedAnimation(
      parent: _backButtonController,
      curve: Curves.easeOut,
    );

    // Initialize based on mode
    if (widget.selectionMode && widget.forcedCategoryId != null) {
      _selectedCategory = widget.forcedCategoryId;
      _backButtonController.value = 1.0;
      // Defer provider update to avoid build error
      Future.microtask(
        () => ref.read(isMenuProductViewProvider.notifier).state = true,
      );
    } else {
      Future.microtask(
        () => ref.read(isMenuProductViewProvider.notifier).state = false,
      );
    }
  }

  @override
  void dispose() {
    // Note: Don't use ref.read() in dispose() - it's not allowed after widget disposal
    _scrollController.dispose();
    _backButtonController.dispose();
    super.dispose();
  }

  // Get current filter options for provider - cached to avoid repeated allocations
  MenuFilterOptions _getFilterOptions(String searchQuery) {
    if (_cachedFilterOptions == null ||
        _lastCategoryId != _selectedCategory ||
        _lastSearchQuery != searchQuery) {
      _lastCategoryId = _selectedCategory;
      _lastSearchQuery = searchQuery;
      _cachedFilterOptions = MenuFilterOptions(
        selectedCategoryId: _selectedCategory,
        searchQuery: searchQuery,
        sortBy: 'popular',
      );
    }
    return _cachedFilterOptions!;
  }

  void _showAddToCartDialog(MenuItemModel item) {
    // If in selection mode, return the selected product
    if (widget.selectionMode && widget.onProductSelected != null) {
      widget.onProductSelected!(item);
      return;
    }

    // Forcefully remove focus from search bar before showing modal
    FocusManager.instance.primaryFocus?.unfocus();

    // Use new customization modal/bottom sheet (adapts to screen size)
    ProductCustomizationModal.show(context, item).then((_) {
      // Remove focus from search bar after modal closes
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _resetScrollAndFocus() {
    // Forcefully remove focus from search bar
    FocusManager.instance.primaryFocus?.unfocus();

    // Scroll to top of the screen
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _selectCategory(String categoryId, String categoryName) {
    // Immediately unfocus search bar when selecting category
    FocusScope.of(context).unfocus();

    // Add a small delay before navigation starts (80ms)
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() {
          _selectedCategory = categoryId;
        });
        ref.read(isMenuProductViewProvider.notifier).state = true;
        _backButtonController.forward();
        _resetScrollAndFocus();
      }
    });
  }

  void _goBackToCategoryGrid() {
    ref.read(menuBackNavigationInProgressProvider.notifier).state = true;

    // In selection mode with forced category, cancel instead
    if (widget.selectionMode && widget.onCancel != null) {
      widget.onCancel!();
      ref.read(menuBackNavigationInProgressProvider.notifier).state = false;
      return;
    }

    // Add a small delay before navigation starts (80ms)
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) {
        ref.read(menuBackNavigationInProgressProvider.notifier).state = false;
        return;
      }

      _backButtonController.reverse();
      setState(() {
        _selectedCategory = null;
        ref.read(globalSearchQueryProvider.notifier).state = '';
      });
      ref.read(isMenuProductViewProvider.notifier).state = false;
      _resetScrollAndFocus();
      ref.read(menuBackNavigationInProgressProvider.notifier).state = false;
    });
  }

  // Get platform-appropriate scroll physics
  ScrollPhysics get _scrollPhysics {
    if (kIsWeb) return const ClampingScrollPhysics();
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      }
    } catch (_) {}
    return const ClampingScrollPhysics();
  }

  // Helper method to check if a category is deactivated
  // Uses static _dayNamesMap to avoid allocations
  bool _isCategoryDeactivated(CategoryModel category) {
    // If manually deactivated, it's deactivated
    if (!category.attiva) {
      return true;
    }

    // If no scheduled deactivation, it's active
    if (!category.disattivazioneProgrammata) {
      return false;
    }

    // Check if today is a deactivation day
    final giorniDisattivazione = category.giorniDisattivazione;
    if (giorniDisattivazione == null || giorniDisattivazione.isEmpty) {
      return false; // No specific days set, so it's active
    }

    // Use cached day name lookup
    final todayName = _dayNamesMap[DateTime.now().weekday]!;

    // If today is in the deactivation list, it's deactivated
    return giorniDisattivazione.contains(todayName);
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isMobile = AppBreakpoints.isMobile(context);

    // Listen for menu reset trigger from navigation
    ref.listen(menuResetTriggerProvider, (previous, next) {
      // Only reset if not in selection mode and currently showing products
      if (!widget.selectionMode && ref.read(isMenuProductViewProvider)) {
        _goBackToCategoryGrid();
      }
    });

    // Check for pending category navigation from banner
    final pendingCategoryId = ref.watch(bannerNavigationProvider);
    final isProductView = ref.watch(isMenuProductViewProvider);

    if (pendingCategoryId != null && !isProductView) {
      // Use post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          // Get category name from categories provider
          final categoriesAsync = ref.read(categoriesProvider);
          categoriesAsync.whenData((categories) {
            final category = categories.firstWhere(
              (cat) => cat.id == pendingCategoryId,
              orElse: () => categories.first,
            );
            _selectCategory(pendingCategoryId, category.nome);
          });
          ref.read(bannerNavigationProvider.notifier).clear();
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: PopScope(
          canPop: widget.selectionMode ? false : !isProductView,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (widget.selectionMode && widget.onCancel != null) {
                widget.onCancel!();
              } else if (isProductView) {
                // If we're viewing products, go back to category grid instead of popping the route
                _goBackToCategoryGrid();
              }
            }
          },
          child: GestureDetector(
            onTap: () {
              // Forcefully remove focus from search bar when tapping outside
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    // Simple fade transition - most performance efficient
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: !isProductView
                      ? KeyedSubtree(
                          key: const ValueKey('category_grid'),
                          child: _buildCategoryGridView(
                            context,
                            menuState,
                            isMobile,
                            isDesktop,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('products_view'),
                          child: _buildProductsView(
                            context,
                            menuState,
                            isMobile,
                            isDesktop,
                          ),
                        ),
                ),

                // Floating back button (only when in selection mode)
                if (widget.selectionMode && isProductView)
                  Positioned(
                    top:
                        MediaQuery.of(context).padding.top +
                        (isMobile ? 8 : 12),
                    left: isMobile ? 8 : 12,
                    child: ScaleTransition(
                      scale: _backButtonAnimation,
                      child: FadeTransition(
                        opacity: _backButtonAnimation,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _goBackToCategoryGrid,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 6 : 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: isMobile ? 18 : 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Indietro',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsView(
    BuildContext context,
    AsyncValue menuState,
    bool isMobile,
    bool isDesktop,
  ) {
    // Watch search query so this view rebuilds when the user types
    final searchQuery = ref.watch(globalSearchQueryProvider);
    final isSearching = searchQuery.isNotEmpty;

    // Build filter options using cached method
    final options = _getFilterOptions(searchQuery);

    // Hoist these watches outside .when() to avoid redundant subscriptions
    final categoriesState = ref.watch(categoriesProvider);
    final categories = categoriesState.value ?? [];
    final availabilityAsync = ref.watch(productAvailabilityMapProvider);
    final availabilityMap = availabilityAsync.value ?? <String, bool>{};

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping on scroll area
        FocusScope.of(context).unfocus();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: _scrollPhysics,
        key: const ValueKey('products_view'),
        slivers: [
          // Top spacing for floating back button
          SliverPadding(
            padding: EdgeInsets.only(
              top: isMobile ? AppSpacing.massive * 1.5 : AppSpacing.massive,
            ),
          ),

          // Search bar for selection mode
          if (widget.selectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppBreakpoints.responsive(
                    context: context,
                    mobile: AppSpacing.md,
                    tablet: AppSpacing.massive,
                    desktop: AppSpacing.xxl,
                  ),
                ),
                child: _buildSelectionModeSearchBar(isMobile),
              ),
            ),

          // Content - grouped by category using provider
          menuState.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(child: _buildEmptyState(context));
              }

              // Use provider for filtered items - this is memoized and efficient
              final filteredItems = ref.watch(
                filteredMenuItemsProvider(options),
              );

              if (filteredItems.isEmpty) {
                return SliverFillRemaining(
                  child: _buildNoResultsState(
                    context,
                    isSearching: isSearching,
                  ),
                );
              }

              // Use provider for grouped items - now async to filter by availability
              return ref
                  .watch(groupedMenuItemsProvider(options))
                  .when(
                    data: (groupedItems) {
                      if (groupedItems.isEmpty) {
                        return SliverFillRemaining(
                          child: _buildNoResultsState(
                            context,
                            isSearching: isSearching,
                          ),
                        );
                      }

                      // Build ordered list of category sections
                      final orderedCategoryIds = categories
                          .map((c) => c.id)
                          .where((id) => groupedItems.containsKey(id))
                          .toList();

                      // Add uncategorized section if exists
                      if (groupedItems.containsKey('uncategorized')) {
                        orderedCategoryIds.add('uncategorized');
                      }

                      return SliverMainAxisGroup(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppBreakpoints.responsive(
                                context: context,
                                mobile: AppSpacing.sm,
                                tablet: AppSpacing.massive,
                                desktop: AppSpacing.xxl,
                              ),
                            ),
                            sliver: SliverList.builder(
                              itemCount: orderedCategoryIds.length,
                              itemBuilder: (context, index) {
                                final categoryId = orderedCategoryIds[index];
                                final categoryItems = groupedItems[categoryId]!;

                                // Find category info
                                final category = categoryId == 'uncategorized'
                                    ? null
                                    : categories.firstWhere(
                                        (c) => c.id == categoryId,
                                      );

                                return _buildCategorySection(
                                  context,
                                  category,
                                  categoryItems,
                                  isMobile,
                                  isDesktop,
                                  availabilityMap,
                                );
                              },
                            ),
                          ),
                          // Disclaimer
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: AppSpacing.xl,
                                bottom: isMobile ? 100 : AppSpacing.massive,
                              ),
                              child: Center(
                                child: Text(
                                  'Immagini solo a scopo illustrativo',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.textTertiary.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: 9,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => SliverToBoxAdapter(
                      child: MenuLoadingShimmer(isMobile: isMobile),
                    ),
                    error: (error, stack) => SliverFillRemaining(
                      child: _buildNoResultsState(
                        context,
                        isSearching: isSearching,
                      ),
                    ),
                  );
            },
            loading: () => SliverToBoxAdapter(
              child: MenuLoadingShimmer(isMobile: isMobile),
            ),
            error: (error, stack) =>
                SliverFillRemaining(child: _buildErrorState(context)),
          ),
        ],
      ),
    );
  }

  // Beautiful category grid view (first step) with search bar
  Widget _buildCategoryGridView(
    BuildContext context,
    AsyncValue menuState,
    bool isMobile,
    bool isDesktop,
  ) {
    final categoriesState = ref.watch(categoriesProvider);
    final searchQuery = ref.watch(globalSearchQueryProvider);

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping on scroll area
        FocusScope.of(context).unfocus();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: _scrollPhysics,
        key: const ValueKey('category_grid_view'),
        slivers: [
          // Menu Header Section (Banner + Search + Categories)
          if (searchQuery.isEmpty)
            categoriesState.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Nessuna categoria disponibile',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: MenuHeaderSection(
                    isMobile: isMobile,
                    isDesktop: isDesktop,
                    // Search props removed
                    categories: categories,
                    onCategorySelected: _selectCategory,
                    isCategoryDeactivated: _isCategoryDeactivated,
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppBreakpoints.responsive(
                      context: context,
                      mobile: AppSpacing.md,
                      tablet: AppSpacing.massive,
                      desktop: AppSpacing.xxl,
                    ),
                  ),
                  child: CategoryGridShimmer(
                    isMobile: isMobile,
                    isDesktop: isDesktop,
                  ),
                ),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Errore nel caricamento delle categorie',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            )
          else
            // Show search results if searching
            // Search results view
            menuState.when(
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(child: _buildEmptyState(context));
                }

                // Use provider for filtered items
                final filteredItems = ref.watch(
                  filteredMenuItemsProvider(_getFilterOptions(searchQuery)),
                );

                if (filteredItems.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildNoResultsState(context, isSearching: true),
                  );
                }

                // Use provider for grouped items
                return ref
                    .watch(
                      groupedMenuItemsProvider(_getFilterOptions(searchQuery)),
                    )
                    .when(
                      data: (groupedItems) {
                        if (groupedItems.isEmpty) {
                          return SliverFillRemaining(
                            child: _buildNoResultsState(
                              context,
                              isSearching: true,
                            ),
                          );
                        }

                        final categoriesState = ref.watch(categoriesProvider);
                        final categories = categoriesState.value ?? [];

                        // Watch availability map for esaurito overlay
                        final availabilityAsync = ref.watch(
                          productAvailabilityMapProvider,
                        );
                        final availabilityMap =
                            availabilityAsync.value ?? <String, bool>{};

                        // Build ordered list of category sections
                        final orderedCategoryIds = categories
                            .map((c) => c.id)
                            .where((id) => groupedItems.containsKey(id))
                            .toList();

                        // Add uncategorized section if exists
                        if (groupedItems.containsKey('uncategorized')) {
                          orderedCategoryIds.add('uncategorized');
                        }

                        return SliverMainAxisGroup(
                          slivers: [
                            SliverPadding(
                              padding:
                                  EdgeInsets.symmetric(
                                    horizontal: AppBreakpoints.responsive(
                                      context: context,
                                      mobile: AppSpacing.sm,
                                      tablet: AppSpacing.massive,
                                      desktop: AppSpacing.xxl,
                                    ),
                                  ).copyWith(
                                    top: isMobile
                                        ? AppSpacing.massive * 1.5
                                        : AppSpacing.massive,
                                  ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final categoryId = orderedCategoryIds[index];
                                  final categoryItems =
                                      groupedItems[categoryId]!;

                                  // Find category info
                                  final category = categoryId == 'uncategorized'
                                      ? null
                                      : categories.firstWhere(
                                          (c) => c.id == categoryId,
                                        );

                                  return _buildCategorySection(
                                    context,
                                    category,
                                    categoryItems,
                                    isMobile,
                                    isDesktop,
                                    availabilityMap,
                                  );
                                }, childCount: orderedCategoryIds.length),
                              ),
                            ),
                            // Disclaimer
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: AppSpacing.xl,
                                  bottom: isMobile
                                      ? 100 +
                                            MediaQuery.of(
                                              context,
                                            ).padding.bottom
                                      : AppSpacing.massive +
                                            MediaQuery.of(
                                              context,
                                            ).padding.bottom,
                                ),
                                child: Center(
                                  child: Text(
                                    'Immagini solo a scopo illustrativo',
                                    style: AppTypography.captionSmall.copyWith(
                                      color: AppColors.textTertiary.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 9,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => SliverToBoxAdapter(
                        child: MenuLoadingShimmer(isMobile: isMobile),
                      ),
                      error: (error, stack) => SliverFillRemaining(
                        child: _buildNoResultsState(context, isSearching: true),
                      ),
                    );
              },
              loading: () => SliverToBoxAdapter(
                child: MenuLoadingShimmer(isMobile: isMobile),
              ),
              error: (error, stack) =>
                  SliverFillRemaining(child: _buildErrorState(context)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 40,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Nessun prodotto disponibile',
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Torna più tardi per scoprire il nostro menu',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(
    BuildContext context, {
    required bool isSearching,
  }) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.restaurant_menu_rounded,
                size: 40,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              isSearching
                  ? 'Nessun risultato trovato'
                  : 'Nessun prodotto disponibile',
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isSearching
                  ? 'Prova a modificare i filtri o la ricerca'
                  : 'Torna più tardi per scoprire il nostro menu',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (isSearching)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    ref.read(globalSearchQueryProvider.notifier).state = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusXL,
                  ),
                ),
                child: Text(
                  'Rimuovi filtri',
                  style: AppTypography.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Errore nel caricamento', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Non siamo riusciti a caricare il menu',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => ref.refresh(menuProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
              ),
              child: Text(
                'Riprova',
                style: AppTypography.buttonMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build search bar for selection mode
  Widget _buildSelectionModeSearchBar(bool isMobile) {
    final searchQuery = ref.watch(globalSearchQueryProvider);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      height: isMobile ? 48 : 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              onChanged: (value) {
                ref.read(globalSearchQueryProvider.notifier).state = value;
              },
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Cerca prodotti...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                ref.read(globalSearchQueryProvider.notifier).state = '';
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build a category section with header and items
  Widget _buildCategorySection(
    BuildContext context,
    dynamic category,
    List<MenuItemModel> items,
    bool isMobile,
    bool isDesktop,
    Map<String, bool> availabilityMap,
  ) {
    final categoryName = category?.nome ?? 'Varie';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Simplified category header
        Padding(
          padding: EdgeInsets.only(
            top: isMobile ? AppSpacing.lg : AppSpacing.xl,
            bottom: AppSpacing.md,
          ),
          child: Row(
            children: [
              // Simple accent bar
              Container(
                width: 3,
                height: isMobile ? 20 : 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Category name
              Expanded(
                child: Text(
                  categoryName,
                  style:
                      (isMobile
                              ? AppTypography.titleLarge
                              : AppTypography.headlineSmall)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                ),
              ),
            ],
          ),
        ),

        // Items - use builders for better performance (lazy rendering)
        if (isMobile)
          // Mobile: efficient list with ListView.builder for lazy rendering
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isAvailable = availabilityMap[item.id] ?? true;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ProductListCard(
                  key: ValueKey(item.id),
                  item: item,
                  onTap: () => _showAddToCartDialog(item),
                  isAvailable: isAvailable,
                ),
              );
            },
          )
        else
          // Desktop: efficient grid with builder
          LayoutBuilder(
            builder: (context, constraints) {
              // Use 5 columns for selection mode, 4 for normal
              final crossAxisCount = widget.selectionMode
                  ? AppBreakpoints.responsive(
                      context: context,
                      mobile: 2,
                      tablet: 4,
                      desktop: 5,
                    )
                  : AppBreakpoints.responsive(
                      context: context,
                      mobile: 1,
                      tablet: 3,
                      desktop: 4,
                    );

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: widget.selectionMode ? 0.8 : 0.75,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isAvailable = availabilityMap[item.id] ?? true;
                  return PizzaCard(
                    key: ValueKey(item.id),
                    item: item,
                    onTap: () => _showAddToCartDialog(item),
                    isAvailable: isAvailable,
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
