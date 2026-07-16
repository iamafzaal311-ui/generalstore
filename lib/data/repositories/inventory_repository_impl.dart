import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    if (category.isInBox) {
      await category.save();
    } else {
      await _db.categoriesBox.put(category.categoryId, category);
    }
    try {
      unawaited(_sync.syncDirtyRecords());
    } catch (e) {
      print('Sync error: $e');
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final category = _db.categoriesBox.get(categoryId);
    if (category != null) {
      category.isDeleted = true;
      category.isDirty = true;
      category.lastUpdated = DateTime.now();
      await category.save();
      try {
        unawaited(_sync.syncDirtyRecords());
      } catch (e) {
        print('Sync error: $e');
      }
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
    if (brand.isInBox) {
      await brand.save();
    } else {
      await _db.brandsBox.put(brand.brandId, brand);
    }
    try {
      unawaited(_sync.syncDirtyRecords());
    } catch (e) {
      print('Sync error: $e');
    }
  }

  @override
  Future<void> deleteBrand(String brandId) async {
    final brand = _db.brandsBox.get(brandId);
    if (brand != null) {
      brand.isDeleted = true;
      brand.isDirty = true;
      brand.lastUpdated = DateTime.now();
      await brand.save();
      try {
        unawaited(_sync.syncDirtyRecords());
      } catch (e) {
        print('Sync error: $e');
      }
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
    if (supplier.isInBox) {
      await supplier.save();
    } else {
      await _db.suppliersBox.put(supplier.supplierId, supplier);
    }
    try {
      unawaited(_sync.syncDirtyRecords());
    } catch (e) {
      print('Sync error: $e');
    }
  }

  @override
  Future<void> deleteSupplier(String supplierId) async {
    final supplier = _db.suppliersBox.get(supplierId);
    if (supplier != null) {
      supplier.isDeleted = true;
      supplier.isDirty = true;
      supplier.lastUpdated = DateTime.now();
      await supplier.save();
      try {
        unawaited(_sync.syncDirtyRecords());
      } catch (e) {
        print('Sync error: $e');
      }
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
    if (product.isInBox) {
      await product.save();
    } else {
      await _db.productsBox.put(product.productId, product);
    }
    try {
      unawaited(_sync.syncDirtyRecords());
    } catch (e) {
      print('Sync error: $e');
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    // Hard delete from local Hive box
    await _db.productsBox.delete(productId);
    
    // Hard delete from Firestore immediately if online
    try {
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final docRef = FirebaseFirestore.instance
              .collection('stores')
              .doc(user.uid)
              .collection('products')
              .doc(productId);
          await docRef.delete();
        }
      }
    } catch (e) {
      print('Firebase hard delete error: $e');
    }
    
    try {
      unawaited(_sync.syncDirtyRecords());
    } catch (e) {
      print('Sync error: $e');
    }
  }

  @override
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    return _db.productsBox.values
        .where((e) => e.barcode == barcode && !e.isDeleted)
        .firstOrNull;
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
