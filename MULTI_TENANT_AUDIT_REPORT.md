# Vittoria Ristorazione - Multi-Tenant Architecture Audit Report

**Project:** RistorazioneVittoria (qgnecuqcfzzclhwatzpv)
**Date:** 2025-01-30
**Status:** DETAILED AUDIT COMPLETE
**Production Readiness:** ~70% - NOT READY FOR PUBLIC RELEASE

---

## Executive Summary

This is a **multi-tenant restaurant management SaaS platform** built with Flutter and Supabase. The application serves restaurants (organizations/tenants) and their customers, with role-based access control for managers, kitchen staff, delivery drivers, and customers.

**Overall Assessment:**
- **Architecture Quality:** 8/10 - Well-designed with excellent RLS policies
- **Security:** 6/10 - Critical vulnerabilities must be addressed
- **State Management:** 7/10 - One race condition in CartProvider, rest is good
- **Production Readiness:** ~70% - 4-6 weeks of focused work needed

### Key Findings

| Category | Status | Details |
|----------|--------|---------|
| RLS Policies | ✅ Excellent | All tables protected, proper tenant isolation |
| Organization ID Propagation | ✅ Good | Consistently implemented across providers |
| Provider Auto-Reload | ✅ Good | Categories, Ingredients, Sizes, ProductSizes all use `ref.watch` correctly |
| Auth Flow | ✅ Good | Google Sign-In, profile creation, org membership handling |
| Cart State | ⚠️ Issue | Race condition in initialization |
| Database Indexes | ⚠️ Missing | 24 unindexed foreign keys affecting performance |
| Security | ⚠️ Issues | Leaked password protection disabled |
| Organization Creation | ❌ Missing | No UI for creating organizations |

---

## 1. Database Analysis

### 1.1 Schema Overview

**Total Tables:** 33
**Foreign Keys:** 68
**RLS Policies:** Comprehensive coverage on all tables

### 1.2 Multi-Tenant Core Tables

| Table | Organization ID | RLS Status | Notes |
|-------|----------------|------------|-------|
| `organizations` | PK | ✅ Protected | Tenant/restaurant data |
| `organization_members` | ✅ Yes | ✅ Protected | User-tenant relationships |
| `profiles` | `current_organization_id` | ✅ Protected | User profiles with current org |
| `menu_items` | ✅ Yes | ✅ Protected | Products |
| `categorie_menu` | ✅ Yes | ✅ Protected | Menu categories |
| `ingredients` | ✅ Yes | ✅ Protected | Ingredients |
| `sizes_master` | ✅ Yes | ✅ Protected | Size variants |
| `ordini` | ✅ Yes | ✅ Protected | Orders |
| `ordini_items` | ✅ Yes | ✅ Protected | Order line items |
| All settings tables | ✅ Yes | ✅ Protected | Business rules, delivery, etc. |

### 1.3 RLS Policies Analysis

**Excellent Coverage:** All tables have RLS policies applied to `authenticated` role only.

**Sample Policies:**
```sql
-- organizations table: Users can see active, non-deleted orgs they belong to
SELECT: ((is_active = true) AND (deleted_at IS NULL)
         AND ((id = get_current_organization_id())
              OR is_organization_member(id)
              OR is_super_admin))

-- menu_items: Strict organization filtering
ALL: ((organization_id = get_current_organization_id())
      AND is_organization_admin(organization_id))

-- ordini: Staff can see all, customers only their own
SELECT: ((organization_id = get_current_organization_id())
         AND ((cliente_id = auth.uid()) OR is_staff()))
```

**✅ No Public Access:** Verified - no policies apply to `public` role (good security practice)

### 1.4 Foreign Key Constraints

**Critical Foreign Keys:**
```sql
-- organization_members -> organizations
organization_id REFERENCES organizations(id) ON DELETE CASCADE

-- profiles.current_organization_id -> organizations
current_organization_id REFERENCES organizations(id) ON DELETE SET NULL
```

**⚠️ Issue:** `profiles.current_organization_id` can be set to invalid organization IDs (no database-level validation)

### 1.5 Missing Database Indexes (Performance)

**24 unindexed foreign keys** - This will impact query performance as data grows.

**High Priority Indexes:**
```sql
-- Notifications (user lookups)
CREATE INDEX idx_notifiche_user_org ON notifiche(user_id, organization_id);

-- Order items (order lookups)
CREATE INDEX idx_ordini_items_ordine ON ordini_items(ordine_id);

-- Menu items by category
CREATE INDEX idx_menu_items_categoria_attivo ON menu_items(categoria_id, attivo)
  WHERE attivo = true;

-- Organization members (membership checks)
CREATE INDEX idx_org_members_user_active ON organization_members(user_id, is_active)
  WHERE is_active = true;

-- Audit logs (recent logs)
CREATE INDEX idx_audit_logs_org_created ON audit_logs(organization_id, created_at DESC);
```

### 1.6 Security Advisory

**From Supabase Advisors:**
- **⚠️ Leaked Password Protection DISABLED** - Should be enabled to prevent use of compromised passwords (HaveIBeenPwned.org check)

---

## 2. Provider Architecture Analysis

### 2.1 Current Organization Provider ✅

**File:** `lib/providers/organization_provider.dart`

**Status:** WELL IMPLEMENTED

**Key Features:**
- Reads `profiles.current_organization_id`
- Validates organization exists, is active, not deleted
- Validates user is still an active member
- Falls back to first active organization if current is invalid
- Clears cart before org switch (prevents cross-org data contamination)
- Invalidates provider on changes

```dart
@riverpod
class CurrentOrganization extends _$CurrentOrganization {
  @override
  Future<String?> build() async {
    // 1. Get current_organization_id from profile
    // 2. Validate org exists, active, not deleted
    // 3. Validate user membership is active
    // 4. Fallback to first org if invalid
    // 5. Return null if no memberships
  }

  Future<void> switchOrganization(String organizationId) async {
    await ref.read(cartProvider.notifier).clearForOrganization(organizationId);
    await client.from('profiles').update({'current_organization_id': organizationId});
    ref.invalidateSelf();
  }
}
```

### 2.2 Data Providers Auto-Reload Analysis

| Provider | Uses `ref.watch` | Auto-Reloads | Status |
|----------|-----------------|--------------|--------|
| `categoriesProvider` | ✅ Yes (line 12) | ✅ Yes | GOOD |
| `ingredientsProvider` | ✅ Yes (line 14) | ✅ Yes | GOOD |
| `sizesProvider` | ✅ Yes (line 13) | ✅ Yes | GOOD |
| `productSizesProvider` | ✅ Yes (line 14) | ✅ Yes | GOOD |
| `cartProvider` | ⚠️ No (uses `ref.read`) | ❌ No | **ISSUE** |

### 2.3 Cart Provider Race Condition ⚠️

**File:** `lib/providers/cart_provider.dart`

**Issue:** Async initialization not awaited in constructor

```dart
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier(this.ref) : super([]) {
    _init();  // ⚠️ NOT AWAITED
  }

  Future<void> _init() async {
    if (_initialized) return;
    final orgId = ref.read(currentOrganizationProvider).value;  // ⚠️ SYNCHRONOUS READ
    final loaded = await _loadFromStorage(orgId);
    state = loaded;
    _initialized = true;
  }
}
```

**Impact:**
- Cart may load with null/old organization ID
- Race condition between org switch and cart load
- Possible cross-org data contamination

**Recommended Fix:**
```dart
@riverpod
class Cart extends _$Cart {
  @override
  Future<List<CartItem>> build() async {
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return await _loadFromStorage(orgId);
  }
}
```

### 2.4 Auth Provider ✅

**File:** `lib/providers/auth_provider.dart`

**Status:** WELL IMPLEMENTED

**Key Features:**
- Profile update sanitization (prevents privilege escalation)
- `_allowedProfileFields` whitelist blocks role changes
- `reloadOrgRole()` method for org switch handling
- Session management with token refresh
- FCM token handling

---

## 3. Authentication & Organization Flow

### 3.1 Complete Flow: QR Code to Order

```
1. SCAN QR CODE (ConnectScreen)
   ├─ MobileScanner captures QR code
   ├─ Extract slug from URL (handles multiple formats)
   └─ Call organizationJoinProvider.lookupBySlug(slug)

2. ORGANIZATION LOOKUP
   ├─ Query organizations table by slug
   ├─ Validate: is_active=true, deleted_at=null
   └─ Return OrganizationPreview (name, logo, address)

3. PREVIEW SCREEN (OrganizationPreviewScreen)
   ├─ Display organization details
   └─ User clicks "Join" button

4. AUTHENTICATION (if not authenticated)
   ├─ Trigger Google Sign-In
   └─ Create/update user profile

5. JOIN ORGANIZATION (join-organization Edge Function)
   ├─ Validate user authentication
   ├─ Check rate limit (10 joins/hour)
   ├─ Create/update organization_members record
   ├─ Set profiles.current_organization_id
   └─ Return success

6. ROUTER REDIRECT (RouterNotifier)
   ├─ Listen to currentOrganizationProvider changes
   ├─ Call authProvider.reloadOrgRole()
   └─ Redirect to role-based home screen

7. LOAD ORGANIZATION DATA
   ├─ Categories filter by organization_id
   ├─ Menu items filter by organization_id
   ├─ Ingredients filter by organization_id
   ├─ Sizes filter by organization_id
   └─ All queries use RLS for isolation

8. PLACE ORDER (place-order Edge Function)
   ├─ Validate organization membership
   ├─ Server-side price validation
   ├─ Create order with organization_id
   └─ All order items include organization_id
```

### 3.2 Organization Switch Flow

**File:** `lib/providers/organization_provider.dart:126-141`

```dart
Future<void> switchOrganization(String organizationId) async {
  // 1. Clear cart BEFORE switching (prevents cross-org contamination)
  await ref.read(cartProvider.notifier).clearForOrganization(organizationId);

  // 2. Update database
  await client.from('profiles').update({
    'current_organization_id': organizationId
  }).eq('id', userId);

  // 3. Invalidate provider (triggers reload of all watching providers)
  ref.invalidateSelf();
}
```

**✅ Good:** Cart is cleared before org switch

**⚠️ Issue:** Cart has race condition (see section 2.3)

### 3.3 Role Reload on Org Switch ✅

**File:** `lib/providers/auth_provider.dart:158-211`

```dart
Future<void> reloadOrgRole() async {
  // 1. Get new organization ID
  final currentOrgId = await ref.read(currentOrganizationProvider.future);

  // 2. Fetch role from organization_members
  final memberResponse = await client
      .from('organization_members')
      .select('role')
      .eq('user_id', currentUser.id)
      .eq('organization_id', currentOrgId)
      .eq('is_active', true)
      .maybeSingle();

  // 3. Update user role without full auth invalidation
  state = AsyncValue.data(updatedUser);
}
```

**✅ Good:** Prevents race condition during org switch

---

## 4. Security Analysis

### 4.1 Authentication Security ✅

**Strong Points:**
- Google Sign-In with proper token handling
- Profile auto-creation on first login
- FCM token cleared on logout
- Profile update sanitization prevents privilege escalation
- Session expiry handling with token refresh

**Whitelisted Profile Fields:**
```dart
static const _allowedProfileFields = {
  'nome', 'cognome', 'telefono', 'avatar_url',
};
// 'ruolo', 'attivo', 'current_organization_id' explicitly blocked
```

### 4.2 Database Security ✅

**RLS Policies:**
- All tables protected
- Tenant isolation enforced at database level
- Role-based access (owner, manager, kitchen, delivery, customer)
- No public access (all policies require authentication)

**Edge Functions:**
- Rate limiting: 10 joins/hour, 20 orders/hour
- Server-side price validation
- Organization membership validation
- HMAC signature validation (non-blocking during transition)

### 4.3 Security Issues

| Issue | Severity | Impact |
|-------|----------|--------|
| Leaked password protection disabled | ⚠️ Medium | Compromised passwords not blocked |
| No FK on `profiles.current_organization_id` | ⚠️ Medium | Can reference invalid orgs |
| Console logging PII | ⚠️ Low | Emails, order amounts in logs |
| `--no-verify-jwt` on join-organization | ⚠️ Low | Manual auth check only |

---

## 5. Missing Features

### 5.1 Organization Creation Flow ❌

**Status:** NOT IMPLEMENTED

**Current State:** Organizations must be manually created in the database

**Required:**
1. `create-organization` Edge Function
2. `CreateOrganizationScreen` UI
3. RLS INSERT policy for organizations
4. Stripe subscription integration
5. Onboarding flow for new restaurant owners

### 5.2 Missing Model Fields

| Model | Missing Field | Database Status |
|-------|---------------|-----------------|
| `UserModel` | `isSuperAdmin` | ✅ In database |
| `UserModel` | `currentOrganizationId` | ✅ In database |
| `UserModel` | `fcmTokens` (array) | ✅ In database |
| `OrderReminderModel` | `organizationId` | ✅ In database (but missing from model) |

### 5.3 Missing Organization Models

**Should Create:**
- `OrganizationModel` - maps to `organizations` table
- `OrganizationMemberModel` - maps to `organization_members` table

---

## 6. Production Readiness Checklist

### 6.1 Critical Blockers (Must Fix)

- [ ] **Fix CartProvider race condition** - Convert to `@riverpod` pattern
- [ ] **Enable leaked password protection** - Supabase dashboard setting
- [ ] **Create organization creation flow** - Edge Function + UI
- [ ] **Add missing database indexes** - Apply migration

### 6.2 High Priority (Should Fix)

- [ ] **Add FK constraint on `profiles.current_organization_id`**
- [ ] **Sanitize console logs** - Remove PII (emails, amounts)
- [ ] **Enable JWT verification on `join-organization`** - Remove `--no-verify-jwt`
- [ ] **Create `OrganizationModel` and `OrganizationMemberModel`**
- [ ] **Add camera permission handling** - QR scanner
- [ ] **Add production origins to CORS whitelist** - `https://rotante.app`

### 6.3 Medium Priority (Nice to Have)

- [ ] **Add session expiry handling** - Auto-refresh in preview screen
- [ ] **Add comprehensive error messages** - Better UX
- [ ] **Add loading states** - Better UX during org switch
- [ ] **Add monitoring** - Sentry error tracking
- [ ] **Add analytics** - User behavior tracking

### 6.4 Testing

- [ ] **Unit tests** - Provider logic
- [ ] **Integration tests** - Multi-tenancy flow
- [ ] **E2E tests** - QR scan to order flow
- [ ] **Security tests** - RLS policies, auth flow

---

## 7. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER DEVICE                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │   QR Scan    │───▶│  Lookup Org  │───▶│  Join Org    │     │
│  │              │    │  by Slug     │    │  (Edge Fn)   │     │
│  └──────────────┘    └──────────────┘    └──────┬───────┘     │
│                                                    │             │
│                                                    ▼             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           currentOrganizationProvider                     │  │
│  │  - Reads profiles.current_organization_id                │  │
│  │  - Validates org & membership                             │  │
│  │  - Clears cart on switch                                  │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                           │                                     │
│          ┌────────────────┼────────────────┐                   │
│          ▼                ▼                ▼                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  Categories  │  │  Menu Items  │  │  Ingredients  │        │
│  │  .eq(orgId)  │  │  .eq(orgId)  │  │  .eq(orgId)  │        │
│  │  ref.watch   │  │  ref.watch   │  │  ref.watch   │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   RouterNotifier                          │  │
│  │  - Listens to org changes                                 │  │
│  │  - Calls authProvider.reloadOrgRole()                     │  │
│  │  - Redirects to role-based home                           │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SUPABASE BACKEND                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    RLS POLICIES                            │  │
│  │  - All tables filter by organization_id                  │  │
│  │  - Role-based access (owner, manager, kitchen, etc.)     │  │
│  │  - Users can only access their org's data               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  organizations  │  │   profiles      │  │  org_members    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           ▲                    ▲                     ▲           │
│           │                    │                     │           │
│  ┌────────┴────────┐    ┌─────┴──────┐    ┌────────┴────────┐   │
│  │  menu_items     │    │  ordini    │    │  categorie_menu │   │
│  │  ingredients    │    │  ordini_   │    │  ingredients    │   │
│  │                 │    │    items   │    │                 │   │
│  └─────────────────┘    └────────────┘    └─────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              EDGE FUNCTIONS                                │  │
│  │  - join-organization (rate limit: 10/hr)                 │  │
│  │  - place-order (rate limit: 20/hr, price validation)     │  │
│  │  - create-payment-intent (Stripe)                        │  │
│  │  - verify-payment                                         │  │
│  │  - send-notification                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Recommendations

### 8.1 Immediate Actions (This Week)

1. **Fix CartProvider Race Condition**
   - Convert to `@riverpod` pattern with `ref.watch`
   - Ensure async initialization is awaited
   - Test org switch scenarios

2. **Enable Leaked Password Protection**
   - Go to Supabase Dashboard → Authentication → Policies
   - Enable "Leaked Password Protection"

3. **Add Missing Database Indexes**
   - Create migration with 24 indexes
   - Test query performance before/after

4. **Fix Organization Creation Flow**
   - Create `create-organization` Edge Function
   - Build `CreateOrganizationScreen` UI
   - Add RLS INSERT policy

### 8.2 Short-term Actions (This Month)

1. **Complete Security Hardening**
   - Add FK constraint on `profiles.current_organization_id`
   - Sanitize console logs
   - Enable JWT verification on `join-organization`
   - Add production origins to CORS

2. **Improve Error Handling**
   - Add camera permission check
   - Improve error messages
   - Add session expiry handling
   - Add loading states

3. **Complete Model Definitions**
   - Create `OrganizationModel`
   - Create `OrganizationMemberModel`
   - Add `organizationId` to `OrderReminderModel`

### 8.3 Long-term Actions (Next Quarter)

1. **Add Comprehensive Testing**
   - Unit tests for providers
   - Integration tests for multi-tenancy
   - E2E tests for critical flows
   - Security tests for RLS policies

2. **Implement Monitoring**
   - Set up Sentry error tracking
   - Add performance monitoring
   - Create incident response plan

3. **Documentation**
   - Document security architecture
   - Document multi-tenancy design
   - Create operations runbook
   - Create API documentation

---

## 9. Estimated Timeline to Production

| Phase | Duration | Tasks |
|-------|----------|-------|
| **Phase 1: Critical Fixes** | 1-2 weeks | Cart provider, password protection, indexes |
| **Phase 2: Security Hardening** | 1 week | FK constraints, JWT verification, CORS |
| **Phase 3: Missing Features** | 2 weeks | Org creation flow, models, permissions |
| **Phase 4: Testing** | 1-2 weeks | Unit, integration, E2E tests |
| **Phase 5: Polish** | 1 week | Error handling, loading states, monitoring |

**Total: 6-8 weeks to production-ready**

---

## 10. Summary

**Strengths:**
- ✅ Excellent RLS policies with proper tenant isolation
- ✅ Clean multi-tenancy pattern with consistent organization_id propagation
- ✅ Server-side price validation prevents tampering
- ✅ Good rate limiting on critical endpoints
- ✅ Most providers correctly use `ref.watch` for auto-reload
- ✅ Router integration with org change detection

**Weaknesses:**
- ❌ CartProvider has race condition in initialization
- ❌ No organization creation flow (manual database operation required)
- ❌ Missing database indexes (24 unindexed foreign keys)
- ⚠️ Leaked password protection disabled
- ⚠️ Missing FK constraint on `profiles.current_organization_id`

**Production Readiness:** ~70%

The application has a solid architectural foundation for multi-tenancy with excellent security at the database level. However, critical issues in state management (CartProvider), missing features (organization creation), and performance concerns (missing indexes) must be addressed before public launch.

**Recommendation:** Focus on Phase 1 tasks (CartProvider, password protection, indexes) immediately, then proceed through phases 2-5 systematically.
