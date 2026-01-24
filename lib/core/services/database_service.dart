import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../models/order_model.dart';
import '../models/menu_item_model.dart';
import '../models/product_configuration_model.dart';
import '../models/pizzeria_model.dart';
import '../models/cashier_customer_model.dart';
import '../models/order_reminder_model.dart';
import '../models/settings/pizzeria_settings_model.dart';
import '../models/settings/order_management_settings.dart';
import '../models/settings/delivery_configuration_settings.dart';
import '../models/settings/display_branding_settings.dart';
import '../models/settings/kitchen_management_settings.dart';
import '../models/settings/business_rules_settings.dart';
import '../utils/enums.dart';
import '../utils/model_parsers.dart';
import '../exceptions/app_exceptions.dart';

class DatabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Helper globale per DateTime (usa quello di ModelParsers)
  DateTime? _parseDateTime(dynamic value) => ModelParsers.parseDateTime(value);
  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// SECURITY: Log detailed error but return generic message to prevent schema leakage
  DatabaseException _handleDbError(String operation, PostgrestException e) {
    // Log full error details for debugging (server-side only in production)
    Logger.error(
      'Database error during $operation: ${e.message} (code: ${e.code})',
      tag: 'DatabaseService',
      error: e,
    );
    // Return generic error message to user - prevents schema/table name leakage
    return DatabaseException('Si è verificato un errore. Riprova più tardi.');
  }

  Map<String, dynamic> _menuItemInsertPayload(MenuItemModel item) {
    final payload = Map<String, dynamic>.from(item.toJson());
    payload.remove('id');
    payload.remove('created_at');
    payload.remove('updated_at');
    return payload;
  }

  Map<String, dynamic> _sanitizeMenuItemUpdates(Map<String, dynamic> updates) {
    final payload = Map<String, dynamic>.from(updates);
    const immutableFields = {'id', 'created_at', 'updated_at'};
    payload.removeWhere((key, _) => immutableFields.contains(key));
    return payload;
  }

  Future<Map<String, dynamic>?> _fetchSettingsRow(String table) async {
    try {
      final data = await _client.from(table).select().maybeSingle();

      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } on PostgrestException catch (e) {
      throw _handleDbError('fetchSettingsRow', e);
    }
  }

  Future<void> _upsertSettingsRow(
    String table,
    Map<String, dynamic> values,
  ) async {
    final payload = Map<String, dynamic>.from(values);
    const immutableFields = {'id', 'created_at', 'updated_at'};
    payload.removeWhere((key, _) => immutableFields.contains(key));
    payload['updated_at'] = _nowUtcIso();

    try {
      // Fetch existing row to get its ID (single-tenant: one row per table)
      final existing = await _client.from(table).select('id').maybeSingle();

      if (existing != null) {
        // Update existing row
        await _client.from(table).update(payload).eq('id', existing['id']);
      } else {
        // Insert new row if none exists
        await _client.from(table).insert(payload);
      }
    } on PostgrestException catch (e) {
      throw _handleDbError('upsertSettingsRow', e);
    }
  }

  // ========== PIZZERIA ==========

  /// Get the single pizzeria from business_rules (single-tenant system)
  Future<PizzeriaModel> getPizzeria() async {
    try {
      final data = await _client
          .from('business_rules')
          .select()
          .limit(1)
          .maybeSingle();

      if (data == null) {
        // Return default pizzeria if no business_rules found
        final now = DateTime.now().toIso8601String();
        return PizzeriaModel(
          id: 'default',
          indirizzo: 'Via Roma 123',
          citta: 'Roma',
          cap: '00100',
          provincia: 'RM',
          telefono: '+39 06 123456',
          email: 'info@lamiapizzeria.it',
          immagineCopertinaUrl: null,
          orari: {
            'lunedi': {
              'aperto': false,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
            'martedi': {
              'aperto': true,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
            'mercoledi': {
              'aperto': true,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
            'giovedi': {
              'aperto': true,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
            'venerdi': {
              'aperto': true,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
            'sabato': {
              'aperto': true,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
            'domenica': {
              'aperto': true,
              'apertura': '18:00',
              'chiusura': '23:00',
            },
          },
          latitude: 41.9028,
          longitude: 12.4964,
          attiva: true,
          chiusuraTemporanea: false,
          dataChiusuraDa: null,
          dataChiusuraA: null,
          createdAt: DateTime.parse(now),
          updatedAt: DateTime.parse(now),
        );
      }

      return PizzeriaModel(
        id: data['id'] as String,
        indirizzo: data['indirizzo'] as String?,
        citta: data['citta'] as String?,
        cap: data['cap'] as String?,
        provincia: data['provincia'] as String?,
        telefono: data['telefono'] as String?,
        email: data['email'] as String?,
        immagineCopertinaUrl: data['immagine_copertina_url'] as String?,
        orari: data['orari'] != null && data['orari'] is Map
            ? data['orari'] as Map<String, dynamic>
            : null,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        attiva: data['attiva'] as bool? ?? true,
        chiusuraTemporanea: data['chiusura_temporanea'] as bool? ?? false,
        dataChiusuraDa: _parseDateTime(data['data_chiusura_da']),
        dataChiusuraA: _parseDateTime(data['data_chiusura_a']),
        createdAt: _parseDateTime(data['created_at'])!,
        updatedAt: _parseDateTime(data['updated_at']),
      );
    } on PostgrestException catch (e) {
      throw _handleDbError('getPizzeria', e);
    }
  }

  Future<PizzeriaSettingsModel> getPizzeriaSettings() async {
    final base = await getPizzeria();
    try {
      final orderData = await _fetchSettingsRow('order_management');
      final deliveryData = await _fetchSettingsRow('delivery_configuration');
      final brandingData = await _fetchSettingsRow('display_branding');
      final kitchenData = await _fetchSettingsRow('kitchen_management');
      final businessData = await _fetchSettingsRow('business_rules');

      return PizzeriaSettingsModel(
        pizzeria: base,
        orderManagement: orderData != null
            ? OrderManagementSettings.fromJson(orderData)
            : OrderManagementSettings.defaults(),
        deliveryConfiguration: deliveryData != null
            ? DeliveryConfigurationSettings.fromJson(deliveryData)
            : DeliveryConfigurationSettings.defaults(),
        branding: brandingData != null
            ? DisplayBrandingSettings.fromJson(brandingData)
            : DisplayBrandingSettings.defaults(),
        kitchen: kitchenData != null
            ? KitchenManagementSettings.fromJson(kitchenData)
            : KitchenManagementSettings.defaults(),
        businessRules: businessData != null
            ? BusinessRulesSettings.fromJson(businessData)
            : BusinessRulesSettings.defaults().copyWith(attiva: base.attiva),
      );
    } on PostgrestException catch (e) {
      throw _handleDbError('getPizzeriaSettings', e);
    }
  }

  /// Update business_rules table (single-tenant)
  Future<void> updateBusinessRules(Map<String, dynamic> updates) async {
    try {
      final payload = Map<String, dynamic>.from(updates);
      // Remove immutable fields
      const immutableFields = {'id', 'created_at', 'updated_at'};
      payload.removeWhere((key, _) => immutableFields.contains(key));

      // Add updated_at timestamp
      payload['updated_at'] = _nowUtcIso();

      // Fetch existing row to get its ID (single-tenant: one row)
      final existing = await _client
          .from('business_rules')
          .select('id')
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('business_rules')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        // Insert if no row exists
        await _client.from('business_rules').insert(payload);
      }
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore aggiornamento business rules: ${e.message}',
      );
    }
  }

  Future<void> saveOrderManagementSettings(
    OrderManagementSettings settings,
  ) async {
    await _upsertSettingsRow('order_management', settings.toJson());
  }

  Future<void> saveOrderManagementSettingsRaw(
    Map<String, dynamic> values,
  ) async {
    await _upsertSettingsRow('order_management', values);
  }

  Future<void> saveDeliveryConfigurationSettings(
    DeliveryConfigurationSettings settings,
  ) async {
    await _upsertSettingsRow('delivery_configuration', settings.toJson());
  }

  Future<void> saveDisplayBrandingSettings(
    DisplayBrandingSettings settings,
  ) async {
    await _upsertSettingsRow('display_branding', settings.toJson());
  }

  Future<void> saveKitchenManagementSettings(
    KitchenManagementSettings settings,
  ) async {
    await _upsertSettingsRow('kitchen_management', settings.toJson());
  }

  Future<void> saveBusinessRulesSettings(BusinessRulesSettings settings) async {
    await _upsertSettingsRow('business_rules', settings.toJson());
  }

  // ========== MENU ==========

  Future<List<MenuItemModel>> getMenuItems({bool onlyAvailable = true}) async {
    try {
      var query = _client
          .from(AppConstants.tableMenuItems)
          // Join included ingredients to hydrate display list when legacy field is null
          .select(
            '*, menu_item_included_ingredients(menu_item_id, ingredients(nome))',
          );

      if (onlyAvailable) {
        query = query.eq('disponibile', true);
      }

      final data = await query.order('ordine');

      return data.map((json) => _menuItemFromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero menu: ${e.message}');
    }
  }

  // Helper per parsare MenuItemModel dal JSON di Supabase
  MenuItemModel _menuItemFromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return null;
    }

    // Legacy inline ingredients array (preferred if present and non-empty)
    List<String> inlineIngredients = [];
    if (json['ingredienti'] != null && json['ingredienti'] is List) {
      inlineIngredients = (json['ingredienti'] as List)
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    // Fallback: collect names from joined included ingredients
    List<String> joinedIngredients = [];
    final included = json['menu_item_included_ingredients'];
    if ((included is List) && included.isNotEmpty) {
      for (final entry in included) {
        if (entry is Map && entry['ingredients'] is Map) {
          final ing = entry['ingredients'] as Map;
          final name = ing['nome']?.toString();
          if (name != null && name.trim().isNotEmpty) {
            joinedIngredients.add(name);
          }
        }
      }
    }

    final effectiveIngredients = inlineIngredients.isNotEmpty
        ? inlineIngredients
        : joinedIngredients;

    return MenuItemModel(
      id: json['id'] as String,
      categoriaId: json['categoria_id'] as String?,
      nome: json['nome'] as String,
      descrizione: json['descrizione'] as String?,
      prezzo: (json['prezzo'] as num).toDouble(),
      prezzoScontato: json['prezzo_scontato'] != null
          ? (json['prezzo_scontato'] as num).toDouble()
          : null,
      immagineUrl: json['immagine_url'] as String?,
      ingredienti: effectiveIngredients,
      allergeni: json['allergeni'] != null
          ? (json['allergeni'] as List).map((e) => e.toString()).toList()
          : [],
      valoriNutrizionali:
          json['valori_nutrizionali'] != null &&
              json['valori_nutrizionali'] is Map
          ? json['valori_nutrizionali'] as Map<String, dynamic>
          : null,
      disponibile: json['disponibile'] as bool? ?? true,
      inEvidenza: json['in_evidenza'] as bool? ?? false,
      ordine: json['ordine'] as int? ?? 0,
      productConfiguration:
          (json['product_configuration'] != null &&
              json['product_configuration'] is Map)
          ? ProductConfigurationModel.fromJson(
              Map<String, dynamic>.from(json['product_configuration'] as Map),
            )
          : null,
      createdAt: parseDateTime(json['created_at'])!,
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Future<MenuItemModel> createMenuItem(MenuItemModel item) async {
    try {
      final payload = _menuItemInsertPayload(item);
      final data = await _client
          .from(AppConstants.tableMenuItems)
          .insert(payload)
          .select()
          .single();

      return _menuItemFromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore creazione prodotto: ${e.message}');
    }
  }

  Future<void> updateMenuItem({
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final payload = _sanitizeMenuItemUpdates(updates);
      await _client
          .from(AppConstants.tableMenuItems)
          .update(payload)
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore aggiornamento prodotto: ${e.message}');
    }
  }

  Future<void> deleteMenuItem({required String id}) async {
    try {
      await _client.from(AppConstants.tableMenuItems).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore eliminazione prodotto: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> placeOrder({
    required Map<String, dynamic> requestData,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'place-order',
        body: requestData,
      );

      if (response.status != 200) {
        throw DatabaseException(
          response.data['error'] ?? 'Errore creazione ordine',
        );
      }

      return response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      debugPrint('[placeOrder] FunctionException: $e');
      throw DatabaseException('Errore funzione ordine: ${e.reasonPhrase}');
    } catch (e) {
      throw DatabaseException('Errore imprevisto creazione ordine: $e');
    }
  }

  Future<void> verifyOrderPayment({
    required String orderId,
    required String paymentIntentId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-payment',
        body: {
          'orderId': orderId,
          'paymentIntentId': paymentIntentId,
        },
      );

      if (response.status != 200) {
        throw DatabaseException(
          response.data['error'] ?? 'Verifica pagamento fallita',
        );
      }

      // Record transaction client-side as fallback (since Edge Function deployment failed)
      // Ideally this should be server-side, but this ensures we have a record.
      try {
        await _client.from('payment_transactions').insert({
          'order_id': orderId,
          'payment_intent_id': paymentIntentId,
          'status': 'succeeded',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          // Amount/Metadata would be nice but we don't have them easily here without re-fetching or passing them
        });
      } catch (e) {
        debugPrint('Failed to record payment transaction log: $e');
      }

    } on FunctionException catch (e) {
      throw DatabaseException('Errore verifica pagamento: ${e.reasonPhrase}');
    } catch (e) {
      throw DatabaseException('Errore imprevisto verifica pagamento: $e');
    }
  }

  // ========== ORDERS ==========

  Future<OrderModel> createOrder({
    required String clienteId,
    required OrderType tipo,
    required String nomeCliente,
    required String telefonoCliente,
    String? emailCliente,
    String? indirizzoConsegna,
    String? cittaConsegna,
    String? capConsegna,
    double? latitudeConsegna,
    double? longitudeConsegna,
    String? note,
    required List<Map<String, dynamic>> items,
    required double subtotale,
    required double costoConsegna,
    double sconto = 0,
    required double totale,
    PaymentMethod? metodoPagamento,
    DateTime? slotPrenotatoStart,
    String? cashierCustomerId,
    OrderStatus status = OrderStatus.confirmed,
    String? zone,
  }) async {
    try {
      // Pass items AS-IS to RPC with minimal extraction for price validation
      // The RPC will ONLY validate prices and save the EXACT data we send
      final requestBody = {
        'items': items, // Pass complete items with all data including varianti
        'orderType': tipo.dbValue,
        'paymentMethod': metodoPagamento?.name ?? 'cash',
        'nomeCliente': nomeCliente,
        'telefonoCliente': telefonoCliente,
        'emailCliente': emailCliente,
        'indirizzoConsegna': indirizzoConsegna,
        'cittaConsegna': cittaConsegna,
        'capConsegna': capConsegna,
        'deliveryLatitude': latitudeConsegna,
        'deliveryLongitude': longitudeConsegna,
        'note': note,
        'slotPrenotatoStart': slotPrenotatoStart?.toUtc().toIso8601String(),
        'cashierCustomerId': cashierCustomerId,
        'zone': zone,
        'subtotale': subtotale,
        'costoConsegna': costoConsegna,
        'sconto': sconto,
        'totale': totale,
        // Staff overrides
        'status': status.name,
      };

      debugPrint('[createOrder] Calling RPC with ${items.length} items');

      final response = await placeOrder(requestData: requestBody);
      final orderId = response['orderId'] as String;

      debugPrint('[createOrder] RPC returned orderId: $orderId');

      return await getOrder(orderId);
    } catch (e) {
      debugPrint('[createOrder] Error: $e');
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Errore creazione ordine: $e');
    }
  }

  Future<OrderModel> getOrder(String orderId) async {
    try {
      final data = await _client
          .from(AppConstants.tableOrdini)
          .select('*, ordini_items(*)')
          .eq('id', orderId)
          .single();

      return ModelParsers.orderFromJson(data);
    } on PostgrestException catch (e) {
      throw _handleDbError('getOrder', e);
    }
  }

  Future<List<OrderModel>> getOrders({
    List<OrderStatus>? statuses,
    String? clienteId,
    int limit = AppConstants.defaultPageSize,
    int offset = 0,
    bool includeItems = true,
  }) async {
    try {
      final selectColumns = [
        'id',
        'cliente_id',
        'numero_ordine',
        'stato',
        'tipo',
        'nome_cliente',
        'telefono_cliente',
        'email_cliente',
        'indirizzo_consegna',
        'citta_consegna',
        'cap_consegna',
        'latitude_consegna',
        'longitude_consegna',
        'note',
        'subtotale',
        'costo_consegna',
        'sconto',
        'totale',
        'metodo_pagamento',
        'pagato',
        'assegnato_cucina_id',
        'assegnato_delivery_id',
        'tempo_stimato_minuti',
        'valutazione',
        'recensione',
        'created_at',
        'confermato_at',
        'preparazione_at',
        'pronto_at',
        'in_consegna_at',
        'completato_at',
        'cancellato_at',
        'updated_at',
        'slot_prenotato_start',
        if (includeItems)
          'ordini_items(id, ordine_id, menu_item_id, nome_prodotto, quantita, prezzo_unitario, subtotale, note, varianti, created_at)',
      ].join(', ');

      var query = _client.from(AppConstants.tableOrdini).select(selectColumns);

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('stato', statuses.map((s) => s.name).toList());
      }

      if (clienteId != null) {
        query = query.eq('cliente_id', clienteId);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return data.map((json) => ModelParsers.orderFromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw _handleDbError('getOrders', e);
    }
  }

  /// Return the raw order management settings row.
  /// Useful for reading fields not yet modeled in OrderManagementSettings.
  Future<Map<String, dynamic>?> getOrderManagementSettingsRaw() async {
    return _fetchSettingsRow('order_management');
  }

  /// Count total items within a time window (slot) for a given order type.
  /// Uses slot_prenotato_start to find orders and sums up all item quantities.
  Future<int> countItemsInSlot({
    required DateTime slotStartUtc,
    required DateTime slotEndUtc,
    required OrderType type,
  }) async {
    try {
      final res = await _client
          .from(AppConstants.tableOrdini)
          .select('id, ordini_items(quantita)')
          .eq('tipo', type.dbValue)
          .neq('stato', OrderStatus.cancelled.name)
          .gte('slot_prenotato_start', slotStartUtc.toIso8601String())
          .lt('slot_prenotato_start', slotEndUtc.toIso8601String());
      final List data = res as List;

      int totalItems = 0;
      for (final order in data) {
        final items = order['ordini_items'] as List? ?? [];
        for (final item in items) {
          totalItems += (item['quantita'] as int? ?? 1);
        }
      }
      return totalItems;
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore conteggio articoli nello slot: ${e.message}',
      );
    }
  }

  /// Count orders within a time window (slot) for a given order type.
  /// Uses slot_prenotato_start to count orders scheduled for the same slot.
  /// @deprecated Use countItemsInSlot instead for capacity checking
  Future<int> countOrdersInSlot({
    required DateTime slotStartUtc,
    required DateTime slotEndUtc,
    required OrderType type,
  }) async {
    try {
      final res = await _client
          .from(AppConstants.tableOrdini)
          .select('id')
          .eq('tipo', type.dbValue)
          .neq('stato', OrderStatus.cancelled.name)
          .gte('slot_prenotato_start', slotStartUtc.toIso8601String())
          .lt('slot_prenotato_start', slotEndUtc.toIso8601String());
      final List data = res as List;
      return data.length;
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore conteggio ordini nello slot: ${e.message}',
      );
    }
  }

  /// Returns aggregated item counts grouped by slot within a time range.
  Future<Map<DateTime, int>> getItemCountsBySlotRange({
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
    required OrderType type,
  }) async {
    try {
      final response = await _client
          .from(AppConstants.tableOrdini)
          .select('slot_prenotato_start, ordini_items(quantita)')
          .eq('tipo', type.dbValue)
          .neq('stato', OrderStatus.cancelled.name)
          .gte('slot_prenotato_start', rangeStartUtc.toIso8601String())
          .lt('slot_prenotato_start', rangeEndUtc.toIso8601String());

      final List data = response as List;
      final counts = <DateTime, int>{};

      for (final row in data) {
        final slot = _parseDateTime(row['slot_prenotato_start']);
        if (slot == null) {
          continue;
        }

        final slotKey = slot.toUtc();
        final items = row['ordini_items'] as List? ?? const [];
        final slotCount = items.fold<int>(
          0,
          (sum, item) => sum + (item['quantita'] as int? ?? 0),
        );

        if (slotCount == 0) continue;
        counts[slotKey] = (counts[slotKey] ?? 0) + slotCount;
      }

      return counts;
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore aggregazione articoli per slot: ${e.message}',
      );
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    try {
      final updates = <String, dynamic>{'stato': status.name};

      // Aggiungi timestamp appropriato
      final now = _nowUtcIso();
      switch (status) {
        case OrderStatus.confirmed:
          updates['confermato_at'] = now;
          break;
        case OrderStatus.preparing:
          updates['preparazione_at'] = now;
          break;
        case OrderStatus.ready:
          updates['pronto_at'] = now;
          break;
        case OrderStatus.delivering:
          updates['in_consegna_at'] = now;
          break;
        case OrderStatus.completed:
          updates['completato_at'] = now;
          break;
        case OrderStatus.cancelled:
          updates['cancellato_at'] = now;
          break;
        default:
          break;
      }

      await _client
          .from(AppConstants.tableOrdini)
          .update(updates)
          .eq('id', orderId);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore aggiornamento stato ordine: ${e.message}',
      );
    }
  }

  Future<void> assignOrderToKitchen({
    required String orderId,
    required String kitchenUserId,
  }) async {
    try {
      await _client
          .from(AppConstants.tableOrdini)
          .update({'assegnato_cucina_id': kitchenUserId})
          .eq('id', orderId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore assegnazione ordine: ${e.message}');
    }
  }

  Future<void> assignOrderToDelivery({
    required String orderId,
    required String deliveryUserId,
  }) async {
    try {
      await _client
          .from(AppConstants.tableOrdini)
          .update({'assegnato_delivery_id': deliveryUserId})
          .eq('id', orderId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore assegnazione consegna: ${e.message}');
    }
  }

  /// Cancel an order by setting its status to cancelled.
  /// Returns true if successful.
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _client
          .from(AppConstants.tableOrdini)
          .update({
            'stato': OrderStatus.cancelled.name,
            'cancellato_at': _nowUtcIso(),
          })
          .eq('id', orderId);
      return true;
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore annullamento ordine: ${e.message}');
    }
  }

  /// Delete an order and its items permanently.
  /// Use with caution - prefer cancelOrder for audit trail.
  Future<bool> deleteOrder(String orderId) async {
    try {
      // Delete order items first (foreign key constraint)
      await _client
          .from(AppConstants.tableOrdiniItems)
          .delete()
          .eq('ordine_id', orderId);

      // Delete the order
      await _client.from(AppConstants.tableOrdini).delete().eq('id', orderId);

      return true;
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore eliminazione ordine: ${e.message}');
    }
  }

  /// Update an existing order with new data.
  /// Replaces all items with the new items list.
  /// Sets stampato to false so the order gets reprinted.
  /// Does NOT change numero_ordine - keeps the original order number.
  /// Now uses the place-order RPC function for consistency and proper validation.
  Future<OrderModel> updateOrder({
    required String orderId,
    required OrderType tipo,
    required String nomeCliente,
    required String telefonoCliente,
    String? emailCliente,
    String? indirizzoConsegna,
    String? cittaConsegna,
    String? capConsegna,
    double? latitudeConsegna,
    double? longitudeConsegna,
    String? note,
    required List<Map<String, dynamic>> items,
    required double subtotale,
    required double costoConsegna,
    double sconto = 0,
    required double totale,
    PaymentMethod? metodoPagamento,
    DateTime? slotPrenotatoStart,
    String? cashierCustomerId,
    String? zone,
  }) async {
    try {
      // Pass items AS-IS to RPC (same as createOrder)
      final requestBody = {
        'orderId': orderId, // This tells the RPC to UPDATE instead of CREATE
        'items': items, // Pass complete items with all data including varianti
        'orderType': tipo.dbValue,
        'paymentMethod': metodoPagamento?.name ?? 'cash',
        'nomeCliente': nomeCliente,
        'telefonoCliente': telefonoCliente,
        'emailCliente': emailCliente,
        'indirizzoConsegna': indirizzoConsegna,
        'cittaConsegna': cittaConsegna,
        'capConsegna': capConsegna,
        'deliveryLatitude': latitudeConsegna,
        'deliveryLongitude': longitudeConsegna,
        'note': note,
        'slotPrenotatoStart': slotPrenotatoStart?.toUtc().toIso8601String(),
        'cashierCustomerId': cashierCustomerId,
        'zone': zone,
        'subtotale': subtotale,
        'costoConsegna': costoConsegna,
        'sconto': sconto,
        'totale': totale,
      };

      debugPrint('[updateOrder] Calling RPC for orderId: $orderId with ${items.length} items');

      final response = await placeOrder(requestData: requestBody);
      final returnedOrderId = response['orderId'] as String;

      debugPrint('[updateOrder] Order updated successfully');

      return await getOrder(returnedOrderId);
    } catch (e) {
      debugPrint('[updateOrder] Error: $e');
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Errore modifica ordine: $e');
    }
  }

  /// Mark an order as not printed (so it gets picked up by the printer service)
  Future<void> markOrderAsNotPrinted(String orderId) async {
    try {
      await _client
          .from(AppConstants.tableOrdini)
          .update({'printed': false})
          .eq('id', orderId);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore aggiornamento stato stampa: ${e.message}',
      );
    }
  }

  /// Toggle the pagato status of an order
  /// When setting pagato to true, also resets is_pagato_printed to false
  /// so the printer service will print the "PAGATO" receipt
  /// When setting pagato to false, also resets is_pagato_printed to false
  Future<void> toggleOrderPagato(String orderId, bool pagato) async {
    try {
      await _client
          .from(AppConstants.tableOrdini)
          .update({'pagato': pagato, 'is_pagato_printed': false})
          .eq('id', orderId);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore aggiornamento stato pagamento: ${e.message}',
      );
    }
  }

  // ========== CASHIER CUSTOMERS ==========

  /// Search cashier customers by name (case-insensitive)
  /// Searches by:
  /// 1. Name starts with query (e.g., "barr" matches "Barrano Giovanni")
  /// 2. Any word in name starts with query (e.g., "giom" matches "Barrano Giombattista")
  /// 3. Contains query anywhere (e.g., "ombat" matches "Barrano Giombattista")
  /// Returns customers sorted by most recent orders first
  Future<List<CashierCustomerModel>> searchCashierCustomers(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      final normalizedQuery = query.trim().toLowerCase();

      // Search patterns:
      // 1. Starts with query: "barr%"
      // 2. Has word starting with query: "% giom%" (space before)
      // 3. Contains query anywhere: "%ombat%"
      final data = await _client
          .from('cashier_customers')
          .select()
          .or(
            'nome_normalized.ilike.$normalizedQuery%,nome_normalized.ilike.% $normalizedQuery%,nome_normalized.ilike.%$normalizedQuery%',
          )
          .order('ordini_count', ascending: false)
          .order('ultimo_ordine_at', ascending: false, nullsFirst: false)
          .limit(10);

      return (data as List)
          .map((json) => CashierCustomerModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore ricerca clienti: ${e.message}');
    }
  }

  /// Build search patterns including swapped name/surname
  /// "giovanni rossi" -> ["giovanni rossi", "rossi giovanni"]
  /// "giovanni" -> ["giovanni"]
  List<String> _buildNameSearchPatterns(String normalizedName) {
    final patterns = <String>[normalizedName];

    final parts = normalizedName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      // Swap first and last parts: "a b c" -> "c b a" and "c a b" etc.
      // For simplicity, just swap first and last
      final swapped = [...parts];
      final first = swapped.first;
      swapped[0] = swapped.last;
      swapped[swapped.length - 1] = first;
      final swappedName = swapped.join(' ');
      if (swappedName != normalizedName) {
        patterns.add(swappedName);
      }

      // Also try with just first two parts swapped for "name surname" cases
      if (parts.length == 2) {
        // Already covered above
      } else if (parts.length > 2) {
        // Try swapping just first two: "a b c" -> "b a c"
        final swapFirstTwo = [parts[1], parts[0], ...parts.sublist(2)];
        final swapFirstTwoName = swapFirstTwo.join(' ');
        if (!patterns.contains(swapFirstTwoName)) {
          patterns.add(swapFirstTwoName);
        }
      }
    }

    return patterns;
  }

  /// Find a customer by exact or fuzzy match
  /// Uses intelligent matching: name similarity + phone number validation
  /// Also matches swapped name/surname (e.g., "Giovanni Rossi" matches "Rossi Giovanni")
  /// Returns the best matching customer or null
  Future<CashierCustomerModel?> findMatchingCustomer({
    required String nome,
    String? telefono,
  }) async {
    if (nome.trim().isEmpty) return null;

    try {
      final normalizedName = nome.trim().toLowerCase();
      final normalizedPhone = telefono?.replaceAll(RegExp(r'[^0-9]'), '');

      // Build name patterns including swapped versions
      final namePatterns = _buildNameSearchPatterns(normalizedName);

      // First try: exact name match (including swapped) with phone validation
      if (normalizedPhone != null && normalizedPhone.length >= 6) {
        for (final namePattern in namePatterns) {
          final exactMatch = await _client
              .from('cashier_customers')
              .select()
              .eq('nome_normalized', namePattern)
              .eq('telefono_normalized', normalizedPhone)
              .maybeSingle();

          if (exactMatch != null) {
            return CashierCustomerModel.fromJson(exactMatch);
          }
        }
      }

      // Second try: exact name match (including swapped, any phone or no phone)
      for (final namePattern in namePatterns) {
        final nameMatch = await _client
            .from('cashier_customers')
            .select()
            .eq('nome_normalized', namePattern)
            .order('ordini_count', ascending: false)
            .limit(1)
            .maybeSingle();

        if (nameMatch != null) {
          // Validate phone if both have phones
          final existingPhone = nameMatch['telefono_normalized'] as String?;
          if (normalizedPhone != null &&
              normalizedPhone.length >= 6 &&
              existingPhone != null &&
              existingPhone.length >= 6) {
            // Check if phones match (last 6 digits)
            final phoneSuffix = normalizedPhone.substring(
              normalizedPhone.length - 6,
            );
            final existingSuffix = existingPhone.length >= 6
                ? existingPhone.substring(existingPhone.length - 6)
                : existingPhone;

            if (phoneSuffix == existingSuffix) {
              return CashierCustomerModel.fromJson(nameMatch);
            }
            // Phone mismatch - might be a different person with same name
            // Continue to next pattern instead of returning null immediately
            continue;
          }
          // One or both don't have phone - match on name alone
          return CashierCustomerModel.fromJson(nameMatch);
        }
      }

      // Third try: fuzzy name match using first word of each pattern
      final searchedFirstNames = <String>{};
      for (final namePattern in namePatterns) {
        final firstName = namePattern.split(' ').first;
        if (firstName.length >= 3 && !searchedFirstNames.contains(firstName)) {
          searchedFirstNames.add(firstName);

          final fuzzyMatches = await _client
              .from('cashier_customers')
              .select()
              .ilike('nome_normalized', '$firstName%')
              .order('ordini_count', ascending: false)
              .limit(5);

          final matches = (fuzzyMatches as List)
              .map((json) => CashierCustomerModel.fromJson(json))
              .toList();

          // If phone provided, try to find matching phone
          if (normalizedPhone != null && normalizedPhone.length >= 6) {
            for (final customer in matches) {
              if (customer.telefonoNormalized != null &&
                  customer.telefonoNormalized!.length >= 6) {
                final phoneSuffix = normalizedPhone.substring(
                  normalizedPhone.length - 6,
                );
                final existingSuffix = customer.telefonoNormalized!.length >= 6
                    ? customer.telefonoNormalized!.substring(
                        customer.telefonoNormalized!.length - 6,
                      )
                    : customer.telefonoNormalized!;

                if (phoneSuffix == existingSuffix) {
                  return customer;
                }
              }
            }
          }
        }
      }

      return null;
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore ricerca cliente: ${e.message}');
    }
  }

  /// Create a new cashier customer
  Future<CashierCustomerModel> createCashierCustomer({
    required String nome,
    String? telefono,
    String? indirizzo,
    String? citta,
    String? cap,
    String? provincia,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    try {
      final data = await _client
          .from('cashier_customers')
          .insert({
            'nome': nome.trim(),
            'telefono': telefono?.trim(),
            'indirizzo': indirizzo?.trim(),
            'citta': citta?.trim() ?? 'Vittoria',
            'cap': cap?.trim() ?? '97019',
            'provincia': provincia?.trim() ?? 'RG',
            'latitude': latitude,
            'longitude': longitude,
            'geocoded_at': latitude != null ? _nowUtcIso() : null,
            'note': note?.trim(),
          })
          .select()
          .single();

      return CashierCustomerModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore creazione cliente: ${e.message}');
    }
  }

  /// Update an existing cashier customer
  /// Only updates non-null fields provided
  Future<CashierCustomerModel> updateCashierCustomer({
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
    try {
      final updates = <String, dynamic>{};

      if (nome != null) updates['nome'] = nome.trim();
      if (telefono != null) updates['telefono'] = telefono.trim();
      if (indirizzo != null) updates['indirizzo'] = indirizzo.trim();
      if (citta != null) updates['citta'] = citta.trim();
      if (cap != null) updates['cap'] = cap.trim();
      if (provincia != null) updates['provincia'] = provincia.trim();
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (updateGeocodedAt == true) updates['geocoded_at'] = _nowUtcIso();
      if (note != null) updates['note'] = note.trim();

      if (updates.isEmpty) {
        // Nothing to update, just fetch current
        final current = await _client
            .from('cashier_customers')
            .select()
            .eq('id', customerId)
            .single();
        return CashierCustomerModel.fromJson(current);
      }

      final data = await _client
          .from('cashier_customers')
          .update(updates)
          .eq('id', customerId)
          .select()
          .single();

      return CashierCustomerModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore aggiornamento cliente: ${e.message}');
    }
  }

  /// Increment order stats for a customer after successful order
  Future<void> incrementCustomerOrderStats({
    required String customerId,
    required double orderTotal,
  }) async {
    try {
      // Direct update to ensure ultimo_ordine_at is always set correctly
      final current = await _client
          .from('cashier_customers')
          .select('ordini_count, totale_speso')
          .eq('id', customerId)
          .maybeSingle();

      if (current != null) {
        final newCount = (current['ordini_count'] as int? ?? 0) + 1;
        final newTotal = (current['totale_speso'] as num?)?.toDouble() ?? 0;

        await _client
            .from('cashier_customers')
            .update({
              'ordini_count': newCount,
              'totale_speso': newTotal + orderTotal,
              'ultimo_ordine_at': _nowUtcIso(),
            })
            .eq('id', customerId);
      }
    } catch (e) {
      // Log error but don't fail flow
      debugPrint('Error updating customer stats: $e');
    }
  }

  /// Get a single cashier customer by ID
  Future<CashierCustomerModel?> getCashierCustomer(String customerId) async {
    try {
      final data = await _client
          .from('cashier_customers')
          .select()
          .eq('id', customerId)
          .maybeSingle();

      if (data == null) return null;
      return CashierCustomerModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero cliente: ${e.message}');
    }
  }

  /// Get all cashier customers with optional search and pagination
  Future<List<CashierCustomerModel>> getAllCashierCustomers({
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    String sortBy = 'ordini_count',
    bool sortAscending = false,
  }) async {
    try {
      dynamic query = _client.from('cashier_customers').select();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final normalizedQuery = searchQuery.trim().toLowerCase();
        query = query.or(
          'nome_normalized.ilike.%$normalizedQuery%,telefono_normalized.ilike.%$normalizedQuery%,indirizzo.ilike.%$normalizedQuery%',
        );
      }

      // Apply sorting
      if (sortBy == 'nome') {
        // For name, we might want case-insensitive sort using normalized column if available,
        // or just standard sort. Let's use standard for now.
        query = query.order('nome', ascending: sortAscending);
      } else {
        query = query.order(sortBy, ascending: sortAscending);
      }

      // Secondary sort for stability
      query = query.order('created_at', ascending: false);

      final data = await query.range(offset, offset + limit - 1);

      return (data as List)
          .map((json) => CashierCustomerModel.fromJson(json))
          .toList()
          .cast<CashierCustomerModel>();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero clienti cassa: ${e.message}');
    }
  }

  /// Get orders for a specific cashier customer
  Future<List<OrderModel>> getOrdersByCashierCustomerId(
    String cashierCustomerId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final selectColumns = [
        'id',
        'cliente_id',
        'numero_ordine',
        'stato',
        'tipo',
        'nome_cliente',
        'telefono_cliente',
        'email_cliente',
        'indirizzo_consegna',
        'citta_consegna',
        'cap_consegna',
        'latitude_consegna',
        'longitude_consegna',
        'note',
        'subtotale',
        'costo_consegna',
        'sconto',
        'totale',
        'metodo_pagamento',
        'pagato',
        'assegnato_cucina_id',
        'assegnato_delivery_id',
        'tempo_stimato_minuti',
        'valutazione',
        'recensione',
        'created_at',
        'confermato_at',
        'preparazione_at',
        'pronto_at',
        'in_consegna_at',
        'completato_at',
        'cancellato_at',
        'updated_at',
        'slot_prenotato_start',
        'ordini_items(id, ordine_id, menu_item_id, nome_prodotto, quantita, prezzo_unitario, subtotale, note, varianti, created_at)',
      ].join(', ');

      final data = await _client
          .from(AppConstants.tableOrdini)
          .select(selectColumns)
          .eq('cashier_customer_id', cashierCustomerId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return data.map((json) => ModelParsers.orderFromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero ordini cliente: ${e.message}');
    }
  }

  // ========== ORDER REMINDERS ==========

  /// Get all active (non-completed) reminders, sorted by priority and creation date
  /// Joins with orders to get order details
  Future<List<OrderReminderModel>> getActiveReminders() async {
    try {
      final data = await _client
          .from('order_reminders')
          .select('''
            id,
            ordine_id,
            titolo,
            descrizione,
            priorita,
            scadenza,
            completato,
            completato_at,
            created_by,
            created_at,
            updated_at,
            ordini:ordine_id(numero_ordine, nome_cliente)
          ''')
          .eq('completato', false)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => OrderReminderModel.fromSupabase(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero promemoria: ${e.message}');
    }
  }

  /// Get reminders for a specific order
  Future<List<OrderReminderModel>> getRemindersByOrder(String orderId) async {
    try {
      final data = await _client
          .from('order_reminders')
          .select('''
            id,
            ordine_id,
            titolo,
            descrizione,
            priorita,
            scadenza,
            completato,
            completato_at,
            created_by,
            created_at,
            updated_at,
            ordini:ordine_id(numero_ordine, nome_cliente)
          ''')
          .eq('ordine_id', orderId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => OrderReminderModel.fromSupabase(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Errore recupero promemoria ordine: ${e.message}',
      );
    }
  }

  /// Create a new reminder for an order
  Future<OrderReminderModel> createReminder({
    required String ordineId,
    required String titolo,
    String? descrizione,
    ReminderPriority priorita = ReminderPriority.normal,
    DateTime? scadenza,
    String? createdBy,
  }) async {
    try {
      final data = await _client
          .from('order_reminders')
          .insert({
            'ordine_id': ordineId,
            'titolo': titolo.trim(),
            'descrizione': descrizione?.trim(),
            'priorita': priorita.name,
            'scadenza': scadenza?.toUtc().toIso8601String(),
            'created_by': createdBy,
          })
          .select('''
            id,
            ordine_id,
            titolo,
            descrizione,
            priorita,
            scadenza,
            completato,
            completato_at,
            created_by,
            created_at,
            updated_at,
            ordini:ordine_id(numero_ordine, nome_cliente)
          ''')
          .single();

      return OrderReminderModel.fromSupabase(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore creazione promemoria: ${e.message}');
    }
  }

  /// Mark a reminder as completed
  Future<void> completeReminder(String reminderId) async {
    try {
      await _client
          .from('order_reminders')
          .update({
            'completato': true,
            'completato_at': _nowUtcIso(),
            'updated_at': _nowUtcIso(),
          })
          .eq('id', reminderId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore completamento promemoria: ${e.message}');
    }
  }

  /// Delete a reminder permanently
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _client.from('order_reminders').delete().eq('id', reminderId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore eliminazione promemoria: ${e.message}');
    }
  }

  /// Update a reminder
  Future<OrderReminderModel> updateReminder({
    required String reminderId,
    String? titolo,
    String? descrizione,
    ReminderPriority? priorita,
    DateTime? scadenza,
    bool? clearScadenza,
  }) async {
    try {
      final updates = <String, dynamic>{'updated_at': _nowUtcIso()};

      if (titolo != null) updates['titolo'] = titolo.trim();
      if (descrizione != null) updates['descrizione'] = descrizione.trim();
      if (priorita != null) updates['priorita'] = priorita.name;
      if (scadenza != null) {
        updates['scadenza'] = scadenza.toUtc().toIso8601String();
      } else if (clearScadenza == true) {
        updates['scadenza'] = null;
      }

      final data = await _client
          .from('order_reminders')
          .update(updates)
          .eq('id', reminderId)
          .select('''
            id,
            ordine_id,
            titolo,
            descrizione,
            priorita,
            scadenza,
            completato,
            completato_at,
            created_by,
            created_at,
            updated_at,
            ordini:ordine_id(numero_ordine, nome_cliente)
          ''')
          .single();

      return OrderReminderModel.fromSupabase(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore aggiornamento promemoria: ${e.message}');
    }
  }
}
