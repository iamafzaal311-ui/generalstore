import '../../data/models/product_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/brand_model.dart';
import '../../data/models/supplier_model.dart';

abstract class InventoryRepository {
  // Categories
  Future<List<CategoryModel>> getCategories();
  Future<void> saveCategory(CategoryModel category);
  Future<void> deleteCategory(String categoryId);

  // Brands
  Future<List<BrandModel>> getBrands();
  Future<void> saveBrand(BrandModel brand);
  Future<void> deleteBrand(String brandId);

  // Suppliers
  Future<List<SupplierModel>> getSuppliers();
  Future<void> saveSupplier(SupplierModel supplier);
  Future<void> deleteSupplier(String supplierId);

  // Products
  Future<List<ProductModel>> getProducts();
  Future<void> saveProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
  Future<ProductModel?> getProductByBarcode(String barcode);
  Future<void> updateStock(String productId, double quantityChange);
}
