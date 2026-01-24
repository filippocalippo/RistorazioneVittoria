import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';

part 'order_reminder_model.freezed.dart';
part 'order_reminder_model.g.dart';

/// Priority levels for reminders
enum ReminderPriority {
  low,
  normal,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case ReminderPriority.low:
        return 'Bassa';
      case ReminderPriority.normal:
        return 'Normale';
      case ReminderPriority.high:
        return 'Alta';
      case ReminderPriority.urgent:
        return 'Urgente';
    }
  }

  Color get color {
    switch (this) {
      case ReminderPriority.low:
        return const Color(0xFF6B7280); // Gray
      case ReminderPriority.normal:
        return const Color(0xFF3B82F6); // Blue
      case ReminderPriority.high:
        return const Color(0xFFF59E0B); // Orange/Amber
      case ReminderPriority.urgent:
        return const Color(0xFFEF4444); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReminderPriority.low:
        return const Color(0xFFF3F4F6);
      case ReminderPriority.normal:
        return const Color(0xFFDBEAFE);
      case ReminderPriority.high:
        return const Color(0xFFFEF3C7);
      case ReminderPriority.urgent:
        return const Color(0xFFFEE2E2);
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderPriority.low:
        return Icons.arrow_downward_rounded;
      case ReminderPriority.normal:
        return Icons.remove_rounded;
      case ReminderPriority.high:
        return Icons.arrow_upward_rounded;
      case ReminderPriority.urgent:
        return Icons.priority_high_rounded;
    }
  }

  static ReminderPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return ReminderPriority.low;
      case 'high':
        return ReminderPriority.high;
      case 'urgent':
        return ReminderPriority.urgent;
      default:
        return ReminderPriority.normal;
    }
  }
}

@freezed
class OrderReminderModel with _$OrderReminderModel {
  const OrderReminderModel._();

  const factory OrderReminderModel({
    required String id,
    required String ordineId,
    required String titolo,
    String? descrizione,
    @Default(ReminderPriority.normal) ReminderPriority priorita,
    DateTime? scadenza,
    @Default(false) bool completato,
    DateTime? completatoAt,
    String? createdBy,
    required DateTime createdAt,
    DateTime? updatedAt,
    // Joined fields from order (populated when fetching with order details)
    String? numeroOrdine,
    String? nomeCliente,
  }) = _OrderReminderModel;

  /// Parse from Supabase response with joined order data
  factory OrderReminderModel.fromSupabase(Map<String, dynamic> json) {
    // Handle priority conversion from string
    final prioritaString = json['priorita'] as String? ?? 'normal';
    final priorita = ReminderPriority.fromString(prioritaString);

    // Handle joined order data
    String? numeroOrdine;
    String? nomeCliente;
    final ordiniData = json['ordini'];
    if (ordiniData is Map<String, dynamic>) {
      numeroOrdine = ordiniData['numero_ordine'] as String?;
      nomeCliente = ordiniData['nome_cliente'] as String?;
    }

    return OrderReminderModel(
      id: json['id'] as String,
      ordineId: json['ordine_id'] as String,
      titolo: json['titolo'] as String,
      descrizione: json['descrizione'] as String?,
      priorita: priorita,
      scadenza: json['scadenza'] != null
          ? DateTime.parse(json['scadenza'] as String)
          : null,
      completato: json['completato'] as bool? ?? false,
      completatoAt: json['completato_at'] != null
          ? DateTime.parse(json['completato_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      numeroOrdine: numeroOrdine,
      nomeCliente: nomeCliente,
    );
  }

  factory OrderReminderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderReminderModelFromJson(json);

  /// Check if the reminder is overdue
  bool get isOverdue {
    if (scadenza == null || completato) return false;
    return DateTime.now().isAfter(scadenza!);
  }

  /// Check if the reminder is due soon (within 1 hour)
  bool get isDueSoon {
    if (scadenza == null || completato || isOverdue) return false;
    final difference = scadenza!.difference(DateTime.now());
    return difference.inHours < 1 && difference.inMinutes > 0;
  }

  /// Get display text for time remaining or overdue
  String? get timeStatus {
    if (scadenza == null) return null;
    if (completato) return 'Completato';

    final now = DateTime.now();
    final difference = scadenza!.difference(now);

    if (difference.isNegative) {
      final overdue = now.difference(scadenza!);
      if (overdue.inDays > 0) {
        return 'Scaduto da ${overdue.inDays}g';
      } else if (overdue.inHours > 0) {
        return 'Scaduto da ${overdue.inHours}h';
      } else {
        return 'Scaduto da ${overdue.inMinutes}m';
      }
    } else {
      if (difference.inDays > 0) {
        return 'Scade tra ${difference.inDays}g';
      } else if (difference.inHours > 0) {
        return 'Scade tra ${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return 'Scade tra ${difference.inMinutes}m';
      } else {
        return 'Scade ora';
      }
    }
  }

  /// Convert to JSON for database insert
  Map<String, dynamic> toInsertJson() {
    return {
      'ordine_id': ordineId,
      'titolo': titolo,
      'descrizione': descrizione,
      'priorita': priorita.name,
      'scadenza': scadenza?.toUtc().toIso8601String(),
      'created_by': createdBy,
    };
  }
}
