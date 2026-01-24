import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../providers/addresses_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/models/user_address_model.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../widgets/address_form_sheet.dart';

class CheckoutTimeSelectionScreen extends ConsumerStatefulWidget {
  final OrderType orderType;
  const CheckoutTimeSelectionScreen({super.key, required this.orderType});

  @override
  ConsumerState<CheckoutTimeSelectionScreen> createState() => _CheckoutTimeSelectionScreenState();
}

class _CheckoutTimeSelectionScreenState extends ConsumerState<CheckoutTimeSelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSlot;
  UserAddressModel? _selectedAddress;
  List<DateTime> _availableSlots = [];
  bool _isComputingSlots = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    setState(() => _isInitialLoading = true);
    try {
      await ref.read(pizzeriaSettingsProvider.future);
      if (widget.orderType == OrderType.delivery) {
        final addresses = await ref.read(userAddressesProvider.future);
        if (addresses.isNotEmpty && mounted) {
          setState(() => _selectedAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first));
        }
      }
      await _computeAvailableSlots();
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _computeAvailableSlots([DateTime? forDate]) async {
    setState(() => _isComputingSlots = true);
    final targetDate = forDate ?? _selectedDate;
    final settings = ref.read(pizzeriaSettingsProvider).value;
    
    if (settings == null) {
      setState(() { _availableSlots = []; _selectedSlot = null; _isComputingSlots = false; });
      return;
    }

    final businessRules = settings.businessRules;
    if (businessRules.chiusuraTemporanea) {
      final dataChiusuraDa = businessRules.dataChiusuraDa;
      final dataChiusuraA = businessRules.dataChiusuraA;
      if (dataChiusuraDa != null && dataChiusuraA != null) {
        final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
        final closureStart = DateTime(dataChiusuraDa.year, dataChiusuraDa.month, dataChiusuraDa.day);
        final closureEnd = DateTime(dataChiusuraA.year, dataChiusuraA.month, dataChiusuraA.day);
        if (!targetDateOnly.isBefore(closureStart) && !targetDateOnly.isAfter(closureEnd)) {
          setState(() { _availableSlots = []; _selectedSlot = null; _isComputingSlots = false; });
          return;
        }
      }
    }

    final slotMinutes = settings.orderManagement.tempoSlotMinuti;
    final prepMinutes = settings.orderManagement.tempoPreparazioneMedio;
    final now = DateTime.now();
    final effectiveSlotMinutes = slotMinutes > 0 ? slotMinutes : 30;

    final orari = settings.pizzeria.orari ?? {};
    final weekdayIndex = (targetDate.weekday % 7);
    const keys = ['domenica', 'lunedi', 'martedi', 'mercoledi', 'giovedi', 'venerdi', 'sabato'];
    final dayKey = keys[weekdayIndex];
    final day = (orari[dayKey] as Map?) ?? {};
    final isOpen = (day['aperto'] as bool?) ?? false;
    
    if (!isOpen) {
      setState(() { _availableSlots = []; _selectedSlot = null; _isComputingSlots = false; });
      return;
    }

    DateTime? parseTime(String? hhmm, DateTime date) {
      if (hhmm == null) return null;
      final parts = hhmm.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    final apertura = parseTime(day['apertura'] as String?, targetDate) ?? DateTime(targetDate.year, targetDate.month, targetDate.day, 12, 0);
    final chiusura = parseTime(day['chiusura'] as String?, targetDate) ?? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 0);

    if (!chiusura.isAfter(apertura)) {
      setState(() { _availableSlots = []; _selectedSlot = null; _isComputingSlots = false; });
      return;
    }

    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
    final earliest = isToday ? now.add(Duration(minutes: prepMinutes)) : apertura;
    final start = earliest.isAfter(apertura) ? earliest : apertura;
    final roundedStart = DateTime(start.year, start.month, start.day, start.hour, start.minute - (start.minute % effectiveSlotMinutes))
        .add(Duration(minutes: (start.minute % effectiveSlotMinutes) == 0 ? 0 : effectiveSlotMinutes));

    final allSlots = <DateTime>[];
    var cursor = roundedStart;
    while (cursor.isBefore(chiusura)) {
      allSlots.add(cursor);
      cursor = cursor.add(Duration(minutes: effectiveSlotMinutes));
    }

    try {
      final db = ref.read(databaseServiceProvider);
      final cart = ref.read(cartProvider);
      final currentCartItems = cart.fold<int>(0, (sum, item) => sum + item.quantity);
      final raw = await db.getOrderManagementSettingsRaw();
      final capDelivery = (raw?['capacity_delivery_per_slot'] as int?) ?? 50;
      final capTakeaway = (raw?['capacity_takeaway_per_slot'] as int?) ?? 50;
      final capacity = widget.orderType == OrderType.delivery ? capDelivery : capTakeaway;

      final availableSlots = <DateTime>[];
      if (allSlots.isEmpty) {
        if (mounted) setState(() { _availableSlots = availableSlots; _selectedSlot = null; _isComputingSlots = false; });
        return;
      }

      final rangeStartUtc = allSlots.first.toUtc();
      final rangeEndUtc = allSlots.last.add(Duration(minutes: effectiveSlotMinutes)).toUtc();
      final slotCounts = await db.getItemCountsBySlotRange(rangeStartUtc: rangeStartUtc, rangeEndUtc: rangeEndUtc, type: widget.orderType);

      for (final slot in allSlots) {
        final slotKey = slot.toUtc();
        final currentItemsCount = slotCounts[slotKey] ?? 0;
        final totalItemsAfterOrder = currentItemsCount + currentCartItems;
        if (totalItemsAfterOrder <= capacity) availableSlots.add(slot);
      }

      if (mounted) setState(() { _availableSlots = availableSlots; _selectedSlot = null; _isComputingSlots = false; });
    } catch (e) {
      if (mounted) setState(() { _availableSlots = allSlots; _selectedSlot = null; _isComputingSlots = false; });
    }
  }

  void _proceedToCheckout() {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un orario'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (widget.orderType == OrderType.delivery && _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un indirizzo di consegna'), backgroundColor: AppColors.error),
      );
      return;
    }
    context.push('/checkout-new', extra: {
      'orderType': widget.orderType,
      'selectedSlot': _selectedSlot,
      'selectedAddress': _selectedAddress,
      'selectedDate': _selectedDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final topPadding = isMobile ? kToolbarHeight + MediaQuery.of(context).padding.top + AppSpacing.sm : 0.0;

    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          children: [
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.lg), child: _buildContent())),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }


  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.orderType == OrderType.delivery) ...[_buildAddressSection(), const SizedBox(height: AppSpacing.xxl)],
        _buildDateSection(),
        const SizedBox(height: AppSpacing.xxl),
        _buildTimeSection(),
      ],
    );
  }

  Widget _buildAddressSection() {
    return GestureDetector(
      onTap: _showAddressSelectionSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppShadows.xs,
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Indirizzo di Consegna',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress?.etichetta ?? 'Seleziona indirizzo',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedAddress?.fullAddress ?? 'Tocca per selezionare',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.xs,
              ),
              child: Icon(Icons.edit_rounded, color: AppColors.primary, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    final now = DateTime.now();
    final settings = ref.read(pizzeriaSettingsProvider).value;
    final orari = settings?.pizzeria.orari ?? {};
    final availableDates = <DateTime>[];
    var currentDate = DateTime(now.year, now.month, now.day);

    while (availableDates.length < 7) {
      final weekdayIndex = (currentDate.weekday % 7);
      const keys = ['domenica', 'lunedi', 'martedi', 'mercoledi', 'giovedi', 'venerdi', 'sabato'];
      final dayKey = keys[weekdayIndex];
      final day = (orari[dayKey] as Map?) ?? {};
      final isOpen = (day['aperto'] as bool?) ?? false;
      if (isOpen) availableDates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    const dayNames = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: AppRadius.radiusMD),
              child: Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              widget.orderType == OrderType.delivery ? 'Data Consegna' : 'Data Ritiro',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.titleMedium.fontSize! * 0.8, // 20% smaller
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableDates.length,
            itemBuilder: (context, index) {
              final date = availableDates[index];
              final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              final dayName = dayNames[date.weekday % 7];

              return Padding(
                padding: EdgeInsets.only(right: index < availableDates.length - 1 ? AppSpacing.sm : 0),
                child: GestureDetector(
                  onTap: _isComputingSlots ? null : () async {
                    setState(() => _selectedDate = date);
                    await _computeAvailableSlots(date);
                  },
                  child: AnimatedContainer(
                    duration: AppAnimations.fast,
                    width: 72,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.borderLight,
                        width: 2,
                      ),
                      boxShadow: isSelected ? AppShadows.primaryShadow(alpha: 0.3) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 20,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Oggi',
                              style: AppTypography.captionSmall.copyWith(
                                color: isSelected ? Colors.white : AppColors.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.primarySubtle, borderRadius: AppRadius.radiusMD),
              child: Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Orario Consegna',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.titleMedium.fontSize! * 0.8, // 20% smaller
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_isComputingSlots)
          const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: CircularProgressIndicator(color: AppColors.primary)))
        else if (_availableSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: AppRadius.radiusXL, border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
            child: Row(
              children: [
                Icon(Icons.event_busy_rounded, color: AppColors.warning, size: 32),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: Text('Nessun orario disponibile per questa data', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))),
              ],
            ),
          )
        else
          Column(
            children: _availableSlots.map((slot) {
              final isSelected = _selectedSlot == slot;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlot = slot),
                child: AnimatedContainer(
                  duration: AppAnimations.fast,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySubtle : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.time(slot),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final canProceed = _selectedSlot != null && (widget.orderType != OrderType.delivery || _selectedAddress != null);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: canProceed ? _proceedToCheckout : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Procedi al Pagamento', style: AppTypography.buttonLarge.copyWith(color: canProceed ? Colors.white : AppColors.textDisabled, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: canProceed ? Colors.white : AppColors.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddressSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xxl), topRight: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.paddingXL,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.lg), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                Text('Seleziona Indirizzo', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xxl),
                Flexible(child: Consumer(builder: (context, ref, child) {
                  final addressesAsync = ref.watch(userAddressesProvider);
                  return addressesAsync.when(
                    data: (addresses) {
                      if (addresses.isEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: Text('Nessun indirizzo salvato')),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () { Navigator.pop(context); _showAddAddressSheet(); },
                                icon: const Icon(Icons.add),
                                label: const Text('Aggiungi Indirizzo'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL)),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: addresses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == addresses.length) {
                            return ListTile(leading: Icon(Icons.add, color: AppColors.primary), title: const Text('Aggiungi Indirizzo'), onTap: () { Navigator.pop(context); _showAddAddressSheet(); });
                          }
                          final address = addresses[index];
                          final isSelected = _selectedAddress?.id == address.id;
                          return ListTile(
                            leading: Icon(Icons.location_on_rounded, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                            title: Text(address.etichetta ?? 'Indirizzo', style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                            subtitle: Text(address.fullAddress),
                            trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primary) : null,
                            onTap: () { setState(() => _selectedAddress = address); Navigator.pop(context); },
                          );
                        },
                      );
                    },
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: CircularProgressIndicator()),
                    error: (e, _) => Text('Errore: $e', style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
                  );
                })),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: Colors.transparent, barrierColor: Colors.black54, useSafeArea: false, builder: (context) => const AddressFormSheet());
  }
}
