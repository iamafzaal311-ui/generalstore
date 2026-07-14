import '../../data/models/product_model.dart';

/// Domain repository interface for product-level operations.
/// Note: This is a focused subset of [InventoryRepository] for product-only operations.
/// The full [InventoryRepository] also covers categories, brands, and suppliers.
abstract class ProductRepository {
  Future<List<ProductModel>> getProducts();
  Future<ProductModel?> getProductById(String productId);
  Future<ProductModel?> getProductByBarcode(String barcode);
  Future<ProductModel?> getProductBySku(String sku);
  Future<void> saveProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
  Future<void> updateStock(String productId, double quantityChange);
}
