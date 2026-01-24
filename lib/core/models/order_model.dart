import 'package:freezed_annotation/freezed_annotation.dart';
import '../utils/enums.dart';
import 'order_item_model.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

@freezed
class OrderModel with _$OrderModel {
  const factory OrderModel({
    required String id,
    String? clienteId,
    required String numeroOrdine,
    required OrderStatus stato,
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
    required double subtotale,
    @Default(0) double costoConsegna,
    @Default(0) double sconto,
    required double totale,
    PaymentMethod? metodoPagamento,
    @Default(false) bool pagato,
    @Default(false) bool isPagatoPrinted,
    String? assegnatoCucinaId,
    String? assegnatoDeliveryId,
    int? tempoStimatoMinuti,
    int? valutazione,
    String? recensione,
    @Default([]) List<OrderItemModel> items,
    required DateTime createdAt,
    DateTime? confermatoAt,
    DateTime? preparazioneAt,
    DateTime? prontoAt,
    DateTime? inConsegnaAt,
    DateTime? completatoAt,
    DateTime? cancellatoAt,
    DateTime? updatedAt,
    DateTime? slotPrenotatoStart,
    String? zone,
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);
}

extension OrderModelX on OrderModel {
  bool get canBePrepared => stato == OrderStatus.confirmed;
  bool get canBeMarkedReady => stato == OrderStatus.preparing;
  bool get canBeDelivered => stato == OrderStatus.ready;
  bool get canBeCompleted => stato == OrderStatus.delivering;
  bool get canBeCancelled => stato.isActive && stato != OrderStatus.completed;

  /// Human-friendly order number for display.
  ///
  /// Supports both legacy formats like `ORD-YYYYMMDD-1234`
  /// and the new format `YYYYMMDD-0001` by taking the last
  /// hyphen-separated segment (the 4-digit counter).
  String get displayNumeroOrdine {
    if (numeroOrdine.isEmpty) return '';
    final parts = numeroOrdine.split('-');
    return parts.isNotEmpty ? parts.last : numeroOrdine;
  }

  Duration? get elapsedTime {
    if (slotPrenotatoStart == null) return null;

    final remaining = slotPrenotatoStart!.difference(DateTime.now());

    // Return remaining time, but not negative
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantita);
}
