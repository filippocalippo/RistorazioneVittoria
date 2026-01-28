import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';
import 'cart_provider.dart';

part 'organization_provider.g.dart';

/// Current organization ID for multi-tenant queries
///
/// This is THE source of truth for org context across the app.
/// All data-fetching providers should watch this.
@riverpod
class CurrentOrganization extends _$CurrentOrganization {
  @override
  Future<String?> build() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // Get user's current organization from profile
      final response = await client
          .from('profiles')
          .select('current_organization_id')
          .eq('id', userId)
          .maybeSingle();

      final orgId = response?['current_organization_id'] as String?;
      if (orgId != null) return orgId;

      // Fallback: get first organization user belongs to
      final orgs = await client
          .from('organization_members')
          .select('organization_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1);

      if (orgs.isNotEmpty) {
        final firstOrgId = orgs.first['organization_id'] as String;
        // Set as current
        await client
            .from('profiles')
            .update({'current_organization_id': firstOrgId})
            .eq('id', userId);
        return firstOrgId;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Switch to a different organization
  Future<void> switchOrganization(String organizationId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Clear cart BEFORE switching org to prevent cross-org data contamination
    await ref.read(cartProvider.notifier).clearForOrganization(organizationId);

    await client
        .from('profiles')
        .update({'current_organization_id': organizationId})
        .eq('id', userId);

    ref.invalidateSelf();
  }

  /// Join an organization and set as current (edge function handles membership)
  Future<void> joinAndSetCurrent(String organizationId) async {
    final client = Supabase.instance.client;

    // Ensure we have a fresh session
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Sessione non valida. Effettua nuovamente il login.');
    }

    // Check if token is expired (expires_at is in seconds since epoch)
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (session.expiresAt != null && session.expiresAt! < now) {
      // Token expired, try to refresh
      Logger.debug('Token expired, refreshing...', tag: 'OrganizationProvider');
      final response = await client.auth.refreshSession();
      if (response.user == null) {
        throw Exception('Sessione scaduta. Effettua nuovamente il login.');
      }
    }

    final accessToken = client.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw Exception('Impossibile ottenere il token di accesso.');
    }

    final response = await client.functions.invoke(
      'join-organization',
      body: {'organizationId': organizationId},
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : null;
      Logger.error(
        'Join org failed: ${response.status} - $error',
        tag: 'OrganizationProvider',
      );
      throw Exception(error ?? 'Errore durante la richiesta di join');
    }

    ref.invalidateSelf();
    ref.invalidate(userOrganizationsProvider);
  }

  /// Refresh organization context
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// List of organizations the current user belongs to
@riverpod
Future<List<Map<String, dynamic>>> userOrganizations(Ref ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await client
      .from('organization_members')
      .select('organization:organizations(*)')
      .eq('user_id', userId)
      .eq('is_active', true);

  return response
      .map((e) => e['organization'] as Map<String, dynamic>)
      .toList();
}

/// Check if user is member of specific organization
@riverpod
Future<bool> isOrganizationMember(Ref ref, String organizationId) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;

  final response = await client
      .from('organization_members')
      .select('id')
      .eq('user_id', userId)
      .eq('organization_id', organizationId)
      .eq('is_active', true)
      .maybeSingle();

  return response != null;
}

/// Get user's role in current organization
@riverpod
Future<String?> organizationRole(Ref ref) async {
  final orgId = await ref.watch(currentOrganizationProvider.future);
  if (orgId == null) return null;

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final response = await client
      .from('organization_members')
      .select('role')
      .eq('user_id', userId)
      .eq('organization_id', orgId)
      .maybeSingle();

  return response?['role'] as String?;
}
