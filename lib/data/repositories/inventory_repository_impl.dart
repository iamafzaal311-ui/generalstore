import '../../core/services/sync_service.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/local_db_service.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../models/supplier_model.dart';


class InventoryRepositoryImpl implements InventoryRepository {
  final LocalDbService _db;
  final SyncService _sync;

  InventoryRepositoryImpl(this._db, this._sync);

  // CATEGORIES
  @override
  Future<List<CategoryModel>> getCategories() async {
    return _db.categoriesBox.values.where((e) => !e.isDeleted).toList();
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    category.isDirty = true;
    category.lastUpdated = DateTime.now();
    await _db.categoriesBox.put(category.categoryId, category);
    await _sync.syncDirtyRecords();
  }


  @override
  Future<void> deleteCategory(String categoryId) async {
    final category = _db.categoriesBox.get(categoryId);
    if (category != null) {
      category.isDeleted = true;
      category.isDirty = true;
      category.lastUpdated = DateTime.now();
      await category.save();
      await _sync.syncDirtyRecords();
    }
  }

  // BRANDS
  @override
  Future<List<BrandModel>> getBrands() async {
    return _db.brandsBox.values.where((e) => !e.isDeleted).toList();
  }

  @override
  Future<void> saveBrand(BrandModel brand) async {
    brand.isDirty = true;
    brand.lastUpdated = DateTime.now();
    await _db.brandsBox.put(brand.brandId, brand);
    await _sync.syncDirtyRecords();
  }


  @override
  Future<void> deleteBrand(String brandId) async {
    final brand = _db.brandsBox.get(brandId);
    if (brand != null) {
      brand.isDeleted = true;
      brand.isDirty = true;
      brand.lastUpdated = DateTime.now();
      await brand.save();
      await _sync.syncDirtyRecords();
    }
  }

  // SUPPLIERS
  @override
  Future<List<SupplierModel>> getSuppliers() async {
    return _db.suppliersBox.values.where((e) => !e.isDeleted).toList();
  }

  @override
  Future<void> saveSupplier(SupplierModel supplier) async {
    supplier.isDirty = true;
    supplier.lastUpdated = DateTime.now();
    await _db.suppliersBox.put(supplier.supplierId, supplier);
    await _sync.syncDirtyRecords();
  }


  @override
  Future<void> deleteSupplier(String supplierId) async {
    final supplier = _db.suppliersBox.get(supplierId);
    if (supplier != null) {
      supplier.isDeleted = true;
      supplier.isDirty = true;
      supplier.lastUpdated = DateTime.now();
      await supplier.save();
      await _sync.syncDirtyRecords();
    }
  }

  // PRODUCTS
  @override
  Future<List<ProductModel>> getProducts() async {
    return _db.productsBox.values.where((e) => !e.isDeleted).toList();
  }

  @override
  Future<void> saveProduct(ProductModel product) async {
    product.isDirty = true;
    product.lastUpdated = DateTime.now();
    await _db.productsBox.put(product.productId, product);
    await _sync.syncDirtyRecords();
  }


  @override
  Future<void> deleteProduct(String productId) async {
    final product = _db.productsBox.get(productId);
    if (product != null) {
      product.isDeleted = true;
      product.isDirty = true;
      product.lastUpdated = DateTime.now();
      await product.save();
      await _sync.syncDirtyRecords();
    }
  }

  @override
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    return _db.productsBox.values.where((e) => e.barcode == barcode && !e.isDeleted).firstOrNull;
  }

  @override
  Future<void> updateStock(String productId, double quantityChange) async {
    final product = _db.productsBox.get(productId);
    if (product != null) {
      product.stock += quantityChange;
      product.isDirty = true;
      product.lastUpdated = DateTime.now();
      await product.save();
    }
  }
}
