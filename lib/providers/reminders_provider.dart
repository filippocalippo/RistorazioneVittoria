import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/order_reminder_model.dart';
import '../core/services/database_service.dart';
import 'organization_provider.dart';

part 'reminders_provider.g.dart';

/// Provider for active order reminders
/// Only shows non-completed reminders
@riverpod
class ActiveReminders extends _$ActiveReminders {
  @override
  Future<List<OrderReminderModel>> build() async {
    final db = DatabaseService();
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return await db.getActiveReminders(organizationId: orgId);
  }

  /// Refresh the reminders list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Create a new reminder
  Future<OrderReminderModel> create({
    required String ordineId,
    required String titolo,
    String? descrizione,
    ReminderPriority priorita = ReminderPriority.normal,
    DateTime? scadenza,
  }) async {
    final db = DatabaseService();
    final orgId = await ref.read(currentOrganizationProvider.future);
    final reminder = await db.createReminder(
      ordineId: ordineId,
      titolo: titolo,
      descrizione: descrizione,
      priorita: priorita,
      scadenza: scadenza,
      organizationId: orgId,
    );
    await refresh();
    return reminder;
  }

  /// Mark a reminder as completed
  Future<void> complete(String reminderId) async {
    final db = DatabaseService();
    final orgId = await ref.read(currentOrganizationProvider.future);
    await db.completeReminder(reminderId, organizationId: orgId);
    await refresh();
  }

  /// Delete a reminder permanently
  Future<void> delete(String reminderId) async {
    final db = DatabaseService();
    final orgId = await ref.read(currentOrganizationProvider.future);
    await db.deleteReminder(reminderId, organizationId: orgId);
    await refresh();
  }

  /// Update a reminder
  Future<void> updateReminder({
    required String reminderId,
    String? titolo,
    String? descrizione,
    ReminderPriority? priorita,
    DateTime? scadenza,
    bool? clearScadenza,
  }) async {
    final db = DatabaseService();
    final orgId = await ref.read(currentOrganizationProvider.future);
    await db.updateReminder(
      reminderId: reminderId,
      titolo: titolo,
      descrizione: descrizione,
      priorita: priorita,
      scadenza: scadenza,
      clearScadenza: clearScadenza,
      organizationId: orgId,
    );
    await refresh();
  }
}

/// Provider for reminders filtered by priority
@riverpod
List<OrderReminderModel> remindersByPriority(
  Ref ref,
  ReminderPriority priority,
) {
  final reminders = ref.watch(activeRemindersProvider).value ?? [];
  return reminders.where((r) => r.priorita == priority).toList();
}

/// Provider for urgent reminders (high + urgent priority)
@riverpod
List<OrderReminderModel> urgentReminders(Ref ref) {
  final reminders = ref.watch(activeRemindersProvider).value ?? [];
  return reminders
      .where(
        (r) =>
            r.priorita == ReminderPriority.urgent ||
            r.priorita == ReminderPriority.high,
      )
      .toList();
}

/// Provider for reminders of a specific order
@riverpod
Future<List<OrderReminderModel>> remindersByOrder(
  Ref ref,
  String orderId,
) async {
  final db = DatabaseService();
  final orgId = await ref.watch(currentOrganizationProvider.future);
  return await db.getRemindersByOrder(orderId, organizationId: orgId);
}

/// Count of active reminders (for badges/indicators)
@riverpod
int activeRemindersCount(Ref ref) {
  final reminders = ref.watch(activeRemindersProvider).value ?? [];
  return reminders.length;
}

/// Count of urgent/overdue reminders
@riverpod
int urgentRemindersCount(Ref ref) {
  final reminders = ref.watch(activeRemindersProvider).value ?? [];
  return reminders
      .where((r) => r.isOverdue || r.priorita == ReminderPriority.urgent)
      .length;
}
