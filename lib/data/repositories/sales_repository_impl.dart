import 'dart:convert';
import 'dart:async';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/local_db_service.dart';
import '../models/sale_model.dart';

import '../../core/services/sync_service.dart';

import '../models/customer_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  final LocalDbService _db;
  final SyncService _sync;

  SalesRepositoryImpl(this._db, this._sync);

  @override
  Future<List<SaleModel>> getSales() async {
    final sales = _db.salesBox.values.where((e) => !e.isDeleted).toList();
    sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sales;
  }

  @override
  Future<void> saveSale(SaleModel sale) async {
    sale.isDirty = true;
    sale.lastUpdated = DateTime.now();

    // 1. Save Sale
    await _db.salesBox.put(sale.saleId, sale);

    // 2. Adjust Product Stocks
    final items = jsonDecode(sale.itemsJson) as List;
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

    // 3. Adjust Customer Credit (Khata) if there is an unpaid amount
    if (sale.customerId != null) {
      final customer = _db.customersBox.get(sale.customerId);
      if (customer != null) {
        final unpaidAmount = sale.total - sale.paidAmount;
        if (unpaidAmount != 0) {
          customer.balance += unpaidAmount;
          customer.isDirty = true;
          customer.lastUpdated = DateTime.now();
          await customer.save();
        }
      }
    }

    unawaited(_sync.syncDirtyRecords());
  }

  @override
  Future<void> deleteSale(String saleId) async {
    final sale = _db.salesBox.get(saleId);
    if (sale != null) {
      sale.isDeleted = true;
      sale.isDirty = true;
      sale.lastUpdated = DateTime.now();

      // Soft delete sale
      await sale.save();

      // Put back stock levels
      final items = jsonDecode(sale.itemsJson) as List;
      for (final item in items) {
        final productId = item['productId'] as String;
        final qty = (item['quantity'] as num).toDouble();

        final product = _db.productsBox.get(productId);
        if (product != null) {
          product.stock += qty;
          product.isDirty = true;
          product.lastUpdated = DateTime.now();
          await product.save();
        }
      }

      // Revert credit from customer (Khata)
      if (sale.customerId != null) {
        final customer = _db.customersBox.get(sale.customerId);
        if (customer != null) {
          final unpaidAmount = sale.total - sale.paidAmount;
          if (unpaidAmount != 0) {
            customer.balance -= unpaidAmount;
            customer.isDirty = true;
            customer.lastUpdated = DateTime.now();
            await customer.save();
          }
        }
      }
    }
  }

  @override
  Future<List<CustomerModel>> getCustomers() async {
    return _db.customersBox.values.where((e) => !e.isDeleted).toList();
  }

  @override
  Future<void> saveCustomer(CustomerModel customer) async {
    customer.isDirty = true;
    customer.lastUpdated = DateTime.now();
    await _db.customersBox.put(customer.customerId, customer);
  }
}
