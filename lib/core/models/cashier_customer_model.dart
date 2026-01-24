/// Model for cashier customer profiles
/// These are pre-fab customer profiles created at POS, not linked to auth users
class CashierCustomerModel {
  final String id;
  final String nome;
  final String nomeNormalized;
  final String? telefono;
  final String? telefonoNormalized;
  final String? indirizzo;
  final String? citta;
  final String? cap;
  final String? provincia;
  final double? latitude;
  final double? longitude;
  final DateTime? geocodedAt;
  final int ordiniCount;
  final DateTime? ultimoOrdineAt;
  final double totaleSpeso;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  CashierCustomerModel({
    required this.id,
    required this.nome,
    required this.nomeNormalized,
    this.telefono,
    this.telefonoNormalized,
    this.indirizzo,
    this.citta,
    this.cap,
    this.provincia,
    this.latitude,
    this.longitude,
    this.geocodedAt,
    this.ordiniCount = 0,
    this.ultimoOrdineAt,
    this.totaleSpeso = 0,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CashierCustomerModel.fromJson(Map<String, dynamic> json) {
    return CashierCustomerModel(
      id: json['id'] as String,
      nome: json['nome'] as String,
      nomeNormalized: json['nome_normalized'] as String? ?? '',
      telefono: json['telefono'] as String?,
      telefonoNormalized: json['telefono_normalized'] as String?,
      indirizzo: json['indirizzo'] as String?,
      citta: json['citta'] as String?,
      cap: json['cap'] as String?,
      provincia: json['provincia'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geocodedAt: json['geocoded_at'] != null
          ? DateTime.parse(json['geocoded_at'] as String)
          : null,
      ordiniCount: json['ordini_count'] as int? ?? 0,
      ultimoOrdineAt: json['ultimo_ordine_at'] != null
          ? DateTime.parse(json['ultimo_ordine_at'] as String)
          : null,
      totaleSpeso: (json['totale_speso'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'nome_normalized': nomeNormalized,
      'telefono': telefono,
      'telefono_normalized': telefonoNormalized,
      'indirizzo': indirizzo,
      'citta': citta,
      'cap': cap,
      'provincia': provincia,
      'latitude': latitude,
      'longitude': longitude,
      'geocoded_at': geocodedAt?.toIso8601String(),
      'ordini_count': ordiniCount,
      'ultimo_ordine_at': ultimoOrdineAt?.toIso8601String(),
      'totale_speso': totaleSpeso,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns data for insert (without id and computed fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'nome': nome,
      'telefono': telefono,
      'indirizzo': indirizzo,
      'citta': citta,
      'cap': cap,
      'provincia': provincia,
      'latitude': latitude,
      'longitude': longitude,
      'geocoded_at': geocodedAt?.toIso8601String(),
      'note': note,
    };
  }

  CashierCustomerModel copyWith({
    String? id,
    String? nome,
    String? nomeNormalized,
    String? telefono,
    String? telefonoNormalized,
    String? indirizzo,
    String? citta,
    String? cap,
    String? provincia,
    double? latitude,
    double? longitude,
    DateTime? geocodedAt,
    int? ordiniCount,
    DateTime? ultimoOrdineAt,
    double? totaleSpeso,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashierCustomerModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      nomeNormalized: nomeNormalized ?? this.nomeNormalized,
      telefono: telefono ?? this.telefono,
      telefonoNormalized: telefonoNormalized ?? this.telefonoNormalized,
      indirizzo: indirizzo ?? this.indirizzo,
      citta: citta ?? this.citta,
      cap: cap ?? this.cap,
      provincia: provincia ?? this.provincia,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geocodedAt: geocodedAt ?? this.geocodedAt,
      ordiniCount: ordiniCount ?? this.ordiniCount,
      ultimoOrdineAt: ultimoOrdineAt ?? this.ultimoOrdineAt,
      totaleSpeso: totaleSpeso ?? this.totaleSpeso,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if customer has geocoded address
  bool get hasGeocodedAddress => latitude != null && longitude != null;

  /// Check if customer has any address info
  bool get hasAddress => indirizzo != null && indirizzo!.trim().isNotEmpty;

  /// Display name with order count for suggestions
  String get displayNameWithStats {
    final parts = <String>[nome];
    if (ordiniCount > 0) {
      parts.add('($ordiniCount ordini)');
    }
    return parts.join(' ');
  }

  @override
  String toString() => 'CashierCustomerModel(id: $id, nome: $nome, telefono: $telefono)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashierCustomerModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
