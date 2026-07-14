import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/repositories/transactions_repository_impl.dart';
import '../../../domain/repositories/transactions_repository.dart';
import '../../products/viewmodels/inventory_controller.dart';

class PurchaseCartItem {
  final ProductModel product;
  double quantity;
  double purchasePrice;

  PurchaseCartItem({
    required this.product,
    required this.quantity,
    required this.purchasePrice,
  });

  double get total => quantity * purchasePrice;
}

class TransactionsState {
  final List<PurchaseModel> purchases;
  final List<PurchaseCartItem> cart;
  final SupplierModel? selectedSupplier;
  final double paidAmount;
  final bool isLoading;
  final String? errorMessage;

  TransactionsState({
    this.purchases = const [],
    this.cart = const [],
    this.selectedSupplier,
    this.paidAmount = 0.0,
    this.isLoading = false,
    this.errorMessage,
  });

  double get totalAmount => cart.fold(0.0, (sum, item) => sum + item.total);

  TransactionsState copyWith({
    List<PurchaseModel>? purchases,
    List<PurchaseCartItem>? cart,
    SupplierModel? selectedSupplier,
    double? paidAmount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TransactionsState(
      purchases: purchases ?? this.purchases,
      cart: cart ?? this.cart,
      selectedSupplier: selectedSupplier ?? this.selectedSupplier,
      paidAmount: paidAmount ?? this.paidAmount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return TransactionsRepositoryImpl(db);
});

class TransactionsController extends StateNotifier<TransactionsState> {
  final TransactionsRepository _repo;
  final Ref _ref;

  TransactionsController(this._repo, this._ref) : super(TransactionsState()) {
    refreshPurchases();
  }

  Future<void> refreshPurchases() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      List<PurchaseModel> list = await _repo.getPurchases();
      if (list.isEmpty) {
        final dummyPurchase = PurchaseModel()
          ..purchaseId = const Uuid().v4()
          ..invoiceNumber = 'PUR-DUMMY-1'
          ..supplierId = 'Dummy Supplier'
          ..totalAmount = 5000.0
          ..paidAmount = 5000.0
          ..timestamp = DateTime.now()
          ..itemsJson = '[{"productName": "Dummy Item", "quantity": 10, "purchasePrice": 500}]'
          ..isDirty = false
          ..lastUpdated = DateTime.now()
          ..isDeleted = false;
        await _repo.savePurchase(dummyPurchase);
        list = await _repo.getPurchases();
      }
      state = state.copyWith(purchases: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void selectSupplier(SupplierModel? supplier) {
    state = state.copyWith(selectedSupplier: supplier);
  }

  void addToCart(ProductModel product, double qty, double cost) {
    final existingIndex = state.cart.indexWhere((item) => item.product.productId == product.productId);
    final updatedCart = List<PurchaseCartItem>.from(state.cart);

    if (existingIndex >= 0) {
      updatedCart[existingIndex].quantity += qty;
      updatedCart[existingIndex].purchasePrice = cost;
    } else {
      updatedCart.add(PurchaseCartItem(product: product, quantity: qty, purchasePrice: cost));
    }
    state = state.copyWith(cart: updatedCart);
  }

  void removeFromCart(String productId) {
    final updatedCart = state.cart.where((item) => item.product.productId != productId).toList();
    state = state.copyWith(cart: updatedCart);
  }

  void setPaidAmount(double paid) {
    state = state.copyWith(paidAmount: paid);
  }

  Future<void> savePurchase() async {
    if (state.cart.isEmpty || state.selectedSupplier == null) {
      throw Exception('Cart or Supplier is empty');
    }

    state = state.copyWith(isLoading: true);
    try {
      final timestamp = DateTime.now();
      final invoice = 'PUR-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.millisecondsSinceEpoch.toString().substring(8)}';

      final itemsJsonList = state.cart.map((item) => {
        'productId': item.product.productId,
        'name': item.product.name,
        'quantity': item.quantity,
        'purchasePrice': item.purchasePrice,
        'total': item.total,
      }).toList();

      final purchase = PurchaseModel()
        ..purchaseId = const Uuid().v4()
        ..invoiceNumber = invoice
        ..supplierId = state.selectedSupplier!.supplierId
        ..totalAmount = state.totalAmount
        ..paidAmount = state.paidAmount
        ..timestamp = timestamp
        ..itemsJson = jsonEncode(itemsJsonList)
        ..isDeleted = false;

      await _repo.savePurchase(purchase);

      // Refresh inventory so stock levels are updated
      await _ref.read(inventoryControllerProvider.notifier).refreshAll();
      await refreshPurchases();

      // Reset cart
      state = TransactionsState(purchases: state.purchases);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deletePurchase(String purchaseId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.deletePurchase(purchaseId);
      await _ref.read(inventoryControllerProvider.notifier).refreshAll();
      await refreshPurchases();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final transactionsControllerProvider =
    StateNotifierProvider<TransactionsController, TransactionsState>((ref) {
  final repo = ref.watch(transactionsRepositoryProvider);
  return TransactionsController(repo, ref);
});
