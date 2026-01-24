import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/promotional_banner_model.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/constants.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/categories_provider.dart';

/// Form screen for creating or editing a promotional banner
class BannerFormScreen extends ConsumerStatefulWidget {
  final String? bannerId;

  const BannerFormScreen({super.key, this.bannerId});

  @override
  ConsumerState<BannerFormScreen> createState() => _BannerFormScreenState();
}

class _BannerFormScreenState extends ConsumerState<BannerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();

  // Form fields
  final _titoloController = TextEditingController();
  final _descrizioneController = TextEditingController();
  String? _imageUrl;
  File? _selectedImage;
  String _actionType = 'none';
  final _actionDataController = TextEditingController();
  bool _attivo = true;
  DateTime? _dataInizio;
  DateTime? _dataFine;
  int _priorita = 50;
  int _ordine = 10;
  bool _mostraSoloMobile = false;
  bool _mostraSoloDesktop = false;
  bool _isSponsorizzato = false;
  final _sponsorNomeController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.bannerId != null) {
      _isEditing = true;
      _loadBanner();
    }
  }

  @override
  void dispose() {
    _titoloController.dispose();
    _descrizioneController.dispose();
    _actionDataController.dispose();
    _sponsorNomeController.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    setState(() => _isLoading = true);

    try {
      final response = await SupabaseConfig.client
          .from('promotional_banners')
          .select()
          .eq('id', widget.bannerId!)
          .single();

      final banner = PromotionalBannerModel.fromJson(response);

      setState(() {
        _titoloController.text = banner.titolo;
        _descrizioneController.text = banner.descrizione ?? '';
        _imageUrl = banner.immagineUrl;
        _actionType = banner.actionType;
        _actionDataController.text = banner.actionData.toString();
        _attivo = banner.attivo;
        _dataInizio = banner.dataInizio;
        _dataFine = banner.dataFine;
        _priorita = banner.priorita;
        _ordine = banner.ordine;
        _mostraSoloMobile = banner.mostraSoloMobile;
        _mostraSoloDesktop = banner.mostraSoloDesktop;
        _isSponsorizzato = banner.isSponsorizzato;
        _sponsorNomeController.text = banner.sponsorNome ?? '';
      });
    } catch (e) {
      Logger.error('Failed to load banner', tag: 'BannerForm', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        context.pop();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: use file picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedImage = File(result.files.single.path!);
          });
        }
      } else {
        // Mobile: use image picker
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore selezione immagine: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveBanner() async {
    if (!_formKey.currentState!.validate()) return;

    // Check image requirement
    if (!_isEditing && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un\'immagine per il banner'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = _imageUrl ?? '';

      // Upload new image if selected
      if (_selectedImage != null) {
        imageUrl = await _storageService.uploadPromotionalBanner(
          imageFile: _selectedImage!,
          existingImageUrl: _imageUrl,
        );
      }

      // Parse action data based on action type
      Map<String, dynamic> actionData = {};
      final actionValue = _actionDataController.text.trim();
      
      if (actionValue.isNotEmpty) {
        switch (_actionType) {
          case 'external_link':
            actionData = {'url': actionValue};
            break;
          case 'internal_route':
            actionData = {'route': actionValue};
            break;
          case 'product':
            actionData = {'product_id': actionValue};
            break;
          case 'category':
            actionData = {'category_id': actionValue};
            break;
          case 'special_offer':
            actionData = {'promo_code': actionValue};
            break;
        }
      }

      final data = {
        'titolo': _titoloController.text.trim(),
        'descrizione': _descrizioneController.text.trim().isEmpty
            ? null
            : _descrizioneController.text.trim(),
        'immagine_url': imageUrl,
        'action_type': _actionType,
        'action_data': actionData,
        'attivo': _attivo,
        'data_inizio': _dataInizio?.toIso8601String(),
        'data_fine': _dataFine?.toIso8601String(),
        'priorita': _priorita,
        'ordine': _ordine,
        'mostra_solo_mobile': _mostraSoloMobile,
        'mostra_solo_desktop': _mostraSoloDesktop,
        'is_sponsorizzato': _isSponsorizzato,
        'sponsor_nome': _sponsorNomeController.text.trim().isEmpty
            ? null
            : _sponsorNomeController.text.trim(),
      };

      if (_isEditing) {
        await SupabaseConfig.client
            .from('promotional_banners')
            .update(data)
            .eq('id', widget.bannerId!);
      } else {
        await SupabaseConfig.client.from('promotional_banners').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Banner aggiornato con successo'
                  : 'Banner creato con successo',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      Logger.error('Failed to save banner', tag: 'BannerForm', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel salvataggio: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica Banner' : 'Nuovo Banner'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildBasicInfoSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildActionSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSchedulingSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSettingsSection(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Immagine Banner', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Dimensioni consigliate: 1920x1080px (16:9)',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_selectedImage != null || _imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : Image.network(_imageUrl!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: Text(
                _selectedImage != null || _imageUrl != null
                    ? 'Cambia Immagine'
                    : 'Seleziona Immagine',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informazioni Base', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _titoloController,
              decoration: const InputDecoration(
                labelText: 'Titolo *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il titolo è obbligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descrizioneController,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.touch_app, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Azione al Tap', style: AppTypography.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Scegli cosa accade quando un utente tocca il banner',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _actionType,
              decoration: const InputDecoration(
                labelText: 'Tipo Azione',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'none',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 20),
                      SizedBox(width: 8),
                      Text('Nessuna azione'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'external_link',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, size: 20),
                      SizedBox(width: 8),
                      Text('Link Esterno (sito web)'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'internal_route',
                  child: Row(
                    children: [
                      Icon(Icons.navigation, size: 20),
                      SizedBox(width: 8),
                      Text('Navigazione App'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'product',
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_menu, size: 20),
                      SizedBox(width: 8),
                      Text('Prodotto Specifico'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'category',
                  child: Row(
                    children: [
                      Icon(Icons.category, size: 20),
                      SizedBox(width: 8),
                      Text('Categoria Menu'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'special_offer',
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, size: 20),
                      SizedBox(width: 8),
                      Text('Codice Promo'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _actionType = value!;
                  _actionDataController.clear();
                });
              },
            ),
            if (_actionType != 'none') ...[
              const SizedBox(height: AppSpacing.lg),
              _buildActionDataInput(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionDataInput() {
    switch (_actionType) {
      case 'external_link':
        return TextFormField(
          controller: _actionDataController,
          decoration: const InputDecoration(
            labelText: 'URL Completo',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
            hintText: 'https://www.esempio.com',
            helperText: 'Inserisci l\'URL completo con https://',
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Inserisci un URL';
            }
            if (!value.startsWith('http://') && !value.startsWith('https://')) {
              return 'L\'URL deve iniziare con http:// o https://';
            }
            return null;
          },
        );

      case 'internal_route':
        return DropdownButtonFormField<String>(
          initialValue: _actionDataController.text.isEmpty
              ? null
              : _actionDataController.text,
          decoration: const InputDecoration(
            labelText: 'Destinazione',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.navigation),
            helperText: 'Scegli dove navigare nell\'app',
          ),
          items: [
            DropdownMenuItem(
              value: RouteNames.menu,
              child: const Text('📋 Menu Completo'),
            ),
            DropdownMenuItem(
              value: RouteNames.cart,
              child: const Text('🛒 Carrello'),
            ),
            DropdownMenuItem(
              value: RouteNames.currentOrder,
              child: const Text('📦 Ordine Corrente'),
            ),
            DropdownMenuItem(
              value: RouteNames.customerProfile,
              child: const Text('👤 Profilo Utente'),
            ),
          ],
          onChanged: (value) {
            setState(() => _actionDataController.text = value ?? '');
          },
        );

      case 'product':
        final menuAsync = ref.watch(menuProvider);
        return menuAsync.when(
          data: (items) {
            final products = items.where((item) => item.disponibile).toList();
            return DropdownButtonFormField<String>(
              initialValue: _actionDataController.text.isEmpty
                  ? null
                  : _actionDataController.text,
              decoration: const InputDecoration(
                labelText: 'Prodotto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant_menu),
                helperText: 'Scegli il prodotto da mostrare',
              ),
              items: products.map((product) {
                return DropdownMenuItem(
                  value: product.id,
                  child: Row(
                    children: [
                      Text(product.nome),
                      const SizedBox(width: 8),
                      Text(
                        '€${product.prezzo.toStringAsFixed(2)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _actionDataController.text = value ?? '');
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Errore: $e'),
        );

      case 'category':
        final categoriesAsync = ref.watch(categoriesProvider);
        return categoriesAsync.when(
          data: (categories) {
            return DropdownButtonFormField<String>(
              initialValue: _actionDataController.text.isEmpty
                  ? null
                  : _actionDataController.text,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                helperText: 'Scegli la categoria da mostrare',
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category.id,
                  child: Row(
                    children: [
                      Text(category.icona ?? '📁'),
                      const SizedBox(width: 8),
                      Text(category.nome),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _actionDataController.text = value ?? '');
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Errore: $e'),
        );

      case 'special_offer':
        return TextFormField(
          controller: _actionDataController,
          decoration: const InputDecoration(
            labelText: 'Codice Promozionale',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_offer),
            hintText: 'ESTATE2024',
            helperText: 'Codice sconto da applicare',
          ),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Inserisci un codice promo';
            }
            return null;
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSchedulingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Programmazione', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              title: const Text('Banner Attivo'),
              subtitle: const Text('Mostra questo banner agli utenti'),
              value: _attivo,
              onChanged: (value) => setState(() => _attivo = value),
            ),
            const Divider(),
            ListTile(
              title: const Text('Data Inizio'),
              subtitle: Text(_dataInizio == null
                  ? 'Nessuna data di inizio'
                  : _dataInizio.toString().substring(0, 10)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            ListTile(
              title: const Text('Data Fine'),
              subtitle: Text(_dataFine == null
                  ? 'Nessuna data di fine'
                  : _dataFine.toString().substring(0, 10)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impostazioni', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _priorita.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Priorità',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _priorita = int.tryParse(value) ?? _priorita;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    initialValue: _ordine.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Ordine',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _ordine = int.tryParse(value) ?? _ordine;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: const Text('Solo Mobile'),
              value: _mostraSoloMobile,
              onChanged: (value) {
                setState(() {
                  _mostraSoloMobile = value;
                  if (value) _mostraSoloDesktop = false;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Solo Desktop'),
              value: _mostraSoloDesktop,
              onChanged: (value) {
                setState(() {
                  _mostraSoloDesktop = value;
                  if (value) _mostraSoloMobile = false;
                });
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Banner Sponsorizzato'),
              value: _isSponsorizzato,
              onChanged: (value) => setState(() => _isSponsorizzato = value),
            ),
            if (_isSponsorizzato) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _sponsorNomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Sponsor',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveBanner,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        backgroundColor: AppColors.primary,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isEditing ? 'Salva Modifiche' : 'Crea Banner',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _dataInizio : _dataFine) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dataInizio = picked;
        } else {
          _dataFine = picked;
        }
      });
    }
  }
}
