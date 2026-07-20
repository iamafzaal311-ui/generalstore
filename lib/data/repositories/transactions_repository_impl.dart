import 'dart:async';
import 'dart:convert';
import '../../domain/repositories/transactions_repository.dart';
import '../datasources/local_db_service.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';

import '../../core/services/sync_service.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  final LocalDbService _db;
  final SyncService _sync;

  TransactionsRepositoryImpl(this._db, this._sync);

  @override
  Future<List<PurchaseModel>> getPurchases() async {
    final purchases = _db.purchasesBox.values
        .where((e) => !e.isDeleted)
        .toList();
    purchases.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return purchases;
  }

  @override
  Future<void> savePurchase(PurchaseModel purchase) async {
    purchase.isDirty = true;
    purchase.lastUpdated = DateTime.now();

    // 1. Save Purchase
    await _db.purchasesBox.put(purchase.purchaseId, purchase);

    // 2. Adjust Product Stock Levels and Update Purchase Cost
    final items = jsonDecode(purchase.itemsJson) as List;
    for (final item in items) {
      final productId = item['productId'] as String;
      final qty = (item['quantity'] as num).toDouble();
      final cost = (item['purchasePrice'] as num).toDouble();

      final product = _db.productsBox.get(productId);

      if (product != null) {
        product.stock += qty;
        product.purchasePrice = cost; // Update cost price
        product.isDirty = true;
        product.lastUpdated = DateTime.now();
        await product.save();
      }
    }

    // 3. Adjust Supplier Balance (Credit)
    if (purchase.totalAmount > purchase.paidAmount) {
      final supplier = _db.suppliersBox.get(purchase.supplierId);

      if (supplier != null) {
        final unpaid = purchase.totalAmount - purchase.paidAmount;
        supplier.balance += unpaid;
        supplier.isDirty = true;
        supplier.lastUpdated = DateTime.now();
        await supplier.save();
      }
    }
    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<void> updatePurchase(PurchaseModel oldPurchase, PurchaseModel newPurchase) async {
    // 1. REVERT old purchase effects
    final oldItems = jsonDecode(oldPurchase.itemsJson) as List;
    for (final item in oldItems) {
      final productId = item['productId'] as String;
      final qty = (item['quantity'] as num).toDouble();
      final product = _db.productsBox.get(productId);
      if (product != null) {
        product.stock -= qty;
        product.isDirty = true;
        product.lastUpdated = DateTime.now();
        await product.save();
      }
    }
    
    if (oldPurchase.totalAmount > oldPurchase.paidAmount) {
      final supplier = _db.suppliersBox.get(oldPurchase.supplierId);
      if (supplier != null) {
        final unpaid = oldPurchase.totalAmount - oldPurchase.paidAmount;
        supplier.balance -= unpaid;
        supplier.isDirty = true;
        supplier.lastUpdated = DateTime.now();
        await supplier.save();
      }
    }

    // 2. APPLY new purchase effects
    final newItems = jsonDecode(newPurchase.itemsJson) as List;
    for (final item in newItems) {
      final productId = item['productId'] as String;
      final qty = (item['quantity'] as num).toDouble();
      final cost = (item['purchasePrice'] as num).toDouble();
      final product = _db.productsBox.get(productId);
      if (product != null) {
        product.stock += qty;
        product.purchasePrice = cost;
        product.isDirty = true;
        product.lastUpdated = DateTime.now();
        await product.save();
      }
    }

    if (newPurchase.totalAmount > newPurchase.paidAmount) {
      final supplier = _db.suppliersBox.get(newPurchase.supplierId);
      if (supplier != null) {
        final unpaid = newPurchase.totalAmount - newPurchase.paidAmount;
        supplier.balance += unpaid;
        supplier.isDirty = true;
        supplier.lastUpdated = DateTime.now();
        await supplier.save();
      }
    }

    // 3. Update the purchase record
    newPurchase.isDirty = true;
    newPurchase.lastUpdated = DateTime.now();
    await _db.purchasesBox.put(newPurchase.purchaseId, newPurchase);

    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<void> deletePurchase(String purchaseId) async {
    final purchase = _db.purchasesBox.get(purchaseId);

    if (purchase != null) {
      purchase.isDeleted = true;
      purchase.isDirty = true;
      purchase.lastUpdated = DateTime.now();

      // Soft delete purchase
      await purchase.save();

      // Revert stock level increases
      final items = jsonDecode(purchase.itemsJson) as List;
      for (final item in items) {
        final productId = item['productId'] as String;
        final qty = (item['quantity'] as num).toDouble();

        final product = _db.productsBox.get(productId);

        if (product != null) {
          product.stock -= qty;
          product.isDirty = true;
          product.lastUpdated = DateTime.now();
          await product.save();
        }
      }

      // Revert supplier balance credit
      if (purchase.totalAmount > purchase.paidAmount) {
        final supplier = _db.suppliersBox.get(purchase.supplierId);

        if (supplier != null) {
          final unpaid = purchase.totalAmount - purchase.paidAmount;
          supplier.balance -= unpaid;
          supplier.isDirty = true;
          supplier.lastUpdated = DateTime.now();
          await supplier.save();
        }
      }
    }
    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<List<SaleModel>> getSalesLogs() async {
    final sales = _db.salesBox.values.where((e) => !e.isDeleted).toList();
    sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sales;
  }
}
