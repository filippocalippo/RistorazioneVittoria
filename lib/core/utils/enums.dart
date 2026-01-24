/// Ruoli utente nel sistema
enum UserRole {
  customer,
  manager,
  kitchen,
  delivery;
  
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Cliente';
      case UserRole.manager:
        return 'Manager';
      case UserRole.kitchen:
        return 'Cucina';
      case UserRole.delivery:
        return 'Consegne';
    }
  }
  
  /// Converte da stringa a enum
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.customer,
    );
  }
}

/// Stati di un ordine
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  delivering,
  completed,
  cancelled;
  
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'In Attesa';
      case OrderStatus.confirmed:
        return 'Confermato';
      case OrderStatus.preparing:
        return 'In Preparazione';
      case OrderStatus.ready:
        return 'Pronto';
      case OrderStatus.delivering:
        return 'In Consegna';
      case OrderStatus.completed:
        return 'Completato';
      case OrderStatus.cancelled:
        return 'Annullato';
    }
  }
  
  /// Verifica se l'ordine e' ancora attivo
  bool get isActive => [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.delivering,
  ].contains(this);
  
  /// Verifica se l'ordine e' completato
  bool get isCompleted => this == OrderStatus.completed;
  
  /// Converte da stringa a enum
  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// Tipo di ordine
enum OrderType {
  delivery,
  takeaway,
  dineIn;
  
  String get dbValue {
    switch (this) {
      case OrderType.delivery:
        return 'delivery';
      case OrderType.takeaway:
        return 'takeaway';
      case OrderType.dineIn:
        return 'dine_in';
    }
  }
  
  String get displayName {
    switch (this) {
      case OrderType.delivery:
        return 'Consegna';
      case OrderType.takeaway:
        return 'Asporto';
      case OrderType.dineIn:
        return 'Sul Posto';
    }
  }
  
  /// Converte da stringa a enum (gestisce snake_case e camelCase)
  static OrderType fromString(String value) {
    final normalized = value.replaceAll('_', '').toLowerCase();
    return OrderType.values.firstWhere(
      (type) => type.name.toLowerCase() == normalized,
      orElse: () => OrderType.delivery,
    );
  }
}

/// Metodo di pagamento
enum PaymentMethod {
  cash,
  card,
  online;
  
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.card:
        return 'Carta';
      case PaymentMethod.online:
        return 'Online';
    }
  }
  
  /// Converte da stringa a enum
  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}
