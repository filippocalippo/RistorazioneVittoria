import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../core/models/cashier_customer_model.dart';
import '../core/services/database_service.dart';
import '../core/services/google_geocoding_service.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

/// Provider for the DatabaseService instance
final _dbServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

/// State for customer search query
final cashierCustomerSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for customer search results with debouncing built into UI
/// Automatically searches when query changes
final cashierCustomerSearchProvider =
    FutureProvider.autoDispose<List<CashierCustomerModel>>((ref) async {
      final query = ref.watch(cashierCustomerSearchQueryProvider);

      if (query.trim().length < 2) {
        return [];
      }

      final db = ref.read(_dbServiceProvider);
      final orgId = await ref.watch(currentOrganizationProvider.future);
      return db.searchCashierCustomers(
        query,
        organizationId: orgId,
      );
    });

/// Currently selected customer from suggestions
final selectedCashierCustomerProvider = StateProvider<CashierCustomerModel?>(
  (ref) => null,
);

/// Result from processing customer for order
/// Contains customer ID and geocoded coordinates (if available)
class CustomerProcessingResult {
  final String customerId;
  final double? latitude;
  final double? longitude;

  const CustomerProcessingResult({
    required this.customerId,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

/// Service class for intelligent customer profile management
class CashierCustomerService {
  final DatabaseService _db;
  final String? _organizationId;

  CashierCustomerService(this._db, this._organizationId);

  /// Process customer data during order creation
  /// Returns the customer ID and geocoded coordinates to use in the order
  ///
  /// Logic:
  /// 1. Search for existing customer by name + phone
  /// 2. If found: update if needed (new address, geocoding), return ID + coords
  /// 3. If not found: create new customer with geocoding, return ID + coords
  Future<CustomerProcessingResult?> processCustomerForOrder({
    required String nome,
    required String telefono,
    String? indirizzo,
    String? citta,
    String? cap,
    double? orderTotal,
  }) async {
    try {
      // Try to find existing customer
      final existingCustomer = await _db.findMatchingCustomer(
        nome: nome,
        telefono: telefono,
        organizationId: _organizationId,
      );

      if (existingCustomer != null) {
        // Existing customer found - check if we need to update
        return await _updateExistingCustomerIfNeeded(
          customer: existingCustomer,
          nome: nome,
          telefono: telefono,
          indirizzo: indirizzo,
          citta: citta,
          cap: cap,
          orderTotal: orderTotal,
        );
      } else {
        // No existing customer - create new one
        return await _createNewCustomer(
          nome: nome,
          telefono: telefono,
          indirizzo: indirizzo,
          citta: citta,
          cap: cap,
          orderTotal: orderTotal,
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Error processing customer for order: $e',
        tag: 'CashierCustomerService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Update existing customer if there's new information
  /// Returns CustomerProcessingResult with ID and coordinates
  Future<CustomerProcessingResult> _updateExistingCustomerIfNeeded({
    required CashierCustomerModel customer,
    required String nome,
    required String telefono,
    String? indirizzo,
    String? citta,
    String? cap,
    double? orderTotal,
  }) async {
    final updates = <String, dynamic>{};
    bool needsGeocode = false;

    // Track coordinates - start with existing ones
    double? latitude = customer.latitude;
    double? longitude = customer.longitude;

    // Check if phone needs update (customer had no phone or it's different)
    if (telefono.isNotEmpty) {
      final normalizedNewPhone = telefono.replaceAll(RegExp(r'[^0-9]'), '');
      if (customer.telefono == null ||
          customer.telefono!.isEmpty ||
          customer.telefonoNormalized != normalizedNewPhone) {
        updates['telefono'] = telefono;
      }
    }

    // Check if address needs update (customer had no address but now we have one)
    if (indirizzo != null && indirizzo.trim().isNotEmpty) {
      if (customer.indirizzo == null || customer.indirizzo!.trim().isEmpty) {
        updates['indirizzo'] = indirizzo;
        needsGeocode = true;
      } else if (customer.indirizzo!.trim().toLowerCase() !=
          indirizzo.trim().toLowerCase()) {
        // Address changed - update it
        updates['indirizzo'] = indirizzo;
        needsGeocode = true;
      }
    }

    // Check if city needs update
    if (citta != null &&
        citta.trim().isNotEmpty &&
        (customer.citta == null || customer.citta!.trim().isEmpty)) {
      updates['citta'] = citta;
      if (updates.containsKey('indirizzo')) needsGeocode = true;
    }

    // Check if CAP needs update
    if (cap != null &&
        cap.trim().isNotEmpty &&
        (customer.cap == null || customer.cap!.trim().isEmpty)) {
      updates['cap'] = cap;
      if (updates.containsKey('indirizzo')) needsGeocode = true;
    }

    // Geocode if needed and customer doesn't have coordinates
    if (needsGeocode ||
        (updates.containsKey('indirizzo') && !customer.hasGeocodedAddress)) {
      final coords = await _geocodeAddress(
        indirizzo: updates['indirizzo'] as String? ?? customer.indirizzo,
        citta: updates['citta'] as String? ?? customer.citta ?? 'Vittoria',
        cap: updates['cap'] as String? ?? customer.cap ?? '97019',
      );

      if (coords != null) {
        latitude = coords.latitude;
        longitude = coords.longitude;
        updates['latitude'] = latitude;
        updates['longitude'] = longitude;
        updates['updateGeocodedAt'] = true;
      }
    }

    // Apply updates if any
    if (updates.isNotEmpty) {
      Logger.info(
        'Updating customer ${customer.id}: ${updates.keys.join(', ')}',
        tag: 'CashierCustomerService',
      );

      await _db.updateCashierCustomer(
        customerId: customer.id,
        telefono: updates['telefono'] as String?,
        indirizzo: updates['indirizzo'] as String?,
        citta: updates['citta'] as String?,
        cap: updates['cap'] as String?,
        latitude: updates['latitude'] as double?,
        longitude: updates['longitude'] as double?,
        updateGeocodedAt: updates['updateGeocodedAt'] as bool?,
        organizationId: _organizationId,
      );
    }

    // Update order stats
    if (orderTotal != null && orderTotal > 0) {
      await _db.incrementCustomerOrderStats(
        customerId: customer.id,
        orderTotal: orderTotal,
        organizationId: _organizationId,
      );
    }

    return CustomerProcessingResult(
      customerId: customer.id,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Create a new customer profile
  /// Returns CustomerProcessingResult with ID and coordinates
  Future<CustomerProcessingResult> _createNewCustomer({
    required String nome,
    required String telefono,
    String? indirizzo,
    String? citta,
    String? cap,
    double? orderTotal,
  }) async {
    Logger.info('Creating new customer: $nome', tag: 'CashierCustomerService');

    // Geocode address if provided
    double? latitude;
    double? longitude;

    if (indirizzo != null && indirizzo.trim().isNotEmpty) {
      final coords = await _geocodeAddress(
        indirizzo: indirizzo,
        citta: citta ?? 'Vittoria',
        cap: cap ?? '97019',
      );

      if (coords != null) {
        latitude = coords.latitude;
        longitude = coords.longitude;
      }
    }

    // Create the customer
    final customer = await _db.createCashierCustomer(
      nome: nome,
      telefono: telefono.isNotEmpty ? telefono : null,
      indirizzo: indirizzo?.trim().isNotEmpty == true ? indirizzo : null,
      citta: citta ?? 'Vittoria',
      cap: cap ?? '97019',
      latitude: latitude,
      longitude: longitude,
      organizationId: _organizationId,
    );

    // Update stats for first order
    if (orderTotal != null && orderTotal > 0) {
      await _db.incrementCustomerOrderStats(
        customerId: customer.id,
        orderTotal: orderTotal,
        organizationId: _organizationId,
      );
    }

    return CustomerProcessingResult(
      customerId: customer.id,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Geocode an address using Google API
  /// Returns cached coordinates if available
  Future<LatLng?> _geocodeAddress({
    String? indirizzo,
    String? citta,
    String? cap,
  }) async {
    if (indirizzo == null || indirizzo.trim().isEmpty) {
      return null;
    }

    try {
      return await GoogleGeocodingService.geocodeAddress(
        indirizzo: indirizzo,
        citta: citta,
        cap: cap,
        provincia: 'RG',
      );
    } catch (e) {
      Logger.warning(
        'Failed to geocode address: $indirizzo',
        tag: 'CashierCustomerService',
      );
      return null;
    }
  }
}

/// Provider for the customer service
final cashierCustomerServiceProvider = Provider<CashierCustomerService>((ref) {
  final db = ref.read(_dbServiceProvider);
  final orgId = ref.watch(currentOrganizationProvider).value;
  return CashierCustomerService(db, orgId);
});

/// Provider to process customer for order and get customer ID + coordinates
/// Call this during order creation
final processCustomerForOrderProvider = FutureProvider.family
    .autoDispose<CustomerProcessingResult?, CustomerOrderParams>((
      ref,
      params,
    ) async {
      final service = ref.read(cashierCustomerServiceProvider);
      return service.processCustomerForOrder(
        nome: params.nome,
        telefono: params.telefono,
        indirizzo: params.indirizzo,
        citta: params.citta,
        cap: params.cap,
        orderTotal: params.orderTotal,
      );
    });

/// Parameters for processing customer during order creation
class CustomerOrderParams {
  final String nome;
  final String telefono;
  final String? indirizzo;
  final String? citta;
  final String? cap;
  final double? orderTotal;

  const CustomerOrderParams({
    required this.nome,
    required this.telefono,
    this.indirizzo,
    this.citta,
    this.cap,
    this.orderTotal,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerOrderParams &&
          runtimeType == other.runtimeType &&
          nome == other.nome &&
          telefono == other.telefono &&
          indirizzo == other.indirizzo;

  @override
  int get hashCode =>
      nome.hashCode ^ telefono.hashCode ^ (indirizzo?.hashCode ?? 0);
}

// ============================================================
// CASHIER CUSTOMERS LIST PROVIDERS (for Staff Screen)
// ============================================================

/// Provider for all cashier customers list
final allCashierCustomersProvider =
    FutureProvider.autoDispose<List<CashierCustomerModel>>((ref) async {
      final db = ref.read(_dbServiceProvider);
      final orgId = await ref.watch(currentOrganizationProvider.future);
      return db.getAllCashierCustomers(organizationId: orgId);
    });

/// State for cached customers list
class CashierCustomersState {
  final List<CashierCustomerModel> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String searchQuery;
  final String sortColumn;
  final bool sortAscending;

  const CashierCustomersState({
    required this.items,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.searchQuery = '',
    this.sortColumn = 'ordini_count',
    this.sortAscending = false,
  });

  CashierCustomersState copyWith({
    List<CashierCustomerModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
    String? searchQuery,
    String? sortColumn,
    bool? sortAscending,
  }) {
    return CashierCustomersState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

/// Notifier for managing cashier customers list with refresh capability
class CashierCustomersNotifier extends AsyncNotifier<CashierCustomersState> {
  static const int _pageSize = 50;

  @override
  Future<CashierCustomersState> build() async {
    return _fetchInitial();
  }

  Future<CashierCustomersState> _fetchInitial() async {
    final db = ref.read(_dbServiceProvider);
    final orgId = await ref.watch(currentOrganizationProvider.future);
    final items = await db.getAllCashierCustomers(
      limit: _pageSize,
      offset: 0,
      sortBy: 'ordini_count',
      sortAscending: false,
      organizationId: orgId,
    );

    return CashierCustomersState(
      items: items,
      hasMore: items.length >= _pageSize,
      sortColumn: 'ordini_count',
      sortAscending: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchInitial());
  }

  Future<void> search(String query) async {
    // If query hasn't changed, do nothing
    if (state.value?.searchQuery == query) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(_dbServiceProvider);
      final orgId = await ref.read(currentOrganizationProvider.future);
      // Reset sort when searching for best relevance, or keep it?
      // Let's keep current sort preference unless user changes it.
      final currentSort = state.value?.sortColumn ?? 'ordini_count';
      final currentAsc = state.value?.sortAscending ?? false;

      final items = await db.getAllCashierCustomers(
        searchQuery: query,
        limit: _pageSize,
        offset: 0,
        sortBy: currentSort,
        sortAscending: currentAsc,
        organizationId: orgId,
      );

      return CashierCustomersState(
        items: items,
        hasMore: items.length >= _pageSize,
        searchQuery: query,
        sortColumn: currentSort,
        sortAscending: currentAsc,
      );
    });
  }

  Future<void> sort(String column) async {
    final currentState = state.value;
    if (currentState == null) return;

    final isSameColumn = currentState.sortColumn == column;
    // Actually for metrics like 'ordini_count' or 'totale_speso' or 'ultimo_ordine_at' usually desc is default.
    // Let's make it intuitive:
    // If switching TO 'ordini_count', 'totale_speso', 'ultimo_ordine_at', default to DESC (false).
    // If switching TO 'nome', default to ASC (true).
    // If SAME column, just toggle.

    bool nextAscending = true;
    if (isSameColumn) {
      nextAscending = !currentState.sortAscending;
    } else {
      if ([
        'ordini_count',
        'totale_speso',
        'ultimo_ordine_at',
      ].contains(column)) {
        nextAscending = false;
      } else {
        nextAscending = true;
      }
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(_dbServiceProvider);
      final orgId = await ref.read(currentOrganizationProvider.future);

      final items = await db.getAllCashierCustomers(
        searchQuery: currentState.searchQuery,
        limit: _pageSize,
        offset: 0,
        sortBy: column,
        sortAscending: nextAscending,
        organizationId: orgId,
      );

      return currentState.copyWith(
        items: items,
        hasMore: items.length >= _pageSize,
        sortColumn: column,
        sortAscending: nextAscending,
        isLoadingMore: false,
      );
    });
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        !currentState.hasMore ||
        currentState.isLoadingMore) {
      return;
    }

    // Set loading more flag without triggering full UI rebuild (optimization)
    // Actually we need to update state to show spinner at bottom
    // We update just the isLoadingMore flag
    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final db = ref.read(_dbServiceProvider);
      final orgId = await ref.read(currentOrganizationProvider.future);
      final currentCount = currentState.items.length;

      final newItems = await db.getAllCashierCustomers(
        searchQuery: currentState.searchQuery,
        limit: _pageSize,
        offset: currentCount,
        sortBy: currentState.sortColumn,
        sortAscending: currentState.sortAscending,
        organizationId: orgId,
      );

      state = AsyncValue.data(
        currentState.copyWith(
          items: [...currentState.items, ...newItems],
          hasMore: newItems.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e, stack) {
      // If load more fails, revert loading flag and keep existing data
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      // Could also set error state but might be too disruptive
      Logger.error(
        'Failed to load more customers: $e',
        tag: 'CashierCustomersNotifier',
        stackTrace: stack,
      );
    }
  }

  /// Update a customer and refresh the list
  Future<CashierCustomerModel> updateCustomer({
    required String customerId,
    String? nome,
    String? telefono,
    String? indirizzo,
    String? citta,
    String? cap,
    String? provincia,
    double? latitude,
    double? longitude,
    bool? updateGeocodedAt,
    String? note,
  }) async {
    final db = ref.read(_dbServiceProvider);
    final orgId = await ref.read(currentOrganizationProvider.future);
    final updated = await db.updateCashierCustomer(
      customerId: customerId,
      nome: nome,
      telefono: telefono,
      indirizzo: indirizzo,
      citta: citta,
      cap: cap,
      provincia: provincia,
      latitude: latitude,
      longitude: longitude,
      updateGeocodedAt: updateGeocodedAt,
      note: note,
      organizationId: orgId,
    );

    // Update local state
    state.whenData((currentState) {
      final items = currentState.items;
      final index = items.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        final newList = List<CashierCustomerModel>.from(items);
        newList[index] = updated;
        state = AsyncValue.data(currentState.copyWith(items: newList));
      }
    });

    return updated;
  }
}

final cashierCustomersNotifierProvider =
    AsyncNotifierProvider<CashierCustomersNotifier, CashierCustomersState>(
      CashierCustomersNotifier.new,
    );

/// Provider for orders of a specific cashier customer
final cashierCustomerOrdersProvider = FutureProvider.family
    .autoDispose<List<dynamic>, String>((ref, customerId) async {
      final db = ref.read(_dbServiceProvider);
      final orgId = await ref.watch(currentOrganizationProvider.future);
      return db.getOrdersByCashierCustomerId(
        customerId,
        organizationId: orgId,
      );
    });
