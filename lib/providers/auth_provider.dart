import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/auth_service.dart';
import '../core/models/user_model.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import '../core/utils/enums.dart';
import 'organization_provider.dart';

part 'auth_provider.g.dart';

@riverpod
AuthService authService(Ref ref) {
  return AuthService();
}

@riverpod
class Auth extends _$Auth {
  @override
  Future<UserModel?> build() async {
    final authService = ref.watch(authServiceProvider);

    // Ascolta i cambiamenti di stato auth
    final subscription = authService.authStateChanges.listen((event) async {
      Logger.info('Auth state change event: ${event.event}', tag: 'Auth');
      switch (event.event) {
        case AuthChangeEvent.signedIn:
          // Don't invalidate on signedIn - the signIn() method handles state update
          // Invalidating here would cause the state to rebuild and potentially lose the user data
          Logger.info(
            'SignedIn event received, state already updated by signIn()',
            tag: 'Auth',
          );
          break;
        case AuthChangeEvent.tokenRefreshed:
          // Token refresh doesn't change user data, no need to rebuild
          Logger.debug('Token refreshed, keeping current state', tag: 'Auth');
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted: // ignore: deprecated_member_use
          // Clear state so UI reacts immediately
          Logger.info('Clearing auth state due to ${event.event}', tag: 'Auth');
          state = const AsyncValue.data(null);
          break;
        default:
          Logger.debug('Ignoring auth event: ${event.event}', tag: 'Auth');
          break;
      }

      final refreshedUser = event.session?.user;
      if (event.event == AuthChangeEvent.tokenRefreshed &&
          refreshedUser != null) {
        // Keep last access timestamp aligned with fresh tokens
        await authService.updateLastAccess(refreshedUser.id);
      }
    });

    ref.onDispose(() {
      subscription.cancel();
    });

    final currentUser = authService.currentUser;
    if (currentUser == null) {
      Logger.debug('No current user in session', tag: 'Auth');
      return null;
    }

    Logger.debug('Restoring session user from Supabase', tag: 'Auth');

    try {
      // Load profile with current organization ID
      final profileResponse = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .single();

      final currentOrgId = profileResponse['current_organization_id'] as String?;
      Map<String, dynamic> profileData = Map<String, dynamic>.from(profileResponse);

      if (currentOrgId != null) {
        // Get role from organization_members for the current organization
        final memberResponse = await SupabaseConfig.client
            .from('organization_members')
            .select('role')
            .eq('user_id', currentUser.id)
            .eq('organization_id', currentOrgId)
            .eq('is_active', true)
            .maybeSingle();

        if (memberResponse != null) {
          profileData['ruolo'] = memberResponse['role'] as String;
          Logger.debug('Using org role: ${memberResponse['role']}', tag: 'Auth');
        } else {
          Logger.warning('No active membership in current org, using default role', tag: 'Auth');
        }
      } else {
        Logger.debug('No current organization set, using default role', tag: 'Auth');
      }

      final profile = UserModel.fromJson(profileData);

      Logger.debug('Profile loaded from session with role: ${profile.ruolo.name}', tag: 'Auth');
      return profile;
    } catch (e) {
      Logger.error(
        'Failed to load profile from session: $e',
        tag: 'Auth',
        error: e,
      );
      // Se fallisce, fai logout per pulire la sessione corrotta
      await authService.signOut();
      return null;
    }
  }


  Future<void> signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    state = const AsyncValue.data(null);
    Logger.debug('Sign out complete, auth state cleared', tag: 'Auth');
  }

  Future<void> signInWithGoogle() async {
    try {
      final authService = ref.read(authServiceProvider);
      Logger.debug('Attempting Google sign-in', tag: 'Auth');

      final user = await authService.signInWithGoogle();
      Logger.debug('Google sign-in successful', tag: 'Auth');

      await authService.updateLastAccess(user.id);
      Logger.debug('Last access timestamp updated', tag: 'Auth');

      // Update state with user data - this triggers the router and notifies watchers
      state = AsyncValue.data(user);
      Logger.debug('State updated with authenticated user', tag: 'Auth');
    } catch (e, stack) {
      Logger.error('Google sign-in error: $e', tag: 'Auth', error: e);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateFcmToken(String token) async {
    final user = state.value;
    if (user != null) {
      final authService = ref.read(authServiceProvider);
      await authService.updateFcmToken(user.id, token);
    }
  }

  /// Reload only the organization role without invalidating the entire auth state.
  /// This prevents the race condition when switching organizations.
  /// Called by RouterNotifier when currentOrganizationProvider changes.
  Future<void> reloadOrgRole() async {
    final currentUser = state.value;
    if (currentUser == null) {
      Logger.debug('No user to reload role for', tag: 'Auth');
      return;
    }

    Logger.debug('Reloading org role for user: ${currentUser.id}', tag: 'Auth');

    try {
      final client = Supabase.instance.client;

      // Get current organization ID from the provider
      final currentOrgId = await ref.read(currentOrganizationProvider.future);

      if (currentOrgId == null) {
        // No organization - use default customer role
        Logger.debug('No organization set, using default customer role', tag: 'Auth');
        final updatedUser = currentUser.copyWith(ruolo: UserRole.customer);
        state = AsyncValue.data(updatedUser);
        return;
      }

      // Get role for the new organization
      final memberResponse = await client
          .from('organization_members')
          .select('role')
          .eq('user_id', currentUser.id)
          .eq('organization_id', currentOrgId)
          .eq('is_active', true)
          .maybeSingle();

      if (memberResponse != null) {
        final roleString = memberResponse['role'] as String;
        final role = UserRole.fromString(roleString);
        final updatedUser = currentUser.copyWith(ruolo: role);
        state = AsyncValue.data(updatedUser);
        Logger.debug('Org role reloaded successfully: $roleString', tag: 'Auth');
      } else {
        // No active membership - use default customer role
        Logger.warning('No active membership in current org, using default customer role', tag: 'Auth');
        final updatedUser = currentUser.copyWith(ruolo: UserRole.customer);
        state = AsyncValue.data(updatedUser);
      }
    } catch (e, stack) {
      Logger.error(
        'Failed to reload org role: $e',
        tag: 'Auth',
        error: e,
        stackTrace: stack,
      );
      // Don't change state on error - keep existing user data
    }
  }

  /// Allowed fields that users can update on their own profile.
  /// Security: ruolo, attivo, and other sensitive fields are explicitly excluded
  /// to prevent privilege escalation attacks.
  static const _allowedProfileFields = {
    'nome',
    'cognome',
    'telefono',
    'avatar_url',
  };

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = state.value;
    if (user == null) return;

    try {
      // SECURITY: Sanitize updates to only allow safe fields
      // This prevents privilege escalation by removing sensitive fields like 'ruolo'
      final sanitizedUpdates = <String, dynamic>{};
      for (final key in updates.keys) {
        if (_allowedProfileFields.contains(key)) {
          sanitizedUpdates[key] = updates[key];
        } else {
          Logger.warning(
            'Blocked attempt to update restricted field: $key',
            tag: 'Auth',
          );
        }
      }

      if (sanitizedUpdates.isEmpty) {
        Logger.debug('No valid fields to update', tag: 'Auth');
        return;
      }

      // Update in database with sanitized fields only
      await SupabaseConfig.client
          .from('profiles')
          .update({
            ...sanitizedUpdates,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

      // Create updated user model manually to avoid router redirect
      final updatedUser = UserModel(
        id: user.id,
        email: user.email,
        nome: sanitizedUpdates['nome'] ?? user.nome,
        cognome: sanitizedUpdates['cognome'] ?? user.cognome,
        telefono: sanitizedUpdates['telefono'] ?? user.telefono,
        indirizzo: user.indirizzo,
        citta: user.citta,
        cap: user.cap,
        ruolo: user.ruolo,
        avatarUrl: user.avatarUrl,
        fcmToken: user.fcmToken,
        attivo: user.attivo,
        ultimoAccesso: user.ultimoAccesso,
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update state directly without invalidating to prevent router redirect
      state = AsyncValue.data(updatedUser);
      
      // Note: Dependent providers will automatically rebuild when they detect
      // the auth state change through their ref.watch(authProvider) calls.
    } catch (e) {
      Logger.error('Failed to update profile: $e', tag: 'Auth', error: e);
      rethrow;
    }
  }
}

/// Provider per verificare se l'utente è autenticato
@riverpod
bool isAuthenticated(Ref ref) {
  final authState = ref.watch(authProvider);
  return authState.value != null;
}

/// Provider per il ruolo dell'utente corrente
@riverpod
String? userRole(Ref ref) {
  final authState = ref.watch(authProvider);
  return authState.value?.ruolo.name;
}
