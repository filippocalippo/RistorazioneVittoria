import 'package:intl/intl.dart';

/// Formattatori per dati
class Formatters {
  // ========== Currency ==========
  
  static final _currencyFormat = NumberFormat.currency(
    symbol: '€',
    decimalDigits: 2,
    locale: 'it_IT',
  );
  
  /// Formatta un importo in valuta (es: 12.50 → "€12,50")
  static String currency(double amount) {
    return _currencyFormat.format(amount);
  }
  
  // ========== Date & Time ==========
  
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'it_IT');
  static final _timeFormat = DateFormat('HH:mm', 'it_IT');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');
  static final _shortDateFormat = DateFormat('dd MMM', 'it_IT');
  static final _fullDateFormat = DateFormat('EEEE dd MMMM yyyy', 'it_IT');
  
  /// Formatta data (es: 25/10/2025)
  static String date(DateTime date) {
    return _dateFormat.format(date);
  }
  
  /// Formatta ora (es: 14:30)
  /// Note: DateTime should already be in local time from parseDateTime()
  static String time(DateTime date) {
    return _timeFormat.format(date);
  }
  
  /// Formatta data e ora (es: 25/10/2025 14:30)
  static String dateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }
  
  /// Formatta data breve (es: 25 Ott)
  static String shortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }
  
  /// Formatta data completa (es: Venerdì 25 Ottobre 2025)
  static String fullDate(DateTime date) {
    return _fullDateFormat.format(date);
  }
  
  // ========== Phone ==========
  
  /// Formatta numero di telefono italiano
  /// +39 06 1234567 → +39 06 123 4567
  static String phone(String phone) {
    if (phone.startsWith('+39')) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        final prefix = digits.substring(0, 2); // 39
        final area = digits.substring(2, 4); // 06
        final first = digits.substring(4, 7); // 123
        final second = digits.substring(7); // 4567
        return '+$prefix $area $first $second';
      }
    }
    return phone;
  }
  
  // ========== Order ==========
  
  /// Formatta numero ordine (es: ORD-20251025-1234 → #ORD-20251025-1234)
  static String orderNumber(String number) {
    return '#$number';
  }
  
  // ========== Time Ago ==========
  
  /// Formatta tempo relativo (es: "2h fa", "Ora")
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return shortDate(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}g fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h fa';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m fa';
    } else {
      return 'Ora';
    }
  }
  
  // ========== Duration ==========
  
  /// Formatta durata in minuti (es: 90 → "1h 30m")
  static String duration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (mins == 0) {
      return '${hours}h';
    }
    
    return '${hours}h ${mins}m';
  }
  
  // ========== Distance ==========
  
  /// Formatta distanza in km (es: 1.5 → "1,5 km")
  static String distance(double km) {
    if (km < 1) {
      return '${(km * 1000).toInt()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
  
  // ========== Percentage ==========
  
  /// Formatta percentuale (es: 0.15 → "15%")
  static String percentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
  
  // ========== Capitalize ==========
  
  /// Capitalizza prima lettera (es: "mario" → "Mario")
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  /// Capitalizza ogni parola (es: "mario rossi" → "Mario Rossi")
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map(capitalize).join(' ');
  }
  
  // ========== Truncate ==========
  
  /// Tronca testo con ellipsis (es: "Testo lungo..." → "Testo...")
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
