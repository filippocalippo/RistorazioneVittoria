import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/database_service.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/filtered_menu_provider.dart';
import '../../../providers/manager_orders_provider.dart';
import '../widgets/cashier_product_grid.dart';
import '../widgets/cashier_order_panel.dart';
import '../widgets/cashier_category_filter.dart';
import '../widgets/cashier_product_card.dart';
import '../../../providers/cashier_order_provider.dart';
import '../../customer/widgets/product_customization_modal.dart';
import '../../../providers/order_price_calculator_provider.dart';
import '../../../providers/top_products_per_category_provider.dart';

/// Professional POS-style cashier order screen
/// Split-panel layout: products on left, order summary on right
class CashierOrderScreen extends ConsumerStatefulWidget {
  const CashierOrderScreen({super.key});

  @override
  ConsumerState<CashierOrderScreen> createState() => _CashierOrderScreenState();
}

class _CashierOrderScreenState extends ConsumerState<CashierOrderScreen> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Register hardware keyboard listener for global shortcuts
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);

    // Pre-load allSizeAssignmentsProvider to ensure OrderPriceCalculator is ready
    // when completing orders - this avoids falling back to potentially incorrect UI prices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allSizeAssignmentsProvider);
      // Fetch top products for "I più venduti" section (lazy load on cashier entry)
      ref.read(topProductsByCategoryProvider.notifier).fetchIfNeeded();
    });
  }

  @override
  void dispose() {
    // Remove hardware keyboard listener
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Checks if any text input field (TextField, TextFormField, etc.) is currently focused.
  bool _isAnyTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;

    // Check if the focused widget's context contains an EditableText
    // This covers TextField, TextFormField, and any other text input widgets
    final context = primaryFocus.context;
    if (context == null) return false;

    // Walk up the widget tree to check if we're in an editable text context
    bool isEditable = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        isEditable = true;
        return false; // Stop visiting
      }
      return true; // Continue visiting
    });

    return isEditable;
  }

  /// Checks if a modal/dialog is currently displayed on top of this screen.
  bool _isModalOpen() {
    final route = ModalRoute.of(context);
    if (route == null) return false;
    // If the current route is not the topmost route, a modal is on top
    return !route.isCurrent;
  }

  /// Hardware-level keyboard handler for global shortcuts.
  /// This works regardless of which widget has focus.
  bool _handleHardwareKeyEvent(KeyEvent event) {
    // Only handle key down events to avoid double triggers
    if (event is! KeyDownEvent) {
      return false;
    }

    // Handle Ctrl+F for order search (even if field focused, dialog handles its own escape)
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyF) {
      _openOrderSearchOverlay();
      return true;
    }

    // Don't handle shortcuts if a modal/dialog is open
    if (_isModalOpen()) {
      return false;
    }

    // Get the panel state for focus node access
    final panelState = CashierOrderPanel.panelKey.currentState;

    // Enter key: when search bar is focused and has results, open first product
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        // Get filtered items
        final filteredItems = ref.read(
          filteredMenuItemsProvider(_filterOptions),
        );
        if (filteredItems.isNotEmpty) {
          // Unfocus search bar first
          _searchFocusNode.unfocus();
          // Open modal for first product
          _handleProductTap(filteredItems.first);
          return true;
        }
      }

      // If in the order panel's name field with suggestions, select first suggestion
      if (panelState != null && panelState.nameFocusNode.hasFocus) {
        if (panelState.hasSuggestions) {
          panelState.selectFirstSuggestion();
          return true;
        } else {
          // No suggestions, move to next field
          panelState.focusNextField();
          return true;
        }
      }

      // If in other order panel fields, move to next field
      if (panelState != null && panelState.hasAnyFieldFocused) {
        panelState.focusNextField();
        return true;
      }
    }

    // Don't handle letter shortcuts if any text field is focused (allow normal typing)
    if (_isAnyTextFieldFocused()) {
      return false;
    }

    // N key: Focus Name field
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      if (panelState != null) {
        panelState.nameFocusNode.requestFocus();
        return true;
      }
    }

    // T key: Focus Telephone field
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      if (panelState != null) {
        panelState.phoneFocusNode.requestFocus();
        return true;
      }
    }

    // I key: Focus Address (Indirizzo) field
    if (event.logicalKey == LogicalKeyboardKey.keyI) {
      if (panelState != null) {
        panelState.addressFocusNode.requestFocus();
        return true;
      }
    }

    // 1 key: Select Takeaway (Asporto)
    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.numpad1) {
      if (panelState != null) {
        panelState.setOrderType(OrderType.takeaway);
        return true;
      }
    }

    // 2 key: Select Delivery (Consegna)
    if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.numpad2) {
      if (panelState != null) {
        panelState.setOrderType(OrderType.delivery);
        return true;
      }
    }

    // Check if spacebar was pressed
    if (event.logicalKey == LogicalKeyboardKey.space) {
      // Clear search field
      _searchController.clear();
      // Update state immediately (bypass debounce for instant clear)
      setState(() {
        _searchQuery = '';
      });
      // Cancel any pending debounce
      _searchDebounce?.cancel();
      // Focus the search field after a microtask to ensure it works
      Future.microtask(() {
        _searchFocusNode.requestFocus();
      });
      // Consume the event
      return true;
    }

    // Escape key to unfocus search
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return true;
      }
    }

    return false;
  }

  MenuFilterOptions get _filterOptions => MenuFilterOptions(
    selectedCategoryId: null, // Don't filter by category - show all
    searchQuery: _searchQuery,
    sortBy: 'popular',
  );

  void _scrollToCategory(String? categoryId) {
    // Update selected category immediately
    setState(() => _selectedCategoryId = categoryId);

    if (categoryId == null) {
      // Scroll to top for "All"
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Use WidgetsBinding to ensure the widget tree is built before scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _categoryKeys[categoryId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.0, // Align to top
        );
      }
    });
  }

  void _handleProductTap(MenuItemModel item) async {
    // Always show customization modal
    await _showCustomizationModal(item);
  }

  void _quickAddToCart(MenuItemModel item) {
    ref.read(cashierOrderProvider.notifier).addItem(item);
    HapticFeedback.lightImpact();
  }

  Future<void> _showCustomizationModal(MenuItemModel item) async {
    // Dismiss keyboard if open
    FocusScope.of(context).unfocus();

    // Show customization modal with callback
    await ProductCustomizationModal.show(
      context,
      item,
      onCustomizationComplete: (customization) {
        // Check if this is a split product
        if (customization['isSplit'] == true) {
          // Handle split product - use same size for both halves
          final selectedSize = customization['selectedSize'];
          ref
              .read(cashierOrderProvider.notifier)
              .addSplitItem(
                firstProduct: customization['firstProduct'] as MenuItemModel,
                secondProduct: customization['secondProduct'] as MenuItemModel,
                firstProductSize: selectedSize,
                secondProductSize: selectedSize,
                firstProductAddedIngredients:
                    customization['firstProductAddedIngredients'],
                firstProductRemovedIngredients:
                    customization['firstProductRemovedIngredients'],
                secondProductAddedIngredients:
                    customization['secondProductAddedIngredients'],
                secondProductRemovedIngredients:
                    customization['secondProductRemovedIngredients'],
                note: customization['note'] as String?,
                totalPrice: customization['total'] as double?,
              );
        } else {
          // Add directly to cashier order with customization data
          ref
              .read(cashierOrderProvider.notifier)
              .addItemWithCustomization(
                item,
                quantity: customization['quantity'] as int,
                selectedSize: customization['selectedSize'],
                addedIngredients: customization['addedIngredients'],
                removedIngredients: customization['removedIngredients'],
                note: customization['note'] as String?,
                effectiveBasePrice:
                    customization['effectiveBasePrice'] as double?,
              );
        }
      },
    );
  }

  void _openOrderSearchOverlay() {
    // Show the search dialog using showDialog to cover the entire screen including sidebar
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: true,
      builder: (ctx) => _OrderSearchDialog(
        onOrderTap: (order) {
          Navigator.of(ctx).pop();
          _showOrderDetailModal(order);
        },
      ),
    );
  }

  void _showOrderDetailModal(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: _OrderDetailContent(
                  order: order,
                  scrollController: controller,
                  onModify: () {
                    Navigator.pop(ctx);
                    _modifyOrder(order);
                  },
                  onStatusChange: (status) {
                    _updateStatus(order.id, status);
                  },
                  onCancel: () {
                    Navigator.pop(ctx);
                    _cancelOrder(order);
                  },
                  onPrint: () => _printOrder(order),
                  onTogglePagato: () {
                    _togglePagato(order);
                  },
                  onClose: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _modifyOrder(OrderModel order) async {
    // Check if order can be modified
    if (order.stato == OrderStatus.completed ||
        order.stato == OrderStatus.cancelled) {
      _showSnackBar(
        'Non puoi modificare un ordine ${order.stato.displayName}',
        isError: true,
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifica Ordine'),
        content: Text(
          'Vuoi modificare l\'ordine #${order.numeroOrdine}?\n\n'
          'L\'ordine verrà caricato nel pannello cassa per la modifica. '
          'Il numero ordine rimarrà invariato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifica'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Load menu items for reconstruction
    List<MenuItemModel> menuItems;
    try {
      menuItems = await ref.read(menuProvider.future);
    } catch (e) {
      menuItems = [];
    }

    // Load order into cashier
    CashierOrderLoader.loadFromOrder(order, menuItems, ref);

    // Navigate to cashier screen (already on it, so just dismiss any modals)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      await ref
          .read(managerOrdersProvider.notifier)
          .updateStatus(orderId, newStatus);
      _showSnackBar('Stato aggiornato');
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annulla Ordine'),
        content: Text(
          'Sei sicuro di voler annullare l\'ordine #${order.numeroOrdine}?\n\n'
          'Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Annulla Ordine'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(managerOrdersProvider.notifier)
          .updateStatus(order.id, OrderStatus.cancelled);
      _showSnackBar('Ordine annullato');
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }

  Future<void> _printOrder(OrderModel order) async {
    try {
      final db = DatabaseService();
      await db.markOrderAsNotPrinted(order.id);
      _showSnackBar('Inviato alla stampante');
    } catch (e) {
      _showSnackBar('Errore invio stampa: $e', isError: true);
    }
  }

  Future<void> _togglePagato(OrderModel order) async {
    try {
      final db = DatabaseService();
      final newPagatoStatus = !order.pagato;
      await db.toggleOrderPagato(order.id, newPagatoStatus);
      ref.invalidate(managerOrdersProvider);
      _showSnackBar(
        newPagatoStatus
            ? 'Ordine segnato come pagato'
            : 'Ordine segnato come non pagato',
      );
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isMobile = AppBreakpoints.isMobile(context);
    final menuState = ref.watch(menuProvider);
    final categoriesState = ref.watch(categoriesProvider);

    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search and category filter
            _buildHeader(context, categoriesState, isMobile),

            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Products panel (left side)
                  Expanded(
                    flex: isDesktop ? 7 : 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          right: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      child: menuState.when(
                        data: (items) {
                          final filteredItems = ref.watch(
                            filteredMenuItemsProvider(_filterOptions),
                          );

                          if (filteredItems.isEmpty) {
                            return _buildEmptyState();
                          }

                          // If searching, show flat list of results
                          if (_searchQuery.isNotEmpty) {
                            return _buildSearchResults(
                              filteredItems,
                              categoriesState.valueOrNull ?? [],
                            );
                          }

                          return categoriesState.when(
                            data: (categories) => _buildCategorizedProductList(
                              filteredItems,
                              categories,
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stack) => CashierProductGrid(
                              items: filteredItems,
                              onProductTap: _handleProductTap,
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) =>
                            Center(child: Text('Errore: $error')),
                      ),
                    ),
                  ),

                  // Order panel (right side) - hidden on mobile in portrait
                  if (!isMobile || MediaQuery.of(context).size.width > 600)
                    SizedBox(
                      width: isDesktop
                          ? 420
                          : 350, // Slightly wider for better readability
                      child: CashierOrderPanel(key: CashierOrderPanel.panelKey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Floating action button for mobile to show order summary
      floatingActionButton: isMobile && MediaQuery.of(context).size.width <= 600
          ? _buildMobileOrderButton()
          : null,
    );

    return scaffold;
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<List<CategoryModel>> categoriesState,
    bool isMobile,
  ) {
    final orderCount = ref.watch(cashierOrderItemCountProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppSpacing.md : AppSpacing.lg,
        isMobile ? AppSpacing.md : AppSpacing.lg,
        isMobile ? AppSpacing.md : AppSpacing.lg,
        0, // Remove bottom padding as category filter has its own
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and search
          Row(
            children: [
              // Title with icon - Hidden on mobile
              if (!isMobile) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.orangeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Title Area
                if (_searchQuery.isEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Cassa',
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: AppTypography.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (orderCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$orderCount',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.success,
                                    fontWeight: AppTypography.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(width: AppSpacing.md),
              ],

              // Search bar
              Expanded(
                flex: isMobile ? 1 : (_searchQuery.isEmpty ? 2 : 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? AppColors.primary
                          : AppColors.border,
                      width: _searchFocusNode.hasFocus ? 1.5 : 1,
                    ),
                    boxShadow: [
                      if (_searchFocusNode.hasFocus)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      if (_searchDebounce?.isActive ?? false) {
                        _searchDebounce!.cancel();
                      }
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      );
                    },
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cerca prodotti...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _searchFocusNode.hasFocus
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.textTertiary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textSecondary,
                                  size: 14,
                                ),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Category filter (only show if NOT searching)
          AnimatedCrossFade(
            firstChild: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                categoriesState.when(
                  data: (categories) {
                    return CashierCategoryFilter(
                      categories: categories,
                      selectedCategoryId: _selectedCategoryId,
                      onCategorySelected: _scrollToCategory,
                    );
                  },
                  loading: () => const SizedBox(height: 40),
                  error: (error, stack) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
            secondChild: const SizedBox(height: AppSpacing.sm),
            crossFadeState: _searchQuery.isEmpty
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nessun prodotto trovato'
                : 'Nessun prodotto disponibile',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Prova a cercare qualcos\'altro',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    List<MenuItemModel> items,
    List<CategoryModel> categories,
  ) {
    final isMobile = AppBreakpoints.isMobile(context);
    final padding = isMobile ? AppSpacing.md : AppSpacing.lg;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: padding,
              right: padding,
              top: padding,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.manage_search_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Risultati ricerca',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${items.length} trovati',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: isMobile
              ? SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    final category = categories
                        .where((c) => c.id == item.categoriaId)
                        .firstOrNull;
                    final categoryName = category?.nome;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: CashierProductCard(
                        item: item,
                        categoryName: categoryName,
                        onTap: () => _handleProductTap(item),
                        onQuickAdd: () => _quickAddToCart(item),
                        isListView: true,
                      ),
                    );
                  }, childCount: items.length),
                )
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    // Find category name
                    final category = categories
                        .where((c) => c.id == item.categoriaId)
                        .firstOrNull;
                    final categoryName = category?.nome;

                    return CashierProductCard(
                      item: item,
                      categoryName: categoryName,
                      onTap: () => _handleProductTap(item),
                      onQuickAdd: () => _quickAddToCart(item),
                    );
                  }, childCount: items.length),
                ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: padding)),
      ],
    );
  }

  Widget _buildTopSellingHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.goldGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I più venduti',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'I prodotti preferiti dai clienti',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedProductList(
    List<MenuItemModel> items,
    List<CategoryModel> categories,
  ) {
    final isMobile = AppBreakpoints.isMobile(context);
    final padding = isMobile ? AppSpacing.md : AppSpacing.lg;

    // Group items by category
    final Map<String?, List<MenuItemModel>> groupedItems = {};
    for (final item in items) {
      groupedItems.putIfAbsent(item.categoriaId, () => []).add(item);
    }

    // Sort categories by order
    final sortedCategories = categories.toList()
      ..sort((a, b) => a.ordine.compareTo(b.ordine));

    final List<Widget> slivers = [];

    // Add top padding
    slivers.add(SliverPadding(padding: EdgeInsets.only(top: padding)));

    // Add "I più venduti" section if data is available
    final topProductsState = ref.watch(topProductsByCategoryProvider);
    topProductsState.whenData((topProducts) {
      if (topProducts.hasData) {
        // Add section header
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: _buildTopSellingHeader(),
            ),
          ),
        );

        // Debug log
        Logger.info(
          'Rendering Top Products: ${topProducts.productsByCategory.length} categories from API',
          tag: 'TopProductsUI',
        );

        // 1. Resolve all top products to actual MenuItemModels
        // We do this globally first to handle cases where a product moved categories
        final allTopItems = <MenuItemModel>[];
        final menuItemsById = <String, MenuItemModel>{};
        final menuItemsByName = <String, MenuItemModel>{};

        // Build lookup maps from ALL items (not just grouped chunks)
        for (final item in items) {
          menuItemsById[item.id] = item;
          menuItemsByName[item.nome.toLowerCase()] = item;
        }

        // Flatten top products and resolve them
        final Set<String> processedProductNames = {}; // Avoid duplicates
        for (final categoryList in topProducts.productsByCategory.values) {
          for (final topItem in categoryList) {
            if (processedProductNames.contains(
              topItem.productName.toLowerCase(),
            )) {
              continue;
            }

            MenuItemModel? resolvedItem;
            // Try ID match
            if (topItem.menuItemId != null) {
              resolvedItem = menuItemsById[topItem.menuItemId];
            }
            // Try Name match
            resolvedItem ??= menuItemsByName[topItem.productName.toLowerCase()];

            if (resolvedItem != null) {
              allTopItems.add(resolvedItem);
              processedProductNames.add(topItem.productName.toLowerCase());
            } else {
              // Optional: Log missing items for debugging
              // Logger.debug('Could not find top product: ${topItem.productName}', tag: 'TopProductsUI');
            }
          }
        }

        // 2. Group resolved top items by their CURRENT category
        final Map<String, List<MenuItemModel>> topItemsByCurrentCategory = {};
        for (final item in allTopItems) {
          // If category is null (uncategorized), treat as 'Uncategorized' match or skip?
          // We will group by ID, null key handles uncategorized
          final catId = item.categoriaId ?? 'uncategorized';
          topItemsByCurrentCategory.putIfAbsent(catId, () => []);
          topItemsByCurrentCategory[catId]!.add(item);
        }

        Logger.info(
          'Resolved ${allTopItems.length} top products into ${topItemsByCurrentCategory.keys.length} current categories',
          tag: 'TopProductsUI',
        );

        // 3. Render categories that have top products
        // Iterate sorted categories to maintain order
        for (final category in sortedCategories) {
          final topItemsForThisCategory =
              topItemsByCurrentCategory[category.id];

          if (topItemsForThisCategory == null ||
              topItemsForThisCategory.isEmpty) {
            continue;
          }

          // Add category label for top products
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: padding,
                  right: padding,
                  bottom: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.goldGradient,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category.nome,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Add horizontal scrollable cards
          slivers.add(
            SliverToBoxAdapter(
              child: SizedBox(
                height: isMobile ? 120 : 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  itemCount: topItemsForThisCategory.length,
                  itemBuilder: (context, index) {
                    final item = topItemsForThisCategory[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < topItemsForThisCategory.length - 1
                            ? AppSpacing.md
                            : 0,
                      ),
                      child: SizedBox(
                        width: isMobile ? 160 : 180,
                        child: CashierProductCard(
                          item: item,
                          categoryName: category.nome,
                          onTap: () => _handleProductTap(item),
                          onQuickAdd: () => _quickAddToCart(item),
                          isGoldenHighlight: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );

          slivers.add(
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          );
        }

        // Add separator after top selling section
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: AppSpacing.md,
              ),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.gold.withValues(alpha: 0.3),
                      AppColors.gold.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    for (final category in sortedCategories) {
      final categoryItems = groupedItems[category.id];
      if (categoryItems == null || categoryItems.isEmpty) continue;

      // Ensure we have a key for this category
      _categoryKeys.putIfAbsent(category.id, () => GlobalKey());

      slivers.add(
        SliverToBoxAdapter(
          key: _categoryKeys[category.id],
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: _buildCategoryHeaderWidget(category, categoryItems.length),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: isMobile
              ? SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = categoryItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: CashierProductCard(
                        item: item,
                        categoryName: category.nome,
                        onTap: () => _handleProductTap(item),
                        onQuickAdd: () => _quickAddToCart(item),
                        isListView: true,
                      ),
                    );
                  }, childCount: categoryItems.length),
                )
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = categoryItems[index];
                    return CashierProductCard(
                      item: item,
                      categoryName: category.nome,
                      onTap: () => _handleProductTap(item),
                      onQuickAdd: () => _quickAddToCart(item),
                    );
                  }, childCount: categoryItems.length),
                ),
        ),
      );

      slivers.add(
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      );
    }

    // Add uncategorized items at the end
    final uncategorizedItems = groupedItems[null];
    if (uncategorizedItems != null && uncategorizedItems.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: _buildUncategorizedHeaderWidget(uncategorizedItems.length),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: isMobile
              ? SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = uncategorizedItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: CashierProductCard(
                        item: item,
                        categoryName: 'Altro',
                        onTap: () => _handleProductTap(item),
                        onQuickAdd: () => _quickAddToCart(item),
                        isListView: true,
                      ),
                    );
                  }, childCount: uncategorizedItems.length),
                )
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = uncategorizedItems[index];
                    return CashierProductCard(
                      item: item,
                      categoryName: 'Altro',
                      onTap: () => _handleProductTap(item),
                      onQuickAdd: () => _quickAddToCart(item),
                    );
                  }, childCount: uncategorizedItems.length),
                ),
        ),
      );

      slivers.add(
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      );
    }

    return CustomScrollView(controller: _scrollController, slivers: slivers);
  }

  Widget _buildCategoryHeaderWidget(CategoryModel category, int itemCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Row(
        children: [
          if (category.icona != null && category.icona!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                category.icona!,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          Text(
            category.nome,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$itemCount',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUncategorizedHeaderWidget(int itemCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            'Altri Prodotti',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: AppTypography.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$itemCount',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileOrderButton() {
    final orderItemCount = ref.watch(cashierOrderItemCountProvider);
    final subtotal = ref.watch(cashierOrderSubtotalProvider);

    return FloatingActionButton.extended(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: const CashierOrderPanel(),
          ),
        );
      },
      icon: const Icon(Icons.shopping_cart_rounded),
      label: Row(
        children: [
          Text('Ordine ($orderItemCount)'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '€${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
    );
  }
}

/// Order search dialog widget - compact floating search centered on screen
class _OrderSearchDialog extends ConsumerStatefulWidget {
  final ValueChanged<OrderModel> onOrderTap;

  const _OrderSearchDialog({required this.onOrderTap});

  @override
  ConsumerState<_OrderSearchDialog> createState() => _OrderSearchDialogState();
}

class _OrderSearchDialogState extends ConsumerState<_OrderSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders, String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return orders.where((order) {
      return order.numeroOrdine.toLowerCase().contains(lowerQuery) ||
          order.nomeCliente.toLowerCase().contains(lowerQuery) ||
          order.telefonoCliente.contains(lowerQuery);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(managerOrdersProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final searchWidth = isDesktop ? 500.0 : screenWidth * 0.9;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: searchWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search bar header
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.orangeGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        style: AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Cerca ordine...',
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.background,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

              // Results list
              ordersAsync.when(
                data: (orders) {
                  final filteredOrders = _filterOrders(orders, _searchQuery);

                  if (_searchQuery.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 40,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Cerca per nome, telefono o numero ordine',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (filteredOrders.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Nessun ordine trovato',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(
                        left: AppSpacing.sm,
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      itemCount: filteredOrders.length.clamp(0, 10),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return _OrderSearchResultCard(
                          order: order,
                          onTap: () => widget.onOrderTap(order),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Errore: $e',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),

              // Results count footer (if results)
              if (_searchQuery.isNotEmpty)
                ordersAsync.maybeWhen(
                  data: (orders) {
                    final filteredOrders = _filterOrders(orders, _searchQuery);
                    if (filteredOrders.isEmpty) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            filteredOrders.length > 10
                                ? 'Mostrati 10 di ${filteredOrders.length}'
                                : '${filteredOrders.length} risultati',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order search result card
class _OrderSearchResultCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderSearchResultCard({required this.order, required this.onTap});

  Color get _statusColor {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivering:
        return AppColors.accent;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Order info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '#${order.numeroOrdine}',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: AppTypography.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.stato.displayName,
                              style: AppTypography.captionSmall.copyWith(
                                color: _statusColor,
                                fontWeight: AppTypography.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (order.pagato) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'PAGATO',
                                    style: AppTypography.captionSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: AppTypography.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            order.tipo == OrderType.delivery
                                ? Icons.delivery_dining_rounded
                                : Icons.shopping_bag_rounded,
                            size: 14,
                            color: order.tipo == OrderType.delivery
                                ? AppColors.accent
                                : AppColors.info,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.nomeCliente,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            order.telefonoCliente,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Total and time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(order.totale),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: AppTypography.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (order.slotPrenotatoStart != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            Formatters.time(order.slotPrenotatoStart!),
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        Formatters.timeAgo(order.createdAt),
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Order detail content widget (for modal)
class _OrderDetailContent extends StatelessWidget {
  final OrderModel order;
  final ScrollController? scrollController;
  final VoidCallback onModify;
  final Function(OrderStatus) onStatusChange;
  final VoidCallback onCancel;
  final VoidCallback onPrint;
  final VoidCallback onTogglePagato;
  final VoidCallback onClose;

  const _OrderDetailContent({
    required this.order,
    this.scrollController,
    required this.onModify,
    required this.onStatusChange,
    required this.onCancel,
    required this.onPrint,
    required this.onTogglePagato,
    required this.onClose,
  });

  Color get _statusColor {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivering:
        return AppColors.accent;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canModify =
        order.stato != OrderStatus.completed &&
        order.stato != OrderStatus.cancelled;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getStatusIcon(), color: Colors.white, size: 24),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Ordine #${order.numeroOrdine}',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.stato.displayName,
                              style: AppTypography.labelMedium.copyWith(
                                color: _statusColor,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: order.tipo == OrderType.delivery
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : AppColors.info.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  order.tipo == OrderType.delivery
                                      ? Icons.delivery_dining_rounded
                                      : Icons.shopping_bag_rounded,
                                  size: 14,
                                  color: order.tipo == OrderType.delivery
                                      ? AppColors.accent
                                      : AppColors.info,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.tipo.displayName,
                                  style: AppTypography.captionSmall.copyWith(
                                    color: order.tipo == OrderType.delivery
                                        ? AppColors.accent
                                        : AppColors.info,
                                    fontWeight: AppTypography.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.dateTime(order.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Customer information
                _buildSection('Cliente', Icons.person_outline_rounded, [
                  _buildInfoRow('Nome', order.nomeCliente),
                  _buildInfoRow('Telefono', order.telefonoCliente),
                ]),

                const SizedBox(height: AppSpacing.lg),

                // Scheduled time (if set)
                if (order.slotPrenotatoStart != null) ...[
                  _buildSection(
                    order.tipo == OrderType.delivery
                        ? 'Orario consegna'
                        : 'Orario ritiro',
                    Icons.schedule_rounded,
                    [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              Formatters.time(order.slotPrenotatoStart!),
                              style: AppTypography.headlineMedium.copyWith(
                                fontWeight: AppTypography.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Delivery address
                if (order.tipo == OrderType.delivery &&
                    order.indirizzoConsegna != null) ...[
                  _buildSection('Indirizzo', Icons.location_on_outlined, [
                    _buildInfoRow('Via', order.indirizzoConsegna!),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Order notes
                if (order.note != null && order.note!.isNotEmpty) ...[
                  _buildSection('Note', Icons.note_outlined, [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(order.note!, style: AppTypography.bodyMedium),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Order items
                _buildSection(
                  'Prodotti (${order.totalItems} articoli)',
                  Icons.restaurant_menu_rounded,
                  order.items.map((item) => _buildOrderItem(item)).toList(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Payment summary
                _buildSection('Pagamento', Icons.receipt_outlined, [
                  _buildPriceRow('Subtotale', order.subtotale),
                  if (order.costoConsegna > 0)
                    _buildPriceRow('Consegna', order.costoConsegna),
                  if (order.sconto > 0)
                    _buildPriceRow('Sconto', -order.sconto, isDiscount: true),
                  const Divider(height: 24),
                  _buildPriceRow('Totale', order.totale, isTotal: true),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        order.pagato ? Icons.check_circle : Icons.pending,
                        size: 18,
                        color: order.pagato
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        order.pagato ? 'Pagato' : 'Non pagato',
                        style: AppTypography.bodyMedium.copyWith(
                          color: order.pagato
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                    ],
                  ),
                ]),

                const SizedBox(height: 100), // Space for bottom actions
              ],
            ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pagato toggle
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onTogglePagato,
                    icon: Icon(
                      order.pagato
                          ? Icons.money_off_rounded
                          : Icons.payments_rounded,
                      size: 20,
                    ),
                    label: Text(
                      order.pagato ? 'Segna NON Pagato' : 'Segna Pagato',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: order.pagato
                          ? AppColors.warning
                          : AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                if (canModify) const SizedBox(height: AppSpacing.sm),

                // Secondary actions
                if (canModify)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: onModify,
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Modifica'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        height: 46,
                        width: 46,
                        child: IconButton(
                          onPressed: onPrint,
                          icon: const Icon(Icons.print_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        height: 46,
                        width: 46,
                        child: IconButton(
                          onPressed: onCancel,
                          icon: const Icon(Icons.delete_outline_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.error,
                            backgroundColor: AppColors.error.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.quantita}x',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.isSplitProduct
                      ? item.splitProductNames
                      : item.nomeProdotto,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ),
              Text(
                Formatters.currency(item.subtotale),
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          if (item.sizeName.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Formato: ${item.sizeName}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          // Added ingredients
          if (item.addedIngredients.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.addedIngredients.map((ing) {
                final name = ing['name'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$name',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Removed ingredients
          if (item.removedIngredients.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.removedIngredients.map((ing) {
                final name = ing['name'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-$name',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Note
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.note!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? AppTypography.titleMedium.copyWith(
                    fontWeight: AppTypography.bold,
                  )
                : AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          Text(
            Formatters.currency(amount),
            style: isTotal
                ? AppTypography.titleLarge.copyWith(
                    fontWeight: AppTypography.bold,
                    color: AppColors.primary,
                  )
                : AppTypography.bodyMedium.copyWith(
                    color: isDiscount ? AppColors.success : null,
                    fontWeight: AppTypography.medium,
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (order.stato) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing:
        return Icons.restaurant_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_rounded;
      case OrderStatus.delivering:
        return Icons.delivery_dining_rounded;
      case OrderStatus.completed:
        return Icons.done_all_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }
}
