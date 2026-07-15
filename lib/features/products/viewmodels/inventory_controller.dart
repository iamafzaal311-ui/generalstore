import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/brand_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/repositories/inventory_repository_impl.dart';
import '../../../domain/repositories/inventory_repository.dart';

class InventoryState {
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final List<BrandModel> brands;
  final List<SupplierModel> suppliers;
  final bool isLoading;
  final String? errorMessage;

  InventoryState({
    this.products = const [],
    this.categories = const [],
    this.brands = const [],
    this.suppliers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  InventoryState copyWith({
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    List<BrandModel>? brands,
    List<SupplierModel>? suppliers,
    bool? isLoading,
    String? errorMessage,
  }) {
    return InventoryState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(localDbServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  return InventoryRepositoryImpl(db, sync);
});

class InventoryController extends StateNotifier<InventoryState> {
  final InventoryRepository _repo;

  InventoryController(this._repo) : super(InventoryState()) {
    refreshAll();
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final products = await _repo.getProducts();
      final categories = await _repo.getCategories();
      final brands = await _repo.getBrands();
      final suppliers = await _repo.getSuppliers();
      
      state = state.copyWith(
        products: products,
        categories: categories,
        brands: brands,
        suppliers: suppliers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // CATEGORIES
  Future<void> saveCategory(CategoryModel category) async {
    await _repo.saveCategory(category);
    await refreshAll();
  }

  Future<void> deleteCategory(String categoryId) async {
    await _repo.deleteCategory(categoryId);
    await refreshAll();
  }

  // BRANDS
  Future<void> saveBrand(BrandModel brand) async {
    await _repo.saveBrand(brand);
    await refreshAll();
  }

  Future<void> deleteBrand(String brandId) async {
    await _repo.deleteBrand(brandId);
    await refreshAll();
  }

  // SUPPLIERS
  Future<void> saveSupplier(SupplierModel supplier) async {
    await _repo.saveSupplier(supplier);
    await refreshAll();
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _repo.deleteSupplier(supplierId);
    await refreshAll();
  }

  // PRODUCTS
  Future<void> saveProduct(ProductModel product) async {
    await _repo.saveProduct(product);
    await refreshAll();
  }

  Future<void> deleteProduct(String productId) async {
    await _repo.deleteProduct(productId);
    await refreshAll();
  }
  
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    return await _repo.getProductByBarcode(barcode);
  }
}

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, InventoryState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return InventoryController(repo);
});
