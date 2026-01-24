import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/menu_item_size_assignment_model.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/models/menu_item_extra_ingredient_model.dart';
import '../../../core/models/cart_item_model.dart';
import '../../../core/models/size_variant_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_sizes_provider.dart';
import '../../../providers/product_included_ingredients_provider.dart';
import '../../../providers/product_extra_ingredients_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/filtered_menu_provider.dart';
import '../../../providers/recommended_ingredients_provider.dart';
import 'dual_stack_split_modal.dart';

/// Advanced product customization modal/bottom sheet with size and ingredients
class ProductCustomizationModal extends ConsumerStatefulWidget {
  final MenuItemModel item;
  final Function(Map<String, dynamic>)? onCustomizationComplete;

  // Edit mode parameters
  final int? editIndex;
  final int? initialQuantity;
  final SizeVariantModel? initialSize;
  final List<SelectedIngredient>? initialAddedIngredients;
  final List<IngredientModel>? initialRemovedIngredients;
  final String? initialNote;

  const ProductCustomizationModal({
    super.key,
    required this.item,
    this.onCustomizationComplete,
    this.editIndex,
    this.initialQuantity,
    this.initialSize,
    this.initialAddedIngredients,
    this.initialRemovedIngredients,
    this.initialNote,
  });

  bool get isEditMode => editIndex != null;

  @override
  ConsumerState<ProductCustomizationModal> createState() =>
      _ProductCustomizationModalState();

  /// Show as bottom sheet on mobile, modal on desktop
  static Future<void> show(
    BuildContext context,
    MenuItemModel item, {
    Function(Map<String, dynamic>)? onCustomizationComplete,
  }) async {
    // Forcefully unfocus any text field (search bar)
    FocusManager.instance.primaryFocus?.unfocus();

    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true, // Ensure it displays above AppShell UI
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor:
            Colors.black54, // Darkens entire screen including status bar
        useSafeArea: false, // Allow barrier to extend to status bar
        builder: (context) => ProductCustomizationModal(
          item: item,
          onCustomizationComplete: onCustomizationComplete,
        ),
      );
    } else {
      await showDialog(
        context: context,
        useRootNavigator: true, // Ensure it displays above AppShell UI
        builder: (context) => ProductCustomizationModal(
          item: item,
          onCustomizationComplete: onCustomizationComplete,
        ),
      );
    }
  }

  /// Show in edit mode with initial values
  static Future<void> showForEdit(
    BuildContext context,
    MenuItemModel item, {
    required int editIndex,
    int? initialQuantity,
    SizeVariantModel? initialSize,
    List<SelectedIngredient>? initialAddedIngredients,
    List<IngredientModel>? initialRemovedIngredients,
    String? initialNote,
    Function(Map<String, dynamic>)? onCustomizationComplete,
  }) async {
    // Forcefully unfocus any text field (search bar)
    FocusManager.instance.primaryFocus?.unfocus();

    final isMobile = MediaQuery.of(context).size.width < 600;

    final modal = ProductCustomizationModal(
      item: item,
      editIndex: editIndex,
      initialQuantity: initialQuantity,
      initialSize: initialSize,
      initialAddedIngredients: initialAddedIngredients,
      initialRemovedIngredients: initialRemovedIngredients,
      initialNote: initialNote,
      onCustomizationComplete: onCustomizationComplete,
    );

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        useSafeArea: false,
        builder: (context) => modal,
      );
    } else {
      await showDialog(
        context: context,
        useRootNavigator: true,
        builder: (context) => modal,
      );
    }
  }
}

class _ProductCustomizationModalState
    extends ConsumerState<ProductCustomizationModal> {
  int _quantity = 1;
  MenuItemSizeAssignmentModel? _selectedSize;
  final Set<String> _removedIngredientIds = {};
  final Map<String, int> _addedIngredientQuantities = {};
  bool _isLoading = false;
  String? _selectedCategory;
  String _extraSearchQuery = '';
  late ScrollController _scrollController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _extraSearchController = TextEditingController();
  final FocusNode _extraSearchFocusNode = FocusNode();
  static const int _maxNoteLength = 100;

  // Quick ingredient shortcut state
  List<IngredientModel>? _includedIngredients;
  String _shortcutPrefix = ''; // Current typed prefix for disambiguation
  List<IngredientModel> _matchingIngredients =
      []; // Ingredients matching prefix
  OverlayEntry? _shortcutOverlay;
  final GlobalKey _includedIngredientsKey = GlobalKey();

  // Sizes for keyboard shortcuts (1, 2, 3...)
  List<MenuItemSizeAssignmentModel>? _availableSizes;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Register hardware keyboard listener for spacebar shortcut
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Initialize from edit mode values if present
    if (widget.isEditMode) {
      _quantity = widget.initialQuantity ?? 1;
      _noteController.text = widget.initialNote ?? '';

      // Initialize removed ingredients
      if (widget.initialRemovedIngredients != null) {
        for (var ing in widget.initialRemovedIngredients!) {
          _removedIngredientIds.add(ing.id);
        }
      }

      // Initialize added ingredients
      if (widget.initialAddedIngredients != null) {
        for (var ing in widget.initialAddedIngredients!) {
          _addedIngredientQuantities[ing.ingredientId] = ing.quantity;
        }
      }
    }
  }

  @override
  void dispose() {
    _hideShortcutOverlay();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scrollController.dispose();
    _noteController.dispose();
    _extraSearchController.dispose();
    _extraSearchFocusNode.dispose();
    super.dispose();
  }

  /// Checks if any text input field is currently focused.
  bool _isAnyTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final focusContext = primaryFocus.context;
    if (focusContext == null) return false;
    bool isEditable = false;
    focusContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        isEditable = true;
        return false;
      }
      return true;
    });
    return isEditable;
  }

  /// Gets the filtered extra ingredients based on current search query.
  /// Prioritizes ingredients that START with the query over those that just CONTAIN it.
  List<MenuItemExtraIngredientModel> _getFilteredExtras() {
    if (_allExtras == null || _allExtras!.isEmpty) return [];

    if (_extraSearchQuery.isNotEmpty) {
      final query = _extraSearchQuery.toLowerCase();

      // Separate into groups based on match type
      final exactMatches = <MenuItemExtraIngredientModel>[];
      final startsWithMatches = <MenuItemExtraIngredientModel>[];
      final containsMatches = <MenuItemExtraIngredientModel>[];

      for (final extra in _allExtras!) {
        final name = extra.ingredientData?.nome.toLowerCase() ?? '';

        if (name == query) {
          exactMatches.add(extra);
        } else if (name.startsWith(query)) {
          startsWithMatches.add(extra);
        } else if (name.contains(query)) {
          containsMatches.add(extra);
        }
      }

      // Sort startsWith comparison by length (shorter = closer match)
      startsWithMatches.sort((a, b) {
        final aLen = a.ingredientData?.nome.length ?? 0;
        final bLen = b.ingredientData?.nome.length ?? 0;
        return aLen.compareTo(bLen);
      });

      // Return exact matches first, then starts-with, then contains
      return [...exactMatches, ...startsWithMatches, ...containsMatches];
    }

    // If not searching, return all extras (category filtering is UI-only)
    return _allExtras!;
  }

  /// Gets ingredients matching a prefix (for Shift+letter shortcuts).
  List<IngredientModel> _getIngredientsMatchingPrefix(String prefix) {
    if (_includedIngredients == null || prefix.isEmpty) return [];
    final lowerPrefix = prefix.toLowerCase();
    return _includedIngredients!
        .where((ing) => ing.nome.toLowerCase().startsWith(lowerPrefix))
        .toList();
  }

  /// Toggles an ingredient's removal status.
  void _toggleIngredientRemoval(IngredientModel ingredient) {
    setState(() {
      if (_removedIngredientIds.contains(ingredient.id)) {
        _removedIngredientIds.remove(ingredient.id);
      } else {
        _removedIngredientIds.add(ingredient.id);
      }
    });
  }

  /// Shows the shortcut disambiguation overlay.
  void _showShortcutOverlay() {
    _hideShortcutOverlay();

    // Get position of included ingredients section
    double top = 100; // fallback
    final keyContext = _includedIngredientsKey.currentContext;
    if (keyContext != null) {
      final RenderBox box = keyContext.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      top = position.dy - 10; // Position slightly above the section
    }

    _shortcutOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _shortcutPrefix.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Premi la prossima lettera:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _cancelShortcut,
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _matchingIngredients.map((ing) {
                      final name = ing.nome;
                      final nextChar = name.length > _shortcutPrefix.length
                          ? name[_shortcutPrefix.length].toUpperCase()
                          : '✓';
                      final isRemoved = _removedIngredientIds.contains(ing.id);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isRemoved
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isRemoved
                                ? AppColors.error
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  nextChar,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isRemoved
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                                decoration: isRemoved
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ESC per annullare',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_shortcutOverlay!);
  }

  /// Hides the shortcut disambiguation overlay.
  void _hideShortcutOverlay() {
    _shortcutOverlay?.remove();
    _shortcutOverlay = null;
  }

  /// Cancels the current shortcut operation.
  void _cancelShortcut() {
    _hideShortcutOverlay();
    setState(() {
      _shortcutPrefix = '';
      _matchingIngredients = [];
    });
  }

  /// Handles letter shortcuts for quick ingredient removal.
  bool _handleLetterShortcut(String letter) {
    // Don't handle if text field is focused
    if (_isAnyTextFieldFocused()) return false;

    // Don't handle if no included ingredients
    if (_includedIngredients == null || _includedIngredients!.isEmpty) {
      return false;
    }

    // Build the new prefix
    final newPrefix = _shortcutPrefix + letter.toLowerCase();

    // Get matching ingredients
    final matches = _getIngredientsMatchingPrefix(newPrefix);

    if (matches.isEmpty) {
      // No matches - cancel if we had a prefix, otherwise ignore
      if (_shortcutPrefix.isNotEmpty) {
        _cancelShortcut();
      }
      return false;
    }

    if (matches.length == 1) {
      // Single match - toggle it immediately
      _hideShortcutOverlay();
      _toggleIngredientRemoval(matches.first);
      setState(() {
        _shortcutPrefix = '';
        _matchingIngredients = [];
      });
      return true;
    }

    // Multiple matches - show/update overlay
    setState(() {
      _shortcutPrefix = newPrefix;
      _matchingIngredients = matches;
    });
    _showShortcutOverlay();
    return true;
  }

  /// Hardware keyboard handler for spacebar shortcut.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Escape: cancel shortcut menu or unfocus search
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_shortcutPrefix.isNotEmpty) {
        _cancelShortcut();
        return true;
      }
      if (_extraSearchFocusNode.hasFocus) {
        _extraSearchFocusNode.unfocus();
        return true;
      }
      return false;
    }

    // Handle shortcuts only when no text field is focused
    if (!_isAnyTextFieldFocused()) {
      final keyLabel = event.logicalKey.keyLabel;

      // Shift+D: split product (if available)
      if (HardwareKeyboard.instance.isShiftPressed &&
          keyLabel.toUpperCase() == 'D' &&
          _categoryAllowsSplits) {
        _handleSplitProduct();
        return true;
      }

      // Number keys 1-9: select size
      if (keyLabel.length == 1 && RegExp(r'[1-9]').hasMatch(keyLabel)) {
        final index = int.parse(keyLabel) - 1; // Convert to 0-based index
        if (_availableSizes != null && index < _availableSizes!.length) {
          setState(() {
            _selectedSize = _availableSizes![index];
          });
          return true;
        }
      }

      // Letter keys: quick ingredient removal (only without Shift)
      if (!HardwareKeyboard.instance.isShiftPressed &&
          keyLabel.length == 1 &&
          RegExp(r'[a-zA-Z]').hasMatch(keyLabel)) {
        if (_handleLetterShortcut(keyLabel)) {
          return true;
        }
      }
    }

    // Enter key handling
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      // If extra search is focused and has results, select first ingredient
      if (_extraSearchFocusNode.hasFocus && _extraSearchQuery.isNotEmpty) {
        final filteredExtras = _getFilteredExtras();
        if (filteredExtras.isNotEmpty) {
          final firstExtra = filteredExtras.first;
          final ingredient = firstExtra.ingredientData;
          if (ingredient != null) {
            setState(() {
              final quantity = _addedIngredientQuantities[ingredient.id] ?? 0;
              if (quantity > 0) {
                _addedIngredientQuantities.remove(ingredient.id);
              } else {
                _addedIngredientQuantities[ingredient.id] = 1;
              }
              // Clear search after selection
              _extraSearchController.clear();
              _extraSearchQuery = '';
            });
            return true;
          }
        }
      }

      // If no text field focused, confirm and add to cart
      if (!_isAnyTextFieldFocused()) {
        _handleAddToCart();
        return true;
      }
    }

    // Spacebar: clear and focus extra search
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (!_isAnyTextFieldFocused()) {
        _extraSearchController.clear();
        setState(() => _extraSearchQuery = '');
        Future.microtask(() => _extraSearchFocusNode.requestFocus());
        return true;
      }
    }

    return false;
  }

  double get _calculatedPrice {
    double basePrice = widget.item.prezzoEffettivo;

    // Apply size price (override if present, otherwise multiplier)
    if (_selectedSize != null) {
      basePrice = _selectedSize!.calculateEffectivePrice(basePrice);
    }

    // Get current size ID for ingredient pricing
    final currentSizeId = _selectedSize?.sizeId;

    // Add extra ingredients (using size-based pricing)
    double extrasTotal = 0;
    _addedIngredientQuantities.forEach((ingredientId, quantity) {
      if (quantity > 0) {
        final extra = _allExtras?.firstWhere(
          (e) => e.ingredientId == ingredientId,
        );
        if (extra != null) {
          // Use size-based pricing
          extrasTotal +=
              extra.getEffectivePriceForSize(currentSizeId) * quantity;
        }
      }
    });

    return (basePrice + extrasTotal) * _quantity;
  }

  List<MenuItemExtraIngredientModel>? _allExtras;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On desktop, use a Dialog with a simplified version of the content
    if (!isMobile) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: _buildDesktopContent(context),
      );
    }

    // On mobile, we use the new immersive design
    return _buildMobileLayout(context);
  }

  Widget _buildDesktopContent(BuildContext context) {
    final config = widget.item.productConfiguration;
    final menuItemId = widget.item.id;
    final showSplitButton = _categoryAllowsSplits;

    return Container(
      constraints: const BoxConstraints(maxWidth: 1170, maxHeight: 910),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Left side - Image and Product Info
          Expanded(
            flex: 4,
            child: Container(
              color: AppColors.surfaceLight,
              child: Column(
                children: [
                  // Product image
                  Expanded(
                    flex: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.item.immagineUrl != null
                            ? CachedNetworkImageWidget.app(
                                imageUrl: widget.item.immagineUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: AppColors.surfaceLight,
                                child: Center(
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    size: 80,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                        // Gradient overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Product name on image
                        Positioned(
                          bottom: 20,
                          left: 24,
                          right: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.nome,
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.item.ingredienti.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.item.ingredienti.join(', '),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Price and quantity section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      children: [
                        // Quantity controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quantità',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  _buildDesktopQuantityButton(
                                    icon: Icons.remove,
                                    onTap: _quantity > 1
                                        ? () => setState(() => _quantity--)
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      '$_quantity',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _buildDesktopQuantityButton(
                                    icon: Icons.add,
                                    onTap: () => setState(() => _quantity++),
                                    isPrimary: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Total price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Totale',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              Formatters.currency(_calculatedPrice),
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Action buttons
                        Row(
                          children: [
                            if (showSplitButton) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleSplitProduct,
                                  icon: const Icon(
                                    Icons.call_split_rounded,
                                    size: 20,
                                  ),
                                  label: const Text('Dividi'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    side: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                    foregroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: showSplitButton ? 2 : 1,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleAddToCart,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        widget.isEditMode
                                            ? Icons.check_rounded
                                            : Icons.add_shopping_cart_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  widget.isEditMode ? 'Aggiorna' : 'Aggiungi',
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: AppColors.textPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
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
            ),
          ),
          // Right side - Customizations
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Personalizza',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceLight,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable customization content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Size selection
                        if (config?.allowSizeSelection ?? false) ...[
                          _buildDesktopSizeSelection(menuItemId),
                          const SizedBox(height: 28),
                        ],

                        // Included ingredients
                        if (config?.allowIngredients ?? false) ...[
                          _buildDesktopIncludedIngredients(menuItemId),
                          const SizedBox(height: 28),
                        ],

                        // Extra ingredients
                        if (config?.allowIngredients ?? false) ...[
                          _buildDesktopExtraIngredients(menuItemId),
                          const SizedBox(height: 28),
                        ],

                        // Product Note
                        _buildNoteSection(),

                        // Allergens
                        if (widget.item.allergeni.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _buildAllergensSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopQuantityButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: isPrimary
                ? Colors.white
                : (onTap != null
                      ? AppColors.textPrimary
                      : AppColors.textDisabled),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSizeSelection(String menuItemId) {
    final sizesAsync = ref.watch(productSizesProvider(menuItemId));

    return sizesAsync.when(
      data: (sizes) {
        if (sizes.isEmpty) return const SizedBox.shrink();

        // Auto-select default size
        // Store sizes for keyboard shortcuts
        if (_availableSizes == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _availableSizes = sizes;
            }
          });
        }

        if (_selectedSize == null && sizes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                if (widget.isEditMode && widget.initialSize != null) {
                  _selectedSize = sizes.firstWhere(
                    (s) => s.sizeData?.id == widget.initialSize!.id,
                    orElse: () => sizes.firstWhere(
                      (s) => s.isDefault,
                      orElse: () => sizes.first,
                    ),
                  );
                } else {
                  _selectedSize = sizes.firstWhere(
                    (s) => s.isDefault,
                    orElse: () => sizes.first,
                  );
                }
              });
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.straighten_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dimensione',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sizes.map((size) {
                final isSelected = _selectedSize?.id == size.id;
                final basePrice = widget.item.prezzoEffettivo;
                final effectivePrice = size.calculateEffectivePrice(basePrice);
                final sizeDiff = effectivePrice - basePrice;
                final hasUpcharge = sizeDiff > 0.01;

                return GestureDetector(
                  onTap: () => setState(() => _selectedSize = size),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          size.getDisplayName(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (hasUpcharge)
                          Text(
                            '+${Formatters.currency(sizeDiff)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildDesktopIncludedIngredients(String menuItemId) {
    final includedAsync = ref.watch(
      productIncludedIngredientsProvider(menuItemId),
    );

    return includedAsync.when(
      data: (included) {
        if (included.isEmpty) return const SizedBox.shrink();

        // Update included ingredients for keyboard shortcuts
        final ingredients = included
            .map((item) => item.ingredientData)
            .whereType<IngredientModel>()
            .toList();
        // Use addPostFrameCallback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _includedIngredients == null) {
            _includedIngredients = ingredients;
          }
        });

        return Column(
          key: _includedIngredientsKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rimuovi ingredienti',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: included.map((item) {
                final ingredient = item.ingredientData;
                if (ingredient == null) return const SizedBox.shrink();

                final isIncluded = !_removedIngredientIds.contains(
                  ingredient.id,
                );

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isIncluded) {
                        _removedIngredientIds.add(ingredient.id);
                      } else {
                        _removedIngredientIds.remove(ingredient.id);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isIncluded
                          ? AppColors.surface
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isIncluded ? AppColors.border : AppColors.error,
                        width: isIncluded ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isIncluded
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 18,
                          color: isIncluded
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ingredient.nome,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isIncluded
                                ? AppColors.textPrimary
                                : AppColors.error,
                            decoration: isIncluded
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildDesktopExtraIngredients(String menuItemId) {
    final extrasAsync = ref.watch(productExtraIngredientsProvider(menuItemId));
    final recommendedAsync = ref.watch(
      recommendedIngredientsProvider(menuItemId),
    );

    return extrasAsync.when(
      data: (extras) {
        if (extras.isEmpty) return const SizedBox.shrink();

        _allExtras = extras;

        // Group by category
        final Map<String, List<MenuItemExtraIngredientModel>>
        categorizedExtras = {};
        for (var extra in extras) {
          final ingredient = extra.ingredientData;
          if (ingredient != null) {
            final category = ingredient.categoria ?? 'Altro';
            categorizedExtras.putIfAbsent(category, () => []).add(extra);
          }
        }

        // Build ordered categories: Consigliati -> Tutti -> [sorted except Altro] -> Altro
        final otherCategories =
            categorizedExtras.keys.where((c) => c != 'Altro').toList()..sort();

        final categories = <String>[
          'Consigliati',
          'Tutti',
          ...otherCategories,
          if (categorizedExtras.containsKey('Altro')) 'Altro',
        ];

        // Default to "Consigliati" as the first and default category
        const defaultCategory = 'Consigliati';
        final currentCategory = _selectedCategory ?? defaultCategory;

        // Get recommended ingredient IDs for filtering
        final recommendedIds = recommendedAsync.maybeWhen(
          data: (data) => data.allIngredientIds.toSet(),
          orElse: () => <String>{},
        );

        // Filter logic
        List<MenuItemExtraIngredientModel> extrasToDisplay;
        if (_extraSearchQuery.isNotEmpty) {
          extrasToDisplay = _getFilteredExtras();
        } else if (currentCategory == 'Consigliati') {
          // Filter by recommended IDs, maintaining order from provider
          if (recommendedIds.isNotEmpty) {
            final extrasMap = {for (var e in extras) e.ingredientId: e};
            extrasToDisplay = recommendedIds
                .where((id) => extrasMap.containsKey(id))
                .map((id) => extrasMap[id]!)
                .toList();
          } else {
            // Fallback: show first 20 extras if no recommendations yet
            extrasToDisplay = extras.take(20).toList();
          }
        } else if (currentCategory == 'Tutti') {
          extrasToDisplay = extras;
        } else {
          extrasToDisplay = categorizedExtras[currentCategory] ?? [];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 20,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Aggiungi ingredienti',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _extraSearchController,
                focusNode: _extraSearchFocusNode,
                onChanged: (val) => setState(() => _extraSearchQuery = val),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cerca ingredienti...',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textTertiary),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Category pills
            if (categories.length > 2)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected =
                        currentCategory == category &&
                        _extraSearchQuery.isEmpty;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                          _extraSearchQuery = '';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            // Ingredients grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: extrasToDisplay.length,
              itemBuilder: (context, index) {
                final extra = extrasToDisplay[index];
                final ingredient = extra.ingredientData;
                if (ingredient == null) return const SizedBox.shrink();

                final quantity = _addedIngredientQuantities[ingredient.id] ?? 0;
                final isSelected = quantity > 0;
                // Use size-based pricing
                final price = extra.getEffectivePriceForSize(
                  _selectedSize?.sizeId,
                );

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _addedIngredientQuantities.remove(ingredient.id);
                      } else {
                        _addedIngredientQuantities[ingredient.id] = 1;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ingredient.nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '+${Formatters.currency(price)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final menuItemId = widget.item.id;
    final config = widget.item.productConfiguration;

    final screenHeight = MediaQuery.of(context).size.height;
    // Use a fixed hero image height proportional to screen height (35%)
    final heroImageHeight = screenHeight * 0.35;
    // Max height is 95% of screen
    final maxModalHeight = screenHeight * 0.95;

    return Container(
      constraints: BoxConstraints(maxHeight: maxModalHeight),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // 1. Immersive Hero Image (Parallax)
          AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              double offset = 0;
              if (_scrollController.hasClients) {
                offset = _scrollController.offset;
              }
              double yPos = 0;
              if (offset > 0) {
                yPos = -offset * 0.3;
              }

              return Positioned(
                top: yPos,
                left: 0,
                right: 0,
                height: heroImageHeight + (offset < 0 ? -offset : 0),
                child: child!,
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.item.immagineUrl != null
                    ? CachedNetworkImageWidget.app(
                        imageUrl: widget.item.immagineUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
              ],
            ),
          ),

          // 2. Scrollable Content (Slivers)
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Transparent Spacer
              SliverToBoxAdapter(
                child: SizedBox(height: heroImageHeight * 0.9),
              ),

              // Main Content Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 20),
                          width: 48,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.nome,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            if (widget.item.ingredienti.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.item.ingredienti.join(', '),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            const SizedBox(height: 24),
                            if (config?.allowSizeSelection ?? false) ...[
                              _buildSizeSelectionNew(menuItemId),
                              const SizedBox(height: 32),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Included Ingredients (Sliver)
              if (config?.allowIngredients ?? false)
                _buildIncludedIngredientsSliver(menuItemId),

              const SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppColors.background,
                  child: SizedBox(height: 32),
                ),
              ),

              // Extra Ingredients
              if (config?.allowIngredients ?? false)
                ..._buildExtraIngredientsSlivers(menuItemId),

              if (config?.allowIngredients ?? false)
                const SliverToBoxAdapter(
                  child: ColoredBox(
                    color: AppColors.background,
                    child: SizedBox(height: 32),
                  ),
                ),

              // Note Section
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildNoteSection(),
                ),
              ),

              const SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppColors.background,
                  child: SizedBox(height: 32),
                ),
              ),

              // Allergens
              if (widget.item.allergeni.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildAllergensSection(),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: ColoredBox(
                    color: AppColors.background,
                    child: SizedBox(height: 32),
                  ),
                ),
              ],

              // Footer Spacer
              const SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppColors.background,
                  child: SizedBox(height: 180),
                ),
              ),
            ],
          ),

          // 3. Fixed Footer - wrapped in RepaintBoundary for scroll isolation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(child: _buildFooterNew(context)),
          ),

          // 4. Close Button (No BackdropFilter)
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergensSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                'Allergeni',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.item.allergeni.map((allergen) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  allergen,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text('Note per la cucina', style: _sectionTitleStyle),
            const Spacer(),
            // Use ValueListenableBuilder to avoid full modal rebuild on keystroke
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _noteController,
              builder: (context, value, _) {
                return Text(
                  '${value.text.length}/$_maxNoteLength',
                  style: _noteCounterStyle,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFF3F4F6))),
            boxShadow: [
              BoxShadow(
                color: Color(0x08000000), // pre-computed
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _noteController,
            maxLength: _maxNoteLength,
            maxLines: 2,
            // Removed: onChanged: (_) => setState(() {}),
            style: _noteInputStyle,
            decoration: InputDecoration(
              hintText: 'Es: ben cotta, senza cipolla tagliata...',
              hintStyle: _noteHintStyle,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              counterText: '', // Hide default counter
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeSelectionNew(String menuItemId) {
    final sizesAsync = ref.watch(productSizesProvider(menuItemId));

    return sizesAsync.when(
      data: (sizes) {
        if (sizes.isEmpty) return const SizedBox.shrink();

        // Auto-select: use initial size in edit mode, otherwise default or first
        if (_selectedSize == null && sizes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                if (widget.isEditMode && widget.initialSize != null) {
                  // Find matching size by ID in edit mode
                  _selectedSize = sizes.firstWhere(
                    (s) => s.sizeData?.id == widget.initialSize!.id,
                    orElse: () => sizes.firstWhere(
                      (s) => s.isDefault,
                      orElse: () => sizes.first,
                    ),
                  );
                } else {
                  _selectedSize = sizes.firstWhere(
                    (s) => s.isDefault,
                    orElse: () => sizes.first,
                  );
                }
              });
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleziona dimensione',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: sizes.map((size) {
                  final isSelected = _selectedSize?.id == size.id;
                  final basePrice = widget.item.prezzoEffettivo;
                  final effectivePrice = size.calculateEffectivePrice(
                    basePrice,
                  );
                  final sizeDiff = effectivePrice - basePrice;
                  final hasUpcharge = sizeDiff > 0.01;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Haptic feedback
                        // HapticFeedback.selectionClick(); // if imported
                        setState(() => _selectedSize = size);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              size.getDisplayName(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (hasUpcharge)
                              Text(
                                '+${Formatters.currency(sizeDiff)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildFooterNew(BuildContext context) {
    final showSplitButton = _categoryAllowsSplits;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Quantity Stepper & Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stepper
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '-',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _quantity++),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33ACC7BE),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTALE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      Formatters.currency(_calculatedPrice),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Action Buttons
            Row(
              children: [
                if (showSplitButton) ...[
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSplitProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_split_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Dividi',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAddToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary, // Dark button
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(widget.isEditMode ? 'Aggiorna' : 'Aggiungi'),
                              const SizedBox(width: 8),
                              Icon(
                                widget.isEditMode
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Check if the product's category and selected size allow splits
  bool get _categoryAllowsSplits {
    if (widget.item.categoriaId == null) {
      return false; // Default to false if no category
    }

    // First check if category allows splits
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryAllows = categoriesAsync.maybeWhen(
      data: (categories) {
        final category = categories.firstWhere(
          (c) => c.id == widget.item.categoriaId,
          orElse: () => categories.first, // Fallback - shouldn't happen
        );
        return category.permittiDivisioni;
      },
      orElse: () => false, // Default to false if loading or error
    );

    // If category doesn't allow splits, return false
    if (!categoryAllows) return false;

    // If no size is selected, return false
    if (_selectedSize == null) return false;

    // Check if the selected size allows splits
    // Access through sizeData which contains the actual SizeVariantModel
    return _selectedSize!.sizeData?.permittiDivisioni ?? false;
  }

  Future<void> _handleSplitProduct() async {
    // Check if category allows splits
    if (!_categoryAllowsSplits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La divisione non è disponibile per questa categoria'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Build added ingredients list for split - use size-based pricing
    final addedIngredients = <SelectedIngredient>[];
    _addedIngredientQuantities.forEach((ingredientId, quantity) {
      if (quantity > 0 && _allExtras != null) {
        try {
          final extra = _allExtras!.firstWhere(
            (e) => e.ingredientId == ingredientId,
          );
          if (extra.ingredientData != null) {
            addedIngredients.add(
              SelectedIngredient(
                ingredientId: ingredientId,
                ingredientName: extra.ingredientData!.nome,
                // Use size-based pricing to correctly carry over ingredient prices
                unitPrice: extra.getEffectivePriceForSize(
                  _selectedSize?.sizeId,
                ),
                quantity: quantity,
              ),
            );
          }
        } catch (e) {
          // Ignore if not found
        }
      }
    });

    // Build removed ingredients list for split
    final removedIngredients = <IngredientModel>[];
    if (_removedIngredientIds.isNotEmpty) {
      try {
        final includedData = await ref.read(
          productIncludedIngredientsProvider(widget.item.id).future,
        );
        for (var item in includedData) {
          if (_removedIngredientIds.contains(item.ingredientId) &&
              item.ingredientData != null) {
            removedIngredients.add(item.ingredientData!);
          }
        }
      } catch (e) {
        // Continue anyway
      }
    }

    // Close current modal
    if (!mounted) return;
    Navigator.pop(context);

    // Open split modal with personalizations
    // Pass editIndex if in edit mode so the original item gets replaced
    // Pass onSplitComplete if we're in callback mode (e.g., cashier order)
    DualStackSplitModal.show(
      context,
      ref,
      firstProduct: widget.item,
      initialSize: _selectedSize,
      initialAddedIngredients: addedIngredients.isNotEmpty
          ? addedIngredients
          : null,
      initialRemovedIngredients: removedIngredients.isNotEmpty
          ? removedIngredients
          : null,
      editIndex: widget.editIndex,
      onSplitComplete: widget.onCustomizationComplete != null
          ? (splitData) {
              // Transform split data into the expected format for the callback
              widget.onCustomizationComplete!({'isSplit': true, ...splitData});
            }
          : null,
      autoOpenSecondProductSelector: true, // Auto-open for faster workflow
    );
  }

  Future<void> _handleAddToCart() async {
    if (!mounted) return;

    // Comprehensive validation
    if (widget.item.productConfiguration?.allowSizeSelection ?? false) {
      if (_selectedSize == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleziona una dimensione per continuare'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Validate quantity
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La quantità deve essere almeno 1'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // FRESH AVAILABILITY CHECK: Verify product is still available before adding to cart
      final isAvailable = await checkProductFreshAvailability(widget.item.id);
      if (!isAvailable) {
        if (!mounted) return;
        // Invalidate availability cache so menu updates
        ref.invalidate(productAvailabilityProvider);
        ref.invalidate(productAvailabilityMapProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prodotto esaurito - non più disponibile'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      // Build added ingredients list with validation
      final addedIngredients = <SelectedIngredient>[];
      _addedIngredientQuantities.forEach((ingredientId, quantity) {
        if (quantity > 0) {
          if (_allExtras == null) {
            throw Exception('Dati ingredienti extra non disponibili');
          }

          MenuItemExtraIngredientModel? extra;
          try {
            extra = _allExtras!.firstWhere(
              (e) => e.ingredientId == ingredientId,
            );
          } catch (e) {
            throw Exception('Ingrediente non trovato: $ingredientId');
          }

          if (extra.ingredientData == null) {
            throw Exception('Dati ingrediente non disponibili');
          }

          // Use size-based pricing
          addedIngredients.add(
            SelectedIngredient(
              ingredientId: ingredientId,
              ingredientName: extra.ingredientData!.nome,
              unitPrice: extra.getEffectivePriceForSize(_selectedSize?.sizeId),
              quantity: quantity,
            ),
          );
        }
      });

      // Build removed ingredients list with error handling
      final removedIngredients = <IngredientModel>[];
      if (_removedIngredientIds.isNotEmpty) {
        try {
          final includedData = await ref.read(
            productIncludedIngredientsProvider(widget.item.id).future,
          );

          for (var item in includedData) {
            if (_removedIngredientIds.contains(item.ingredientId)) {
              if (item.ingredientData != null) {
                removedIngredients.add(item.ingredientData!);
              } else {
                Logger.warning(
                  'Ingrediente rimosso senza dati: ${item.ingredientId}',
                  tag: 'ProductCustomization',
                );
              }
            }
          }
        } catch (e) {
          Logger.error(
            'Errore nel recupero ingredienti inclusi: $e',
            tag: 'ProductCustomization',
          );
          // Continue anyway - removed ingredients are optional
        }
      }

      // Get note text (trimmed, null if empty)
      final noteText = _noteController.text.trim();
      final note = noteText.isNotEmpty ? noteText : null;

      // Calculate effective base price (respects priceOverride from size assignment)
      double? effectiveBasePrice;
      if (_selectedSize != null) {
        effectiveBasePrice = _selectedSize!.calculateEffectivePrice(
          widget.item.prezzoEffettivo,
        );
      }

      // Check if there's a custom callback (for cashier screen)
      if (widget.onCustomizationComplete != null) {
        // Return customization data via callback
        widget.onCustomizationComplete!({
          'quantity': _quantity,
          'selectedSize': _selectedSize?.sizeData,
          'addedIngredients': addedIngredients.isNotEmpty
              ? addedIngredients
              : null,
          'removedIngredients': removedIngredients.isNotEmpty
              ? removedIngredients
              : null,
          'note': note,
          'effectiveBasePrice': effectiveBasePrice,
        });

        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      // Default behavior: Add to cart or replace if in edit mode
      if (!mounted) return;

      if (widget.isEditMode) {
        // Edit mode: replace the existing item
        ref
            .read(cartProvider.notifier)
            .replaceItemAtIndex(
              widget.editIndex!,
              widget.item,
              quantity: _quantity,
              selectedSize: _selectedSize?.sizeData,
              addedIngredients: addedIngredients.isNotEmpty
                  ? addedIngredients
                  : null,
              removedIngredients: removedIngredients.isNotEmpty
                  ? removedIngredients
                  : null,
              note: note,
              effectiveBasePrice: effectiveBasePrice,
            );
      } else {
        // Add mode: add new item to cart
        ref
            .read(cartProvider.notifier)
            .addItemWithCustomization(
              widget.item,
              quantity: _quantity,
              selectedSize: _selectedSize?.sizeData,
              addedIngredients: addedIngredients.isNotEmpty
                  ? addedIngredients
                  : null,
              removedIngredients: removedIngredients.isNotEmpty
                  ? removedIngredients
                  : null,
              note: note,
              effectiveBasePrice: effectiveBasePrice,
            );
      }

      if (!mounted) return;

      // Successfully added/updated cart
      Navigator.pop(context);

      // Show success feedback on desktop
      final isMobile = MediaQuery.of(context).size.width < 600;
      if (!isMobile) {
        final message = widget.isEditMode
            ? '${widget.item.nome} aggiornato'
            : '${widget.item.nome} aggiunto al carrello';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error(
        'Errore aggiunta al carrello: $e',
        tag: 'ProductCustomization',
      );

      if (!mounted) return;

      // User-friendly error messages
      String errorMessage = 'Impossibile aggiungere al carrello';

      if (e.toString().contains('Ingrediente non trovato')) {
        errorMessage = 'Errore nella selezione degli ingredienti. Riprova.';
      } else if (e.toString().contains('Dati ingrediente')) {
        errorMessage = 'Alcuni dati degli ingredienti non sono disponibili.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Errore di connessione. Verifica la tua connessione internet.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Riprova',
            textColor: Colors.white,
            onPressed: () => _handleAddToCart(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildIncludedIngredientsSliver(String menuItemId) {
    final includedAsync = ref.watch(
      productIncludedIngredientsProvider(menuItemId),
    );

    return includedAsync.when(
      data: (included) {
        if (included.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // Build tiles list once - more efficient than shrinkWrap GridView
        final tiles = <Widget>[];
        for (int i = 0; i < included.length; i += 2) {
          final item1 = included[i];
          final item2 = i + 1 < included.length ? included[i + 1] : null;

          tiles.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _buildIncludedIngredientItem(item1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: item2 != null
                        ? _buildIncludedIngredientItem(item2)
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rimuovi ingredienti', style: _sectionTitleStyle),
                const SizedBox(height: 12),
                ...tiles,
              ],
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (error, stack) =>
          const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildIncludedIngredientItem(dynamic item) {
    final ingredient = item.ingredientData;
    if (ingredient == null) return const SizedBox.shrink();

    final isIncluded = !_removedIngredientIds.contains(ingredient.id);

    return _IncludedIngredientTile(
      ingredientId: ingredient.id,
      ingredientName: ingredient.nome,
      isIncluded: isIncluded,
      onTap: () {
        setState(() {
          if (isIncluded) {
            _removedIngredientIds.add(ingredient.id);
          } else {
            _removedIngredientIds.remove(ingredient.id);
          }
        });
      },
    );
  }

  // Pre-computed TextStyle for section titles
  static final _sectionTitleStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Pre-computed TextStyles for note section
  static final _noteCounterStyle = GoogleFonts.poppins(
    fontSize: 12,
    color: AppColors.textTertiary,
  );

  static final _noteInputStyle = GoogleFonts.poppins(fontSize: 14);

  static final _noteHintStyle = GoogleFonts.poppins(
    color: Color.lerp(AppColors.textTertiary, Colors.transparent, 0.3),
    fontSize: 14,
  );

  List<Widget> _buildExtraIngredientsSlivers(String menuItemId) {
    final extrasAsync = ref.watch(productExtraIngredientsProvider(menuItemId));
    final recommendedAsync = ref.watch(
      recommendedIngredientsProvider(menuItemId),
    );

    return extrasAsync.when(
      data: (extras) {
        if (extras.isEmpty) {
          return [const SliverToBoxAdapter(child: SizedBox.shrink())];
        }

        _allExtras = extras;

        final Map<String, List<MenuItemExtraIngredientModel>>
        categorizedExtras = {};
        for (var extra in extras) {
          final ingredient = extra.ingredientData;
          if (ingredient != null) {
            final category = ingredient.categoria ?? 'Altro';
            categorizedExtras.putIfAbsent(category, () => []).add(extra);
          }
        }

        final otherCategories =
            categorizedExtras.keys.where((c) => c != 'Altro').toList()..sort();
        final categories = <String>[
          'Consigliati',
          'Tutti',
          ...otherCategories,
          if (categorizedExtras.containsKey('Altro')) 'Altro',
        ];

        const defaultCategory = 'Consigliati';
        final currentCategory = _selectedCategory ?? defaultCategory;

        final recommendedIds = recommendedAsync.maybeWhen(
          data: (data) => data.allIngredientIds.toSet(),
          orElse: () => <String>{},
        );

        List<MenuItemExtraIngredientModel> extrasToDisplay;
        if (_extraSearchQuery.isNotEmpty) {
          extrasToDisplay = _getFilteredExtras();
        } else if (currentCategory == 'Consigliati') {
          if (recommendedIds.isNotEmpty) {
            final extrasMap = {for (var e in extras) e.ingredientId: e};
            extrasToDisplay = recommendedIds
                .where((id) => extrasMap.containsKey(id))
                .map((id) => extrasMap[id]!)
                .toList();
          } else {
            extrasToDisplay = extras.take(20).toList();
          }
        } else if (currentCategory == 'Tutti') {
          extrasToDisplay = extras;
        } else {
          extrasToDisplay = categorizedExtras[currentCategory] ?? [];
        }

        return [
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aggiungi ingredienti',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) =>
                          setState(() => _extraSearchQuery = val),
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cerca ingredienti...',
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.textTertiary.withValues(alpha: 0.7),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Categories
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected =
                            currentCategory == category &&
                            _extraSearchQuery.isEmpty;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                              _extraSearchQuery = '';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFF3F4F6),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                category,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final itemIndex1 = index * 2;
              final itemIndex2 = itemIndex1 + 1;
              if (itemIndex1 >= extrasToDisplay.length) return null;

              final extra1 = extrasToDisplay[itemIndex1];
              final extra2 = itemIndex2 < extrasToDisplay.length
                  ? extrasToDisplay[itemIndex2]
                  : null;

              return Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildExtraIngredientItemSliver(extra1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: extra2 != null
                          ? _buildExtraIngredientItemSliver(extra2)
                          : const SizedBox(),
                    ),
                  ],
                ),
              );
            }, childCount: (extrasToDisplay.length / 2).ceil()),
          ),
        ];
      },
      loading: () => [
        const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, stack) => [
        const SliverToBoxAdapter(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _buildExtraIngredientItemSliver(MenuItemExtraIngredientModel extra) {
    final ingredient = extra.ingredientData;
    if (ingredient == null) return const SizedBox.shrink();

    final quantity = _addedIngredientQuantities[ingredient.id] ?? 0;
    final isSelected = quantity > 0;
    final price = extra.getEffectivePriceForSize(_selectedSize?.sizeId);

    return _ExtraIngredientTile(
      ingredientId: ingredient.id,
      ingredientName: ingredient.nome,
      price: price,
      isSelected: isSelected,
      onTap: () {
        setState(() {
          if (isSelected) {
            _addedIngredientQuantities.remove(ingredient.id);
          } else {
            _addedIngredientQuantities[ingredient.id] = 1;
          }
        });
      },
    );
  }
}

// =============================================================================
// PERFORMANCE-OPTIMIZED WIDGETS
// =============================================================================

/// Optimized extra ingredient tile widget to avoid inline rebuilds.
/// Uses const where possible and isolates state changes.
class _ExtraIngredientTile extends StatelessWidget {
  final String ingredientId;
  final String ingredientName;
  final double price;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExtraIngredientTile({
    required this.ingredientId,
    required this.ingredientName,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000), // Pre-computed shadow color
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ingredientName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _ingredientNameStyle,
                    ),
                  ),
                  _SelectionIndicator(isSelected: isSelected),
                ],
              ),
              const SizedBox(height: 8),
              _PriceChip(price: price, isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }

  static final _ingredientNameStyle = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.textPrimary,
  );
}

/// Selection indicator circle - extracted for better rebuild isolation
class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;

  const _SelectionIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0x4D9E9E9E),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// Price chip - extracted with pre-computed styles
class _PriceChip extends StatelessWidget {
  final double price;
  final bool isSelected;

  const _PriceChip({required this.price, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '+${Formatters.currency(price)}',
        style: isSelected ? _selectedPriceStyle : _unselectedPriceStyle,
      ),
    );
  }

  static final _selectedPriceStyle = GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static final _unselectedPriceStyle = GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );
}

/// Included ingredient tile - optimized version
class _IncludedIngredientTile extends StatelessWidget {
  final String ingredientId;
  final String ingredientName;
  final bool isIncluded;
  final VoidCallback onTap;

  const _IncludedIngredientTile({
    required this.ingredientId,
    required this.ingredientName,
    required this.isIncluded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isIncluded ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isIncluded
                ? AppColors.primary.withValues(alpha: 0.5)
                : const Color(0x33999999),
            width: isIncluded ? 1.5 : 1,
          ),
          boxShadow: isIncluded
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isIncluded
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 20,
                color: isIncluded ? AppColors.primary : AppColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ingredientName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isIncluded ? FontWeight.w600 : FontWeight.w500,
                    decoration: !isIncluded ? TextDecoration.lineThrough : null,
                    color: isIncluded
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
