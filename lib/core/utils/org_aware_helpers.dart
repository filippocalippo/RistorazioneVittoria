/// Organization-aware database helpers
/// 
/// Use these extensions to easily add organization filtering to queries.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

extension OrganizationAwareQuery on PostgrestFilterBuilder {
  /// Add organization filter if orgId is provided
  PostgrestFilterBuilder orgFilter(String? organizationId) {
    if (organizationId != null) {
      return eq('organization_id', organizationId);
    }
    return this;
  }
}

extension OrganizationAwareInsert on Map<String, dynamic> {
  /// Add organization_id to insert payload
  Map<String, dynamic> withOrgId(String? organizationId) {
    if (organizationId != null) {
      this['organization_id'] = organizationId;
    }
    return this;
  }
}
