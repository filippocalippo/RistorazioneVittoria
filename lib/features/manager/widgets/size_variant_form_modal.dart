import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/size_variant_model.dart';

class SizeVariantFormModal extends ConsumerStatefulWidget {
  final SizeVariantModel? size;
  final Function(SizeVariantModel) onSave;

  const SizeVariantFormModal({
    super.key,
    this.size,
    required this.onSave,
  });

  @override
  ConsumerState<SizeVariantFormModal> createState() =>
      _SizeVariantFormModalState();
}

class _SizeVariantFormModalState extends ConsumerState<SizeVariantFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _slugController;
  late TextEditingController _descrizioneController;
  late TextEditingController _multiplierController;
  bool _isLoading = false;
  late bool _permittiDivisioni;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.size?.nome);
    _slugController = TextEditingController(text: widget.size?.slug);
    _descrizioneController = TextEditingController(
      text: widget.size?.descrizione,
    );
    _multiplierController = TextEditingController(
      text: widget.size?.priceMultiplier.toString() ?? '1.0',
    );
    _permittiDivisioni = widget.size?.permittiDivisioni ?? false;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _slugController.dispose();
    _descrizioneController.dispose();
    _multiplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.size != null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: AppSpacing.paddingXXL,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Modifica Dimensione' : 'Nuova Dimensione',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Nome
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    hintText: 'es: Piccola, Media, Grande',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obbligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Slug
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug *',
                    hintText: 'es: small, medium, large',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obbligatorio';
                    }
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                      return 'Solo lettere minuscole, numeri e underscore';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Descrizione
                TextFormField(
                  controller: _descrizioneController,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    hintText: 'es: 25cm, 30cm, etc.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Price Multiplier
                TextFormField(
                  controller: _multiplierController,
                  decoration: const InputDecoration(
                    labelText: 'Moltiplicatore Prezzo *',
                    hintText: '1.0',
                    helperText: 'Es: 1.0 = prezzo base, 1.3 = +30%, 0.8 = -20%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obbligatorio';
                    }
                    final number = double.tryParse(value);
                    if (number == null || number <= 0) {
                      return 'Inserisci un numero maggiore di 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Permetti Divisioni Checkbox
                CheckboxListTile(
                  value: _permittiDivisioni,
                  onChanged: (value) {
                    setState(() {
                      _permittiDivisioni = value ?? false;
                    });
                  },
                  title: const Text('Permetti divisioni'),
                  subtitle: const Text(
                    'Consente ai clienti di dividere questo prodotto in due metà diverse',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Preview
                Container(
                  padding: AppSpacing.paddingLG,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: AppRadius.radiusLG,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anteprima Prezzi',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildPricePreview(10.0),
                      _buildPricePreview(15.0),
                      _buildPricePreview(20.0),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEdit ? 'Salva' : 'Crea'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricePreview(double basePrice) {
    final multiplier = double.tryParse(_multiplierController.text) ?? 1.0;
    final finalPrice = basePrice * multiplier;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '€${basePrice.toStringAsFixed(2)}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Icon(
            Icons.arrow_forward,
            size: 16,
            color: AppColors.textSecondary,
          ),
          Text(
            '€${finalPrice.toStringAsFixed(2)}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final multiplier = double.parse(_multiplierController.text);

      final sizeModel = SizeVariantModel(
        id: widget.size?.id ?? const Uuid().v4(),
        nome: _nomeController.text.trim(),
        slug: _slugController.text.trim(),
        descrizione: _descrizioneController.text.trim().isEmpty
            ? null
            : _descrizioneController.text.trim(),
        priceMultiplier: multiplier,
        ordine: widget.size?.ordine ?? 0,
        attivo: widget.size?.attivo ?? true,
        permittiDivisioni: _permittiDivisioni,
        createdAt: widget.size?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.onSave(sizeModel);
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
