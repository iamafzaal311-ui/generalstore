import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/local_db_service.dart';
import '../../data/models/brand_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/supplier_model.dart';
import '../../data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';


class SyncService {
  final LocalDbService _db;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService(this._db) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        syncDirtyRecords();
      }
    });
    
    // Also monitor auth state to trigger sync on login
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        restoreAllFromCloud();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncDirtyRecords() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isSyncing = false;
        return; // Don't sync if no admin is logged in
      }
      final adminUid = user.uid;
      final storeRef = FirebaseFirestore.instance.collection('stores').doc(adminUid);

      // 1. Sync Categories
      final dirtyCats = _db.categoriesBox.values.where((e) => e.isDirty).toList();
      for (final cat in dirtyCats) {
        await storeRef.collection('categories').doc(cat.categoryId).set({
          'categoryId': cat.categoryId,
          'name': cat.name,
          'description': cat.description,
          'lastUpdated': cat.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': cat.isDeleted,
        });
        cat.isDirty = false;
        if (cat.isInBox) await cat.save();
      }

      // 2. Sync Brands
      final dirtyBrands = _db.brandsBox.values.where((e) => e.isDirty).toList();
      for (final brand in dirtyBrands) {
        await storeRef.collection('brands').doc(brand.brandId).set({
          'brandId': brand.brandId,
          'name': brand.name,
          'description': brand.description,
          'lastUpdated': brand.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': brand.isDeleted,
        });
        brand.isDirty = false;
        if (brand.isInBox) await brand.save();
      }

      // 3. Sync Suppliers
      final dirtySuppliers = _db.suppliersBox.values.where((e) => e.isDirty).toList();
      for (final sup in dirtySuppliers) {
        await storeRef.collection('suppliers').doc(sup.supplierId).set({
          'supplierId': sup.supplierId,
          'name': sup.name,
          'contactName': sup.contactName,
          'phone': sup.phone,
          'email': sup.email,
          'address': sup.address,
          'balance': sup.balance,
          'lastUpdated': sup.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': sup.isDeleted,
        });
        sup.isDirty = false;
        if (sup.isInBox) await sup.save();
      }

      // 4. Sync Customers
      final dirtyCustomers = _db.customersBox.values.where((e) => e.isDirty).toList();
      for (final cust in dirtyCustomers) {
        await storeRef.collection('customers').doc(cust.customerId).set({
          'customerId': cust.customerId,
          'name': cust.name,
          'phone': cust.phone,
          'email': cust.email,
          'address': cust.address,
          'balance': cust.balance,
          'lastUpdated': cust.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': cust.isDeleted,
        });
        cust.isDirty = false;
        if (cust.isInBox) await cust.save();
      }

      // 5. Sync Products
      final dirtyProducts = _db.productsBox.values.where((e) => e.isDirty).toList();
      for (final prod in dirtyProducts) {
        await storeRef.collection('products').doc(prod.productId).set({
          'productId': prod.productId,
          'name': prod.name,
          'sku': prod.sku,
          'barcode': prod.barcode,
          'categoryId': prod.categoryId,
          'brandId': prod.brandId,
          'supplierId': prod.supplierId,
          'purchasePrice': prod.purchasePrice,
          'wholesalePrice': prod.wholesalePrice,
          'retailPrice': prod.retailPrice,
          'minimumPrice': prod.minimumPrice,
          'stock': prod.stock,
          'unit': prod.unit,
          'openingStock': prod.openingStock,
          'minimumStock': prod.minimumStock,
          'maximumStock': prod.maximumStock,
          'expiryDate': prod.expiryDate?.toUtc().toIso8601String(),
          'description': prod.description,
          'lastUpdated': prod.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': prod.isDeleted,
        });
        prod.isDirty = false;
        if (prod.isInBox) await prod.save();
      }

      // 6. Sync Sales
      final dirtySales = _db.salesBox.values.where((e) => e.isDirty).toList();
      for (final sale in dirtySales) {
        await storeRef.collection('sales').doc(sale.saleId).set({
          'saleId': sale.saleId,
          'invoiceNumber': sale.invoiceNumber,
          'cashierId': sale.cashierId,
          'customerId': sale.customerId,
          'subtotal': sale.subtotal,
          'discount': sale.discount,
          'total': sale.total,
          'paidAmount': sale.paidAmount,
          'changeAmount': sale.changeAmount,
          'paymentMethod': sale.paymentMethod,
          'timestamp': sale.timestamp.toUtc().toIso8601String(),
          'itemsJson': sale.itemsJson,
          'lastUpdated': sale.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': sale.isDeleted,
        });
        sale.isDirty = false;
        if (sale.isInBox) await sale.save();
      }

      // 7. Sync Purchases
      final dirtyPurchases = _db.purchasesBox.values.where((e) => e.isDirty).toList();
      for (final purchase in dirtyPurchases) {
        await storeRef.collection('purchases').doc(purchase.purchaseId).set({
          'purchaseId': purchase.purchaseId,
          'invoiceNumber': purchase.invoiceNumber,
          'supplierId': purchase.supplierId,
          'totalAmount': purchase.totalAmount,
          'paidAmount': purchase.paidAmount,
          'timestamp': purchase.timestamp.toUtc().toIso8601String(),
          'itemsJson': purchase.itemsJson,
          'lastUpdated': purchase.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': purchase.isDeleted,
        });
        purchase.isDirty = false;
        if (purchase.isInBox) await purchase.save();
      }

      // 8. Sync Expenses
      final dirtyExpenses = _db.expensesBox.values.where((e) => e.isDirty).toList();
      for (final expense in dirtyExpenses) {
        await storeRef.collection('expenses').doc(expense.expenseId).set({
          'expenseId': expense.expenseId,
          'title': expense.title,
          'category': expense.category,
          'amount': expense.amount,
          'description': expense.description,
          'timestamp': expense.timestamp.toUtc().toIso8601String(),
          'lastUpdated': expense.lastUpdated.toUtc().toIso8601String(),
          'isDeleted': expense.isDeleted,
        });
        expense.isDirty = false;
        if (expense.isInBox) await expense.save();
      }

      // 9. Sync Users
      final dirtyUsers = _db.usersBox.values.where((e) => e.isDirty).toList();
      for (final user in dirtyUsers) {
        await storeRef.collection('users').doc(user.userId).set({
          'userId': user.userId,
          'username': user.username,
          'fullName': user.fullName,
          'role': user.role,
          'isActive': user.isActive,
          'passwordHash': user.passwordHash,
          'salt': user.salt,
          'lastUpdated': user.lastUpdated.toUtc().toIso8601String(),
        });
        user.isDirty = false;
        if (user.isInBox) await user.save();
      }
    } catch (e) {
      print('SyncService syncDirtyRecords error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> restoreAllFromCloud() async {
    await syncDirtyRecords();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final adminUid = user.uid;
      final storeRef = FirebaseFirestore.instance.collection('stores').doc(adminUid);

      // 1. Restore Users
      final usersSnapshot = await storeRef.collection('users').get();
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final user = UserModel()
          ..userId = data['userId']
          ..username = data['username']
          ..fullName = data['fullName']
          ..role = data['role']
          ..isActive = data['isActive']
          ..passwordHash = data['passwordHash'] ?? ''
          ..salt = data['salt'] ?? ''
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated']);
        await _db.usersBox.put(user.userId, user);
      }

      // 2. Restore Categories
      final catsSnapshot = await storeRef.collection('categories').get();
      for (final doc in catsSnapshot.docs) {
        final data = doc.data();
        final cat = CategoryModel()
          ..categoryId = data['categoryId']
          ..name = data['name']
          ..description = data['description']
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.categoriesBox.put(cat.categoryId, cat);
      }

      // 3. Restore Brands
      final brandsSnapshot = await storeRef.collection('brands').get();
      for (final doc in brandsSnapshot.docs) {
        final data = doc.data();
        final brand = BrandModel()
          ..brandId = data['brandId']
          ..name = data['name']
          ..description = data['description']
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.brandsBox.put(brand.brandId, brand);
      }

      // 4. Restore Suppliers
      final supsSnapshot = await storeRef.collection('suppliers').get();
      for (final doc in supsSnapshot.docs) {
        final data = doc.data();
        final sup = SupplierModel()
          ..supplierId = data['supplierId']
          ..name = data['name']
          ..contactName = data['contactName']
          ..phone = data['phone']
          ..email = data['email']
          ..address = data['address']
          ..balance = (data['balance'] as num).toDouble()
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.suppliersBox.put(sup.supplierId, sup);
      }

      // 5. Restore Customers
      final custsSnapshot = await storeRef.collection('customers').get();
      for (final doc in custsSnapshot.docs) {
        final data = doc.data();
        final cust = CustomerModel()
          ..customerId = data['customerId']
          ..name = data['name']
          ..phone = data['phone']
          ..email = data['email']
          ..address = data['address']
          ..balance = (data['balance'] as num).toDouble()
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.customersBox.put(cust.customerId, cust);
      }

      // 6. Restore Products
      final prodsSnapshot = await storeRef.collection('products').get();
      for (final doc in prodsSnapshot.docs) {
        final data = doc.data();
        final prod = ProductModel()
          ..productId = data['productId']
          ..name = data['name']
          ..sku = data['sku']
          ..barcode = data['barcode']
          ..categoryId = data['categoryId']
          ..brandId = data['brandId']
          ..supplierId = data['supplierId']
          ..purchasePrice = (data['purchasePrice'] as num).toDouble()
          ..wholesalePrice = (data['wholesalePrice'] as num).toDouble()
          ..retailPrice = (data['retailPrice'] as num).toDouble()
          ..minimumPrice = (data['minimumPrice'] as num).toDouble()
          ..stock = (data['stock'] as num).toDouble()
          ..unit = data['unit']
          ..openingStock = (data['openingStock'] as num).toDouble()
          ..minimumStock = (data['minimumStock'] as num).toDouble()
          ..maximumStock = (data['maximumStock'] as num).toDouble()
          ..expiryDate = data['expiryDate'] != null ? DateTime.parse(data['expiryDate']) : null
          ..description = data['description']
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.productsBox.put(prod.productId, prod);
      }

      // 7. Restore Sales
      final salesSnapshot = await storeRef.collection('sales').get();
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final sale = SaleModel()
          ..saleId = data['saleId']
          ..invoiceNumber = data['invoiceNumber']
          ..cashierId = data['cashierId']
          ..customerId = data['customerId']
          ..subtotal = (data['subtotal'] as num).toDouble()
          ..discount = (data['discount'] as num).toDouble()
          ..total = (data['total'] as num).toDouble()
          ..paidAmount = (data['paidAmount'] as num).toDouble()
          ..changeAmount = (data['changeAmount'] as num).toDouble()
          ..paymentMethod = data['paymentMethod']
          ..timestamp = DateTime.parse(data['timestamp'])
          ..itemsJson = data['itemsJson']
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.salesBox.put(sale.saleId, sale);
      }

      // 8. Restore Purchases
      final purchasesSnapshot = await storeRef.collection('purchases').get();
      for (final doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final purchase = PurchaseModel()
          ..purchaseId = data['purchaseId']
          ..invoiceNumber = data['invoiceNumber']
          ..supplierId = data['supplierId']
          ..totalAmount = (data['totalAmount'] as num).toDouble()
          ..paidAmount = (data['paidAmount'] as num).toDouble()
          ..timestamp = DateTime.parse(data['timestamp'])
          ..itemsJson = data['itemsJson']
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.purchasesBox.put(purchase.purchaseId, purchase);
      }

      // 9. Restore Expenses
      final expensesSnapshot = await storeRef.collection('expenses').get();
      for (final doc in expensesSnapshot.docs) {
        final data = doc.data();
        final expense = ExpenseModel()
          ..expenseId = data['expenseId']
          ..title = data['title']
          ..category = data['category']
          ..amount = (data['amount'] as num).toDouble()
          ..description = data['description']
          ..timestamp = DateTime.parse(data['timestamp'])
          ..isDirty = false
          ..lastUpdated = DateTime.parse(data['lastUpdated'])
          ..isDeleted = data['isDeleted'] ?? false;
        await _db.expensesBox.put(expense.expenseId, expense);
      }
    } catch (_) {}
  }
}
