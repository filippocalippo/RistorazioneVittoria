import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../DesignSystem/app_colors.dart';
import '../../../DesignSystem/app_typography.dart';
import '../../../DesignSystem/app_spacing.dart';
import '../../../DesignSystem/app_radius.dart';
import '../../../DesignSystem/app_shadows.dart';
import '../../../DesignSystem/app_icons.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/logger.dart';
import '../../../core/models/user_address_model.dart';
import '../../../core/models/allowed_city_model.dart';
import '../../../providers/addresses_provider.dart';
import '../../../providers/cities_provider.dart';

/// Modello per le predizioni di Google Places Autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting =
        json['structured_formatting'] as Map<String, dynamic>?;
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String?,
      secondaryText: structuredFormatting?['secondary_text'] as String?,
    );
  }
}

/// Bottom sheet per aggiungere o modificare un indirizzo
/// Utilizza Google Places Autocomplete per suggerimenti indirizzi
class AddressFormSheet extends ConsumerStatefulWidget {
  final UserAddressModel? address;

  const AddressFormSheet({super.key, this.address});

  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  late final TextEditingController _etichettaController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  AllowedCityModel? _selectedCity;
  bool _isDefault = false;

  // Indirizzo selezionato dall'autocomplete
  String? _selectedAddress;
  bool _addressSelected = false;

  // Autocomplete state
  List<PlacePrediction> _predictions = [];
  bool _showPredictions = false;
  Timer? _debounceTimer;
  final FocusNode _addressFocusNode = FocusNode();

  // Vittoria, RG - Centro città
  // CAP 97019, Provincia di Ragusa
  static const double _vittoriaLat = 36.9528;
  static const double _vittoriaLng = 14.5297;
  // Raggio di 5km per coprire tutta Vittoria
  static const int _searchRadiusMeters = 5000;

  @override
  void initState() {
    super.initState();
    _etichettaController = TextEditingController(
      text: widget.address?.etichetta ?? '',
    );
    _noteController = TextEditingController(text: widget.address?.note ?? '');
    _isDefault = widget.address?.isDefault ?? false;

    // Pre-fill address if editing
    if (widget.address != null) {
      _addressController = TextEditingController(
        text: widget.address!.indirizzo,
      );
      _selectedAddress = widget.address!.indirizzo;
      _addressSelected = true;
    } else {
      _addressController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _etichettaController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _debounceTimer?.cancel();
    _addressFocusNode.dispose();
    super.dispose();
  }

  /// Estrae l'indirizzo pulito dalla prediction di Google Places
  /// Rimuove ", Vittoria RG, Italia" e simili suffissi
  String _extractCleanAddress(PlacePrediction prediction) {
    final description = prediction.description;

    // Rimuovi suffissi comuni italiani
    final suffixesToRemove = [
      ', Vittoria, Provincia di Ragusa, Italia',
      ', Vittoria, RG, Italia',
      ', Vittoria RG, Italia',
      ', 97019 Vittoria RG, Italia',
      ', 97019 Vittoria, Italia',
      ', Vittoria, Italia',
      ', Italia',
    ];

    String cleaned = description;
    for (final suffix in suffixesToRemove) {
      if (cleaned.toLowerCase().endsWith(suffix.toLowerCase())) {
        cleaned = cleaned.substring(0, cleaned.length - suffix.length);
        break;
      }
    }

    return cleaned.trim();
  }

  /// Cerca indirizzi usando Google Places Autocomplete API
  /// Con STRICT BOUNDS per limitare i risultati SOLO a Vittoria (RG)
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
      });
      return;
    }

    final apiKey = EnvConfig.googleMapsApiKey;
    if (apiKey.isEmpty) {
      Logger.warning(
        'Google Maps API key not configured',
        tag: 'AddressFormSheet',
      );
      return;
    }

    try {
      // Costruisci URL con parametri per STRICT restriction a Vittoria
      // Usando location + radius + strictbounds per limitare SOLO a Vittoria
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': apiKey,
          'language': 'it',
          'components': 'country:it',
          'types': 'address', // Solo indirizzi, non POI
          'location': '$_vittoriaLat,$_vittoriaLng',
          'radius': '$_searchRadiusMeters',
          'strictbounds':
              'true', // IMPORTANTE: limita SOLO all'area specificata
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        Logger.warning(
          'Places API returned ${response.statusCode}',
          tag: 'AddressFormSheet',
        );
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'OK') {
        final predictions = (data['predictions'] as List<dynamic>)
            .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _predictions = predictions;
            _showPredictions = predictions.isNotEmpty;
          });
        }
      } else if (status == 'ZERO_RESULTS') {
        if (mounted) {
          setState(() {
            _predictions = [];
            _showPredictions = false;
          });
        }
      } else {
        Logger.warning('Places API status: $status', tag: 'AddressFormSheet');
      }
    } catch (e) {
      Logger.error('Error searching places: $e', tag: 'AddressFormSheet');
    }
  }

  /// Gestisce il cambio di testo con debounce
  void _onAddressChanged(String value) {
    _debounceTimer?.cancel();

    // Reset selection se l'utente modifica il testo
    if (_addressSelected && value != _selectedAddress) {
      setState(() {
        _addressSelected = false;
        _selectedAddress = null;
      });
    }

    // Debounce di 500ms per ridurre chiamate API
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(value);
    });
  }

  /// Seleziona un indirizzo dalla lista
  void _selectPrediction(PlacePrediction prediction) {
    final cleanAddress = _extractCleanAddress(prediction);
    setState(() {
      _selectedAddress = cleanAddress;
      _addressSelected = true;
      _addressController.text = cleanAddress;
      _predictions = [];
      _showPredictions = false;
    });
    // Rimuovi focus per chiudere la tastiera
    _addressFocusNode.unfocus();
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textTertiary,
      ),
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  /// Costruisce il widget Google Places Autocomplete personalizzato
  /// Con STRICT BOUNDS per limitare i risultati SOLO a Vittoria (RG) CAP 97019
  Widget _buildAddressAutocomplete() {
    final apiKey = EnvConfig.googleMapsApiKey;

    if (apiKey.isEmpty) {
      // Fallback a campo testo normale se API key mancante
      return TextFormField(
        controller: _addressController,
        style: AppTypography.bodyMedium,
        decoration: _inputDecoration('es. Via Roma 123'),
        validator: (v) =>
            (v?.trim().isEmpty ?? true) ? 'Inserisci l\'indirizzo' : null,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        onChanged: (value) {
          setState(() {
            _selectedAddress = value.trim();
            _addressSelected = value.trim().isNotEmpty;
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo di input
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          style: AppTypography.bodyMedium,
          decoration: _inputDecoration('Cerca via a Vittoria...').copyWith(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.md),
              child: Icon(
                Icons.search,
                color: AppColors.textTertiary,
                size: AppIcons.sizeMD,
              ),
            ),
            suffixIcon: _addressController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _addressController.clear();
                        _selectedAddress = null;
                        _addressSelected = false;
                        _predictions = [];
                        _showPredictions = false;
                      });
                    },
                    child: const Icon(
                      Icons.clear,
                      color: AppColors.textTertiary,
                      size: AppIcons.sizeMD,
                    ),
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onChanged: _onAddressChanged,
        ),
        // Lista predizioni
        if (_showPredictions && _predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusMD,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return InkWell(
                  onTap: () => _selectPrediction(prediction),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: index < _predictions.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: AppRadius.radiusSM,
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: AppIcons.sizeSM,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.mainText ?? prediction.description,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (prediction.secondaryText != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  prediction.secondaryText!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
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
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seleziona una città',
            style: AppTypography.bodySmall.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
        ),
      );
      return;
    }

    // Usa l'indirizzo selezionato dall'autocomplete o il testo inserito manualmente
    final address = _selectedAddress ?? _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inserisci un indirizzo valido',
            style: AppTypography.bodySmall.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.address == null) {
        await ref
            .read(userAddressesProvider.notifier)
            .createAddress(
              allowedCityId: _selectedCity!.id,
              etichetta: _etichettaController.text.trim().isEmpty
                  ? null
                  : _etichettaController.text.trim(),
              indirizzo: address,
              citta: _selectedCity!.nome,
              cap: _selectedCity!.cap,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              isDefault: _isDefault,
            );
      } else {
        await ref
            .read(userAddressesProvider.notifier)
            .updateAddress(widget.address!.id, {
              'allowed_city_id': _selectedCity!.id,
              'etichetta': _etichettaController.text.trim().isEmpty
                  ? null
                  : _etichettaController.text.trim(),
              'indirizzo': address,
              'citta': _selectedCity!.nome,
              'cap': _selectedCity!.cap,
              'note': _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              'is_default': _isDefault,
            });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.address == null
                  ? 'Indirizzo aggiunto'
                  : 'Indirizzo aggiornato',
              style: AppTypography.bodySmall.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore: $e',
              style: AppTypography.bodySmall.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(allowedCitiesProvider);
    final isEditing = widget.address != null;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xxl),
          topRight: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Modifica Indirizzo' : 'Nuovo Indirizzo',
                    style: AppTypography.titleLarge,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: AppRadius.radiusSM,
                    ),
                    child: const Icon(
                      AppIcons.close,
                      color: AppColors.textSecondary,
                      size: AppIcons.sizeMD,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: AppSpacing.lg,
                bottom:
                    bottomPadding +
                    (AppSpacing.lg * 1.1), // 10% more bottom padding
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selezione città
                    Text('Città *', style: AppTypography.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    citiesAsync.when(
                      data: (cities) {
                        if (cities.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: AppRadius.radiusMD,
                              border: Border.all(color: AppColors.warning),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'Nessuna città disponibile. Contatta il gestore.',
                                    style: AppTypography.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (cities.length == 1 && _selectedCity == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _selectedCity = cities.first);
                            }
                          });
                        }

                        return DropdownButtonFormField<AllowedCityModel>(
                          key: ValueKey(_selectedCity),
                          initialValue: _selectedCity,
                          decoration: _inputDecoration('Seleziona città'),
                          dropdownColor: AppColors.surface,
                          style: AppTypography.bodyMedium,
                          items: cities.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text('${city.nome} (${city.cap})'),
                            );
                          }).toList(),
                          onChanged: (city) =>
                              setState(() => _selectedCity = city),
                          validator: (v) =>
                              v == null ? 'Seleziona una città' : null,
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (e, _) => Text(
                        'Errore: $e',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Indirizzo con Google Places Autocomplete
                    Text('Indirizzo *', style: AppTypography.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    _buildAddressAutocomplete(),
                    const SizedBox(height: AppSpacing.xl),
                    // Etichetta
                    Text('Etichetta', style: AppTypography.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _etichettaController,
                      style: AppTypography.bodyMedium,
                      decoration: _inputDecoration('es. Casa, Lavoro, Ufficio'),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Note
                    Text('Note di consegna', style: AppTypography.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _noteController,
                      style: AppTypography.bodyMedium,
                      decoration: _inputDecoration(
                        'es. Citofono rotto, suonare al piano',
                      ),
                      textInputAction: TextInputAction.done,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Checkbox predefinito
                    GestureDetector(
                      onTap: () => setState(() => _isDefault = !_isDefault),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: _isDefault
                              ? AppColors.primarySubtle
                              : AppColors.surfaceLight,
                          borderRadius: AppRadius.radiusMD,
                          border: Border.all(
                            color: _isDefault
                                ? AppColors.primary
                                : Colors.transparent,
                            width: _isDefault ? 2 : 0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _isDefault
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: AppRadius.radiusSM,
                                border: Border.all(
                                  color: _isDefault
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: _isDefault
                                  ? const Icon(
                                      AppIcons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Imposta come indirizzo predefinito',
                              style: AppTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Pulsante salva
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleSave,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color: _isLoading
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : AppColors.primary,
                            borderRadius: AppRadius.radiusXL,
                            boxShadow: _isLoading
                                ? null
                                : AppShadows.primaryShadow(),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Salva Indirizzo',
                                    style: AppTypography.buttonMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
