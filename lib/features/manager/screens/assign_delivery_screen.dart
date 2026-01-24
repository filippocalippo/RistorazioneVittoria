import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../delivery/widgets/delivery_map_widget.dart';
import '../widgets/modern_order_card.dart';
import 'zone_management_shell.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/google_geocoding_service.dart';
import '../../../providers/assign_delivery_provider.dart';
import '../../../providers/delivery_zones_provider.dart';
import '../../../core/models/delivery_zone_model.dart';
import '../../../core/utils/geometry_utils.dart';
import '../widgets/radial_zone_editor.dart';
import '../widgets/delivery_heatmap_widget.dart';

/// Assign delivery screen for managers
class AssignDeliveryScreen extends ConsumerStatefulWidget {
  const AssignDeliveryScreen({super.key});

  @override
  ConsumerState<AssignDeliveryScreen> createState() =>
      _AssignDeliveryScreenState();
}

class _GeocodeResult {
  final String orderId;
  final LatLng? location;

  const _GeocodeResult(this.orderId, this.location);
}

/// Filter options for order list
enum OrderFilter { all, pending, assigned, completed }

class _AssignDeliveryScreenState extends ConsumerState<AssignDeliveryScreen> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();
  final Map<String, LatLng> _orderLocations = {};
  final Map<String, String> _orderAddressSignatures = {};
  final Map<String, GlobalKey> _orderCardKeys = {};

  String? _selectedOrderId;
  String? _assigningOrderId;
  bool _isGeocodingOrders = false;
  bool _initialGeocodeDone = false;

  List<OrderModel>? _queuedGeocodeOrders;
  List<UserModel> _deliveryDrivers = [];
  Map<String, UserModel> _driverMap = {};

  LatLng? _pizzeriaCenter;

  // UI State
  String _currentTab = 'orders'; // 'orders', 'zones', or 'heatmap'
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  OrderFilter _activeFilter = OrderFilter.all;

  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([_loadPizzeriaLocation(), _loadDeliveryDrivers()]);
  }

  Future<void> _loadPizzeriaLocation() async {
    try {
      final settings = await ref.read(pizzeriaSettingsProvider.future);
      if (settings == null || !mounted) return;

      final pizzeria = settings.pizzeria;

      if (pizzeria.latitude != null && pizzeria.longitude != null) {
        setState(() {
          _pizzeriaCenter = LatLng(pizzeria.latitude!, pizzeria.longitude!);
        });
      } else if (pizzeria.citta != null) {
        final coords = await GoogleGeocodingService.geocodeCity(
          citta: pizzeria.citta!,
          provincia: pizzeria.provincia,
        );
        if (mounted && coords != null) {
          setState(() => _pizzeriaCenter = coords);
        }
      }
    } catch (e) {
      Logger.warning(
        'Failed to load pizzeria location: $e',
        tag: 'AssignDelivery',
      );
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveryDrivers() async {
    if (!mounted) return;

    try {
      final user = ref.read(authProvider).value;
      if (user == null) return;

      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('ruolo', 'delivery')
          .eq('attivo', true)
          .order('nome');

      if (!mounted) return;

      final drivers = (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();

      final driverMap = <String, UserModel>{};
      for (final driver in drivers) {
        driverMap[driver.id] = driver;
      }

      if (mounted) {
        setState(() {
          _deliveryDrivers = drivers;
          _driverMap = driverMap;
        });
      }
    } catch (e) {
      Logger.error(
        'Failed to load delivery drivers: $e',
        tag: 'AssignDelivery',
        error: e,
      );
    }
  }

  void _handleOrdersUpdate(List<OrderModel> orders, {bool isInitial = false}) {
    if (_currentTab != 'orders') return;

    // Initialize card keys for scrolling
    for (final order in orders) {
      _orderCardKeys.putIfAbsent(order.id, () => GlobalKey());
    }

    final pendingGeocode = _prepareOrderLocations(orders);

    if (pendingGeocode.isNotEmpty) {
      if (isInitial && !_initialGeocodeDone) {
        // On initial load, start geocoding immediately without debounce
        _initialGeocodeDone = true;
        _startGeocode(pendingGeocode);
      } else {
        _enqueueGeocode(pendingGeocode);
      }
    }
  }

  List<OrderModel> _prepareOrderLocations(List<OrderModel> orders) {
    final needsGeocode = <OrderModel>[];

    for (final order in orders) {
      final signature = _locationSignature(order);
      final previousSignature = _orderAddressSignatures[order.id];
      if (previousSignature != signature) {
        _orderAddressSignatures[order.id] = signature;
        _orderLocations.remove(order.id);
      }

      if (order.tipo != OrderType.delivery) {
        continue;
      }

      if (order.latitudeConsegna != null && order.longitudeConsegna != null) {
        _orderLocations[order.id] = LatLng(
          order.latitudeConsegna!,
          order.longitudeConsegna!,
        );
        continue;
      }

      if (_orderLocations.containsKey(order.id)) {
        continue;
      }

      if ((order.indirizzoConsegna?.isNotEmpty ?? false) ||
          (order.cittaConsegna?.isNotEmpty ?? false)) {
        needsGeocode.add(order);
      }
    }

    return needsGeocode;
  }

  String _locationSignature(OrderModel order) {
    return [
      order.indirizzoConsegna?.trim() ?? '',
      order.cittaConsegna?.trim() ?? '',
      order.capConsegna?.trim() ?? '',
      order.updatedAt?.millisecondsSinceEpoch ??
          order.createdAt.millisecondsSinceEpoch,
    ].join('|');
  }

  void _enqueueGeocode(List<OrderModel> orders) {
    if (orders.isEmpty) return;

    _geocodeDebounce?.cancel();

    final combined = <String, OrderModel>{
      for (final existing in _queuedGeocodeOrders ?? const <OrderModel>[])
        existing.id: existing,
      for (final incoming in orders) incoming.id: incoming,
    };
    _queuedGeocodeOrders = combined.values.toList();

    _geocodeDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_queuedGeocodeOrders != null && _queuedGeocodeOrders!.isNotEmpty) {
        final queued = _queuedGeocodeOrders!;
        _queuedGeocodeOrders = null;
        _startGeocode(queued);
      }
    });
  }

  Future<void> _startGeocode(List<OrderModel> orders) async {
    if (_isGeocodingOrders || !mounted) return;

    _isGeocodingOrders = true;
    if (mounted) setState(() {});

    final newLocations = <String, LatLng>{};
    const batchSize = 8;
    for (var i = 0; i < orders.length; i += batchSize) {
      final batch = orders.sublist(i, math.min(i + batchSize, orders.length));
      final results = await Future.wait(batch.map(_geocodeOrder));

      for (final result in results) {
        if (result.location == null) continue;

        final existing = _orderLocations[result.orderId];
        if (existing != null && _sameLocation(existing, result.location!)) {
          continue;
        }

        newLocations[result.orderId] = result.location!;
      }

      if (!mounted) {
        _isGeocodingOrders = false;
        return;
      }
    }

    if (newLocations.isNotEmpty && mounted) {
      setState(() {
        _orderLocations.addAll(newLocations);
      });
    }

    _isGeocodingOrders = false;
  }

  Future<_GeocodeResult> _geocodeOrder(OrderModel order) async {
    if (order.tipo != OrderType.delivery) {
      return _GeocodeResult(order.id, null);
    }

    if ((order.indirizzoConsegna?.isEmpty ?? true) &&
        (order.cittaConsegna?.isEmpty ?? true)) {
      return _GeocodeResult(order.id, null);
    }

    try {
      final coords = await GoogleGeocodingService.geocodeAddress(
        indirizzo: order.indirizzoConsegna,
        citta: order.cittaConsegna,
        cap: order.capConsegna,
        provincia: null,
        proximity: _pizzeriaCenter,
      );
      return _GeocodeResult(order.id, coords);
    } catch (e) {
      Logger.warning(
        'Failed to geocode order ${order.numeroOrdine}: $e',
        tag: 'AssignDelivery',
      );
      return _GeocodeResult(order.id, null);
    }
  }

  bool _sameLocation(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-6 &&
        (a.longitude - b.longitude).abs() < 1e-6;
  }

  void _scrollToOrder(String orderId, List<OrderModel> orders) {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    // Estimate card height (approximately 200 pixels per card + spacing)
    const cardHeight = 220.0;
    final targetOffset = index * cardHeight;

    // Clamp to valid scroll extent
    final maxScroll = _listScrollController.position.maxScrollExtent;
    final scrollTo = targetOffset.clamp(0.0, maxScroll);

    _listScrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _assignOrder(OrderModel order) async {
    if (_deliveryDrivers.isEmpty) {
      _showNoDriversDialog();
      return;
    }

    final driver = await _showDriverSelector();
    if (driver == null) return;

    setState(() => _assigningOrderId = order.id);

    try {
      await SupabaseConfig.client
          .from('ordini')
          .update({'assegnato_delivery_id': driver.id})
          .eq('id', order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ordine #${order.numeroOrdine} assegnato a ${driver.nome} ${driver.cognome}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to assign order: $e',
        tag: 'AssignDelivery',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l\'assegnazione'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _assigningOrderId = null);
      }
    }
  }

  Future<void> _unassignOrder(OrderModel order) async {
    setState(() => _assigningOrderId = order.id);

    try {
      await SupabaseConfig.client
          .from('ordini')
          .update({'assegnato_delivery_id': null})
          .eq('id', order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver rimosso dall\'ordine #${order.numeroOrdine}'),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to unassign order: $e',
        tag: 'AssignDelivery',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante la rimozione'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _assigningOrderId = null);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<UserModel?> _showDriverSelector() async {
    return showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seleziona Driver',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_deliveryDrivers.length} driver disponibili',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _deliveryDrivers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final driver = _deliveryDrivers[index];
                  return _buildDriverCard(
                    driver,
                    context,
                    key: ValueKey(driver.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(UserModel driver, BuildContext context, {Key? key}) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(driver),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${driver.nome?[0] ?? ''}${driver.cognome?[0] ?? ''}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${driver.nome} ${driver.cognome}',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (driver.telefono != null)
                      Text(
                        driver.telefono!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoDriversDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            const Text('Nessun Driver'),
          ],
        ),
        content: const Text(
          'Non ci sono driver attivi disponibili.\nAggiungi dei driver dalla sezione Utenti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scansiona per Assegnare',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              QrImageView(
                data: order.id,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    switch (_activeFilter) {
      case OrderFilter.pending:
        return orders
            .where(
              (o) =>
                  o.assegnatoDeliveryId == null &&
                  o.stato != OrderStatus.completed &&
                  o.stato != OrderStatus.cancelled,
            )
            .toList();
      case OrderFilter.assigned:
        return orders
            .where(
              (o) =>
                  o.assegnatoDeliveryId != null &&
                  o.stato != OrderStatus.completed &&
                  o.stato != OrderStatus.cancelled,
            )
            .toList();
      case OrderFilter.completed:
        return orders.where((o) => o.stato == OrderStatus.completed).toList();
      case OrderFilter.all:
        return orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Orders for Selected Date
    final ordersAsync = ref.watch(
      deliveryManagementOrdersProvider(_selectedDate),
    );
    final zonesAsync = ref.watch(deliveryZonesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header & Navigation
          _buildHeader(),

          // Main Content
          Expanded(
            child: _currentTab == 'zones'
                ? ZoneManagementShell(pizzeriaCenter: _pizzeriaCenter)
                : _currentTab == 'heatmap'
                ? DeliveryHeatmapWidget(pizzeriaCenter: _pizzeriaCenter)
                : ordersAsync.when(
                    data: (orders) {
                      // Filter by search query
                      var filteredOrders = orders.where((o) {
                        if (_searchQuery.isEmpty) return true;
                        final q = _searchQuery.toLowerCase();
                        final nameMatch = o.nomeCliente.toLowerCase().contains(
                          q,
                        );
                        final numberMatch = o.numeroOrdine.toString().contains(
                          q,
                        );
                        final addressMatch =
                            o.indirizzoConsegna?.toLowerCase().contains(q) ??
                            false;
                        return nameMatch || numberMatch || addressMatch;
                      }).toList();

                      // Trigger geocoding for new orders - immediate on initial load
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _handleOrdersUpdate(
                          filteredOrders,
                          isInitial: !_initialGeocodeDone,
                        );
                      });

                      // Apply filter
                      final displayOrders = _applyFilter(filteredOrders);

                      final zones = zonesAsync.maybeWhen(
                        data: (z) => z,
                        orElse: () => <DeliveryZoneModel>[],
                      );

                      return _buildDashboardContent(
                        displayOrders,
                        filteredOrders,
                        zones,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => _buildErrorState(e),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.xs,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione Consegne',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Assegna e monitora le consegne',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Tab Switcher
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.circular),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTabButton('Ordini', 'orders', Icons.list_alt_rounded),
                  _buildTabButton(
                    'Mappa Termica',
                    'heatmap',
                    Icons.whatshot_rounded,
                  ),
                  _buildTabButton('Zone', 'zones', Icons.map_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, String id, IconData icon) {
    final isSelected = _currentTab == id;
    return InkWell(
      onTap: () => setState(() => _currentTab = id),
      borderRadius: BorderRadius.circular(AppRadius.circular),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          boxShadow: isSelected ? AppShadows.xs : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<OrderModel> allOrders) {
    // Calculate counts for each filter
    final pendingCount = allOrders
        .where(
          (o) =>
              o.assegnatoDeliveryId == null &&
              o.stato != OrderStatus.completed &&
              o.stato != OrderStatus.cancelled,
        )
        .length;
    final assignedCount = allOrders
        .where(
          (o) =>
              o.assegnatoDeliveryId != null &&
              o.stato != OrderStatus.completed &&
              o.stato != OrderStatus.cancelled,
        )
        .length;
    final completedCount = allOrders
        .where((o) => o.stato == OrderStatus.completed)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              'Tutti',
              OrderFilter.all,
              allOrders.length,
              Icons.all_inclusive_rounded,
              AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildFilterChip(
              'Da Assegnare',
              OrderFilter.pending,
              pendingCount,
              Icons.hourglass_empty_rounded,
              AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildFilterChip(
              'Assegnati',
              OrderFilter.assigned,
              assignedCount,
              Icons.delivery_dining_rounded,
              AppColors.info,
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildFilterChip(
              'Completati',
              OrderFilter.completed,
              completedCount,
              Icons.check_circle_rounded,
              AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    OrderFilter filter,
    int count,
    IconData icon,
    Color color,
  ) {
    final isActive = _activeFilter == filter;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filter),
      borderRadius: BorderRadius.circular(AppRadius.circular),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.2)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                count.toString(),
                style: AppTypography.captionSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersListHeader() {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Date selector row
          Row(
            children: [
              // Previous day
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 1),
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.textSecondary,
                ),
                iconSize: 20,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Date display button
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isToday
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isToday
                                  ? 'Oggi'
                                  : DateFormat(
                                      'EEEE',
                                      'it_IT',
                                    ).format(_selectedDate),
                              style: AppTypography.labelSmall.copyWith(
                                color: isToday
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'd MMM yyyy',
                                'it_IT',
                              ).format(_selectedDate),
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Next day
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_right_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.textSecondary,
                ),
                iconSize: 20,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Today button
              if (!isToday)
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedDate = DateTime.now()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  child: const Text('Oggi'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Cerca ordine, cliente, indirizzo...',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    List<OrderModel> displayOrders,
    List<OrderModel> allFilteredOrders,
    List<DeliveryZoneModel> zones,
  ) {
    // Stats
    final total = allFilteredOrders.length;
    final unassigned = allFilteredOrders
        .where(
          (o) =>
              o.assegnatoDeliveryId == null &&
              o.stato != OrderStatus.completed &&
              o.stato != OrderStatus.cancelled,
        )
        .length;
    final active = allFilteredOrders
        .where(
          (o) =>
              o.assegnatoDeliveryId != null &&
              o.stato != OrderStatus.completed &&
              o.stato != OrderStatus.cancelled,
        )
        .length;
    final completed = allFilteredOrders
        .where((o) => o.stato == OrderStatus.completed)
        .length;

    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          color: AppColors.background,
          child: Row(
            children: [
              _buildSummaryCard(
                'Totale Ordini',
                total.toString(),
                Icons.shopping_bag_outlined,
                AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard(
                'Da Assegnare',
                unassigned.toString(),
                Icons.assignment_ind_outlined,
                AppColors.warning,
                isAlert: unassigned > 0,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard(
                'In Consegna',
                active.toString(),
                Icons.delivery_dining_outlined,
                Colors.blue,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildSummaryCard(
                'Completati',
                completed.toString(),
                Icons.check_circle_outline,
                AppColors.success,
              ),
              const Spacer(),
              // Radial Fee Config Button
              _buildRadialConfigButton(),
            ],
          ),
        ),

        const Divider(height: 1),

        // Split View
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Orders List
              Container(
                width: 480,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    // Search & Date header
                    _buildOrdersListHeader(),
                    // Filter chips
                    _buildFilterChips(allFilteredOrders),
                    const Divider(height: 1),
                    // Orders list
                    Expanded(
                      child: displayOrders.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              controller: _listScrollController,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: displayOrders.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final order = displayOrders[index];
                                final assignedDriver =
                                    order.assegnatoDeliveryId != null
                                    ? _driverMap[order.assegnatoDeliveryId]
                                    : null;

                                // Calculate Zone
                                final loc = _orderLocations[order.id];
                                final zone = loc != null
                                    ? GeometryUtils.findZoneForPoint(loc, zones)
                                    : null;

                                return ModernOrderCard(
                                  key:
                                      _orderCardKeys[order.id] ??
                                      ValueKey(order.id),
                                  order: order,
                                  assignedDriver: assignedDriver,
                                  deliveryZone: zone,
                                  isSelected: _selectedOrderId == order.id,
                                  isAssigning: _assigningOrderId == order.id,
                                  onTap: () {
                                    setState(() => _selectedOrderId = order.id);
                                    if (loc != null) {
                                      _mapController.move(loc, 16);
                                    }
                                  },
                                  onAssign: () => _assignOrder(order),
                                  onUnassign: assignedDriver != null
                                      ? () => _unassignOrder(order)
                                      : null,
                                  onReassign: assignedDriver != null
                                      ? () => _assignOrder(order)
                                      : null,
                                  onShowQr: assignedDriver == null
                                      ? () => _showQrDialog(order)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Right: Map
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: DeliveryMapWidget(
                        pizzeriaCenter: _pizzeriaCenter,
                        orderLocations: _orderLocations,
                        orders: allFilteredOrders,
                        zones: zones,
                        selectedOrderId: _selectedOrderId,
                        onOrderTap: (order) {
                          setState(() => _selectedOrderId = order.id);
                          // Auto-scroll to the selected card
                          _scrollToOrder(order.id, displayOrders);
                        },
                        mapController: _mapController,
                        radialZones:
                            ref
                                .watch(pizzeriaSettingsProvider)
                                .valueOrNull
                                ?.deliveryConfiguration
                                .costoConsegnaRadiale ??
                            [],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isAlert = false,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isAlert ? color : AppColors.border,
          width: isAlert ? 2 : 1,
        ),
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (isAlert)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_activeFilter) {
      case OrderFilter.pending:
        message = 'Nessun ordine da assegnare';
        icon = Icons.check_circle_outline_rounded;
        break;
      case OrderFilter.assigned:
        message = 'Nessun ordine assegnato';
        icon = Icons.delivery_dining_rounded;
        break;
      case OrderFilter.completed:
        message = 'Nessun ordine completato';
        icon = Icons.inbox_rounded;
        break;
      default:
        message = 'Nessun ordine trovato';
        icon = Icons.inbox_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Prova a modificare la ricerca',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text('Errore Caricamento', style: AppTypography.titleMedium),
          Text(error.toString(), style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: () => setState(() {}), // Retry implicitly via build
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadialConfigButton() {
    final settings = ref.watch(pizzeriaSettingsProvider).valueOrNull;
    final deliveryConfig = settings?.deliveryConfiguration;
    final isRadial = deliveryConfig?.tipoCalcoloConsegna == 'radiale';
    final tierCount = deliveryConfig?.costoConsegnaRadiale.length ?? 0;

    return ElevatedButton.icon(
      onPressed: () => _showRadialConfigModal(),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRadial ? AppColors.primary : AppColors.surface,
        foregroundColor: isRadial ? Colors.white : AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: isRadial
              ? BorderSide.none
              : BorderSide(color: AppColors.border),
        ),
        elevation: 0,
      ),
      icon: Icon(
        isRadial ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 18,
      ),
      label: Text(
        isRadial ? 'Zone Radiali ($tierCount)' : 'Configura Zone Radiali',
        style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showRadialConfigModal() {
    final settings = ref.read(pizzeriaSettingsProvider).valueOrNull;
    if (settings == null || _pizzeriaCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile aprire configurazione: dati mancanti'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final deliveryConfig = settings.deliveryConfiguration;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RadialZoneEditor(
          center: _pizzeriaCenter!,
          initialTiers: deliveryConfig.costoConsegnaRadiale,
          initialOuterPrice: deliveryConfig.prezzoFuoriRaggio,
          initialIsRadial: deliveryConfig.tipoCalcoloConsegna == 'radiale',
          onSave: (isRadial, tiers, outerPrice) {
            _saveRadialConfig(
              isRadial: isRadial,
              tiers: tiers,
              prezzoFuoriRaggio: outerPrice,
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveRadialConfig({
    required bool isRadial,
    required List<Map<String, dynamic>> tiers,
    required double prezzoFuoriRaggio,
  }) async {
    try {
      final settingsNotifier = ref.read(pizzeriaSettingsProvider.notifier);
      final currentSettings = ref.read(pizzeriaSettingsProvider).valueOrNull;
      if (currentSettings == null) return;

      final currentDeliveryConfig = currentSettings.deliveryConfiguration;

      // Sort tiers by km ascending
      tiers.sort(
        (a, b) => ((a['km'] as num?) ?? 0).compareTo((b['km'] as num?) ?? 0),
      );

      final updatedConfig = currentDeliveryConfig.copyWith(
        tipoCalcoloConsegna: isRadial ? 'radiale' : 'fisso',
        costoConsegnaRadiale: tiers,
        prezzoFuoriRaggio: prezzoFuoriRaggio,
      );

      await settingsNotifier.saveDeliveryConfiguration(updatedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configurazione consegne aggiornata'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
