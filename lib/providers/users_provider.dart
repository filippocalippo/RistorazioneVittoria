import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/supabase_config.dart';
import '../core/models/user_model.dart';
import '../core/utils/enums.dart';
import '../core/utils/logger.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

/// Provider per ottenere tutti gli utenti di una pizzeria
class PizzeriaUsersNotifier extends AsyncNotifier<List<UserModel>> {
  @override
  Future<List<UserModel>> build() async {
    final currentUser = ref.watch(authProvider).value;
    if (currentUser == null) {
      return [];
    }
    final orgId = await ref.watch(currentOrganizationProvider.future);
    if (orgId == null) {
      return [];
    }

    try {
      final response = await SupabaseConfig.client
          .from('organization_members')
          .select('role, is_active, profiles:profiles(*)')
          .eq('organization_id', orgId)
          .eq('is_active', true);

      final users = (response as List).map((data) {
        final profile = data['profiles'] as Map<String, dynamic>? ?? {};
        return _parseUserModel(profile, overrideRole: data['role'] as String?);
      }).toList();

      Logger.debug(
        'Loaded ${users.length} users for current pizzeria',
        tag: 'UsersProvider',
      );

      return users;
    } catch (e) {
      Logger.error('Failed to load users: $e', tag: 'UsersProvider', error: e);
      rethrow;
    }
  }

  /// Aggiorna il ruolo di un utente
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      final orgId = await ref.read(currentOrganizationProvider.future);
      if (orgId == null) return;

      await SupabaseConfig.client
          .from('organization_members')
          .update({
            'role': newRole.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('organization_id', orgId);

      Logger.debug(
        'Updated user role to ${newRole.name}',
        tag: 'UsersProvider',
      );

      // Refresh the list
      ref.invalidateSelf();
    } catch (e) {
      Logger.error(
        'Failed to update user role: $e',
        tag: 'UsersProvider',
        error: e,
      );
      rethrow;
    }
  }

  /// Attiva/disattiva un utente
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      final orgId = await ref.read(currentOrganizationProvider.future);
      if (orgId == null) return;

      await SupabaseConfig.client
          .from('organization_members')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('organization_id', orgId);

      Logger.debug(
        'Updated user status to ${isActive ? "active" : "inactive"}',
        tag: 'UsersProvider',
      );

      // Refresh the list
      ref.invalidateSelf();
    } catch (e) {
      Logger.error(
        'Failed to update user status: $e',
        tag: 'UsersProvider',
        error: e,
      );
      rethrow;
    }
  }

  UserModel _parseUserModel(
    Map<String, dynamic> data, {
    String? overrideRole,
  }) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return null;
    }

    return UserModel(
      id: data['id'] as String,
      email: data['email'] as String,
      nome: data['nome'] as String?,
      cognome: data['cognome'] as String?,
      telefono: data['telefono'] as String?,
      indirizzo: data['indirizzo'] as String?,
      citta: data['citta'] as String?,
      cap: data['cap'] as String?,
      ruolo: UserRole.fromString(overrideRole ?? (data['ruolo'] as String)),
      avatarUrl: data['avatar_url'] as String?,
      fcmToken: data['fcm_token'] as String?,
      attivo: data['attivo'] as bool? ?? true,
      ultimoAccesso: parseDateTime(data['ultimo_accesso']),
      createdAt: parseDateTime(data['created_at'])!,
      updatedAt: parseDateTime(data['updated_at']),
    );
  }
}

/// Provider per ottenere tutti gli utenti di una pizzeria
final pizzeriaUsersProvider = AsyncNotifierProvider<PizzeriaUsersNotifier, List<UserModel>>(
  PizzeriaUsersNotifier.new,
);

/// Provider per filtrare solo lo staff (non-customers)
final staffUsersProvider = Provider<List<UserModel>>((ref) {
  final usersAsync = ref.watch(pizzeriaUsersProvider);
  return usersAsync.when(
    data: (users) => users.where((user) => user.isStaff).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
});

/// Provider per filtrare solo i clienti
final customerUsersProvider = Provider<List<UserModel>>((ref) {
  final usersAsync = ref.watch(pizzeriaUsersProvider);
  return usersAsync.when(
    data: (users) => users.where((user) => user.isCustomer).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
});
