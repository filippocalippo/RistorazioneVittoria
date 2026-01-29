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

      var orgId = response?['current_organization_id'] as String?;
      
      // Validate organization exists and user is still a member
      if (orgId != null) {
        final isValid = await _validateOrganizationMembership(orgId, userId);
        if (!isValid) {
          Logger.warning(
            'Organization $orgId not valid for user $userId, clearing context',
            tag: 'OrganizationProvider',
          );
          // Clear invalid organization context
          await client
              .from('profiles')
              .update({'current_organization_id': null})
              .eq('id', userId);
          orgId = null;
        }
      }
      
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
      Logger.error('Error building organization context: $e', tag: 'OrganizationProvider');
      return null;
    }
  }
  
  /// Validate that organization exists, is active, and user is a member
  Future<bool> _validateOrganizationMembership(String orgId, String userId) async {
    final client = Supabase.instance.client;
    
    try {
      // Check organization exists and is active
      final orgResponse = await client
          .from('organizations')
          .select('id, is_active, deleted_at')
          .eq('id', orgId)
          .maybeSingle();
      
      if (orgResponse == null) {
        Logger.debug('Organization $orgId not found', tag: 'OrganizationProvider');
        return false;
      }
      
      if (orgResponse['is_active'] != true) {
        Logger.debug('Organization $orgId is not active', tag: 'OrganizationProvider');
        return false;
      }
      
      if (orgResponse['deleted_at'] != null) {
        Logger.debug('Organization $orgId is deleted', tag: 'OrganizationProvider');
        return false;
      }
      
      // Check user is still a member
      final memberResponse = await client
          .from('organization_members')
          .select('id, is_active')
          .eq('organization_id', orgId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (memberResponse == null) {
        Logger.debug('User $userId is not a member of org $orgId', tag: 'OrganizationProvider');
        return false;
      }
      
      if (memberResponse['is_active'] != true) {
        Logger.debug('User $userId membership in org $orgId is not active', tag: 'OrganizationProvider');
        return false;
      }
      
      return true;
    } catch (e) {
      Logger.error('Error validating organization membership: $e', tag: 'OrganizationProvider');
      return false;
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
