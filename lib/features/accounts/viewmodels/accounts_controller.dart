import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/expense_model.dart';


class AccountsState {
  final List<CustomerModel> customers;
  final List<SupplierModel> suppliers;
  final List<ExpenseModel> expenses;
  final double totalSalesCash;
  final double totalPurchasesCash;
  final double totalExpensesCash;
  final bool isLoading;
  final String? errorMessage;

  AccountsState({
    this.customers = const [],
    this.suppliers = const [],
    this.expenses = const [],
    this.totalSalesCash = 0.0,
    this.totalPurchasesCash = 0.0,
    this.totalExpensesCash = 0.0,
    this.isLoading = false,
    this.errorMessage,
  });

  double get netCashInHand => totalSalesCash - (totalPurchasesCash + totalExpensesCash);

  AccountsState copyWith({
    List<CustomerModel>? customers,
    List<SupplierModel>? suppliers,
    List<ExpenseModel>? expenses,
    double? totalSalesCash,
    double? totalPurchasesCash,
    double? totalExpensesCash,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AccountsState(
      customers: customers ?? this.customers,
      suppliers: suppliers ?? this.suppliers,
      expenses: expenses ?? this.expenses,
      totalSalesCash: totalSalesCash ?? this.totalSalesCash,
      totalPurchasesCash: totalPurchasesCash ?? this.totalPurchasesCash,
      totalExpensesCash: totalExpensesCash ?? this.totalExpensesCash,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AccountsController extends StateNotifier<AccountsState> {
  final Ref _ref;

  AccountsController(this._ref) : super(AccountsState()) {
    refreshAccounts();
  }

  Future<void> refreshAccounts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final db = _ref.read(localDbServiceProvider);
      
      final customers = db.customersBox.values.where((e) => !e.isDeleted).toList();
      final suppliers = db.suppliersBox.values.where((e) => !e.isDeleted).toList();
      final expensesRaw = db.expensesBox.values.where((e) => !e.isDeleted).toList();
      final expenses = [...expensesRaw]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      final sales = db.salesBox.values.where((e) => !e.isDeleted).toList();
      final purchases = db.purchasesBox.values.where((e) => !e.isDeleted).toList();
      
      final totalSales = sales.fold(0.0, (sum, s) => sum + s.paidAmount);
      final totalPurchases = purchases.fold(0.0, (sum, p) => sum + p.paidAmount);
      final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

      state = state.copyWith(
        customers: customers,
        suppliers: suppliers,
        expenses: expenses,
        totalSalesCash: totalSales,
        totalPurchasesCash: totalPurchases,
        totalExpensesCash: totalExpenses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addExpense({
    required String title,
    required String category,
    required double amount,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final db = _ref.read(localDbServiceProvider);
      final expense = ExpenseModel()
        ..expenseId = const Uuid().v4()
        ..title = title
        ..category = category
        ..amount = amount
        ..description = description
        ..timestamp = DateTime.now()
        ..isDeleted = false
        ..isDirty = true
        ..lastUpdated = DateTime.now();

      await db.expensesBox.put(expense.expenseId, expense);
      await refreshAccounts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    state = state.copyWith(isLoading: true);
    try {
      final db = _ref.read(localDbServiceProvider);
      final expense = db.expensesBox.get(expenseId);
      if (expense != null) {
        expense.isDeleted = true;
        expense.isDirty = true;
        expense.lastUpdated = DateTime.now();
        await expense.save();
      }
      await refreshAccounts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> receiveCustomerPayment(String customerId, double amountPaid) async {
    final db = _ref.read(localDbServiceProvider);
    final customer = db.customersBox.get(customerId);
    if (customer != null) {
      customer.balance -= amountPaid; // Pay off Khata debt
      customer.isDirty = true;
      customer.lastUpdated = DateTime.now();
      await customer.save();
    }
    await refreshAccounts();
  }

  Future<void> paySupplier(String supplierId, double amountPaid) async {
    final db = _ref.read(localDbServiceProvider);
    final supplier = db.suppliersBox.get(supplierId);
    if (supplier != null) {
      supplier.balance -= amountPaid; // Pay off supplier credit debt
      supplier.isDirty = true;
      supplier.lastUpdated = DateTime.now();
      await supplier.save();
    }
    await refreshAccounts();
  }
}

final accountsControllerProvider =
    StateNotifierProvider<AccountsController, AccountsState>((ref) {
  return AccountsController(ref);
});
