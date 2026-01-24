import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/models/cart_item_model.dart';
import '../../../core/models/menu_item_size_assignment_model.dart';
import '../../../core/models/menu_item_extra_ingredient_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/item_card.dart';
import 'product_list_card.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/product_included_ingredients_provider.dart';
import '../../../providers/product_extra_ingredients_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../../../providers/product_sizes_provider.dart';
import '../../../providers/filtered_menu_provider.dart';
import '../../../providers/recommended_ingredients_provider.dart';

class DualStackSplitModal extends ConsumerStatefulWidget {
  final MenuItemModel firstProduct;
  final MenuItemSizeAssignmentModel? initialSize;
  final List<SelectedIngredient>? initialAddedIngredients;
  final List<IngredientModel>? initialRemovedIngredients;

  // Edit mode: if set, the item at this index will be removed after adding the split
  final int? editIndex;

  // For editing existing split products
  final MenuItemModel? initialSecondProduct;
  final List<SelectedIngredient>? initialSecondAddedIngredients;
  final List<IngredientModel>? initialSecondRemovedIngredients;
  final String? initialNote;

  // Callback for external handling (e.g., cashier order)
  // If set, the modal will call this instead of adding to cartProvider
  final Function(Map<String, dynamic>)? onSplitComplete;

  // Auto-open second product selector on modal open (for cashier efficiency)
  final bool autoOpenSecondProductSelector;

  const DualStackSplitModal({
    super.key,
    required this.firstProduct,
    this.initialSize,
    this.initialAddedIngredients,
    this.initialRemovedIngredients,
    this.editIndex,
    this.initialSecondProduct,
    this.initialSecondAddedIngredients,
    this.initialSecondRemovedIngredients,
    this.initialNote,
    this.onSplitComplete,
    this.autoOpenSecondProductSelector = false,
  });

  bool get isEditMode => editIndex != null;

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    WidgetRef ref, {
    required MenuItemModel firstProduct,
    MenuItemSizeAssignmentModel? initialSize,
    List<SelectedIngredient>? initialAddedIngredients,
    List<IngredientModel>? initialRemovedIngredients,
    int? editIndex,
    Function(Map<String, dynamic>)? onSplitComplete,
    bool autoOpenSecondProductSelector = false,
  }) {
    // Validate that splits are allowed before showing modal
    if (!_validateSplitPermissions(ref, firstProduct, initialSize)) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La divisione non è disponibile per questa combinazione di prodotto e dimensione',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return Future.value(null);
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final modal = DualStackSplitModal(
      firstProduct: firstProduct,
      initialSize: initialSize,
      initialAddedIngredients: initialAddedIngredients,
      initialRemovedIngredients: initialRemovedIngredients,
      editIndex: editIndex,
      onSplitComplete: onSplitComplete,
      autoOpenSecondProductSelector: autoOpenSecondProductSelector,
    );

    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        useSafeArea: false,
        builder: (context) => modal,
      );
    } else {
      // Desktop: use a constrained dialog with proper sizing
      return showDialog<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black54,
        builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1170,
                maxHeight: MediaQuery.of(context).size.height * 0.95,
              ),
              child: modal,
            ),
          ),
        ),
      );
    }
  }

  /// Show for editing an existing split product
  static Future<Map<String, dynamic>?> showForEdit(
    BuildContext context,
    WidgetRef ref, {
    required MenuItemModel firstProduct,
    required MenuItemModel secondProduct,
    required int editIndex,
    MenuItemSizeAssignmentModel? initialSize,
    List<SelectedIngredient>? firstAddedIngredients,
    List<IngredientModel>? firstRemovedIngredients,
    List<SelectedIngredient>? secondAddedIngredients,
    List<IngredientModel>? secondRemovedIngredients,
    String? initialNote,
    Function(Map<String, dynamic>)? onSplitComplete,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final modal = DualStackSplitModal(
      firstProduct: firstProduct,
      initialSize: initialSize,
      initialAddedIngredients: firstAddedIngredients,
      initialRemovedIngredients: firstRemovedIngredients,
      editIndex: editIndex,
      initialSecondProduct: secondProduct,
      initialSecondAddedIngredients: secondAddedIngredients,
      initialSecondRemovedIngredients: secondRemovedIngredients,
      initialNote: initialNote,
      onSplitComplete: onSplitComplete,
    );

    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        useSafeArea: false,
        builder: (context) => modal,
      );
    } else {
      return showDialog<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true,
        builder: (context) =>
            Dialog(backgroundColor: Colors.transparent, child: modal),
      );
    }
  }

  /// Validate that the product's category and size allow splits
  static bool _validateSplitPermissions(
    WidgetRef ref,
    MenuItemModel product,
    MenuItemSizeAssignmentModel? size,
  ) {
    // If no category, deny splits
    if (product.categoriaId == null) return false;

    // Check if category allows splits
    final categoriesAsync = ref.read(categoriesProvider);
    final categoryAllows = categoriesAsync.maybeWhen(
      data: (categories) {
        final category = categories.firstWhere(
          (c) => c.id == product.categoriaId,
          orElse: () => categories.first,
        );
        return category.permittiDivisioni;
      },
      orElse: () => false,
    );

    // If category doesn't allow splits, return false
    if (!categoryAllows) return false;

    // If no size is selected, return false
    if (size == null) return false;

    // Check if the selected size allows splits
    return size.sizeData?.permittiDivisioni ?? false;
  }

  @override
  ConsumerState<DualStackSplitModal> createState() =>
      _DualStackSplitModalState();
}

class _DualStackSplitModalState extends ConsumerState<DualStackSplitModal> {
  // Product 2 State
  MenuItemModel? _secondProduct;

  // Shared State
  MenuItemSizeAssignmentModel? _selectedSize;
  MenuItemSizeAssignmentModel? _secondProductSize;

  // Product 1 Modifications
  late List<SelectedIngredient> _p1Added;
  late List<IngredientModel> _p1Removed;

  // Product 2 Modifications
  List<SelectedIngredient> _p2Added = [];
  List<IngredientModel> _p2Removed = [];

  // Editor State
  int? _activeEditorIndex; // 1 or 2, null if none

  // Note State
  final TextEditingController _noteController = TextEditingController();
  static const int _maxNoteLength = 100;

  // Ingredient shortcut state (for letter-based toggling)
  List<IngredientModel>? _p1IncludedIngredients;
  List<IngredientModel>? _p2IncludedIngredients;
  String _shortcutPrefix = '';
  List<IngredientModel> _matchingIngredients = [];
  OverlayEntry? _shortcutOverlay;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.initialSize;
    _p1Added = List.from(widget.initialAddedIngredients ?? []);
    _p1Removed = List.from(widget.initialRemovedIngredients ?? []);

    // Initialize from edit mode values if present
    if (widget.initialSecondProduct != null) {
      _secondProduct = widget.initialSecondProduct;
      _p2Added = List.from(widget.initialSecondAddedIngredients ?? []);
      _p2Removed = List.from(widget.initialSecondRemovedIngredients ?? []);
    }
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }

    // Load second product size if present
    if (_secondProduct != null && _selectedSize != null) {
      Future.microtask(() => _loadSecondProductSize());
    }

    // Register keyboard handler
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Auto-open second product selector after frame is built
    if (widget.autoOpenSecondProductSelector && _secondProduct == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectSecondProduct();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideShortcutOverlay();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _noteController.dispose();
    super.dispose();
  }

  // ===== Helper Methods =====

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

  // ===== Ingredient Shortcut Methods =====

  /// Gets the included ingredients for the active product.
  List<IngredientModel>? _getActiveIncludedIngredients() {
    if (_activeEditorIndex == null) return null;
    return _activeEditorIndex == 1
        ? _p1IncludedIngredients
        : _p2IncludedIngredients;
  }

  /// Gets the removed list for the active product.
  List<IngredientModel> _getActiveRemovedList() {
    return _activeEditorIndex == 1 ? _p1Removed : _p2Removed;
  }

  /// Gets ingredients matching the given prefix.
  List<IngredientModel> _getIngredientsMatchingPrefix(String prefix) {
    final included = _getActiveIncludedIngredients();
    if (included == null || included.isEmpty) return [];
    return included.where((ing) {
      return ing.nome.toLowerCase().startsWith(prefix.toLowerCase());
    }).toList();
  }

  /// Toggles an ingredient's removal status for the active product.
  void _toggleIngredientRemovalByModel(IngredientModel ingredient) {
    if (_activeEditorIndex == null) return;
    setState(() {
      final targetList = _activeEditorIndex == 1 ? _p1Removed : _p2Removed;
      if (targetList.any((i) => i.id == ingredient.id)) {
        targetList.removeWhere((i) => i.id == ingredient.id);
      } else {
        targetList.add(ingredient);
      }
    });
  }

  /// Cancels the current shortcut operation.
  void _cancelShortcut() {
    _hideShortcutOverlay();
    setState(() {
      _shortcutPrefix = '';
      _matchingIngredients = [];
    });
  }

  /// Hides the shortcut disambiguation overlay.
  void _hideShortcutOverlay() {
    _shortcutOverlay?.remove();
    _shortcutOverlay = null;
  }

  /// Shows the shortcut disambiguation overlay.
  void _showShortcutOverlay() {
    _hideShortcutOverlay();
    final removedList = _getActiveRemovedList();

    _shortcutOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: 150,
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
                      final isRemoved = removedList.any((i) => i.id == ing.id);
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

  /// Handles letter shortcuts for quick ingredient removal.
  bool _handleLetterShortcut(String letter) {
    if (_activeEditorIndex == null) return false;
    final included = _getActiveIncludedIngredients();
    if (included == null || included.isEmpty) return false;

    final newPrefix = _shortcutPrefix + letter.toLowerCase();
    final matches = _getIngredientsMatchingPrefix(newPrefix);

    if (matches.isEmpty) {
      if (_shortcutPrefix.isNotEmpty) _cancelShortcut();
      return false;
    }

    if (matches.length == 1) {
      _hideShortcutOverlay();
      _toggleIngredientRemovalByModel(matches.first);
      setState(() {
        _shortcutPrefix = '';
        _matchingIngredients = [];
      });
      return true;
    }

    setState(() {
      _shortcutPrefix = newPrefix;
      _matchingIngredients = matches;
    });
    _showShortcutOverlay();
    return true;
  }

  /// Hardware keyboard handler for shortcuts.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Only handle if this modal is the top-most route
    // This prevents handling events when child modals (like extras) are open
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    // Escape: cancel shortcut menu
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_shortcutPrefix.isNotEmpty) {
        _cancelShortcut();
        return true;
      }
      return false;
    }

    // Only handle other shortcuts when no text field is focused
    if (_isAnyTextFieldFocused()) return false;

    final keyLabel = event.logicalKey.keyLabel;

    // Enter: confirm/add to cart
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_secondProduct != null) {
        _confirmOrder();
        return true;
      }
      return false;
    }

    // 1: Toggle editor for first product
    if (keyLabel == '1') {
      _cancelShortcut(); // Clear any active shortcut
      _toggleEditor(1);
      return true;
    }

    // 2: Toggle editor for second product (if selected)
    if (keyLabel == '2' && _secondProduct != null) {
      _cancelShortcut();
      _toggleEditor(2);
      return true;
    }

    // + or =: Open extras for active editor
    if ((event.logicalKey == LogicalKeyboardKey.add ||
            event.logicalKey == LogicalKeyboardKey.equal ||
            event.logicalKey == LogicalKeyboardKey.numpadAdd) &&
        _activeEditorIndex != null) {
      final product = _activeEditorIndex == 1
          ? widget.firstProduct
          : _secondProduct;
      if (product != null) {
        _openExtraSelection(product, _activeEditorIndex!);
        return true;
      }
    }

    // Letter keys: quick ingredient removal (when editor is active)
    if (_activeEditorIndex != null &&
        keyLabel.length == 1 &&
        RegExp(r'[a-zA-Z]').hasMatch(keyLabel)) {
      if (_handleLetterShortcut(keyLabel)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!isMobile) {
      return _buildDesktopLayout(context);
    }

    return _buildMobileLayout(context);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1300, maxHeight: 910),
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
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.call_split_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dividi Pizza',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Scegli due gusti diversi per la tua pizza',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),

          // Content - Two columns
          Expanded(
            child: Row(
              children: [
                // Left column - First half
                Expanded(
                  child: _buildDesktopProductColumn(
                    context,
                    product: widget.firstProduct,
                    productIndex: 1,
                    added: _p1Added,
                    removed: _p1Removed,
                    title: 'Prima Metà',
                    isEditing: _activeEditorIndex == 1,
                    onEdit: () => _toggleEditor(1),
                  ),
                ),

                // Divider
                Container(width: 1, color: AppColors.border),

                // Right column - Second half
                Expanded(
                  child: _secondProduct == null
                      ? _buildDesktopEmptyState()
                      : _buildDesktopProductColumn(
                          context,
                          product: _secondProduct!,
                          productIndex: 2,
                          added: _p2Added,
                          removed: _p2Removed,
                          title: 'Seconda Metà',
                          isEditing: _activeEditorIndex == 2,
                          onEdit: () => _toggleEditor(2),
                          onRemove: _removeSecondProduct,
                        ),
                ),
              ],
            ),
          ),

          // Note section (if second product selected)
          if (_secondProduct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      maxLength: _maxNoteLength,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Note per la cucina...',
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Text(
                    '${_noteController.text.length}/$_maxNoteLength',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 2),
              ),
            ),
            child: Row(
              children: [
                // Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Totale',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _secondProduct == null
                          ? '--'
                          : Formatters.currency(_calculateTotal()),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Action button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _secondProduct == null ? null : _confirmOrder,
                    icon: Icon(
                      _secondProduct == null
                          ? Icons.add_rounded
                          : Icons.check_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _secondProduct == null
                          ? 'Scegli seconda metà'
                          : 'Conferma Ordine',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceLight,
                      disabledForegroundColor: AppColors.textDisabled,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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

  Widget _buildDesktopProductColumn(
    BuildContext context, {
    required MenuItemModel product,
    required int productIndex,
    required List<SelectedIngredient> added,
    required List<IngredientModel> removed,
    required String title,
    required bool isEditing,
    required VoidCallback onEdit,
    VoidCallback? onRemove,
  }) {
    final price =
        _calculateHalfPrice(
          product,
          added,
          productIndex == 1 ? _selectedSize : _secondProductSize,
        ) *
        2; // Display full price (calculation uses half)

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Product header with image
          SizedBox(
            height: 180,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                product.immagineUrl != null
                    ? CachedNetworkImageWidget.app(
                        imageUrl: product.immagineUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        child: const Icon(
                          Icons.local_pizza_outlined,
                          size: 60,
                          color: AppColors.textTertiary,
                        ),
                      ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 100,
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
                // Title badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      title.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Remove button
                if (onRemove != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                // Product name and price
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          product.nome,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          Formatters.currency(price),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Customization section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Edit button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: Icon(
                            isEditing ? Icons.expand_less : Icons.tune_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isEditing
                                ? 'Chiudi modifiche'
                                : 'Modifica ingredienti',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Inline editor
                  if (isEditing) ...[
                    const SizedBox(height: 16),
                    _buildDesktopInlineEditor(
                      product,
                      productIndex,
                      added,
                      removed,
                    ),
                  ],

                  // Summary of modifications
                  if (!isEditing &&
                      (added.isNotEmpty || removed.isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    _buildDesktopModificationsSummary(added, removed),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopEmptyState() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Seconda Metà',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tocca per scegliere il secondo gusto',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _selectSecondProduct,
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: const Text('Sfoglia Menu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopInlineEditor(
    MenuItemModel product,
    int productIndex,
    List<SelectedIngredient> added,
    List<IngredientModel> removed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Included ingredients
        Text(
          'Ingredienti (tocca per rimuovere)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Consumer(
          builder: (context, ref, _) {
            final includedAsync = ref.watch(
              productIncludedIngredientsProvider(product.id),
            );

            return includedAsync.when(
              data: (included) {
                // Cache ingredients for keyboard shortcuts
                final ingredientsList = included
                    .where((i) => i.ingredientData != null)
                    .map((i) => i.ingredientData!)
                    .toList();
                if (productIndex == 1 && _p1IncludedIngredients == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _p1IncludedIngredients = ingredientsList;
                  });
                } else if (productIndex == 2 &&
                    _p2IncludedIngredients == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _p2IncludedIngredients = ingredientsList;
                  });
                }

                if (included.isEmpty) {
                  return Text(
                    'Nessun ingrediente modificabile',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: included.map((item) {
                    final ing = item.ingredientData;
                    if (ing == null) return const SizedBox();

                    final isRemoved = removed.any((r) => r.id == ing.id);

                    return GestureDetector(
                      onTap: () => _toggleIngredientRemoval(productIndex, ing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isRemoved
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.surface,
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
                            Text(
                              ing.nome,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: isRemoved
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                                decoration: isRemoved
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: isRemoved
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            if (isRemoved) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.error,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Errore: $e'),
            );
          },
        ),

        const SizedBox(height: 16),

        // Extra ingredients
        Text(
          'Extra aggiunti',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...added.map(
              (ing) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ing.ingredientName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeExtra(productIndex, ing),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Add button
            GestureDetector(
              onTap: () => _openExtraSelection(product, productIndex),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Aggiungi Extra',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopModificationsSummary(
    List<SelectedIngredient> added,
    List<IngredientModel> removed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (removed.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: removed.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '- ${ing.nome}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
        if (added.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: added.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+ ${ing.ingredientName}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: AppShadows.xl,
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dividi Pizza',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Half Label
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'PRIMA METÀ',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  // First Product Card
                  _buildProductCard(
                    product: widget.firstProduct,
                    productIndex: 1,
                    added: _p1Added,
                    removed: _p1Removed,
                    onEdit: () => _toggleEditor(1),
                    isEditing: _activeEditorIndex == 1,
                  ),

                  const SizedBox(height: 24),

                  // Second Half Label
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'SECONDA METÀ',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  // Second Product Card (or Empty State)
                  if (_secondProduct == null)
                    _buildEmptyState()
                  else
                    _buildProductCard(
                      product: _secondProduct!,
                      productIndex: 2,
                      added: _p2Added,
                      removed: _p2Removed,
                      onEdit: () => _toggleEditor(2),
                      isEditing: _activeEditorIndex == 2,
                      onRemove: _removeSecondProduct,
                    ),

                  // Note Section
                  if (_secondProduct != null) ...[
                    const SizedBox(height: 24),
                    _buildNoteSection(),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Totale',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _secondProduct == null
                          ? '--'
                          : Formatters.currency(_calculateTotal()),
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _secondProduct == null ? null : _confirmOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceLight,
                      disabledForegroundColor: AppColors.textDisabled,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _secondProduct == null ? 'Scegli 2ª metà' : 'Conferma',
                      style: AppTypography.buttonMedium,
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

  Widget _buildProductCard({
    required MenuItemModel product,
    required int productIndex,
    required List<SelectedIngredient> added,
    required List<IngredientModel> removed,
    required VoidCallback onEdit,
    required bool isEditing,
    VoidCallback? onRemove,
  }) {
    final price =
        _calculateHalfPrice(
          product,
          added,
          productIndex == 1 ? _selectedSize : _secondProductSize,
        ) *
        2; // Display full price (calculation uses half)
    final isActive = isEditing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: isActive ? AppShadows.lg : AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: product.immagineUrl != null
                            ? CachedNetworkImageWidget.app(
                                imageUrl: product.immagineUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: AppColors.surfaceLight,
                                child: const Icon(
                                  Icons.local_pizza_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.nome,
                            style: AppTypography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Ingredients Summary
                          _buildIngredientsSummary(product, added, removed),

                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                Formatters.currency(price),
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              // Edit Button
                              TextButton.icon(
                                onPressed: onEdit,
                                icon: Icon(
                                  isActive
                                      ? Icons.expand_less
                                      : Icons.tune_rounded,
                                  size: 16,
                                ),
                                label: Text(isActive ? 'Chiudi' : 'Modifica'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  backgroundColor: AppColors.surfaceLight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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

              // Remove Button (Top Right)
              if (onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: AppColors.textTertiary,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(30, 30),
                    ),
                  ),
                ),
            ],
          ),

          // Inline Editor
          AnimatedCrossFade(
            firstChild: Container(height: 0),
            secondChild: _buildInlineEditor(
              product,
              productIndex,
              added,
              removed,
            ),
            crossFadeState: isActive
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSummary(
    MenuItemModel product,
    List<SelectedIngredient> added,
    List<IngredientModel> removed,
  ) {
    // Base ingredients minus removed
    // Plus added

    // For summary, we just show a truncated string
    return Consumer(
      builder: (context, ref, _) {
        final includedAsync = ref.watch(
          productIncludedIngredientsProvider(product.id),
        );

        return includedAsync.when(
          data: (included) {
            final baseNames = included
                .map((e) => e.ingredientData?.nome ?? '')
                .where(
                  (name) =>
                      name.isNotEmpty && !removed.any((r) => r.nome == name),
                )
                .toList();

            final addedNames = added
                .map((e) => '+ ${e.ingredientName}')
                .toList();

            final allNames = [...baseNames, ...addedNames];

            if (allNames.isEmpty) return const SizedBox();

            return Text(
              allNames.join(', '),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
          loading: () => const SizedBox(
            height: 10,
            width: 100,
            child: LinearProgressIndicator(),
          ),
          error: (e, s) => const SizedBox(),
        );
      },
    );
  }

  Widget _buildInlineEditor(
    MenuItemModel product,
    int productIndex,
    List<SelectedIngredient> added,
    List<IngredientModel> removed,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // Included Ingredients (Toggle to remove)
          Text(
            'INGREDIENTI (Tocca per rimuovere)',
            style: AppTypography.captionSmall,
          ),
          const SizedBox(height: 8),

          Consumer(
            builder: (context, ref, _) {
              final includedAsync = ref.watch(
                productIncludedIngredientsProvider(product.id),
              );

              return includedAsync.when(
                data: (included) {
                  if (included.isEmpty) {
                    return const Text('Nessun ingrediente modificabile');
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: included.map((item) {
                      final ing = item.ingredientData;
                      if (ing == null) return const SizedBox();

                      final isRemoved = removed.any((r) => r.id == ing.id);

                      return GestureDetector(
                        onTap: () =>
                            _toggleIngredientRemoval(productIndex, ing),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isRemoved
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRemoved
                                  ? AppColors.error
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ing.nome,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isRemoved
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                  decoration: isRemoved
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: isRemoved
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isRemoved) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: AppColors.error,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Errore: $e'),
              );
            },
          ),

          const SizedBox(height: 16),

          // Extras
          Text('EXTRA AGGIUNTI', style: AppTypography.captionSmall),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...added.map(
                (ing) => Chip(
                  label: Text(ing.ingredientName),
                  onDeleted: () => _removeExtra(productIndex, ing),
                  backgroundColor: AppColors.success.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                  deleteIconColor: AppColors.success,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Add Button
              ActionChip(
                label: const Text('Aggiungi Extra'),
                avatar: const Icon(Icons.add, size: 16),
                onPressed: () => _openExtraSelection(product, productIndex),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.primary, width: 1),
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: _selectSecondProduct,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.sm,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scegli la seconda metà',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tocca per aprire il menu',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Note per la cucina',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_noteController.text.length}/$_maxNoteLength',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLength: _maxNoteLength,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Es: ben cotta, senza cipolla tagliata...',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  // Logic Methods

  void _toggleEditor(int index) {
    setState(() {
      if (_activeEditorIndex == index) {
        _activeEditorIndex = null;
      } else {
        _activeEditorIndex = index;
      }
    });
  }

  void _toggleIngredientRemoval(int productIndex, IngredientModel ing) {
    setState(() {
      List<IngredientModel> targetList = productIndex == 1
          ? _p1Removed
          : _p2Removed;

      if (targetList.any((i) => i.id == ing.id)) {
        targetList.removeWhere((i) => i.id == ing.id);
      } else {
        targetList.add(ing);
      }
    });
  }

  void _removeExtra(int productIndex, SelectedIngredient ing) {
    setState(() {
      if (productIndex == 1) {
        _p1Added.removeWhere((i) => i.ingredientId == ing.ingredientId);
      } else {
        _p2Added.removeWhere((i) => i.ingredientId == ing.ingredientId);
      }
    });
  }

  Future<void> _openExtraSelection(
    MenuItemModel product,
    int productIndex,
  ) async {
    // We reuse the existing product customization modal but only for extras
    // Or simpler: show a list of extras in a bottom sheet

    // Get the correct size ID for this product
    final sizeId = productIndex == 1
        ? _selectedSize?.sizeId
        : (_secondProductSize?.sizeId ?? _selectedSize?.sizeId);

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // Ensure it displays above AppShell UI
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ExtrasSelectionSheet(
        product: product,
        currentAdded: productIndex == 1 ? _p1Added : _p2Added,
        sizeId: sizeId,
        onSave: (newAdded) {
          setState(() {
            if (productIndex == 1) {
              _p1Added = newAdded;
            } else {
              _p2Added = newAdded;
            }
          });
        },
      ),
    );
  }

  Future<void> _selectSecondProduct() async {
    if (widget.firstProduct.categoriaId == null) return;

    final selected = await showModalBottomSheet<MenuItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _ProductSelectionSheet(
        excludeProductId:
            null, // Allow same product for different customizations
      ),
    );

    if (selected != null) {
      setState(() {
        _secondProduct = selected;
        _p2Added = [];
        _p2Removed = [];
        _activeEditorIndex = null; // Close editor
      });
      _loadSecondProductSize();
    }
  }

  void _removeSecondProduct() {
    setState(() {
      _secondProduct = null;
      _p2Added = [];
      _p2Removed = [];
      _activeEditorIndex = null;
      _secondProductSize = null;
    });
  }

  double _calculateBasePrice(
    MenuItemModel product,
    MenuItemSizeAssignmentModel? sizeAssignment,
  ) {
    double price = product.prezzoEffettivo;

    if (sizeAssignment != null) {
      price = sizeAssignment.calculateEffectivePrice(price);
    } else if (_selectedSize != null) {
      // Fallback: use multiplier from the primary selected size if specific assignment not found
      // This handles the case where we haven't loaded the second product size yet or it's missing
      price = price * (_selectedSize!.sizeData?.priceMultiplier ?? 1.0);
    }

    return price;
  }

  double _calculateExtrasPrice(List<SelectedIngredient> added) {
    double total = 0;
    for (var extra in added) {
      total += extra.unitPrice * extra.quantity;
    }
    return total;
  }

  double _calculateHalfPrice(
    MenuItemModel product,
    List<SelectedIngredient> added,
    MenuItemSizeAssignmentModel? sizeAssignment,
  ) {
    final basePrice = _calculateBasePrice(product, sizeAssignment);
    final extrasPrice = _calculateExtrasPrice(added);
    // Base price + extras price, then divided by 2
    return (basePrice + extrasPrice) / 2;
  }

  double _calculateTotal() {
    if (_secondProduct == null) return 0;
    final p1 = _calculateHalfPrice(
      widget.firstProduct,
      _p1Added,
      _selectedSize,
    );
    final p2 = _calculateHalfPrice(
      _secondProduct!,
      _p2Added,
      _secondProductSize,
    );
    final rawTotal = p1 + p2;
    return _roundToNearestHalf(rawTotal);
  }

  Future<void> _loadSecondProductSize() async {
    if (_secondProduct == null || _selectedSize == null) {
      if (mounted) setState(() => _secondProductSize = null);
      return;
    }

    try {
      final sizes = await ref.read(
        productSizesProvider(_secondProduct!.id).future,
      );

      MenuItemSizeAssignmentModel? bestMatch;
      try {
        bestMatch = sizes.firstWhere((s) => s.sizeId == _selectedSize!.sizeId);
      } catch (_) {
        bestMatch = null;
      }

      if (mounted) {
        setState(() {
          _secondProductSize = bestMatch;
        });
      }
    } catch (e) {
      debugPrint('Error loading second product size: $e');
    }
  }

  double _roundToNearestHalf(double value) {
    // Multiply by 2, round UP to nearest integer (ceil), then divide by 2 to get steps of 0.5
    final scaled = (value * 2).ceil();
    return scaled / 2.0;
  }

  Future<void> _confirmOrder() async {
    if (_secondProduct == null) return;

    // FRESH AVAILABILITY CHECK: Verify both products are still available
    final isFirstAvailable = await checkProductFreshAvailability(
      widget.firstProduct.id,
    );
    final isSecondAvailable = await checkProductFreshAvailability(
      _secondProduct!.id,
    );

    if (!isFirstAvailable || !isSecondAvailable) {
      if (!mounted) return;
      // Invalidate availability cache so menu updates
      ref.invalidate(productAvailabilityProvider);
      ref.invalidate(productAvailabilityMapProvider);

      final unavailableProduct = !isFirstAvailable
          ? widget.firstProduct.nome
          : _secondProduct!.nome;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$unavailableProduct esaurito - non più disponibile'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // Get note text (trimmed, null if empty)
    final noteText = _noteController.text.trim();
    final note = noteText.isNotEmpty ? noteText : null;

    // If callback is provided, use it instead of adding to cart directly
    if (widget.onSplitComplete != null) {
      widget.onSplitComplete!({
        'firstProduct': widget.firstProduct,
        'secondProduct': _secondProduct!,
        'selectedSize': _selectedSize?.sizeData,
        'firstProductAddedIngredients': _p1Added.isNotEmpty ? _p1Added : null,
        'firstProductRemovedIngredients': _p1Removed.isNotEmpty
            ? _p1Removed
            : null,
        'secondProductAddedIngredients': _p2Added.isNotEmpty ? _p2Added : null,
        'secondProductRemovedIngredients': _p2Removed.isNotEmpty
            ? _p2Removed
            : null,
        'note': note,
        'total': _calculateTotal(),
      });
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final cartNotifier = ref.read(cartProvider.notifier);

    // If in edit mode, remove the original item first
    if (widget.isEditMode) {
      cartNotifier.removeItemAtIndex(widget.editIndex!);
    }

    // Add the new split item with pre-calculated total (respects priceOverride)
    cartNotifier.addSplitItem(
      firstProduct: widget.firstProduct,
      secondProduct: _secondProduct!,
      firstProductSize: _selectedSize?.sizeData,
      secondProductSize:
          _secondProductSize?.sizeData ?? _selectedSize?.sizeData,
      firstProductAddedIngredients: _p1Added.isNotEmpty ? _p1Added : null,
      firstProductRemovedIngredients: _p1Removed.isNotEmpty ? _p1Removed : null,
      secondProductAddedIngredients: _p2Added.isNotEmpty ? _p2Added : null,
      secondProductRemovedIngredients: _p2Removed.isNotEmpty
          ? _p2Removed
          : null,
      note: note,
      preCalculatedTotal: _calculateTotal(),
    );

    if (mounted) Navigator.of(context).pop();
  }
}

class _ExtrasSelectionSheet extends ConsumerStatefulWidget {
  final MenuItemModel product;
  final List<SelectedIngredient> currentAdded;
  final Function(List<SelectedIngredient>) onSave;
  final String? sizeId; // For size-based pricing

  const _ExtrasSelectionSheet({
    required this.product,
    required this.currentAdded,
    required this.onSave,
    this.sizeId,
  });

  @override
  ConsumerState<_ExtrasSelectionSheet> createState() =>
      _ExtrasSelectionSheetState();
}

class _ExtrasSelectionSheetState extends ConsumerState<_ExtrasSelectionSheet> {
  late Map<String, int> _quantities;
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _quantities = {};
    for (var item in widget.currentAdded) {
      _quantities[item.ingredientId] = item.quantity;
    }
    // Register hardware keyboard listener for spacebar shortcut
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Auto-focus search
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  /// Hardware keyboard handler for spacebar shortcut.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Enter key: when search is focused and has results, toggle first ingredient
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        // Get filtered extras with smart ranking (starts-with before contains)
        final extrasAsync = ref.read(
          productExtraIngredientsProvider(widget.product.id),
        );
        if (extrasAsync.hasValue) {
          final extras = extrasAsync.value!;
          final query = _searchQuery.toLowerCase();

          // Separate into "starts with" and "contains" matches
          final startsWithMatches = <MenuItemExtraIngredientModel>[];
          final containsMatches = <MenuItemExtraIngredientModel>[];

          for (final extra in extras) {
            final name = extra.ingredientData?.nome.toLowerCase() ?? '';
            if (name.startsWith(query)) {
              startsWithMatches.add(extra);
            } else if (name.contains(query)) {
              containsMatches.add(extra);
            }
          }

          final filteredExtras = [...startsWithMatches, ...containsMatches];

          if (filteredExtras.isNotEmpty) {
            final firstExtra = filteredExtras.first;
            final ingredient = firstExtra.ingredientData;
            if (ingredient != null) {
              setState(() {
                final currentQty = _quantities[ingredient.id] ?? 0;
                if (currentQty > 0) {
                  _quantities.remove(ingredient.id);
                } else {
                  _quantities[ingredient.id] = 1;
                }
                // Clear search after selection
                _searchController.clear();
                _searchQuery = '';
              });
              return true;
            }
          }
        }
      }
    }

    // Enter key: when no search active, confirm and save
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (!_searchFocusNode.hasFocus || _searchQuery.isEmpty) {
        _save();
        return true;
      }
    }

    // Spacebar: clear and focus search
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (!_isAnyTextFieldFocused()) {
        _searchController.clear();
        setState(() => _searchQuery = '');
        Future.microtask(() => _searchFocusNode.requestFocus());
        return true;
      }
    }

    // Escape: unfocus search
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return true;
      }
    }

    return false;
  }

  void _save() {
    final List<SelectedIngredient> newAdded = [];
    final extrasAsync = ref.read(
      productExtraIngredientsProvider(widget.product.id),
    );

    if (extrasAsync.hasValue) {
      final extras = extrasAsync.value!;
      final extraMap = {for (var e in extras) e.ingredientId: e};

      _quantities.forEach((id, qty) {
        if (qty > 0 && extraMap.containsKey(id)) {
          final extra = extraMap[id]!;
          // Use size-based pricing (full price for split product extras)
          final price = extra.getEffectivePriceForSize(widget.sizeId);
          newAdded.add(
            SelectedIngredient(
              ingredientId: id,
              ingredientName: extra.ingredientData?.nome ?? '',
              unitPrice: price,
              quantity: 1, // Force quantity to 1
            ),
          );
        }
      });
    }

    widget.onSave(newAdded);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final extrasAsync = ref.watch(
      productExtraIngredientsProvider(widget.product.id),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aggiungi Extra',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Fatto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: extrasAsync.when(
              data: (extras) {
                if (extras.isEmpty) {
                  return Center(
                    child: Text(
                      'Nessun ingrediente extra disponibile',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                // Group ingredients by category
                final Map<String, List<MenuItemExtraIngredientModel>>
                categorizedExtras = {};
                for (var extra in extras) {
                  final ingredient = extra.ingredientData;
                  if (ingredient != null) {
                    final category = ingredient.categoria ?? 'Altro';
                    categorizedExtras
                        .putIfAbsent(category, () => [])
                        .add(extra);
                  }
                }

                // Build ordered categories: Consigliati -> Tutti -> [sorted except Altro] -> Altro
                final otherCategories =
                    categorizedExtras.keys.where((c) => c != 'Altro').toList()
                      ..sort();

                final categories = <String>[
                  'Consigliati',
                  'Tutti',
                  ...otherCategories,
                  if (categorizedExtras.containsKey('Altro')) 'Altro',
                ];

                // Initialize selected category - default to Consigliati
                _selectedCategory ??= 'Consigliati';

                // Get recommended ingredient IDs
                final recommendedAsync = ref.watch(
                  recommendedIngredientsProvider(widget.product.id),
                );
                final recommendedIds = recommendedAsync.maybeWhen(
                  data: (data) => data.allIngredientIds.toSet(),
                  orElse: () => <String>{},
                );

                List<MenuItemExtraIngredientModel> currentExtras;

                if (_searchQuery.isNotEmpty) {
                  // When searching, ignore category and search across all extras
                  // Prioritize "starts with" over "contains" matches
                  final query = _searchQuery.toLowerCase();
                  final startsWithMatches = <MenuItemExtraIngredientModel>[];
                  final containsMatches = <MenuItemExtraIngredientModel>[];

                  for (final extra in extras) {
                    final name = extra.ingredientData?.nome.toLowerCase() ?? '';
                    if (name.startsWith(query)) {
                      startsWithMatches.add(extra);
                    } else if (name.contains(query)) {
                      containsMatches.add(extra);
                    }
                  }

                  currentExtras = [...startsWithMatches, ...containsMatches];
                } else if (_selectedCategory == 'Consigliati') {
                  // Filter by recommended IDs
                  if (recommendedIds.isNotEmpty) {
                    final extrasMap = {for (var e in extras) e.ingredientId: e};
                    currentExtras = recommendedIds
                        .where((id) => extrasMap.containsKey(id))
                        .map((id) => extrasMap[id]!)
                        .toList();
                  } else {
                    // Fallback: show first 20 extras
                    currentExtras = extras.take(20).toList();
                  }
                } else if (_selectedCategory == 'Tutti') {
                  currentExtras = extras;
                } else {
                  // Category-based filtering
                  currentExtras =
                      categorizedExtras[_selectedCategory] ?? extras;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar (matching ProductCustomizationModal)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Container(
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
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cerca ingredienti...',
                            hintStyle: GoogleFonts.poppins(
                              color: AppColors.textTertiary.withValues(
                                alpha: 0.7,
                              ),
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
                    ),
                    const SizedBox(height: 16),

                    // Category pills (matching ProductCustomizationModal)
                    if (categories.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected =
                                  _selectedCategory == category &&
                                  _searchQuery.isEmpty;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                    _searchQuery = '';
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
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.3),
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
                      ),

                    const SizedBox(height: 16),

                    // Ingredients Grid (matching ProductCustomizationModal cards)
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: currentExtras.length,
                        itemBuilder: (context, index) {
                          final extra = currentExtras[index];
                          final ing = extra.ingredientData;
                          if (ing == null) return const SizedBox.shrink();

                          final isSelected = (_quantities[ing.id] ?? 0) > 0;
                          // Use size-based pricing
                          final price = extra.getEffectivePriceForSize(
                            widget.sizeId,
                          );

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _quantities.remove(ing.id);
                                } else {
                                  _quantities[ing.id] = 1;
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFF3F4F6),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ing.nome,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            height: 1.1,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.grey.withValues(
                                                    alpha: 0.3,
                                                  ),
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
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+${Formatters.currency(price)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Errore: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for selecting the second product in split mode
class _ProductSelectionSheet extends ConsumerStatefulWidget {
  final String? excludeProductId;

  const _ProductSelectionSheet({this.excludeProductId});

  @override
  ConsumerState<_ProductSelectionSheet> createState() =>
      _ProductSelectionSheetState();
}

class _ProductSelectionSheetState
    extends ConsumerState<_ProductSelectionSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Register hardware keyboard listener for spacebar shortcut
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Auto-focus search
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  /// Gets filtered products based on current search query.
  List<MenuItemModel> _getFilteredProducts() {
    final menuAsync = ref.read(menuProvider);
    if (!menuAsync.hasValue) return [];
    final items = menuAsync.value!;

    // Get categories that allow splits
    final categoriesAsync = ref.read(categoriesProvider);
    final splitAllowedCategoryIds = categoriesAsync.maybeWhen(
      data: (categories) {
        return categories
            .where((cat) => cat.permittiDivisioni)
            .map((cat) => cat.id)
            .toSet();
      },
      orElse: () => <String>{},
    );

    // Filter by categories that allow splits and search
    var filteredItems = items
        .where(
          (item) =>
              item.categoriaId != null &&
              splitAllowedCategoryIds.contains(item.categoriaId!),
        )
        .where((item) => item.disponibile)
        .where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.nome.toLowerCase().contains(_searchQuery.toLowerCase());
        })
        .toList();

    if (widget.excludeProductId != null) {
      filteredItems = filteredItems
          .where((item) => item.id != widget.excludeProductId)
          .toList();
    }

    return filteredItems;
  }

  /// Hardware keyboard handler for spacebar shortcut.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Enter key: when search is focused and has results, select first product
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        final filteredProducts = _getFilteredProducts();
        if (filteredProducts.isNotEmpty) {
          // Select the first product and close
          Navigator.pop(context, filteredProducts.first);
          return true;
        }
      }
    }

    // Spacebar: clear and focus search
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (!_isAnyTextFieldFocused()) {
        _searchController.clear();
        setState(() => _searchQuery = '');
        Future.microtask(() => _searchFocusNode.requestFocus());
        return true;
      }
    }

    // Escape: unfocus search
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scegli la Seconda Metà',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                          Text(
                            'Seleziona un prodotto',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Search bar
                const SizedBox(height: AppSpacing.lg),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Cerca prodotti...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Product grid
          Expanded(
            child: menuAsync.when(
              data: (items) {
                // Get categories that allow splits
                final categoriesAsync = ref.watch(categoriesProvider);
                final splitAllowedCategoryIds = categoriesAsync.maybeWhen(
                  data: (categories) {
                    return categories
                        .where((cat) => cat.permittiDivisioni)
                        .map((cat) => cat.id)
                        .toSet();
                  },
                  orElse: () => <String>{},
                );

                // Filter by categories that allow splits and search
                var filteredItems = items
                    .where(
                      (item) =>
                          item.categoriaId != null &&
                          splitAllowedCategoryIds.contains(item.categoriaId!),
                    )
                    .where((item) => item.disponibile)
                    .where((item) {
                      if (_searchQuery.isEmpty) return true;
                      return item.nome.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                    })
                    .toList();

                if (widget.excludeProductId != null) {
                  filteredItems = filteredItems
                      .where((item) => item.id != widget.excludeProductId)
                      .toList();
                }

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.textTertiary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Nessun prodotto trovato',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mobile: use list view with ProductListCard
                // Desktop: use 3 cards per row grid
                if (isMobile) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ProductListCard(
                          item: item,
                          onTap: () => Navigator.pop(context, item),
                        ),
                      );
                    },
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return PizzaCard(
                      item: item,
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Text(
                  'Errore nel caricamento',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
