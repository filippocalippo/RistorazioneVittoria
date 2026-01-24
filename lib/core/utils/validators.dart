import 'constants.dart';

/// Validatori per form e input
class Validators {
  /// Valida email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email richiesta';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Email non valida';
    }
    
    return null;
  }
  
  /// Valida password
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password richiesta';
    }
    
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password deve essere almeno ${AppConstants.minPasswordLength} caratteri';
    }
    
    // Verifica che contenga almeno una lettera e un numero
    if (!RegExp(r'[a-zA-Z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password deve contenere lettere e numeri';
    }
    
    return null;
  }
  
  /// Valida campo obbligatorio generico
  static String? required(String? value, [String fieldName = 'Campo']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName richiesto';
    }
    return null;
  }
  
  /// Valida numero di telefono
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Telefono richiesto';
    }
    
    // Rimuovi spazi e caratteri speciali per la validazione
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Verifica formato italiano o internazionale
    final phoneRegex = RegExp(r'^\+?[\d]{8,15}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      return 'Telefono non valido';
    }
    
    return null;
  }
  
  /// Valida prezzo
  static String? price(String? value) {
    if (value == null || value.isEmpty) {
      return 'Prezzo richiesto';
    }
    
    final price = double.tryParse(value.replaceAll(',', '.'));
    if (price == null) {
      return 'Prezzo non valido';
    }
    
    if (price < 0) {
      return 'Prezzo deve essere positivo';
    }
    
    if (price > 999999) {
      return 'Prezzo troppo alto';
    }
    
    return null;
  }
  
  /// Valida quantità
  static String? quantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantità richiesta';
    }
    
    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'Quantità non valida';
    }
    
    if (quantity <= 0) {
      return 'Quantità deve essere maggiore di 0';
    }
    
    if (quantity > 100) {
      return 'Quantità massima: 100';
    }
    
    return null;
  }
  
  /// Valida lunghezza massima
  static String? maxLength(String? value, int max, [String fieldName = 'Campo']) {
    if (value != null && value.length > max) {
      return '$fieldName può essere massimo $max caratteri';
    }
    return null;
  }
  
  /// Valida lunghezza minima
  static String? minLength(String? value, int min, [String fieldName = 'Campo']) {
    if (value != null && value.length < min) {
      return '$fieldName deve essere almeno $min caratteri';
    }
    return null;
  }
  
  /// Valida indirizzo
  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Indirizzo richiesto';
    }
    
    if (value.length < 5) {
      return 'Indirizzo troppo corto';
    }
    
    if (value.length > 200) {
      return 'Indirizzo troppo lungo';
    }
    
    return null;
  }
  
  /// Valida CAP italiano
  static String? cap(String? value) {
    if (value == null || value.isEmpty) {
      return null; // CAP opzionale
    }
    
    final capRegex = RegExp(r'^\d{5}$');
    if (!capRegex.hasMatch(value)) {
      return 'CAP non valido (5 cifre)';
    }
    
    return null;
  }
  
  /// Combina più validatori
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }
}
