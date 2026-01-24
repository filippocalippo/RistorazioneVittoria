/// Central test configuration and exports.
///
/// Import this file in your tests to get access to all testing utilities:
/// ```dart
/// import 'package:rotante/test/test_config.dart';
/// ```
library;

// Re-export testing packages
export 'package:flutter_test/flutter_test.dart';
export 'package:mocktail/mocktail.dart';

// Re-export mocks
// export 'mocks/supabase_mocks.dart';
// export 'mocks/service_mocks.dart';

// Re-export fixtures
// export 'fixtures/model_factories.dart';

// Re-export helpers
// export 'helpers/test_helpers.dart';

// Re-export app models for convenience
export 'package:rotante/core/models/user_model.dart';
export 'package:rotante/core/models/menu_item_model.dart';
export 'package:rotante/core/models/order_model.dart';
export 'package:rotante/core/models/order_item_model.dart';
export 'package:rotante/core/models/category_model.dart';
export 'package:rotante/core/models/ingredient_model.dart';
export 'package:rotante/core/models/size_variant_model.dart';
export 'package:rotante/core/models/cart_item_model.dart';
export 'package:rotante/core/utils/enums.dart';
