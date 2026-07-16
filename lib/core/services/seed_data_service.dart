import '../../data/datasources/local_db_service.dart';

/// Seed data service — disabled for client delivery.
/// The client will add their own products, categories, brands and suppliers.
class SeedDataService {
  /// No-op: does nothing. Kept for compatibility with any existing call sites.
  static Future<void> seedIfEmpty(LocalDbService db) async {
    // Intentionally empty — client adds their own data.
    return;
  }
}
