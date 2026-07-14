import 'dart:convert';
import '../../domain/repositories/transactions_repository.dart';
import '../datasources/local_db_service.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';


class TransactionsRepositoryImpl implements TransactionsRepository {
  final LocalDbService _db;

  TransactionsRepositoryImpl(this._db);

  @override
  Future<List<PurchaseModel>> getPurchases() async {
    final purchases = _db.purchasesBox.values.where((e) => !e.isDeleted).toList();
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
  }

  @override
  Future<List<SaleModel>> getSalesLogs() async {
    final sales = _db.salesBox.values.where((e) => !e.isDeleted).toList();
    sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sales;
  }
}
