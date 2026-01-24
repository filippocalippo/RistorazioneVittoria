class CategoryModel {
  final String id;
  final String? organizationId;
  final String nome;
  final String? descrizione;
  final String? icona;
  final String? iconaUrl;
  final String? colore;
  final int ordine;
  final bool attiva;
  final bool disattivazioneProgrammata;
  final List<String>? giorniDisattivazione;
  final bool permittiDivisioni;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    this.organizationId,
    required this.nome,
    this.descrizione,
    this.icona,
    this.iconaUrl,
    this.colore,
    required this.ordine,
    required this.attiva,
    this.disattivazioneProgrammata = false,
    this.giorniDisattivazione,
    this.permittiDivisioni = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      nome: json['nome'] as String,
      descrizione: json['descrizione'] as String?,
      icona: json['icona'] as String?,
      iconaUrl: json['icona_url'] as String?,
      colore: json['colore'] as String?,
      ordine: json['ordine'] as int? ?? 0,
      attiva: json['attiva'] as bool? ?? true,
      disattivazioneProgrammata:
          json['disattivazione_programmata'] as bool? ?? false,
      giorniDisattivazione: (json['giorni_disattivazione'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      permittiDivisioni: json['permetti_divisioni'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'nome': nome,
      'descrizione': descrizione,
      'icona': icona,
      'icona_url': iconaUrl,
      'colore': colore,
      'ordine': ordine,
      'attiva': attiva,
      'disattivazione_programmata': disattivazioneProgrammata,
      'giorni_disattivazione': giorniDisattivazione,
      'permetti_divisioni': permittiDivisioni,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? organizationId,
    String? nome,
    String? descrizione,
    String? icona,
    String? iconaUrl,
    String? colore,
    int? ordine,
    bool? attiva,
    bool? disattivazioneProgrammata,
    List<String>? giorniDisattivazione,
    bool? permittiDivisioni,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      nome: nome ?? this.nome,
      descrizione: descrizione ?? this.descrizione,
      icona: icona ?? this.icona,
      iconaUrl: iconaUrl ?? this.iconaUrl,
      colore: colore ?? this.colore,
      ordine: ordine ?? this.ordine,
      attiva: attiva ?? this.attiva,
      disattivazioneProgrammata:
          disattivazioneProgrammata ?? this.disattivazioneProgrammata,
      giorniDisattivazione: giorniDisattivazione ?? this.giorniDisattivazione,
      permittiDivisioni: permittiDivisioni ?? this.permittiDivisioni,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
