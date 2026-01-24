import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/ingredients_provider.dart';
import '../../../providers/sizes_provider.dart';
import '../../../core/models/ingredient_model.dart';

/// Master-Detail modal for editing ingredients matching the HTML mockup
class InventoryEditModal extends ConsumerStatefulWidget {
  final IngredientModel? ingredient;
  final VoidCallback? onSave;

  const InventoryEditModal({super.key, this.ingredient, this.onSave});

  @override
  ConsumerState<InventoryEditModal> createState() => _InventoryEditModalState();
}

class _InventoryEditModalState extends ConsumerState<InventoryEditModal> {
  IngredientModel? _selectedIngredient;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isNew = false;

  // Form Controllers
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  String _category = '';
  String _unit = 'kg';
  bool _trackStock = false;
  bool _useSizePricing = false; // New toggle for size-based pricing
  final Map<String, TextEditingController> _consumptionControllers = {};
  final Map<String, TextEditingController> _sizePriceControllers =
      {}; // Size price controllers

  bool _isSaving = false;
  bool _isLoadingRules = true;

  @override
  void initState() {
    super.initState();
    _selectedIngredient = widget.ingredient;
    _isNew = widget.ingredient == null;
    _initFormControllers();
    if (_selectedIngredient != null) {
      _loadConsumptionRules();
    } else {
      setState(() => _isLoadingRules = false);
    }
  }

  void _initFormControllers() {
    final ing = _selectedIngredient;
    _nameController = TextEditingController(text: ing?.nome ?? '');
    _priceController = TextEditingController(
      text: ing?.prezzo.toStringAsFixed(2) ?? '0.00',
    );
    _stockController = TextEditingController(
      text: ing?.stockQuantity.toStringAsFixed(1) ?? '0.0',
    );
    _thresholdController = TextEditingController(
      text: ing?.lowStockThreshold.toStringAsFixed(1) ?? '0.0',
    );
    _category = ing?.categoria ?? '';
    _unit = ing?.unitOfMeasurement ?? 'kg';
    _trackStock = ing?.trackStock ?? false;
    _useSizePricing = ing?.sizePrices.isNotEmpty ?? false;
  }

  Future<void> _loadConsumptionRules() async {
    if (_selectedIngredient == null) {
      setState(() => _isLoadingRules = false);
      return;
    }

    setState(() => _isLoadingRules = true);

    try {
      final supabase = Supabase.instance.client;
      final rules = await supabase
          .from('ingredient_consumption_rules')
          .select()
          .eq('ingredient_id', _selectedIngredient!.id)
          .isFilter('product_id', null);

      final sizes = await ref.read(sizesProvider.future);

      // Clear old controllers
      for (var c in _consumptionControllers.values) {
        c.dispose();
      }
      _consumptionControllers.clear();

      // Initialize new controllers
      for (final size in sizes) {
        Map<String, dynamic>? rule;
        for (final r in (rules as List)) {
          if (r['size_id'] == size.id) {
            rule = r;
            break;
          }
        }
        final qty = rule != null ? (rule['quantity'] as num).toDouble() : 0.0;
        _consumptionControllers[size.id] = TextEditingController(
          text: qty > 0 ? qty.toStringAsFixed(2) : '',
        );
      }

      if (mounted) setState(() => _isLoadingRules = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRules = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento regole: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    for (var c in _consumptionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectIngredient(IngredientModel ingredient) {
    setState(() {
      _selectedIngredient = ingredient;
      _isNew = false;
    });
    // Re-init form
    _nameController.text = ingredient.nome;
    _priceController.text = ingredient.prezzo.toStringAsFixed(2);
    _stockController.text = ingredient.stockQuantity.toStringAsFixed(1);
    _thresholdController.text = ingredient.lowStockThreshold.toStringAsFixed(1);
    _category = ingredient.categoria ?? '';
    _unit = ingredient.unitOfMeasurement;
    _trackStock = ingredient.trackStock;
    _loadConsumptionRules();
  }

  void _createNew() {
    setState(() {
      _selectedIngredient = null;
      _isNew = true;
      _isLoadingRules = false;
    });
    _nameController.clear();
    _priceController.text = '0.00';
    _stockController.text = '0.0';
    _thresholdController.text = '0.0';
    _category = '';
    _unit = 'kg';
    _trackStock = false;
    for (var c in _consumptionControllers.values) {
      c.clear();
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Il nome è obbligatorio'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ingredientData = IngredientModel(
        id: _selectedIngredient?.id ?? const Uuid().v4(),
        nome: _nameController.text.trim(),
        prezzo: double.tryParse(_priceController.text) ?? 0.0,
        categoria: _category.isEmpty ? null : _category,
        allergeni: _selectedIngredient?.allergeni ?? [],
        ordine: _selectedIngredient?.ordine ?? 0,
        attivo: _selectedIngredient?.attivo ?? true,
        createdAt: _selectedIngredient?.createdAt ?? DateTime.now(),
        stockQuantity: double.tryParse(_stockController.text) ?? 0.0,
        unitOfMeasurement: _unit,
        trackStock: _trackStock,
        lowStockThreshold: double.tryParse(_thresholdController.text) ?? 0.0,
      );

      if (_isNew) {
        await ref
            .read(ingredientsProvider.notifier)
            .createIngredient(ingredientData);
      } else {
        await ref
            .read(ingredientsProvider.notifier)
            .updateIngredient(_selectedIngredient!.id, ingredientData.toJson());
      }

      // Save consumption rules
      if (!_isNew && _consumptionControllers.isNotEmpty) {
        final supabase = Supabase.instance.client;
        for (var entry in _consumptionControllers.entries) {
          final qty = double.tryParse(entry.value.text) ?? 0;
          if (qty > 0) {
            await supabase.from('ingredient_consumption_rules').upsert({
              'ingredient_id': ingredientData.id,
              'size_id': entry.key,
              'product_id': null,
              'quantity': qty,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'ingredient_id,size_id,product_id');
          } else {
            await supabase
                .from('ingredient_consumption_rules')
                .delete()
                .eq('ingredient_id', ingredientData.id)
                .eq('size_id', entry.key)
                .isFilter('product_id', null);
          }
        }
      }

      widget.onSave?.call();
      if (mounted) Navigator.pop(context);
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

  Future<void> _delete() async {
    if (_selectedIngredient == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Ingrediente'),
        content: Text(
          'Sei sicuro di voler eliminare "${_selectedIngredient!.nome}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(ingredientsProvider.notifier)
          .deleteIngredient(_selectedIngredient!.id);
      widget.onSave?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 900;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Container(
        width: isDesktop ? 1100 : double.infinity,
        height: screenSize.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXL,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusXL,
          child: Row(
            children: [
              // Left Panel - Ingredient List
              if (isDesktop)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: _buildLeftPanel(ingredientsAsync),
                ),
              // Right Panel - Form
              Expanded(child: _buildRightPanel()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel(AsyncValue<List<IngredientModel>> ingredientsAsync) {
    final categories = ingredientsAsync.maybeWhen(
      data: (list) =>
          list.map((i) => i.categoria).whereType<String>().toSet().toList()
            ..sort(),
      orElse: () => <String>[],
    );

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNew ? 'Nuovo Ingrediente' : 'Modifica',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      Text(
                        'Seleziona o crea nuovo',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded),
                    color: AppColors.primary,
                    onPressed: _createNew,
                    tooltip: 'Nuovo ingrediente',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cerca...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              // Category filters
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _MiniPill(
                      label: 'Tutti',
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    ...categories.map(
                      (cat) => _MiniPill(
                        label: cat,
                        isSelected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory = cat),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Ingredients List
        Expanded(
          child: ingredientsAsync.when(
            data: (ingredients) {
              var filtered = ingredients.where((i) {
                final matchesSearch =
                    _searchQuery.isEmpty ||
                    i.nome.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchesCategory =
                    _selectedCategory == null ||
                    i.categoria == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final ing = filtered[index];
                  final isSelected = _selectedIngredient?.id == ing.id;
                  return _IngredientListTile(
                    ingredient: ing,
                    isSelected: isSelected,
                    onTap: () => _selectIngredient(ing),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Errore: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    final sizesAsync = ref.watch(sizesProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isNew
                          ? 'Nuovo Ingrediente'
                          : 'Configura ${_selectedIngredient?.nome ?? ""}',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    Text(
                      'Imposta proprietà e regole scorte',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        // Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info Section
                _SectionHeader(
                  title: 'INFORMAZIONI BASE',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Nome',
                        child: TextField(
                          controller: _nameController,
                          decoration: _inputDecoration(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label: 'Categoria',
                        child: TextField(
                          controller: TextEditingController(text: _category),
                          onChanged: (v) => _category = v,
                          decoration: _inputDecoration(hint: 'es. Formaggi'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Prezzo Extra (always visible)
                _FormField(
                  label: 'Prezzo Extra (Unico)',
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(
                      prefix: '€ ',
                      suffix: '/ unità',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Size Pricing Section with integrated toggle
                Container(
                  decoration: BoxDecoration(
                    color: _useSizePricing
                        ? AppColors.info.withValues(alpha: 0.05)
                        : AppColors.surfaceLight,
                    borderRadius: AppRadius.radiusMD,
                    border: Border.all(
                      color: _useSizePricing
                          ? AppColors.info.withValues(alpha: 0.2)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Toggle Header
                      InkWell(
                        onTap: () =>
                            setState(() => _useSizePricing = !_useSizePricing),
                        borderRadius: AppRadius.radiusMD,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.aspect_ratio_rounded,
                                color: _useSizePricing
                                    ? AppColors.info
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prezzo per Taglia',
                                      style: AppTypography.labelMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Imposta prezzi diversi per ogni dimensione',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _useSizePricing,
                                onChanged: (value) =>
                                    setState(() => _useSizePricing = value),
                                activeTrackColor: AppColors.info,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Size Fields (shown when enabled)
                      if (_useSizePricing) ...[
                        Divider(height: 1, color: AppColors.border),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildSizePriceFields(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // Inventory Section
                _SectionHeader(
                  title: 'GESTIONE SCORTE',
                  icon: Icons.inventory_rounded,
                ),
                const SizedBox(height: 16),

                // Track Stock Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _trackStock
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : AppColors.surfaceLight,
                    borderRadius: AppRadius.radiusMD,
                    border: Border.all(
                      color: _trackStock
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.track_changes_rounded,
                        color: _trackStock
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Traccia Scorte',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Monitora automaticamente le quantità disponibili',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _trackStock,
                        onChanged: (v) => setState(() => _trackStock = v),
                        activeTrackColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                if (_trackStock) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FormField(
                          label: 'Unità di Misura',
                          child: DropdownButtonFormField<String>(
                            initialValue: _unit,
                            decoration: _inputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                value: 'kg',
                                child: Text('Kilogrammi (kg)'),
                              ),
                              DropdownMenuItem(
                                value: 'g',
                                child: Text('Grammi (g)'),
                              ),
                              DropdownMenuItem(
                                value: 'l',
                                child: Text('Litri (l)'),
                              ),
                              DropdownMenuItem(
                                value: 'ml',
                                child: Text('Millilitri (ml)'),
                              ),
                              DropdownMenuItem(
                                value: 'pz',
                                child: Text('Pezzi (pz)'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _unit = v ?? 'kg'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FormField(
                          label: 'Quantità Attuale',
                          child: TextField(
                            controller: _stockController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(suffix: _unit),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Low Stock Alert
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.05),
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Allarme Scorta Bassa',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ricevi una notifica quando le scorte scendono sotto questa soglia',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: _thresholdController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _inputDecoration(suffix: _unit),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Consumption Rules
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.straighten_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Consumo per Taglia',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Quantità usata',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _isLoadingRules
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : sizesAsync.when(
                                  data: (sizes) => Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: sizes.map((size) {
                                      final controller = _consumptionControllers
                                          .putIfAbsent(
                                            size.id,
                                            () => TextEditingController(),
                                          );
                                      return SizedBox(
                                        width: 150,
                                        child: _FormField(
                                          label: size.nome,
                                          child: TextField(
                                            controller: controller,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: _inputDecoration(
                                              suffix: _unit,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  error: (e, _) => Text('Errore: $e'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (!_isNew)
                TextButton(
                  onPressed: _delete,
                  child: Text(
                    'Elimina',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text('Annulla'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salva Modifiche',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSizePriceFields() {
    final sizesAsync = ref.watch(sizesProvider);

    return sizesAsync.when(
      data: (sizes) {
        // Initialize controllers for each size if needed
        for (final size in sizes) {
          if (!_sizePriceControllers.containsKey(size.id)) {
            // Try to get existing price from ingredient
            double existingPrice = 0.0;
            if (_selectedIngredient != null) {
              final sizePrice = _selectedIngredient!.sizePrices
                  .where((sp) => sp.sizeId == size.id)
                  .firstOrNull;
              existingPrice = sizePrice?.prezzo ?? 0.0;
            }
            _sizePriceControllers[size.id] = TextEditingController(
              text: existingPrice > 0 ? existingPrice.toStringAsFixed(2) : '',
            );
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: AppRadius.radiusMD,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prezzo per Taglia',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sizes.map((size) {
                  return SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _sizePriceControllers[size.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: size.nome,
                        prefixText: '€ ',
                        prefixStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusSM,
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.radiusSM,
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.radiusSM,
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Lascia vuoto per usare il prezzo base',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Errore: $e'),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? prefix,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      suffixText: suffix,
      prefixStyle: TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      suffixStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientListTile extends StatelessWidget {
  final IngredientModel ingredient;
  final bool isSelected;
  final VoidCallback onTap;

  const _IngredientListTile({
    required this.ingredient,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppColors.surface : Colors.transparent,
        borderRadius: AppRadius.radiusMD,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusMD,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusMD,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? AppShadows.xs : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusSM,
                  ),
                  child: Icon(
                    _getCategoryIcon(),
                    color: _getCategoryColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.nome,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${ingredient.categoria ?? "Altro"} • ${ingredient.prezzo == 0 ? "Gratis" : "+€${ingredient.prezzo.toStringAsFixed(2)}"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (ingredient.categoria?.toLowerCase()) {
      case 'carne':
      case 'meat':
      case 'salumi':
        return Colors.red.shade600;
      case 'formaggio':
      case 'formaggi':
      case 'cheese':
      case 'dairy':
        return Colors.amber.shade700;
      case 'verdura':
      case 'verdure':
      case 'veg':
      case 'vegetable':
        return Colors.green.shade600;
      case 'pesce':
      case 'fish':
        return Colors.blue.shade600;
      case 'salsa':
      case 'salse':
      case 'sauce':
        return Colors.orange.shade600;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon() {
    switch (ingredient.categoria?.toLowerCase()) {
      case 'carne':
      case 'meat':
      case 'salumi':
        return Icons.kebab_dining_rounded;
      case 'formaggio':
      case 'formaggi':
      case 'cheese':
      case 'dairy':
        return Icons.egg_rounded;
      case 'verdura':
      case 'verdure':
      case 'veg':
      case 'vegetable':
        return Icons.eco_rounded;
      case 'pesce':
      case 'fish':
        return Icons.set_meal_rounded;
      case 'salsa':
      case 'salse':
      case 'sauce':
        return Icons.water_drop_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }
}
