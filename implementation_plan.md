# SaaS Conversion Implementation Plan
## Vittoria Ristorazione (Rotante) - Multi-Tenant Transformation

**Document Version:** 1.0
**Date:** January 2026
**Project:** Convert single-tenant pizzeria management app to multi-tenant SaaS platform

---

## Executive Summary

This document provides a complete roadmap for transforming the Rotante pizzeria management application from a single-tenant system into a scalable, multi-tenant SaaS platform. The current codebase is well-structured with clean architecture patterns, making it a suitable candidate for SaaS conversion. However, significant changes are required as the application was fundamentally designed for a single pizzeria.

### Current State Assessment

| Aspect | Status | Notes |
|--------|--------|-------|
| Architecture | Good | Clean Architecture with feature-based organization |
| Code Quality | Medium-High | Well-typed, uses Riverpod, Freezed |
| Multi-tenancy | Not Present | Zero tenant isolation currently |
| Database Schema | Single-tenant | No `tenant_id` columns |
| RLS Policies | Role-based only | 97 policies, none tenant-aware |
| Test Coverage | Very Low | Only 1 test file found |
| Documentation | Minimal | No API docs, limited inline comments |

### Estimated Total Effort

| Phase | Duration | Team Size |
|-------|----------|-----------|
| Phase 1: Foundation | 3-4 weeks | 2 developers |
| Phase 2: Database | 2-3 weeks | 2 developers |
| Phase 3: Backend | 2-3 weeks | 2 developers |
| Phase 4: Frontend | 3-4 weeks | 2 developers |
| Phase 5: Infrastructure | 2-3 weeks | 1-2 developers |
| Phase 6: Testing & QA | 2-3 weeks | 2 developers |
| **Total** | **14-20 weeks** | 2-3 developers |

---

## Table of Contents

1. [Architecture Decision: Multi-Tenancy Model](#1-architecture-decision-multi-tenancy-model)
2. [Phase 1: Foundation & Planning](#phase-1-foundation--planning)
3. [Phase 2: Database Schema Changes](#phase-2-database-schema-changes)
4. [Phase 3: Backend & Edge Functions](#phase-3-backend--edge-functions)
5. [Phase 4: Frontend Application](#phase-4-frontend-application)
6. [Phase 5: Infrastructure & DevOps](#phase-5-infrastructure--devops)
7. [Phase 6: Testing & Quality Assurance](#phase-6-testing--quality-assurance)
8. [Migration Strategy for Existing Data](#migration-strategy-for-existing-data)
9. [Risk Assessment & Mitigation](#risk-assessment--mitigation)
10. [Recommended Implementation Order](#recommended-implementation-order)

---

## 1. Architecture Decision: Multi-Tenancy Model

### Options Analysis

#### Option A: Separate Database per Tenant (Silo Model)
```
Tenant A ──> Supabase Project A ──> Database A
Tenant B ──> Supabase Project B ──> Database B
Tenant C ──> Supabase Project C ──> Database C
```

**Pros:**
- Complete data isolation
- Independent scaling
- Simpler security model
- Can customize schema per tenant
- Easy compliance (GDPR, data residency)

**Cons:**
- Higher infrastructure cost (~$25/month minimum per tenant)
- Complex deployment (N projects to manage)
- No cross-tenant analytics
- Harder to push updates

#### Option B: Shared Database with RLS (Pool Model) - RECOMMENDED
```
All Tenants ──> Single Supabase Project ──> Shared Database with RLS
                                              └── tenant_id on all rows
```

**Pros:**
- Lower infrastructure cost
- Single deployment
- Easier updates and maintenance
- Cross-tenant analytics possible
- Better resource utilization

**Cons:**
- Complex RLS policies required
- Single point of failure
- One bug can affect all tenants
- Harder compliance (but achievable)

#### Option C: Hybrid Model
```
Shared Auth & Config ──> Central Supabase Project
Tenant Data ──────────> Separate Projects (on demand)
```

**Pros:**
- Balance of isolation and efficiency
- Can upgrade high-value tenants to dedicated

**Cons:**
- Most complex to implement
- Multiple codepaths

### Recommendation: Option B (Shared Database with RLS)

For a pizzeria SaaS targeting small-medium businesses, the shared model provides the best balance of:
- Cost efficiency for you and customers
- Manageable complexity
- Quick time to market

---

## Phase 1: Foundation & Planning

### 1.1 Create Tenant/Organization Model

**Priority:** CRITICAL
**Effort:** 3-5 days

Create the core tenant entity that all other data will reference.

```sql
-- New table: organizations (tenants)
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL, -- URL-friendly identifier

    -- Branding
    logo_url TEXT,
    primary_color TEXT DEFAULT '#FF5722',
    secondary_color TEXT DEFAULT '#FFC107',

    -- Contact
    email TEXT NOT NULL,
    phone TEXT,
    website TEXT,

    -- Address
    address TEXT,
    city TEXT,
    postal_code TEXT,
    province TEXT,
    country TEXT DEFAULT 'IT',
    latitude NUMERIC,
    longitude NUMERIC,

    -- Subscription
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'starter', 'professional', 'enterprise')),
    subscription_status TEXT DEFAULT 'active' CHECK (subscription_status IN ('active', 'past_due', 'cancelled', 'trialing')),
    trial_ends_at TIMESTAMPTZ,
    subscription_ends_at TIMESTAMPTZ,
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,

    -- Limits (based on tier)
    max_staff_members INTEGER DEFAULT 3,
    max_menu_items INTEGER DEFAULT 50,
    max_orders_per_month INTEGER DEFAULT 500,

    -- Features (JSON for flexibility)
    features JSONB DEFAULT '{
        "delivery": true,
        "takeaway": true,
        "dine_in": false,
        "online_payments": false,
        "inventory": false,
        "analytics": false,
        "api_access": false,
        "white_label": false,
        "priority_support": false
    }'::jsonb,

    -- Settings
    timezone TEXT DEFAULT 'Europe/Rome',
    locale TEXT DEFAULT 'it_IT',
    currency TEXT DEFAULT 'EUR',

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),

    -- Soft delete
    deleted_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_stripe_customer ON organizations(stripe_customer_id);
CREATE INDEX idx_organizations_subscription ON organizations(subscription_tier, subscription_status);
```

### 1.2 User-Organization Membership

**Priority:** CRITICAL
**Effort:** 2-3 days

```sql
-- New table: organization_members
CREATE TABLE public.organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Role within this organization
    role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('owner', 'manager', 'kitchen', 'delivery', 'customer')),

    -- Invitation tracking
    invited_by UUID REFERENCES auth.users(id),
    invited_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    invitation_token TEXT,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    -- Constraints
    UNIQUE(organization_id, user_id)
);

-- Indexes
CREATE INDEX idx_org_members_user ON organization_members(user_id);
CREATE INDEX idx_org_members_org ON organization_members(organization_id);
CREATE INDEX idx_org_members_role ON organization_members(organization_id, role);
```

### 1.3 Update Profiles Table

**Priority:** CRITICAL
**Effort:** 1-2 days

```sql
-- Add organization context to profiles
ALTER TABLE profiles
ADD COLUMN current_organization_id UUID REFERENCES organizations(id),
ADD COLUMN is_super_admin BOOLEAN DEFAULT false;

-- Super admins can access all organizations (for platform support)
```

### 1.4 Create Helper Functions

**Priority:** HIGH
**Effort:** 2-3 days

```sql
-- Get current user's active organization
CREATE OR REPLACE FUNCTION get_current_organization_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT current_organization_id
    FROM profiles
    WHERE id = auth.uid();
$$;

-- Check if user is member of organization
CREATE OR REPLACE FUNCTION is_organization_member(org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = org_id
        AND user_id = auth.uid()
        AND is_active = true
    );
$$;

-- Check if user has specific role in organization
CREATE OR REPLACE FUNCTION has_organization_role(org_id UUID, required_role TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = org_id
        AND user_id = auth.uid()
        AND role = required_role
        AND is_active = true
    );
$$;

-- Check if user is manager or owner
CREATE OR REPLACE FUNCTION is_organization_admin(org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organization_members
        WHERE organization_id = org_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'manager')
        AND is_active = true
    );
$$;
```

---

## Phase 2: Database Schema Changes

### 2.1 Add Tenant ID to All Tables

**Priority:** CRITICAL
**Effort:** 5-7 days

Every table that contains tenant-specific data must have an `organization_id` column.

#### Tables Requiring `organization_id`:

| Table | Current Rows | Migration Complexity |
|-------|--------------|---------------------|
| menu_items | 93 | Low |
| categorie_menu | 6 | Low |
| ingredients | 81 | Low |
| sizes_master | ~10 | Low |
| menu_item_sizes | ~50 | Low |
| menu_item_extra_ingredients | ~100 | Low |
| menu_item_included_ingredients | ~100 | Low |
| ingredient_size_prices | ~50 | Low |
| ordini | 2,505 | Medium |
| ordini_items | ~10,000 | Medium |
| delivery_zones | ~5 | Low |
| allowed_cities | ~10 | Low |
| promotional_banners | ~5 | Low |
| notifiche | ~500 | Low |
| cashier_customers | ~20 | Low |
| order_reminders | ~10 | Low |
| user_addresses | ~50 | Low |
| daily_order_counters | ~30 | Low |
| inventory_logs | ~100 | Low |
| ingredient_consumption_rules | ~20 | Low |
| business_rules | 1 | Convert to org settings |
| delivery_configuration | 1 | Convert to org settings |
| display_branding | 1 | Convert to org settings |
| kitchen_management | 1 | Convert to org settings |
| order_management | 1 | Convert to org settings |

#### Migration Script Template:

```sql
-- Example: Add organization_id to menu_items
ALTER TABLE menu_items
ADD COLUMN organization_id UUID REFERENCES organizations(id);

-- Create index for performance
CREATE INDEX idx_menu_items_org ON menu_items(organization_id);

-- Backfill existing data (assign to first organization)
UPDATE menu_items
SET organization_id = (SELECT id FROM organizations LIMIT 1)
WHERE organization_id IS NULL;

-- Make NOT NULL after backfill
ALTER TABLE menu_items
ALTER COLUMN organization_id SET NOT NULL;
```

### 2.2 Consolidate Settings Tables

**Priority:** HIGH
**Effort:** 3-4 days

Current separate settings tables should be consolidated or linked to organizations:

```sql
-- Option 1: Add organization_id to existing tables
ALTER TABLE business_rules ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE delivery_configuration ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE display_branding ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE kitchen_management ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE order_management ADD COLUMN organization_id UUID REFERENCES organizations(id);

-- Option 2: Consolidate into single JSONB column on organizations (simpler)
-- Already included in organizations table as 'features' JSONB
```

### 2.3 Update All RLS Policies

**Priority:** CRITICAL
**Effort:** 5-7 days

All 97 existing RLS policies must be updated to include tenant isolation.

#### Current Policy Pattern (Role-based only):
```sql
-- CURRENT: Only checks role
CREATE POLICY "Managers can update menu" ON menu_items
FOR UPDATE TO authenticated
USING (
    (SELECT ruolo FROM profiles WHERE id = auth.uid()) = 'manager'
);
```

#### New Policy Pattern (Role + Tenant):
```sql
-- NEW: Checks role AND tenant membership
CREATE POLICY "Managers can update menu" ON menu_items
FOR UPDATE TO authenticated
USING (
    organization_id = get_current_organization_id()
    AND is_organization_admin(organization_id)
);
```

#### RLS Policy Migration Checklist:

- [ ] organizations (new table policies)
- [ ] organization_members (new table policies)
- [ ] profiles (add org context)
- [ ] menu_items (add org filter)
- [ ] categorie_menu (add org filter)
- [ ] ingredients (add org filter)
- [ ] sizes_master (add org filter)
- [ ] menu_item_sizes (add org filter)
- [ ] menu_item_extra_ingredients (add org filter)
- [ ] menu_item_included_ingredients (add org filter)
- [ ] ingredient_size_prices (add org filter)
- [ ] ordini (add org filter)
- [ ] ordini_items (add org filter via ordini)
- [ ] delivery_zones (add org filter)
- [ ] allowed_cities (add org filter)
- [ ] promotional_banners (add org filter)
- [ ] notifiche (add org filter)
- [ ] cashier_customers (add org filter)
- [ ] order_reminders (add org filter)
- [ ] user_addresses (keep user-based, customers can belong to multiple orgs)
- [ ] daily_order_counters (add org filter)
- [ ] inventory_logs (add org filter)
- [ ] ingredient_consumption_rules (add org filter)
- [ ] business_rules (add org filter)
- [ ] delivery_configuration (add org filter)
- [ ] display_branding (add org filter)
- [ ] kitchen_management (add org filter)
- [ ] order_management (add org filter)
- [ ] dashboard_security (add org filter)
- [ ] payment_transactions (add org filter)

### 2.4 Update Database Functions

**Priority:** HIGH
**Effort:** 2-3 days

All 27 existing database functions must be audited:

| Function | Change Required |
|----------|-----------------|
| adjust_ingredient_stock | Add org_id parameter |
| assign_order_number_trigger | Scope counter to org |
| cancel_own_order | Add org validation |
| check_and_deactivate_categories | Add org filter |
| ensure_single_default_address | Keep as-is (user-scoped) |
| generate_numero_ordine_v2 | Scope to organization |
| get_banner_analytics | Add org_id parameter |
| get_ingredient_price | Add org context |
| get_my_role | Return role for current org |
| get_recommended_ingredients | Add org filter |
| get_top_products_by_category | Add org_id parameter |
| handle_new_user | Create org membership |
| increment_banner_click | Add org validation |
| increment_banner_view | Add org validation |
| notify_order_status_change | Add org context |
| prevent_critical_updates | Keep logic, add org check |
| prevent_role_change | Update for org context |
| prevent_self_role_escalation | Update for org context |
| set_ingredient_stock | Add org_id parameter |
| update_ingredient_stock | Add org_id parameter |

### 2.5 Update Triggers

**Priority:** HIGH
**Effort:** 1-2 days

Critical trigger requiring update:

```sql
-- Current: Hardcoded webhook URL
CREATE TRIGGER send_push_notification
AFTER INSERT ON notifiche
FOR EACH ROW
EXECUTE FUNCTION supabase_functions.http_request(
    'https://cnsuywzypkgqolersryr.supabase.co/functions/v1/send-notification',
    ...
);

-- New: Must dynamically route based on configuration
-- Or use a single webhook that handles multi-tenant routing
```

---

## Phase 3: Backend & Edge Functions

### 3.1 Update Edge Functions for Multi-Tenancy

**Priority:** CRITICAL
**Effort:** 5-7 days

#### 3.1.1 create-payment-intent

Current issues:
- Single Stripe account
- No tenant context

Changes required:
```typescript
// Add organization context
interface PaymentIntentRequest {
    organizationId: string;  // NEW
    items: CartItem[];
    // ... existing fields
}

// Fetch organization's Stripe credentials
const { data: org } = await supabaseAdmin
    .from('organizations')
    .select('stripe_account_id, stripe_secret_key')
    .eq('id', organizationId)
    .single();

// Use organization's Stripe account (Stripe Connect)
const stripe = new Stripe(org.stripe_secret_key);
```

#### 3.1.2 place-order

Changes required:
- Add `organization_id` to order creation
- Validate user belongs to organization
- Use organization-specific settings

#### 3.1.3 send-notification

Changes required:
- Route notifications to correct Firebase project (if per-tenant)
- Or use single Firebase with topic-based routing per organization

#### 3.1.4 verify-payment

Changes required:
- Validate payment belongs to organization
- Update organization's order with payment status

### 3.2 Implement Stripe Connect

**Priority:** HIGH
**Effort:** 5-7 days

For SaaS payments, implement Stripe Connect:

```typescript
// New Edge Function: connect-stripe-account
serve(async (req: Request) => {
    const { organizationId } = await req.json();

    // Create Stripe Connect account for organization
    const account = await stripe.accounts.create({
        type: 'standard',
        country: 'IT',
        email: organization.email,
        metadata: {
            organization_id: organizationId
        }
    });

    // Save account ID
    await supabaseAdmin
        .from('organizations')
        .update({ stripe_account_id: account.id })
        .eq('id', organizationId);

    // Generate onboarding link
    const accountLink = await stripe.accountLinks.create({
        account: account.id,
        refresh_url: `${APP_URL}/settings/payments?refresh=true`,
        return_url: `${APP_URL}/settings/payments?success=true`,
        type: 'account_onboarding',
    });

    return new Response(JSON.stringify({ url: accountLink.url }));
});
```

### 3.3 New Edge Functions Required

| Function | Purpose |
|----------|---------|
| create-organization | Onboard new tenant |
| invite-team-member | Send invitation email |
| accept-invitation | Process invitation acceptance |
| connect-stripe-account | Stripe Connect onboarding |
| sync-subscription | Handle subscription webhooks |
| export-data | GDPR data export |
| delete-organization | GDPR right to deletion |

---

## Phase 4: Frontend Application

### 4.1 Remove Hardcoded Values

**Priority:** CRITICAL
**Effort:** 3-5 days

#### File: `lib/core/utils/constants.dart`

```dart
// REMOVE these hardcoded values:
static const String pizzeriaName = 'Pizzeria Rotante';  // DELETE
static const String pizzeriaLogo = 'assets/icons/LOGO.jpg';  // DELETE

// KEEP these (application-level constants):
static const int defaultPageSize = 20;
static const int debounceMilliseconds = 500;
// etc.
```

#### File: `lib/main.dart` (Line 82-84)

```dart
// REMOVE hardcoded project ID:
const projectId = 'cnsuywzypkgqolersryr';  // DELETE

// REPLACE with environment variable or organization config
```

### 4.2 Create Organization Context Provider

**Priority:** CRITICAL
**Effort:** 3-5 days

```dart
// lib/core/providers/organization_provider.dart

@riverpod
class CurrentOrganization extends _$CurrentOrganization {
  @override
  Future<OrganizationModel?> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) return null;

    final db = ref.watch(databaseServiceProvider);
    return db.getCurrentOrganization(user.id);
  }

  Future<void> switchOrganization(String orgId) async {
    final db = ref.watch(databaseServiceProvider);
    await db.setCurrentOrganization(orgId);
    ref.invalidateSelf();
  }
}

@riverpod
Future<List<OrganizationModel>> userOrganizations(Ref ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  final db = ref.watch(databaseServiceProvider);
  return db.getUserOrganizations(user.id);
}
```

### 4.3 Update All Database Queries

**Priority:** CRITICAL
**Effort:** 7-10 days

Every database query must include organization context:

```dart
// BEFORE (single-tenant):
Future<List<MenuItemModel>> getMenuItems() async {
  final response = await _client
      .from('menu_items')
      .select()
      .order('ordine');
  return response.map((e) => MenuItemModel.fromJson(e)).toList();
}

// AFTER (multi-tenant):
Future<List<MenuItemModel>> getMenuItems(String organizationId) async {
  final response = await _client
      .from('menu_items')
      .select()
      .eq('organization_id', organizationId)  // ADD THIS
      .order('ordine');
  return response.map((e) => MenuItemModel.fromJson(e)).toList();
}
```

### 4.4 Dynamic Branding System

**Priority:** HIGH
**Effort:** 3-5 days

```dart
// lib/core/providers/branding_provider.dart

@riverpod
Future<BrandingModel> organizationBranding(Ref ref) async {
  final org = await ref.watch(currentOrganizationProvider.future);
  if (org == null) {
    return BrandingModel.defaultBranding();
  }

  return BrandingModel(
    name: org.name,
    logoUrl: org.logoUrl,
    primaryColor: Color(int.parse(org.primaryColor.replaceFirst('#', '0xFF'))),
    secondaryColor: Color(int.parse(org.secondaryColor.replaceFirst('#', '0xFF'))),
  );
}

// Update AppColors to use dynamic values
class AppColors {
  static Color primary(WidgetRef ref) {
    final branding = ref.watch(organizationBrandingProvider).value;
    return branding?.primaryColor ?? const Color(0xFFFF5722);
  }
}
```

### 4.5 Organization Selector UI

**Priority:** HIGH
**Effort:** 2-3 days

For users belonging to multiple organizations (e.g., franchise owners):

```dart
// lib/features/auth/widgets/organization_selector.dart

class OrganizationSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizations = ref.watch(userOrganizationsProvider);
    final current = ref.watch(currentOrganizationProvider);

    return organizations.when(
      data: (orgs) {
        if (orgs.length <= 1) return const SizedBox.shrink();

        return DropdownButton<String>(
          value: current.value?.id,
          items: orgs.map((org) => DropdownMenuItem(
            value: org.id,
            child: Row(
              children: [
                if (org.logoUrl != null)
                  CachedNetworkImage(imageUrl: org.logoUrl!, width: 24),
                const SizedBox(width: 8),
                Text(org.name),
              ],
            ),
          )).toList(),
          onChanged: (orgId) {
            if (orgId != null) {
              ref.read(currentOrganizationProvider.notifier)
                  .switchOrganization(orgId);
            }
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

### 4.6 Onboarding Flow for New Tenants

**Priority:** HIGH
**Effort:** 5-7 days

New screens required:
1. **CreateOrganizationScreen** - Business details form
2. **SetupMenuScreen** - Initial menu setup wizard
3. **SetupDeliveryScreen** - Delivery zones configuration
4. **SetupPaymentsScreen** - Stripe Connect onboarding
5. **InviteTeamScreen** - Add staff members

### 4.7 Update Navigation & Routing

**Priority:** HIGH
**Effort:** 2-3 days

```dart
// lib/routes/app_router.dart

// Add organization-aware route guards
GoRoute(
  path: '/dashboard',
  builder: (context, state) => const DashboardScreen(),
  redirect: (context, state) {
    final org = ref.read(currentOrganizationProvider).value;
    if (org == null) {
      return '/select-organization';
    }
    if (!org.isActive) {
      return '/subscription-expired';
    }
    return null;
  },
),

// Add new routes
GoRoute(
  path: '/select-organization',
  builder: (context, state) => const OrganizationSelectorScreen(),
),
GoRoute(
  path: '/create-organization',
  builder: (context, state) => const CreateOrganizationScreen(),
),
GoRoute(
  path: '/onboarding',
  builder: (context, state) => const OnboardingWizard(),
),
```

### 4.8 Files Requiring Changes

| File/Directory | Changes Required | Effort |
|----------------|-----------------|--------|
| `lib/core/utils/constants.dart` | Remove hardcoded branding | Low |
| `lib/main.dart` | Remove hardcoded project ID | Low |
| `lib/core/services/database_service.dart` | Add org_id to all queries | High |
| `lib/core/services/auth_service.dart` | Handle org context on login | Medium |
| `lib/providers/*.dart` (70+ files) | Add org dependency | High |
| `lib/features/manager/screens/*` | Use dynamic branding | Medium |
| `lib/features/customer/screens/*` | Use dynamic branding | Medium |
| `lib/features/auth/screens/*` | Add org selection | Medium |
| `lib/DesignSystem/theme.dart` | Support dynamic colors | Medium |
| `lib/routes/app_router.dart` | Add org-aware routing | Medium |

---

## Phase 5: Infrastructure & DevOps

### 5.1 Environment Configuration

**Priority:** HIGH
**Effort:** 2-3 days

```bash
# .env.example (template for all deployments)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_MAPS_API_KEY=your-maps-key

# Platform keys (shared across all tenants)
STRIPE_PLATFORM_KEY=sk_live_platform_key
STRIPE_WEBHOOK_SECRET=whsec_xxx

# Firebase (single project for notifications)
FIREBASE_PROJECT_ID=your-firebase-project

# Feature flags
ENABLE_MULTI_TENANT=true
ENABLE_STRIPE_CONNECT=true
```

### 5.2 CI/CD Pipeline

**Priority:** MEDIUM
**Effort:** 3-5 days

Create GitHub Actions workflow:

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test

  deploy-functions:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase functions deploy --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build appbundle
      - uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_JSON }}
          packageName: com.yourcompany.rotante
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build ipa
      # Add App Store deployment steps
```

### 5.3 Monitoring & Observability

**Priority:** MEDIUM
**Effort:** 2-3 days

Implement:
- **Error tracking**: Sentry or Firebase Crashlytics
- **Analytics**: Mixpanel or Amplitude (with tenant context)
- **Performance monitoring**: Supabase dashboard + custom metrics
- **Uptime monitoring**: Better Uptime or similar

```dart
// lib/core/services/analytics_service.dart

class AnalyticsService {
  Future<void> trackEvent(String event, Map<String, dynamic> properties) async {
    final org = await getCurrentOrganization();

    await _analytics.track(event, {
      ...properties,
      'organization_id': org?.id,
      'organization_name': org?.name,
      'subscription_tier': org?.subscriptionTier,
    });
  }
}
```

### 5.4 Backup & Disaster Recovery

**Priority:** HIGH
**Effort:** 1-2 days

- Enable Supabase Point-in-Time Recovery (Pro plan)
- Set up daily logical backups to separate storage
- Document recovery procedures
- Test restore process quarterly

### 5.5 Security Hardening

**Priority:** CRITICAL
**Effort:** 2-3 days

- [ ] Enable leaked password protection (currently disabled - see advisory)
- [ ] Implement rate limiting on auth endpoints
- [ ] Add API key rotation mechanism
- [ ] Set up security headers
- [ ] Enable database audit logging
- [ ] Review and remove unused indexes (13 identified)

---

## Phase 6: Testing & Quality Assurance

### 6.1 Unit Tests

**Priority:** HIGH
**Effort:** 5-7 days

Current state: Only 1 test file (`order_price_calculator_test.dart`)

Required test coverage:
- [ ] Organization CRUD operations
- [ ] Membership management
- [ ] RLS policy validation
- [ ] Price calculations (existing, expand)
- [ ] All provider state management
- [ ] Edge function logic

```dart
// Example: test/core/services/organization_service_test.dart

void main() {
  group('OrganizationService', () {
    test('creates organization with correct defaults', () async {
      final service = OrganizationService(mockClient);
      final org = await service.create(name: 'Test Pizzeria', email: 'test@test.com');

      expect(org.subscriptionTier, equals('free'));
      expect(org.maxStaffMembers, equals(3));
      expect(org.features['delivery'], isTrue);
    });

    test('enforces tenant isolation in queries', () async {
      // Verify user A cannot access org B's data
    });
  });
}
```

### 6.2 Integration Tests

**Priority:** HIGH
**Effort:** 3-5 days

```dart
// test/integration/multi_tenant_test.dart

void main() {
  group('Multi-Tenant Integration', () {
    late SupabaseClient clientOrgA;
    late SupabaseClient clientOrgB;

    setUpAll(() async {
      // Create two test organizations
      // Create users for each
    });

    test('Organization A cannot see Organization B menu items', () async {
      final orgAItems = await clientOrgA.from('menu_items').select();
      final orgBItems = await clientOrgB.from('menu_items').select();

      // Verify no overlap in IDs
      final orgAIds = orgAItems.map((e) => e['id']).toSet();
      final orgBIds = orgBItems.map((e) => e['id']).toSet();
      expect(orgAIds.intersection(orgBIds), isEmpty);
    });
  });
}
```

### 6.3 End-to-End Tests

**Priority:** MEDIUM
**Effort:** 3-5 days

- [ ] New tenant onboarding flow
- [ ] Complete order lifecycle per tenant
- [ ] Subscription upgrade/downgrade
- [ ] Team member invitation flow
- [ ] Data isolation between tenants

### 6.4 Security Testing

**Priority:** HIGH
**Effort:** 2-3 days

- [ ] RLS bypass attempts
- [ ] Cross-tenant data access attempts
- [ ] Authentication token manipulation
- [ ] SQL injection testing
- [ ] API rate limit testing

---

## Migration Strategy for Existing Data

### Step 1: Create Default Organization

```sql
-- Create organization for existing data
INSERT INTO organizations (
    name,
    slug,
    email,
    subscription_tier,
    subscription_status
)
VALUES (
    'Pizzeria Rotante',
    'rotante',
    'info@pizzeriarotante.it',
    'professional',
    'active'
)
RETURNING id;

-- Store the ID for subsequent migrations
-- Let's call it: org_default_id
```

### Step 2: Backfill Organization ID

```sql
-- Update all tables with existing data
UPDATE menu_items SET organization_id = 'org_default_id' WHERE organization_id IS NULL;
UPDATE categorie_menu SET organization_id = 'org_default_id' WHERE organization_id IS NULL;
UPDATE ingredients SET organization_id = 'org_default_id' WHERE organization_id IS NULL;
UPDATE ordini SET organization_id = 'org_default_id' WHERE organization_id IS NULL;
-- ... repeat for all tables
```

### Step 3: Assign Existing Users

```sql
-- Create memberships for existing users based on their roles
INSERT INTO organization_members (organization_id, user_id, role, accepted_at)
SELECT
    'org_default_id',
    id,
    ruolo,
    now()
FROM profiles
WHERE ruolo IN ('manager', 'kitchen', 'delivery');

-- Set current organization for all users
UPDATE profiles
SET current_organization_id = 'org_default_id'
WHERE ruolo IN ('manager', 'kitchen', 'delivery');
```

### Step 4: Migrate Settings

```sql
-- Copy business_rules to organization
UPDATE organizations
SET
    address = br.indirizzo,
    city = br.citta,
    postal_code = br.cap,
    province = br.provincia,
    phone = br.telefono,
    email = COALESCE(br.email, organizations.email),
    latitude = br.latitude,
    longitude = br.longitude
FROM business_rules br
WHERE organizations.id = 'org_default_id';
```

---

## Risk Assessment & Mitigation

### High Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| RLS policy bug exposes cross-tenant data | Critical | Medium | Extensive security testing, code review, penetration testing |
| Migration corrupts existing data | Critical | Low | Full backup before migration, staged rollout, rollback plan |
| Performance degradation with tenant filtering | High | Medium | Index optimization, query analysis, caching |
| Stripe Connect integration delays | High | Medium | Start Stripe paperwork early, have fallback payment flow |

### Medium Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Scope creep extends timeline | Medium | High | Fixed scope per phase, regular checkpoints |
| Team unfamiliar with multi-tenant patterns | Medium | Medium | Training, documentation, code review |
| Breaking changes affect existing users | Medium | Medium | Feature flags, gradual rollout |

### Low Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Supabase service issues | Medium | Low | Monitoring, incident response plan |
| App store rejection | Medium | Low | Review guidelines compliance |

---

## Recommended Implementation Order

### Week 1-2: Foundation
1. Create `organizations` table and basic RLS
2. Create `organization_members` table and RLS
3. Create helper functions
4. Set up test infrastructure

### Week 3-4: Database Migration
5. Add `organization_id` to all tables (with nullable)
6. Create migration script for existing data
7. Run migration on staging environment
8. Update RLS policies (one table at a time)

### Week 5-6: Backend
9. Update edge functions with org context
10. Create new edge functions (organization management)
11. Set up Stripe Connect integration
12. Update database triggers

### Week 7-8: Frontend Core
13. Create organization provider and context
14. Remove hardcoded values from constants
15. Update DatabaseService with org parameters
16. Create organization selector UI

### Week 9-10: Frontend Features
17. Update all providers with org dependency
18. Implement dynamic branding
19. Create onboarding wizard
20. Update routing with org guards

### Week 11-12: Testing & Polish
21. Write unit tests for new code
22. Write integration tests for multi-tenancy
23. Security testing and penetration testing
24. Performance optimization

### Week 13-14: Deployment
25. Stage migration on production backup
26. Deploy to production (off-peak hours)
27. Monitor for issues
28. Gradual feature flag rollout

---

## Codebase Suitability Assessment

### Strengths (Makes SaaS Conversion Easier)

| Aspect | Why It Helps |
|--------|--------------|
| Clean Architecture | Feature modules can be updated independently |
| Riverpod State Management | Easy to add organization context to providers |
| Freezed Data Classes | Immutable models prevent state corruption |
| Supabase SDK | Built-in support for RLS and real-time |
| TypeScript Edge Functions | Type safety reduces migration bugs |
| Separate Settings Tables | Can easily add org_id column |

### Weaknesses (Requires Extra Effort)

| Aspect | Challenge | Solution |
|--------|-----------|----------|
| No Tests | Can't verify multi-tenant isolation | Must write tests first |
| Large DatabaseService | 1,546 lines to update | Refactor into smaller services |
| Hardcoded Values | Scattered across codebase | Search and replace systematically |
| 70+ Providers | All need org context | Automated refactoring tools |
| Italian Language | Comments/names in Italian | Document changes in English |

### Verdict: SUITABLE WITH MODERATE EFFORT

The codebase is well-structured and suitable for SaaS conversion. The main challenges are:
1. Lack of test coverage (must add before refactoring)
2. Volume of files to update (systematic but time-consuming)
3. No existing multi-tenant patterns (must introduce from scratch)

The architecture is sound, code quality is good, and the technology stack (Supabase, Riverpod) supports multi-tenancy well.

---

## Appendix A: Complete File Change List

### Files to Create

```
lib/
├── core/
│   ├── models/
│   │   ├── organization_model.dart
│   │   ├── organization_member_model.dart
│   │   └── subscription_model.dart
│   ├── providers/
│   │   ├── organization_provider.dart
│   │   └── branding_provider.dart
│   └── services/
│       ├── organization_service.dart
│       └── subscription_service.dart
├── features/
│   ├── onboarding/
│   │   ├── screens/
│   │   │   ├── create_organization_screen.dart
│   │   │   ├── setup_menu_screen.dart
│   │   │   ├── setup_delivery_screen.dart
│   │   │   ├── setup_payments_screen.dart
│   │   │   └── invite_team_screen.dart
│   │   └── widgets/
│   │       └── onboarding_stepper.dart
│   └── settings/
│       └── screens/
│           ├── subscription_screen.dart
│           └── team_management_screen.dart
└── supabase/
    └── functions/
        ├── create-organization/
        ├── invite-team-member/
        ├── accept-invitation/
        ├── connect-stripe-account/
        └── sync-subscription/
```

### Files to Modify (Partial List)

```
lib/core/utils/constants.dart                    # Remove hardcoded branding
lib/main.dart                                     # Remove hardcoded project ID
lib/core/services/database_service.dart          # Add org_id to all queries
lib/core/services/auth_service.dart              # Handle org context
lib/routes/app_router.dart                       # Add org-aware routing
lib/DesignSystem/theme.dart                      # Dynamic colors
lib/providers/*.dart                             # Add org dependency (70+ files)
lib/features/*/screens/*.dart                    # Use dynamic branding (50+ files)
supabase/functions/create-payment-intent/*       # Add org context
supabase/functions/place-order/*                 # Add org context
supabase/functions/send-notification/*           # Add org routing
```

---

## Appendix B: SQL Migration Scripts

Full migration scripts available in: `database_migrations/saas/`

```
database_migrations/saas/
├── 001_create_organizations_table.sql
├── 002_create_organization_members_table.sql
├── 003_create_helper_functions.sql
├── 004_add_org_id_to_menu_items.sql
├── 005_add_org_id_to_categorie_menu.sql
├── 006_add_org_id_to_ingredients.sql
├── 007_add_org_id_to_ordini.sql
├── 008_add_org_id_to_other_tables.sql
├── 009_update_rls_policies.sql
├── 010_update_triggers.sql
├── 011_migrate_existing_data.sql
└── 012_make_org_id_not_null.sql
```

---

## Appendix C: Checklist for Go-Live

### Pre-Launch
- [ ] All RLS policies tested and verified
- [ ] Data migration tested on staging
- [ ] Rollback procedure documented and tested
- [ ] Performance benchmarks acceptable
- [ ] Security audit completed
- [ ] Stripe Connect approved and configured
- [ ] Legal: Terms of Service updated
- [ ] Legal: Privacy Policy updated
- [ ] Legal: Data Processing Agreement ready

### Launch Day
- [ ] Full database backup completed
- [ ] Team on standby for issues
- [ ] Monitoring dashboards ready
- [ ] Customer support briefed
- [ ] Feature flags configured

### Post-Launch
- [ ] Monitor error rates for 48 hours
- [ ] Check cross-tenant isolation logs
- [ ] Verify subscription billing working
- [ ] Gather initial user feedback
- [ ] Plan iteration based on feedback

---

**Document Prepared By:** Claude AI
**Review Required By:** Development Team Lead, Security Officer
**Next Review Date:** After Phase 1 completion
