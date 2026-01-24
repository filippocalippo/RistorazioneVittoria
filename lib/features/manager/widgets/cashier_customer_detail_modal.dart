import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/cashier_customer_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/google_geocoding_service.dart';
import '../../../providers/cashier_customer_provider.dart';

class CashierCustomerDetailModal extends ConsumerStatefulWidget {
  final CashierCustomerModel customer;
  final VoidCallback onCustomerUpdated;

  const CashierCustomerDetailModal({
    super.key,
    required this.customer,
    required this.onCustomerUpdated,
  });

  @override
  ConsumerState<CashierCustomerDetailModal> createState() =>
      _CashierCustomerDetailModalState();
}

class _CashierCustomerDetailModalState
    extends ConsumerState<CashierCustomerDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nomeController;
  late TextEditingController _telefonoController;
  late TextEditingController _indirizzoController;
  late TextEditingController _cittaController;
  late TextEditingController _capController;
  late TextEditingController _provinciaController;
  late TextEditingController _noteController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _addressChanged = false;
  String? _originalIndirizzo;
  String? _originalCitta;
  String? _originalCap;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initControllers();
  }

  void _initControllers() {
    _nomeController = TextEditingController(text: widget.customer.nome);
    _telefonoController = TextEditingController(
      text: widget.customer.telefono ?? '',
    );
    _indirizzoController = TextEditingController(
      text: widget.customer.indirizzo ?? '',
    );
    _cittaController = TextEditingController(text: widget.customer.citta ?? '');
    _capController = TextEditingController(text: widget.customer.cap ?? '');
    _provinciaController = TextEditingController(
      text: widget.customer.provincia ?? '',
    );
    _noteController = TextEditingController(text: widget.customer.note ?? '');

    _originalIndirizzo = widget.customer.indirizzo;
    _originalCitta = widget.customer.citta;
    _originalCap = widget.customer.cap;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _telefonoController.dispose();
    _indirizzoController.dispose();
    _cittaController.dispose();
    _capController.dispose();
    _provinciaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _checkAddressChanged() {
    final newIndirizzo = _indirizzoController.text.trim();
    final newCitta = _cittaController.text.trim();
    final newCap = _capController.text.trim();

    _addressChanged =
        newIndirizzo != (_originalIndirizzo ?? '') ||
        newCitta != (_originalCitta ?? '') ||
        newCap != (_originalCap ?? '');
  }

  Future<void> _saveChanges() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il nome è obbligatorio'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      _checkAddressChanged();

      double? latitude;
      double? longitude;
      bool updateGeocodedAt = false;

      // If address changed, geocode the new address
      if (_addressChanged && _indirizzoController.text.trim().isNotEmpty) {
        final coords = await GoogleGeocodingService.geocodeAddress(
          indirizzo: _indirizzoController.text.trim(),
          citta: _cittaController.text.trim().isNotEmpty
              ? _cittaController.text.trim()
              : 'Vittoria',
          cap: _capController.text.trim().isNotEmpty
              ? _capController.text.trim()
              : null,
          provincia: _provinciaController.text.trim().isNotEmpty
              ? _provinciaController.text.trim()
              : 'RG',
        );

        if (coords != null) {
          latitude = coords.latitude;
          longitude = coords.longitude;
          updateGeocodedAt = true;
        }
      }

      await ref
          .read(cashierCustomersNotifierProvider.notifier)
          .updateCustomer(
            customerId: widget.customer.id,
            nome: _nomeController.text.trim(),
            telefono: _telefonoController.text.trim().isNotEmpty
                ? _telefonoController.text.trim()
                : null,
            indirizzo: _indirizzoController.text.trim().isNotEmpty
                ? _indirizzoController.text.trim()
                : null,
            citta: _cittaController.text.trim().isNotEmpty
                ? _cittaController.text.trim()
                : null,
            cap: _capController.text.trim().isNotEmpty
                ? _capController.text.trim()
                : null,
            provincia: _provinciaController.text.trim().isNotEmpty
                ? _provinciaController.text.trim()
                : null,
            latitude: latitude,
            longitude: longitude,
            updateGeocodedAt: updateGeocodedAt,
            note: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : null,
          );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        widget.onCustomerUpdated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _addressChanged && latitude != null
                  ? 'Cliente aggiornato con nuove coordinate'
                  : 'Cliente aggiornato con successo',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _initControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final dialogWidth = isDesktop
        ? 700.0
        : MediaQuery.of(context).size.width * 0.95;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
      child: Container(
        width: dialogWidth,
        height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.lg),
            _buildTabBar(),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildDetailsTab(), _buildOrdersTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _getAvatarColor(widget.customer.ordiniCount),
          child: Text(
            _getInitials(widget.customer),
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: AppTypography.semiBold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.customer.nome,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _buildStatBadge(
                    '${widget.customer.ordiniCount} ordini',
                    Icons.receipt_long_rounded,
                    AppColors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatBadge(
                    '€${widget.customer.totaleSpeso.toStringAsFixed(2)}',
                    Icons.euro_rounded,
                    AppColors.success,
                  ),
                  if (widget.customer.hasGeocodedAddress) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatBadge(
                      'Geocodificato',
                      Icons.location_on_rounded,
                      AppColors.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(backgroundColor: AppColors.surfaceLight),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMD,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: AppTypography.semiBold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.radiusLG,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: AppTypography.semiBold,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Dettagli'),
          Tab(text: 'Storico Ordini'),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edit/Save buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isEditing) ...[
                TextButton.icon(
                  onPressed: _isSaving ? null : _cancelEditing,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Annulla'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Salvataggio...' : 'Salva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifica'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Form fields
          _buildSectionTitle('Informazioni Personali'),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _nomeController,
            label: 'Nome',
            icon: Icons.person_rounded,
            enabled: _isEditing,
            required: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _telefonoController,
            label: 'Telefono',
            icon: Icons.phone_rounded,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle('Indirizzo'),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _indirizzoController,
            label: 'Indirizzo',
            icon: Icons.location_on_rounded,
            enabled: _isEditing,
            hint: 'Via/Piazza e numero civico',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _cittaController,
                  label: 'Città',
                  icon: Icons.location_city_rounded,
                  enabled: _isEditing,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildTextField(
                  controller: _capController,
                  label: 'CAP',
                  icon: Icons.pin_drop_rounded,
                  enabled: _isEditing,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildTextField(
                  controller: _provinciaController,
                  label: 'Provincia',
                  icon: Icons.map_rounded,
                  enabled: _isEditing,
                ),
              ),
            ],
          ),

          if (_isEditing && _indirizzoController.text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMD,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Se modifichi l\'indirizzo, verrà eseguita una nuova geocodifica al salvataggio.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Geocoding info
          if (widget.customer.hasGeocodedAddress) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMD,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coordinate: ${widget.customer.latitude!.toStringAsFixed(6)}, ${widget.customer.longitude!.toStringAsFixed(6)}',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: AppTypography.semiBold,
                          ),
                        ),
                        if (widget.customer.geocodedAt != null)
                          Text(
                            'Geocodificato il ${DateFormat('dd/MM/yyyy HH:mm').format(widget.customer.geocodedAt!)}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle('Note'),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _noteController,
            label: 'Note',
            icon: Icons.notes_rounded,
            enabled: _isEditing,
            maxLines: 3,
            hint: 'Note aggiuntive sul cliente...',
          ),

          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle('Statistiche'),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(
            'Cliente dal',
            DateFormat('dd/MM/yyyy').format(widget.customer.createdAt),
          ),
          _buildInfoRow(
            'Ultimo ordine',
            widget.customer.ultimoOrdineAt != null
                ? DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(widget.customer.ultimoOrdineAt!)
                : 'Nessun ordine',
          ),
          _buildInfoRow('Totale ordini', '${widget.customer.ordiniCount}'),
          _buildInfoRow(
            'Totale speso',
            '€${widget.customer.totaleSpeso.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.titleSmall.copyWith(
        fontWeight: AppTypography.semiBold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusLG,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLG,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLG,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLG,
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    final ordersAsync = ref.watch(
      cashierCustomerOrdersProvider(widget.customer.id),
    );

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Nessun ordine trovato',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = orders[index] as OrderModel;
            return _buildOrderCard(order);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Errore nel caricamento degli ordini',
              style: AppTypography.titleMedium.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // Order number and status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.displayNumeroOrdine}',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusBadge(order.stato),
              ],
            ),
          ),
          // Order type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipo',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(order.tipo.displayName, style: AppTypography.bodyMedium),
              ],
            ),
          ),
          // Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Totale',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '€${order.totale.toStringAsFixed(2)}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Builder(
              builder: (context) {
                final orderDate = (order.slotPrenotatoStart ?? order.createdAt)
                    .toLocal();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(orderDate),
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormat('HH:mm').format(orderDate),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(dynamic status) {
    Color color;
    String text;

    // Handle OrderStatus enum
    switch (status.toString().split('.').last) {
      case 'pending':
        color = AppColors.warning;
        text = 'In attesa';
        break;
      case 'confirmed':
        color = AppColors.info;
        text = 'Confermato';
        break;
      case 'preparing':
        color = AppColors.warning;
        text = 'In preparazione';
        break;
      case 'ready':
        color = AppColors.success;
        text = 'Pronto';
        break;
      case 'delivering':
        color = AppColors.info;
        text = 'In consegna';
        break;
      case 'completed':
        color = AppColors.success;
        text = 'Completato';
        break;
      case 'cancelled':
        color = AppColors.error;
        text = 'Annullato';
        break;
      default:
        color = AppColors.textSecondary;
        text = status.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusSM,
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: AppTypography.semiBold,
        ),
      ),
    );
  }

  Color _getAvatarColor(int ordiniCount) {
    if (ordiniCount >= 10) {
      return AppColors.success;
    } else if (ordiniCount >= 5) {
      return AppColors.info;
    } else if (ordiniCount > 0) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }

  String _getInitials(CashierCustomerModel customer) {
    final parts = customer.nome.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (customer.nome.isNotEmpty) {
      return customer.nome.substring(0, 1).toUpperCase();
    }
    return '?';
  }
}
