import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'organization_provider.dart';

part 'organization_join_provider.g.dart';

class OrganizationPreview {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? address;
  final String? city;

  const OrganizationPreview({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.address,
    this.city,
  });

  factory OrganizationPreview.fromJson(Map<String, dynamic> json) {
    return OrganizationPreview(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }
}

@riverpod
class OrganizationJoin extends _$OrganizationJoin {
  @override
  Future<OrganizationPreview?> build() async {
    return null;
  }

  Future<OrganizationPreview?> lookupBySlug(String slug) async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('organizations')
          .select('id, name, slug, logo_url, address, city, is_active, deleted_at')
          .eq('slug', slug)
          .maybeSingle();

      if (response == null) return null;
      if (response['is_active'] != true) return null;
      if (response['deleted_at'] != null) return null;

      final preview = OrganizationPreview.fromJson(response);
      state = AsyncValue.data(preview);
      return preview;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> joinOrganization(String organizationId) async {
    await ref
        .read(currentOrganizationProvider.notifier)
        .joinAndSetCurrent(organizationId);
  }
}
