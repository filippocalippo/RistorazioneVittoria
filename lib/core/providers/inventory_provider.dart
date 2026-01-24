import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rotante/core/services/inventory_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'inventory_provider.g.dart';

@riverpod
InventoryService inventoryService(Ref ref) {
  return InventoryService(Supabase.instance.client);
}
