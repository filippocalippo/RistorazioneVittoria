import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/models/size_variant_model.dart';
import '../../../core/models/menu_item_size_assignment_model.dart';
import '../../../core/models/menu_item_included_ingredient_model.dart';
import '../../../core/models/menu_item_extra_ingredient_model.dart';
import '../../../core/models/product_configuration_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/ingredients_provider.dart';
import '../../../providers/sizes_master_provider.dart';
import '../../../providers/product_sizes_provider.dart';
import '../../../providers/product_included_ingredients_provider.dart';
import '../../../providers/product_extra_ingredients_provider.dart';

/// Product Edit Modal - Full-featured modal with all options from ProductFormScreen
class ProductEditModal extends ConsumerStatefulWidget {
  final MenuItemModel? item;
  final Future<void> Function(MenuItemModel) onSave;

  const ProductEditModal({super.key, this.item, required this.onSave});

  @override
  ConsumerState<ProductEditModal> createState() => _ProductEditModalState();
}

class _ProductEditModalState extends ConsumerState<ProductEditModal> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Controllers
  late TextEditingController _nomeController;
  late TextEditingController _descrizioneController;
  late TextEditingController _prezzoController;
  late TextEditingController _prezzoScontatoController;

  // State
  bool _disponibile = true;
  bool _inEvidenza = false;
  bool _isSaving = false;
  String? _selectedCategoryId;

  // Image
  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();

  // Sizes with overrides (full feature parity)
  final List<String> _selectedSizeIds = [];
  String? _defaultSizeId;
  final Map<String, String> _sizeNameOverrides = {};
  final Map<String, double> _sizePriceOverrides = {};

  // Ingredients
  final List<String> _selectedIncludedIngredientIds = [];
  final List<String> _selectedExtraIngredientIds = [];

  bool _hasLoadedExistingData = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.item?.nome ?? '');
    _descrizioneController = TextEditingController(
      text: widget.item?.descrizione ?? '',
    );
    _prezzoController = TextEditingController(
      text: widget.item?.prezzo.toStringAsFixed(2) ?? '',
    );
    _prezzoScontatoController = TextEditingController(
      text: widget.item?.prezzoScontato?.toStringAsFixed(2) ?? '',
    );

    _disponibile = widget.item?.disponibile ?? true;
    _inEvidenza = widget.item?.inEvidenza ?? false;
    _existingImageUrl = widget.item?.immagineUrl;
    _selectedCategoryId = widget.item?.categoriaId;

    if (widget.item != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingData());
    }
  }

  Future<void> _loadExistingData() async {
    if (_hasLoadedExistingData || widget.item == null) return;
    _hasLoadedExistingData = true;

    try {
      final menuItemId = widget.item!.id;

      // Load sizes with overrides
      final sizes = await ref.read(productSizesProvider(menuItemId).future);
      if (sizes.isNotEmpty && mounted) {
        setState(() {
          _selectedSizeIds.addAll(sizes.map((s) => s.sizeId));
          _defaultSizeId =
              sizes.where((s) => s.isDefault).firstOrNull?.sizeId ??
              sizes.first.sizeId;
          for (final size in sizes) {
            if (size.displayNameOverride != null) {
              _sizeNameOverrides[size.sizeId] = size.displayNameOverride!;
            }
            if (size.priceOverride != null) {
              _sizePriceOverrides[size.sizeId] = size.priceOverride!;
            }
          }
        });
      }

      // Load included ingredients
      final included = await ref.read(
        productIncludedIngredientsProvider(menuItemId).future,
      );
      if (included.isNotEmpty && mounted) {
        setState(
          () => _selectedIncludedIngredientIds.addAll(
            included.map((i) => i.ingredientId),
          ),
        );
      }

      // Load extra ingredients
      final extras = await ref.read(
        productExtraIngredientsProvider(menuItemId).future,
      );
      if (extras.isNotEmpty && mounted) {
        setState(
          () => _selectedExtraIngredientIds.addAll(
            extras.map((e) => e.ingredientId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading existing data: $e');
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descrizioneController.dispose();
    _prezzoController.dispose();
    _prezzoScontatoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 900;
    final modalWidth = isDesktop ? 1000.0 : screenSize.width * 0.95;
    final modalHeight = screenSize.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: modalWidth,
        height: modalHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXL,
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item == null ? 'Nuovo Prodotto' : 'Modifica Prodotto',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configura tutti i dettagli del prodotto',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Image + Quick Status
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(),
                const SizedBox(height: 24),
                _buildStatusSection(),
              ],
            ),
          ),
        ),
        // Divider
        Container(width: 1, color: AppColors.border.withValues(alpha: 0.5)),
        // Right column - Form fields
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildFormFields(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 24),
          _buildFormFields(),
          const SizedBox(height: 24),
          _buildStatusSection(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Immagine Prodotto', Icons.image_rounded),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: AppRadius.radiusXL,
                border: Border.all(color: AppColors.border, width: 2),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : _existingImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_existingImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (_selectedImage == null && _existingImageUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Clicca per caricare',
                          style: AppTypography.labelMedium,
                        ),
                        Text(
                          'PNG, JPG fino a 2MB',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: AppRadius.radiusSM,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Carica'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: (_existingImageUrl != null || _selectedImage != null)
                  ? () => setState(() {
                      _selectedImage = null;
                      _existingImageUrl = null;
                    })
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final sizesAsync = ref.watch(sizesMasterProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Info Section
        _buildSectionHeader('Informazioni Base', Icons.info_outline_rounded),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nomeController,
          label: 'Nome Prodotto',
          hint: 'es. Margherita',
          required: true,
          prefixIcon: Icons.restaurant_menu_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _prezzoController,
                label: 'Prezzo (€)',
                hint: '0.00',
                required: true,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.euro_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _prezzoScontatoController,
                label: 'Prezzo Scontato (€)',
                hint: 'Opzionale',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.local_offer_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        categoriesAsync.when(
          data: (cats) => _buildDropdown(
            label: 'Categoria',
            value: _selectedCategoryId,
            items: cats
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
            prefixIcon: Icons.category_rounded,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Errore caricamento categorie'),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descrizioneController,
          label: 'Descrizione',
          hint: 'Descrivi gli ingredienti e i sapori...',
          maxLines: 3,
          prefixIcon: Icons.description_rounded,
        ),

        const SizedBox(height: 32),
        // Sizes Section
        _buildSectionHeader('Dimensioni', Icons.straighten_rounded),
        const SizedBox(height: 12),
        Text(
          'Seleziona le dimensioni disponibili per questo prodotto',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        sizesAsync.when(
          data: (sizes) => sizes.isEmpty
              ? _buildWarningCard('Nessuna dimensione disponibile')
              : Column(
                  children: sizes.map((size) => _buildSizeCard(size)).toList(),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Errore'),
        ),

        const SizedBox(height: 32),
        // Included Ingredients Section
        _buildSectionHeader('Ingredienti Inclusi', Icons.restaurant_rounded),
        const SizedBox(height: 12),
        ingredientsAsync.when(
          data: (ingredients) => _buildIngredientSelector(
            ingredients: ingredients,
            selectedIds: _selectedIncludedIngredientIds,
            chipColor: AppColors.success.withValues(alpha: 0.1),
            chipBorderColor: AppColors.success.withValues(alpha: 0.3),
            chipTextColor: AppColors.success,
            emptyText: 'Tocca per selezionare ingredienti inclusi',
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Errore'),
        ),

        const SizedBox(height: 32),
        // Extra Ingredients Section
        _buildSectionHeader('Ingredienti Extra', Icons.add_circle_rounded),
        const SizedBox(height: 12),
        Text(
          'Ingredienti che il cliente può aggiungere a pagamento',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ingredientsAsync.when(
          data: (ingredients) => _buildIngredientSelector(
            ingredients: ingredients,
            selectedIds: _selectedExtraIngredientIds,
            chipColor: AppColors.info.withValues(alpha: 0.1),
            chipBorderColor: AppColors.info.withValues(alpha: 0.3),
            chipTextColor: AppColors.info,
            emptyText: 'Tocca per selezionare ingredienti extra',
            showPrice: true,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Errore'),
        ),

        const SizedBox(height: 32),
        // Allergens Display
        _buildSectionHeader('Allergeni (Auto)', Icons.warning_amber_rounded),
        const SizedBox(height: 12),
        _buildAllergensDisplay(),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Stato', Icons.toggle_on_rounded),
        const SizedBox(height: 12),
        _buildStatusSwitch(
          label: 'Disponibile',
          subtitle: 'Il prodotto è visibile e ordinabile',
          value: _disponibile,
          onChanged: (v) => setState(() => _disponibile = v),
          activeColor: AppColors.success,
        ),
        const SizedBox(height: 12),
        _buildStatusSwitch(
          label: 'In Evidenza',
          subtitle: 'Mostra nella sezione in evidenza',
          value: _inEvidenza,
          onChanged: (v) => setState(() => _inEvidenza = v),
          activeColor: Colors.amber.shade600,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.radiusSM,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (v) => (v?.isEmpty ?? true) ? 'Campo richiesto' : null
          : null,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    IconData? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
        filled: true,
        fillColor: AppColors.surface,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildSizeCard(SizeVariantModel size) {
    final isSelected = _selectedSizeIds.contains(size.id);
    final isDefault = _defaultSizeId == size.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusMD,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedSizeIds.add(size.id);
              _defaultSizeId ??= size.id;
            } else {
              _selectedSizeIds.remove(size.id);
              if (_defaultSizeId == size.id) {
                _defaultSizeId = _selectedSizeIds.isNotEmpty
                    ? _selectedSizeIds.first
                    : null;
              }
              _sizeNameOverrides.remove(size.id);
              _sizePriceOverrides.remove(size.id);
            }
          });
        },
        title: Row(
          children: [
            Text(
              _sizeNameOverrides[size.id] ?? size.nome,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(x${size.priceMultiplier})',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (isDefault && isSelected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DEFAULT',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: isSelected
            ? Wrap(
                spacing: 8,
                children: [
                  if (_selectedSizeIds.length > 1 && !isDefault)
                    TextButton(
                      onPressed: () => setState(() => _defaultSizeId = size.id),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Imposta default'),
                    ),
                  TextButton(
                    onPressed: () => _showSizeNameOverrideDialog(size),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      _sizeNameOverrides.containsKey(size.id)
                          ? 'Modifica nome'
                          : 'Nome personalizzato',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showSizePriceOverrideDialog(size),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      _sizePriceOverrides.containsKey(size.id)
                          ? 'Prezzo: €${_sizePriceOverrides[size.id]!.toStringAsFixed(2)}'
                          : 'Prezzo personalizzato',
                    ),
                  ),
                ],
              )
            : null,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildIngredientSelector({
    required List<IngredientModel> ingredients,
    required List<String> selectedIds,
    required Color chipColor,
    required Color chipBorderColor,
    required Color chipTextColor,
    required String emptyText,
    bool showPrice = false,
  }) {
    final selected = ingredients
        .where((i) => selectedIds.contains(i.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected chips display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: AppRadius.radiusLG,
            border: Border.all(color: AppColors.border),
          ),
          child: selected.isEmpty
              ? Center(
                  child: Text(
                    emptyText,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selected
                      .map(
                        (ing) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: chipColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: chipBorderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                showPrice
                                    ? '${ing.nome} (+€${ing.prezzo.toStringAsFixed(2)})'
                                    : ing.nome,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: chipTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => selectedIds.remove(ing.id)),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: chipTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${selected.length}/${ingredients.length} selezionati',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _showIngredientPickerDialog(
                title: 'Seleziona Ingredienti',
                ingredients: ingredients,
                selectedIds: selectedIds,
              ),
              child: const Text('Modifica'),
            ),
            TextButton(
              onPressed: () => setState(
                () => selectedIds.addAll(ingredients.map((e) => e.id)),
              ),
              child: const Text('Tutti'),
            ),
            TextButton(
              onPressed: () => setState(() => selectedIds.clear()),
              child: const Text('Nessuno'),
            ),
          ],
        ),
      ],
    );
  }

  void _showIngredientPickerDialog({
    required String title,
    required List<IngredientModel> ingredients,
    required List<String> selectedIds,
  }) {
    // Group ingredients by category
    final Map<String, List<IngredientModel>> grouped = {};
    for (final ing in ingredients) {
      final cat = ing.categoria ?? 'Altro';
      grouped.putIfAbsent(cat, () => []).add(ing);
    }
    final sortedCategories = grouped.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
          child: Container(
            width: 500,
            height: 600,
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${selectedIds.length} selezionati',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView.builder(
                    itemCount: sortedCategories.length,
                    itemBuilder: (context, catIndex) {
                      final category = sortedCategories[catIndex];
                      final catIngredients = grouped[category]!;

                      return ExpansionTile(
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.category,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${catIngredients.length})',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        initiallyExpanded: catIndex == 0,
                        children: catIngredients.map((ing) {
                          final isSelected = selectedIds.contains(ing.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  selectedIds.add(ing.id);
                                } else {
                                  selectedIds.remove(ing.id);
                                }
                              });
                              setState(() {}); // Update parent
                            },
                            title: Text(ing.nome),
                            subtitle: ing.allergeni.isNotEmpty
                                ? Text(
                                    'Allergeni: ${ing.allergeni.join(", ")}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warning,
                                    ),
                                  )
                                : null,
                            secondary: ing.prezzo > 0
                                ? Text(
                                    '+€${ing.prezzo.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            activeColor: AppColors.primary,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Fatto'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllergensDisplay() {
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return ingredientsAsync.when(
      data: (ingredients) {
        final Set<String> derivedAllergens = {};
        for (final id in _selectedIncludedIngredientIds) {
          final ing = ingredients.where((i) => i.id == id).firstOrNull;
          if (ing != null) derivedAllergens.addAll(ing.allergeni);
        }

        if (derivedAllergens.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusLG,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Nessun allergene rilevato',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: AppRadius.radiusLG,
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Allergeni Rilevati:',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: derivedAllergens
                    .map(
                      (allergen) => Chip(
                        label: Text(allergen),
                        backgroundColor: AppColors.warning.withValues(
                          alpha: 0.2,
                        ),
                        side: BorderSide(color: AppColors.warning),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Errore'),
    );
  }

  Widget _buildStatusSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(
          color: value ? activeColor.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          Text(
            message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              side: BorderSide(color: AppColors.border),
            ),
            child: const Text('Annulla'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 20),
            label: Text(_isSaving ? 'Salvando...' : 'Salva Prodotto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showSizeNameOverrideDialog(SizeVariantModel size) {
    final controller = TextEditingController(
      text: _sizeNameOverrides[size.id] ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome Personalizzato'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nome personalizzato',
            hintText: 'Lascia vuoto per usare "${size.nome}"',
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              setState(() {
                if (newName.isEmpty) {
                  _sizeNameOverrides.remove(size.id);
                } else {
                  _sizeNameOverrides[size.id] = newName;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _showSizePriceOverrideDialog(SizeVariantModel size) {
    final controller = TextEditingController(
      text: _sizePriceOverrides[size.id]?.toStringAsFixed(2) ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prezzo Personalizzato'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Prezzo (€)',
            hintText: 'Lascia vuoto per calcolo automatico',
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              setState(() {
                if (text.isEmpty) {
                  _sizePriceOverrides.remove(size.id);
                } else {
                  final value = double.tryParse(text.replaceAll(',', '.'));
                  if (value != null) _sizePriceOverrides[size.id] = value;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          setState(() => _selectedImage = File(result.files.single.path!));
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (image != null) setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Upload image
      String? imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        imageUrl = await _storageService.uploadMenuItemImage(
          imageFile: _selectedImage!,
          existingImageUrl: _existingImageUrl,
        );
      }

      // Parse prices
      final prezzo = double.parse(_prezzoController.text);
      final prezzoScontato = _prezzoScontatoController.text.trim().isNotEmpty
          ? double.parse(_prezzoScontatoController.text)
          : null;

      // Get ingredient allergens
      final ingredientsState = await ref.read(ingredientsProvider.future);
      final Set<String> derivedAllergens = {};
      final List<String> ingredientiNames = [];

      for (final id in _selectedIncludedIngredientIds) {
        final ing = ingredientsState.where((i) => i.id == id).firstOrNull;
        if (ing != null) {
          derivedAllergens.addAll(ing.allergeni);
          ingredientiNames.add(ing.nome);
        }
      }

      // Build configuration
      final hasSizes = _selectedSizeIds.isNotEmpty;
      final hasIngredients =
          _selectedIncludedIngredientIds.isNotEmpty ||
          _selectedExtraIngredientIds.isNotEmpty;

      ProductConfigurationModel? productConfig;
      if (hasSizes || hasIngredients) {
        productConfig = ProductConfigurationModel(
          allowSizeSelection: hasSizes,
          defaultSizeId: _defaultSizeId,
          allowIngredients: hasIngredients,
          maxIngredients: null,
          specialOptions: const [],
        );
      }

      final menuItem = MenuItemModel(
        id: widget.item?.id ?? '',
        categoriaId: _selectedCategoryId,
        nome: _nomeController.text.trim(),
        descrizione: _descrizioneController.text.trim().isNotEmpty
            ? _descrizioneController.text.trim()
            : null,
        prezzo: prezzo,
        prezzoScontato: prezzoScontato,
        immagineUrl: imageUrl,
        ingredienti: ingredientiNames,
        allergeni: derivedAllergens.toList(),
        valoriNutrizionali: widget.item?.valoriNutrizionali,
        disponibile: _disponibile,
        inEvidenza: _inEvidenza,
        ordine: widget.item?.ordine ?? 0,
        productConfiguration: productConfig,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.onSave(menuItem);

      // Save related data
      final menuItemId = widget.item?.id ?? menuItem.id;
      if (menuItemId.isNotEmpty) {
        await _saveRelatedData(menuItemId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.item == null ? 'Prodotto creato' : 'Prodotto aggiornato',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveRelatedData(String menuItemId) async {
    final sizesNotifier = ref.read(productSizesProvider(menuItemId).notifier);
    final includedNotifier = ref.read(
      productIncludedIngredientsProvider(menuItemId).notifier,
    );
    final extraNotifier = ref.read(
      productExtraIngredientsProvider(menuItemId).notifier,
    );

    final effectiveDefaultSizeId = _selectedSizeIds.isEmpty
        ? null
        : (_defaultSizeId ?? _selectedSizeIds.first);

    final sizeAssignments = _selectedSizeIds
        .asMap()
        .entries
        .map(
          (entry) => MenuItemSizeAssignmentModel(
            id: '',
            menuItemId: menuItemId,
            sizeId: entry.value,
            displayNameOverride: _sizeNameOverrides[entry.value],
            isDefault: effectiveDefaultSizeId == entry.value,
            priceOverride: _sizePriceOverrides[entry.value],
            ordine: entry.key,
            createdAt: DateTime.now(),
            sizeData: null,
          ),
        )
        .toList();

    final includedAssignments = _selectedIncludedIngredientIds
        .asMap()
        .entries
        .map(
          (entry) => MenuItemIncludedIngredientModel(
            id: '',
            menuItemId: menuItemId,
            ingredientId: entry.value,
            ordine: entry.key,
            createdAt: DateTime.now(),
            ingredientData: null,
          ),
        )
        .toList();

    final extraAssignments = _selectedExtraIngredientIds
        .asMap()
        .entries
        .map(
          (entry) => MenuItemExtraIngredientModel(
            id: '',
            menuItemId: menuItemId,
            ingredientId: entry.value,
            maxQuantity: 1,
            ordine: entry.key,
            createdAt: DateTime.now(),
            ingredientData: null,
          ),
        )
        .toList();

    try {
      await sizesNotifier.replaceAssignments(menuItemId, sizeAssignments);
    } catch (e) {
      debugPrint('Error replacing size assignments: $e');
    }

    try {
      await includedNotifier.replaceIngredients(
        menuItemId,
        includedAssignments,
      );
    } catch (e) {
      debugPrint('Error replacing included ingredients: $e');
    }

    try {
      await extraNotifier.replaceIngredients(menuItemId, extraAssignments);
    } catch (e) {
      debugPrint('Error replacing extra ingredients: $e');
    }
  }
}
