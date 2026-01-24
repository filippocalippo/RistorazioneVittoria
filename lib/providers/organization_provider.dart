import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Fallback: get any active organization (for single-tenant compatibility)
      final anyOrg = await client
          .from('organizations')
          .select('id')
          .eq('is_active', true)
          .limit(1);

      if (anyOrg.isNotEmpty) {
        return anyOrg.first['id'] as String;
      }

      return null;
    } catch (e) {
      // Fallback for compatibility
      try {
        final orgs = await client
            .from('organizations')
            .select('id')
            .eq('is_active', true)
            .limit(1);
        if (orgs.isNotEmpty) {
          return orgs.first['id'] as String;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Switch to a different organization
  Future<void> switchOrganization(String organizationId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client
        .from('profiles')
        .update({'current_organization_id': organizationId})
        .eq('id', userId);

    ref.invalidateSelf();
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
