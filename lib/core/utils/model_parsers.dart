import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../utils/enums.dart';

/// Helper per parsare modelli Freezed dal JSON di Supabase
/// Necessario perché Supabase restituisce DateTime come oggetti invece che stringhe
class ModelParsers {
  /// Helper per convertire DateTime
  /// Converts UTC timestamps from database to local time
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      // Parse the UTC string and immediately convert to local time
      final parsed = DateTime.parse(value);
      return parsed.toLocal();
    }
    return null;
  }

  /// Helper per convertire double
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  /// Parse OrderModel dal JSON di Supabase
  static OrderModel orderFromJson(Map<String, dynamic> data) {
    // Parse items
    final itemsList = data['ordini_items'] as List?;
    final items = itemsList?.map((itemData) {
      return OrderItemModel(
        id: itemData['id'] as String,
        ordineId: itemData['ordine_id'] as String,
        menuItemId: itemData['menu_item_id'] as String?,
        nomeProdotto: itemData['nome_prodotto'] as String,
        quantita: itemData['quantita'] as int? ?? 1,
        prezzoUnitario: (itemData['prezzo_unitario'] as num).toDouble(),
        subtotale: (itemData['subtotale'] as num).toDouble(),
        note: itemData['note'] as String?,
        varianti: itemData['varianti'] != null && itemData['varianti'] is Map
          ? itemData['varianti'] as Map<String, dynamic>
          : null,
        createdAt: parseDateTime(itemData['created_at'])!,
      );
    }).toList() ?? [];
    
    return OrderModel(
      id: data['id'] as String,
      clienteId: data['cliente_id'] as String?,
      numeroOrdine: data['numero_ordine'] as String,
      stato: OrderStatus.fromString(data['stato'] as String),
      tipo: OrderType.fromString(data['tipo'] as String),
      nomeCliente: data['nome_cliente'] as String,
      telefonoCliente: data['telefono_cliente'] as String,
      emailCliente: data['email_cliente'] as String?,
      indirizzoConsegna: data['indirizzo_consegna'] as String?,
      cittaConsegna: data['citta_consegna'] as String?,
      capConsegna: data['cap_consegna'] as String?,
      latitudeConsegna: parseDouble(data['latitude_consegna']),
      longitudeConsegna: parseDouble(data['longitude_consegna']),
      note: data['note'] as String?,
      subtotale: (data['subtotale'] as num).toDouble(),
      costoConsegna: (data['costo_consegna'] as num?)?.toDouble() ?? 0,
      sconto: (data['sconto'] as num?)?.toDouble() ?? 0,
      totale: (data['totale'] as num).toDouble(),
      metodoPagamento: data['metodo_pagamento'] != null 
        ? PaymentMethod.fromString(data['metodo_pagamento'] as String)
        : null,
      pagato: data['pagato'] as bool? ?? false,
      assegnatoCucinaId: data['assegnato_cucina_id'] as String?,
      assegnatoDeliveryId: data['assegnato_delivery_id'] as String?,
      tempoStimatoMinuti: data['tempo_stimato_minuti'] as int?,
      valutazione: data['valutazione'] as int?,
      recensione: data['recensione'] as String?,
      items: items,
      createdAt: parseDateTime(data['created_at'])!,
      confermatoAt: parseDateTime(data['confermato_at']),
      preparazioneAt: parseDateTime(data['preparazione_at']),
      prontoAt: parseDateTime(data['pronto_at']),
      inConsegnaAt: parseDateTime(data['in_consegna_at']),
      completatoAt: parseDateTime(data['completato_at']),
      cancellatoAt: parseDateTime(data['cancellato_at']),
      updatedAt: parseDateTime(data['updated_at']),
      slotPrenotatoStart: parseDateTime(data['slot_prenotato_start']),
    );
  }
}
