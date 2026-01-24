# Testing Infrastructure

This directory contains the testing infrastructure for the Rotante application.

## Key Principle: No Real Database Interactions

**IMPORTANT**: All tests in this project are designed to run WITHOUT connecting to any real database or external service. All external dependencies are mocked.

## Directory Structure

```
test/
├── mocks/                    # Mock classes for external dependencies
│   ├── supabase_mocks.dart   # Supabase client, auth, storage mocks
│   └── service_mocks.dart    # Application service mocks
├── fixtures/                 # Test data factories
│   └── model_factories.dart  # Factories for creating test models
├── helpers/                  # Test utilities and helpers
│   └── test_helpers.dart     # Widget wrappers, matchers, utilities
├── core/                     # Core module tests
│   ├── services/             # Service unit tests
│   │   ├── database_service_test.dart
│   │   └── auth_service_test.dart
│   └── models/               # Model tests
│       ├── user_model_test.dart
│       └── order_model_test.dart
├── widgets/                  # Widget tests
│   └── common_widgets_test.dart
├── test_config.dart          # Central test exports
└── README.md                 # This file
```

## Quick Start

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run All Tests

```bash
flutter test
```

### 3. Run Specific Test File

```bash
flutter test test/core/models/user_model_test.dart
```

### 4. Run Tests with Coverage

```bash
flutter test --coverage
```

## Writing Tests

### Basic Test Structure

```dart
import '../test_config.dart';

void main() {
  // Run once before all tests
  setUpAll(() {
    setupTestEnvironment();
  });

  // Run before each test
  setUp(() {
    resetTestState();
  });

  group('Feature Name', () {
    test('should do something', () {
      // Arrange
      final input = 'test';

      // Act
      final result = doSomething(input);

      // Assert
      expect(result, equals('expected'));
    });
  });
}
```

### Using Model Factories

Factories provide convenient methods to create test data:

```dart
// Create a customer user
final user = UserFactory.customer(nome: 'Mario');

// Create a manager
final manager = UserFactory.manager();

// Create a menu item
final pizza = MenuItemFactory.pizza(nome: 'Margherita', prezzo: 7.0);

// Create an order
final order = OrderFactory.confirmed(totale: 25.0);
```

### Mocking Supabase

Never use the real Supabase client in tests. Use mocks instead:

```dart
test('fetches menu items from database', () async {
  // Create mock factory
  final factory = MockSupabaseClientFactory();

  // Configure mock response
  final menuBuilder = factory.getTableBuilder('menu_items');
  menuBuilder.whenSelectReturns([
    {'id': '1', 'nome': 'Margherita', 'prezzo': 7.0},
  ]);

  // Use the mock client in your service
  // ...
});
```

### Mocking Authentication

```dart
test('handles authenticated user', () {
  final factory = MockSupabaseClientFactory();

  // Set up authenticated state
  final fakeUser = FakeUser(id: 'user-123', email: 'test@test.com');
  factory.setAuthenticatedUser(fakeUser);

  // Now mockAuth.currentUser returns the fake user
  expect(factory.auth.currentUser, isNotNull);
});

test('handles unauthenticated state', () {
  final factory = MockSupabaseClientFactory();
  factory.setUnauthenticated();

  expect(factory.auth.currentUser, isNull);
});
```

### Widget Tests

Use `wrapWithApp` to set up the widget test environment:

```dart
testWidgets('displays menu items', (tester) async {
  await tester.pumpWidget(
    wrapWithApp(
      const MenuScreen(),
      overrides: [
        menuProvider.overrideWithValue(mockMenuItems),
      ],
    ),
  );

  expect(find.text('Margherita'), findsOneWidget);
});
```

### Testing Riverpod Providers

Use `createTestContainer` for provider tests:

```dart
test('provider returns correct data', () async {
  final container = createTestContainer(
    overrides: [
      databaseServiceProvider.overrideWithValue(mockDbService),
    ],
  );

  final result = await container.read(menuProvider.future);

  expect(result.length, equals(3));
});
```

## Best Practices

### 1. Always Reset State

Call `resetTestState()` in `setUp()` to ensure clean state:

```dart
setUp(() {
  resetTestState();
});
```

### 2. Use Descriptive Test Names

```dart
// Good
test('returns empty list when no orders exist', () {});

// Bad
test('test1', () {});
```

### 3. Follow Arrange-Act-Assert Pattern

```dart
test('calculates total correctly', () {
  // Arrange - Set up test data
  final items = [
    OrderItemFactory.create(prezzoUnitario: 10.0, quantita: 2),
  ];

  // Act - Perform the action
  final total = calculateTotal(items);

  // Assert - Verify the result
  expect(total, equals(20.0));
});
```

### 4. Test Edge Cases

```dart
group('calculateTotal', () {
  test('handles empty list', () {});
  test('handles single item', () {});
  test('handles multiple items', () {});
  test('handles zero quantities', () {});
  test('handles negative quantities', () {});
  test('handles decimal prices', () {});
});
```

### 5. Mock External Dependencies

Never let tests touch real databases, APIs, or services:

```dart
// WRONG - Don't do this
final realClient = Supabase.instance.client;

// CORRECT - Use mocks
final mockClient = MockSupabaseClient();
```

## Available Matchers

```dart
// Async matchers
expect(value, isAsyncLoading<T>());
expect(value, isAsyncData<T>());
expect(value, isAsyncError<T>());
expect(value, asyncDataEquals(expectedValue));

// Currency matcher (handles floating point)
expect(price, closeToCurrency(9.99));

// Sorted list matcher
expect(list, isSortedBy((item) => item.createdAt));
```

## Running in CI/CD

The tests are designed to run in any CI environment without external dependencies:

```yaml
# Example GitHub Actions
- name: Run tests
  run: flutter test --coverage

- name: Check coverage
  run: |
    flutter pub global activate test_coverage
    test_coverage
```

## Troubleshooting

### Tests Failing with "MissingPluginException"

This usually means a platform plugin is being called in tests. Make sure to:
1. Mock all services that use platform plugins
2. Use `setupFakeSharedPreferences()` for SharedPreferences

### Tests Hanging

Check for:
1. Unclosed streams - use `StreamTestHelper.close()`
2. Uncompleted futures - use `AsyncTestHelper.complete()`
3. Timers not advancing - use `FakeAsync`

### "No host specified" Errors

This means the test is trying to make real network requests. Ensure all HTTP clients are mocked.

## Contributing

When adding new tests:
1. Place them in the appropriate directory
2. Follow existing naming conventions
3. Use factories for test data
4. Never use real external services
5. Add new mocks to `mocks/` if needed
6. Update this README if adding new patterns
