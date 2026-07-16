import 'dart:convert';

import '../../data/datasources/local_db_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/brand_model.dart';
import '../../data/models/supplier_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_model.dart';

class BackupHelper {
  static Future<String> exportDatabaseToJson(LocalDbService db) async {
    final Map<String, dynamic> backup = {};

    backup['users'] = db.usersBox.values
        .map(
          (u) => {
            'userId': u.userId,
            'username': u.username,
            'fullName': u.fullName,
            'passwordHash': u.passwordHash,
            'salt': u.salt,
            'role': u.role,
            'isActive': u.isActive,
            'lastUpdated': u.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    backup['categories'] = db.categoriesBox.values
        .map(
          (c) => {
            'categoryId': c.categoryId,
            'name': c.name,
            'description': c.description,
            'isDeleted': c.isDeleted,
            'lastUpdated': c.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    backup['brands'] = db.brandsBox.values
        .map(
          (b) => {
            'brandId': b.brandId,
            'name': b.name,
            'description': b.description,
            'isDeleted': b.isDeleted,
            'lastUpdated': b.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    backup['suppliers'] = db.suppliersBox.values
        .map(
          (s) => {
            'supplierId': s.supplierId,
            'name': s.name,
            'contactName': s.contactName,
            'phone': s.phone,
            'email': s.email,
            'address': s.address,
            'balance': s.balance,
            'isDeleted': s.isDeleted,
            'lastUpdated': s.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    backup['customers'] = db.customersBox.values
        .map(
          (c) => {
            'customerId': c.customerId,
            'name': c.name,
            'phone': c.phone,
            'email': c.email,
            'address': c.address,
            'balance': c.balance,
            'isDeleted': c.isDeleted,
            'lastUpdated': c.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    backup['products'] = db.productsBox.values
        .map(
          (p) => {
            'productId': p.productId,
            'name': p.name,
            'sku': p.sku,
            'barcode': p.barcode,
            'categoryId': p.categoryId,
            'brandId': p.brandId,
            'supplierId': p.supplierId,
            'purchasePrice': p.purchasePrice,
            'wholesalePrice': p.wholesalePrice,
            'retailPrice': p.retailPrice,
            'minimumPrice': p.minimumPrice,
            'stock': p.stock,
            'unit': p.unit,
            'openingStock': p.openingStock,
            'minimumStock': p.minimumStock,
            'maximumStock': p.maximumStock,
            'description': p.description,
            'isDeleted': p.isDeleted,
            'lastUpdated': p.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    backup['sales'] = db.salesBox.values
        .map(
          (s) => {
            'saleId': s.saleId,
            'invoiceNumber': s.invoiceNumber,
            'cashierId': s.cashierId,
            'customerId': s.customerId,
            'subtotal': s.subtotal,
            'discount': s.discount,
            'total': s.total,
            'paidAmount': s.paidAmount,
            'changeAmount': s.changeAmount,
            'paymentMethod': s.paymentMethod,
            'timestamp': s.timestamp.toIso8601String(),
            'itemsJson': s.itemsJson,
            'isDeleted': s.isDeleted,
            'lastUpdated': s.lastUpdated.toIso8601String(),
          },
        )
        .toList();

    return jsonEncode(backup);
  }

  static Future<void> restoreDatabaseFromJson(
    LocalDbService db,
    String jsonContent,
  ) async {
    final Map<String, dynamic> backup = jsonDecode(jsonContent);

    await db.cleanDb();

    if (backup['users'] != null) {
      for (final u in backup['users']) {
        final user = UserModel()
          ..userId = u['userId']
          ..username = u['username']
          ..fullName = u['fullName']
          ..passwordHash = u['passwordHash']
          ..salt = u['salt']
          ..role = u['role']
          ..isActive = u['isActive']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(u['lastUpdated']);
        await db.usersBox.put(user.userId, user);
      }
    }

    if (backup['categories'] != null) {
      for (final c in backup['categories']) {
        final cat = CategoryModel()
          ..categoryId = c['categoryId']
          ..name = c['name']
          ..description = c['description']
          ..isDeleted = c['isDeleted']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(c['lastUpdated']);
        await db.categoriesBox.put(cat.categoryId, cat);
      }
    }

    if (backup['brands'] != null) {
      for (final b in backup['brands']) {
        final brand = BrandModel()
          ..brandId = b['brandId']
          ..name = b['name']
          ..description = b['description']
          ..isDeleted = b['isDeleted']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(b['lastUpdated']);
        await db.brandsBox.put(brand.brandId, brand);
      }
    }

    if (backup['suppliers'] != null) {
      for (final s in backup['suppliers']) {
        final sup = SupplierModel()
          ..supplierId = s['supplierId']
          ..name = s['name']
          ..contactName = s['contactName']
          ..phone = s['phone']
          ..email = s['email']
          ..address = s['address']
          ..balance = (s['balance'] as num).toDouble()
          ..isDeleted = s['isDeleted']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(s['lastUpdated']);
        await db.suppliersBox.put(sup.supplierId, sup);
      }
    }

    if (backup['customers'] != null) {
      for (final c in backup['customers']) {
        final cust = CustomerModel()
          ..customerId = c['customerId']
          ..name = c['name']
          ..phone = c['phone']
          ..email = c['email']
          ..address = c['address']
          ..balance = (c['balance'] as num).toDouble()
          ..isDeleted = c['isDeleted']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(c['lastUpdated']);
        await db.customersBox.put(cust.customerId, cust);
      }
    }

    if (backup['products'] != null) {
      for (final p in backup['products']) {
        final prod = ProductModel()
          ..productId = p['productId']
          ..name = p['name']
          ..sku = p['sku']
          ..barcode = p['barcode']
          ..categoryId = p['categoryId']
          ..brandId = p['brandId']
          ..supplierId = p['supplierId']
          ..purchasePrice = (p['purchasePrice'] as num).toDouble()
          ..wholesalePrice = (p['wholesalePrice'] as num).toDouble()
          ..retailPrice = (p['retailPrice'] as num).toDouble()
          ..minimumPrice = (p['minimumPrice'] as num).toDouble()
          ..stock = (p['stock'] as num).toDouble()
          ..unit = p['unit']
          ..openingStock = (p['openingStock'] as num).toDouble()
          ..minimumStock = (p['minimumStock'] as num).toDouble()
          ..maximumStock = (p['maximumStock'] as num).toDouble()
          ..description = p['description']
          ..isDeleted = p['isDeleted']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(p['lastUpdated']);
        await db.productsBox.put(prod.productId, prod);
      }
    }

    if (backup['sales'] != null) {
      for (final s in backup['sales']) {
        final sale = SaleModel()
          ..saleId = s['saleId']
          ..invoiceNumber = s['invoiceNumber']
          ..cashierId = s['cashierId']
          ..customerId = s['customerId']
          ..subtotal = (s['subtotal'] as num).toDouble()
          ..discount = (s['discount'] as num).toDouble()
          ..total = (s['total'] as num).toDouble()
          ..paidAmount = (s['paidAmount'] as num).toDouble()
          ..changeAmount = (s['changeAmount'] as num).toDouble()
          ..paymentMethod = s['paymentMethod']
          ..timestamp = DateTime.parse(s['timestamp'])
          ..itemsJson = s['itemsJson']
          ..isDeleted = s['isDeleted']
          ..isDirty = true
          ..lastUpdated = DateTime.parse(s['lastUpdated']);
        await db.salesBox.put(sale.saleId, sale);
      }
    }
  }
}
