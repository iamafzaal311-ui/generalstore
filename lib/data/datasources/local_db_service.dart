import 'package:hive_flutter/hive_flutter.dart';

import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/expense_model.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/supplier_model.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';

class LocalDbService {
  bool _isInitialized = false;

  late Box<UserModel> usersBox;
  late Box<CategoryModel> categoriesBox;
  late Box<BrandModel> brandsBox;
  late Box<SupplierModel> suppliersBox;
  late Box<CustomerModel> customersBox;
  late Box<ProductModel> productsBox;
  late Box<SaleModel> salesBox;
  late Box<PurchaseModel> purchasesBox;
  late Box<ExpenseModel> expensesBox;
  late Box<PaymentModel> paymentsBox;
  late Box<String> settingsBox;

  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter('generalstore_db');

    // Register Adapters
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(BrandModelAdapter());
    Hive.registerAdapter(SupplierModelAdapter());
    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(SaleModelAdapter());
    Hive.registerAdapter(PurchaseModelAdapter());
    Hive.registerAdapter(ExpenseModelAdapter());
    Hive.registerAdapter(PaymentModelAdapter());

    // Open Boxes
    usersBox = await Hive.openBox<UserModel>('users');
    categoriesBox = await Hive.openBox<CategoryModel>('categories');
    brandsBox = await Hive.openBox<BrandModel>('brands');
    suppliersBox = await Hive.openBox<SupplierModel>('suppliers');
    customersBox = await Hive.openBox<CustomerModel>('customers');
    productsBox = await Hive.openBox<ProductModel>('products');
    salesBox = await Hive.openBox<SaleModel>('sales');
    purchasesBox = await Hive.openBox<PurchaseModel>('purchases');
    expensesBox = await Hive.openBox<ExpenseModel>('expenses');
    paymentsBox = await Hive.openBox<PaymentModel>('payments');
    settingsBox = await Hive.openBox<String>('settings');

    _isInitialized = true;
  }

  Future<void> cleanDb() async {
    await usersBox.clear();
    await categoriesBox.clear();
    await brandsBox.clear();
    await suppliersBox.clear();
    await customersBox.clear();
    await productsBox.clear();
    await salesBox.clear();
    await purchasesBox.clear();
    await expensesBox.clear();
    await paymentsBox.clear();
    await settingsBox.clear();
  }
}
