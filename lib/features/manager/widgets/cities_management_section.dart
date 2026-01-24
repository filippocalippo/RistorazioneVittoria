import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/cities_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/models/allowed_city_model.dart';

class CitiesManagementSection extends ConsumerStatefulWidget {
  const CitiesManagementSection({super.key});

  @override
  ConsumerState<CitiesManagementSection> createState() => _CitiesManagementSectionState();
}

class _CitiesManagementSectionState extends ConsumerState<CitiesManagementSection> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    final citiesAsync = ref.watch(allowedCitiesProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.radiusLG,
                ),
                child: const Icon(Icons.location_city_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Città Servite',
                      style: AppTypography.titleLarge.copyWith(fontWeight: AppTypography.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gestisci le città dove effettui consegne',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCityDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Aggiungi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          citiesAsync.when(
            data: (cities) {
              if (cities.isEmpty) {
                return _buildEmptyState();
              }
              return Column(
                children: cities.map((city) => _buildCityCard(city)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Errore: $e',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nessuna città configurata',
            style: AppTypography.titleMedium.copyWith(fontWeight: AppTypography.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aggiungi le città dove effettui consegne',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCityCard(AllowedCityModel city) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: city.attiva ? AppColors.border : AppColors.error),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: city.attiva 
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusMD,
            ),
            child: Icon(
              city.attiva ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: city.attiva ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.nome,
                  style: AppTypography.bodyLarge.copyWith(fontWeight: AppTypography.semiBold),
                ),
                const SizedBox(height: 2),
                Text(
                  'CAP: ${city.cap}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditCityDialog(context, city),
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Modifica',
          ),
          IconButton(
            onPressed: () => _deleteCity(city),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.error,
            tooltip: 'Elimina',
          ),
        ],
      ),
    );
  }

  void _showAddCityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CityDialog(
        onSave: (nome, cap) async {
          try {
            final user = ref.read(authProvider).value;
            if (user == null) return;
            
            await ref.read(allowedCitiesProvider.notifier).createCity(
              nome: nome,
              cap: cap,
            );
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Città aggiunta con successo'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Errore: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditCityDialog(BuildContext context, AllowedCityModel city) {
    showDialog(
      context: context,
      builder: (context) => _CityDialog(
        city: city,
        onSave: (nome, cap) async {
          try {
            final user = ref.read(authProvider).value;
            if (user == null) return;
            
            await ref.read(allowedCitiesProvider.notifier).updateCity(
              city.id,
              {'nome': nome, 'cap': cap},
            );
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Città aggiornata con successo'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Errore: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteCity(AllowedCityModel city) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Città'),
        content: Text('Sei sicuro di voler eliminare "${city.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = ref.read(authProvider).value;
        if (user == null) return;
        
        await ref.read(allowedCitiesProvider.notifier).deleteCity(city.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Città eliminata'),
              backgroundColor: AppColors.success,
            ),
          );
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
  }
}

class _CityDialog extends StatefulWidget {
  final AllowedCityModel? city;
  final Future<void> Function(String nome, String cap) onSave;

  const _CityDialog({this.city, required this.onSave});

  @override
  State<_CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<_CityDialog> {
  late final TextEditingController _nomeController;
  late final TextEditingController _capController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.city?.nome ?? '');
    _capController = TextEditingController(text: widget.city?.cap ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _capController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onSave(
        _nomeController.text.trim(),
        _capController.text.trim(),
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.city != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.radiusMD,
                    ),
                    child: const Icon(Icons.location_city, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      isEditing ? 'Modifica Città' : 'Aggiungi Città',
                      style: AppTypography.titleLarge.copyWith(fontWeight: AppTypography.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome Città',
                  hintText: 'es. Roma',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
                ),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Inserisci il nome' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _capController,
                decoration: InputDecoration(
                  labelText: 'CAP',
                  hintText: '00000',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
                ),
                keyboardType: TextInputType.number,
                maxLength: 5,
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Inserisci il CAP';
                  if (v!.trim().length != 5) return 'Il CAP deve essere di 5 cifre';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
                      ),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Salva'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
