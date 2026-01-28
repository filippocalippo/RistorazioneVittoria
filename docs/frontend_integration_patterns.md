# Frontend Integration Patterns Guide

## Overview
This document outlines the standardized patterns for error handling, offline detection, and async data loading across the Rotante Flutter application.

## 1. Error Boundaries

### Purpose
Error boundaries catch Flutter errors and display a consistent error UI, preventing the entire app from crashing due to a single widget error.

### Integration Points
Error boundaries have been integrated at the following levels:

#### Shell Level (Global Coverage)
All shell widgets now wrap their content with `ErrorBoundaryWithLogger`:

- **AppShell** (`lib/core/widgets/app_shell.dart`) - Covers all customer routes
- **ManagerShell** (`lib/features/manager/widgets/manager_shell.dart`) - Covers all manager routes
- **KitchenShell** (`lib/features/kitchen/widgets/kitchen_shell.dart`) - Covers all kitchen routes
- **DeliveryShell** (`lib/features/delivery/widgets/delivery_shell.dart`) - Covers all delivery routes

#### Screen Level (Critical Screens)
Individual screens with complex logic also have error boundaries:

- **MenuScreen** - Customer menu with search/filter
- **CartScreenNew** - Shopping cart
- **CheckoutScreenNew** - Checkout flow
- **OrdersScreen** - Order management
- **DashboardScreen** - Analytics dashboard
- **KitchenOrdersScreen** - Kitchen display

### Usage Pattern
```dart
// In shell widgets:
final content = ErrorBoundaryWithLogger(
  contextTag: 'ShellName',  // Used for error reporting
  child: widget.child,
);

// In individual screens:
return ErrorBoundaryWithLogger(
  contextTag: 'ScreenName',
  child: Scaffold(
    // ... screen content
  ),
);
```

### Benefits
1. **Graceful Degradation** - Errors in one widget don't crash the entire app
2. **Consistent UI** - All errors show the same error display component
3. **Error Logging** - Errors are logged with context tags for easier debugging
4. **Retry Capability** - Users can retry failed operations

---

## 2. Offline Banner

### Purpose
The `OfflineBanner` widget displays a banner at the top of the screen when the device is offline, providing immediate feedback about network connectivity.

### Integration Points
All shell widgets now include the `OfflineBanner` at the top of their Scaffold body:

- **AppShell** - All customer routes
- **ManagerShell** - All manager routes
- **KitchenShell** - All kitchen routes
- **DeliveryShell** - All delivery routes

### Usage Pattern
```dart
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        const OfflineBanner(),  // Shows only when offline
        Expanded(child: content),
      ],
    ),
  ),
)
```

### Features
- **Automatic Detection** - Uses `networkStatusProvider` to monitor connectivity
- **Smart Display** - Only shows when offline (configurable)
- **Visual Feedback** - Color-coded (red for offline, green for reconnected)
- **Non-intrusive** - Collapses to zero height when online

### Additional Components

#### OfflineIndicator
A small dot indicator for use in AppBars:
```dart
AppBar(
  actions: [
    const OfflineIndicator(),
  ],
)
```

#### NetworkAware
Shows different widgets based on connectivity:
```dart
NetworkAware(
  online: OnlineContent(),
  offline: OfflinePlaceholder(
    onRetry: () => ref.refresh(dataProvider),
  ),
)
```

#### NoConnectionPlaceholder
A full-screen placeholder for offline states:
```dart
NoConnectionPlaceholder(
  onRetry: () => ref.refresh(dataProvider),
)
```

---

## 3. AsyncDataBuilder

### Purpose
`AsyncDataBuilder` provides a unified way to handle async data states (loading, error, data) with consistent UI patterns.

### Benefits
1. **Consistent Loading States** - Same loading indicator across app
2. **Standardized Error Handling** - Automatic error display with retry
3. **Type Safety** - Generic type support
4. **Reduced Boilerplate** - Less code duplication

### Basic Usage
```dart
// BEFORE (inconsistent):
final asyncValue = ref.watch(dataProvider);
if (asyncValue.isLoading) {
  return const Center(child: CircularProgressIndicator());
}
if (asyncValue.hasError) {
  return ErrorDisplay(error: asyncValue.error);
}
return DataWidget(data: asyncValue.value!);

// AFTER (standardized):
return AsyncDataBuilder<List<Item>>(
  value: ref.watch(dataProvider),
  data: (items) => DataWidget(data: items),
  loadingMessage: 'Caricamento dati...',  // Optional
  onRetry: () => ref.invalidate(dataProvider),  // Optional
);
```

### With Shimmer Loading
For content that needs a polished loading experience:
```dart
AsyncDataBuilderWithShimmer<List<MenuItem>>(
  value: ref.watch(menuProvider),
  data: (items) => MenuGrid(items: items),
  shimmer: () => MenuLoadingShimmer(),  // Custom shimmer
)
```

### Handling Null Data
```dart
AsyncDataBuilder<UserModel>(
  value: ref.watch(userProvider),
  skipOnNull: const LoginPrompt(),  // Show when data is null
  data: (user) => UserProfile(user: user),
)
```

### Custom Error Handling
```dart
AsyncDataBuilder<List<Order>>(
  value: ref.watch(ordersProvider),
  data: (orders) => OrdersList(orders: orders),
  error: (error, stack) => CustomErrorWidget(
    error: error,
    onRetry: () => ref.invalidate(ordersProvider),
  ),
)
```

---

## 4. Migration Guide

### Step 1: Identify Patterns to Replace
Search for common patterns:
```bash
# Find manual loading checks
grep -r "isLoading" lib/features --include="*.dart"

# Find manual error checks
grep -r "hasError" lib/features --include="*.dart"

# Find when() calls without error handling
grep -r "\.when(" lib/features --include="*.dart"
```

### Step 2: Replace Manual State Handling
```dart
// BEFORE:
return ordersAsync.when(
  data: (orders) => OrdersList(orders: orders),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => ErrorDisplay(error: e),
);

// AFTER:
return AsyncDataBuilder<List<Order>>(
  value: ordersAsync,
  data: (orders) => OrdersList(orders: orders),
  onRetry: () => ref.invalidate(ordersProvider),
);
```

### Step 3: Add Error Boundaries to New Screens
Always wrap new screen widgets with ErrorBoundary:
```dart
class NewScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorBoundaryWithLogger(
      contextTag: 'NewScreen',
      child: Scaffold(
        // ... content
      ),
    );
  }
}
```

---

## 5. Complete Example

### Before Migration
```dart
class OrdersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    
    return Scaffold(
      body: ordersAsync.when(
        data: (orders) => ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) => OrderTile(order: orders[index]),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}
```

### After Migration
```dart
class OrdersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    
    return ErrorBoundaryWithLogger(
      contextTag: 'OrdersScreen',
      child: Scaffold(
        body: AsyncDataBuilder<List<Order>>(
          value: ordersAsync,
          data: (orders) => ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) => OrderTile(order: orders[index]),
          ),
          loadingMessage: 'Caricamento ordini...',
          onRetry: () => ref.invalidate(ordersProvider),
        ),
      ),
    );
  }
}
```

---

## 6. Checklist for New Features

When adding new screens or features:

- [ ] Wrap screen with `ErrorBoundaryWithLogger`
- [ ] Use `AsyncDataBuilder` for async data
- [ ] Add `OfflineBanner` if not using a shell widget
- [ ] Provide retry callbacks for error states
- [ ] Use `OfflineIndicator` in AppBars for critical screens
- [ ] Test error scenarios (disable network, trigger errors)

---

## 7. Testing

### Error Boundary Testing
```dart
testWidgets('ErrorBoundary catches errors', (tester) async {
  await tester.pumpWidget(
    ErrorBoundary(
      child: WidgetThatThrows(),
    ),
  );
  
  expect(find.byType(ErrorDisplay), findsOneWidget);
});
```

### Offline Banner Testing
```dart
testWidgets('OfflineBanner shows when offline', (tester) async {
  // Mock network provider to return offline
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        networkStatusProvider.overrideWithValue(
          AsyncValue.data(NetworkState(isOnline: false)),
        ),
      ],
      child: const OfflineBanner(),
    ),
  );
  
  expect(find.text('Offline - verifica la connessione'), findsOneWidget);
});
```

---

## 8. Related Files

### Widgets
- `lib/core/widgets/error_boundary.dart` - Error boundary widgets
- `lib/core/widgets/offline_banner.dart` - Offline detection widgets
- `lib/core/widgets/async_data_builder.dart` - Async state builder
- `lib/core/widgets/error_display.dart` - Error display widget

### Providers
- `lib/core/providers/network_status_provider.dart` - Network connectivity

### Shells (Integration Points)
- `lib/core/widgets/app_shell.dart`
- `lib/features/manager/widgets/manager_shell.dart`
- `lib/features/kitchen/widgets/kitchen_shell.dart`
- `lib/features/delivery/widgets/delivery_shell.dart`

---

## 9. Summary

All frontend infrastructure is now integrated:

| Component | Status | Coverage |
|-----------|--------|----------|
| Error Boundaries | ✅ Integrated | All shells + critical screens |
| Offline Banner | ✅ Integrated | All shell widgets |
| AsyncDataBuilder | ✅ Available | Ready for adoption |

**Next Steps:**
1. Gradually adopt `AsyncDataBuilder` in existing screens as you touch them
2. Always use error boundaries for new screens
3. Monitor error reporting for issues
