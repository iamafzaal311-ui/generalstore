import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/utils/print_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/sales_repository_impl.dart';
import '../../../domain/repositories/sales_repository.dart';
import '../../products/viewmodels/inventory_controller.dart';

class CartItem {
  final ProductModel product;
  double quantity;
  double discount;

  CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0.0,
  });

  double get subtotal => product.retailPrice * quantity;
  double get total => subtotal - discount;
}

class POSState {
  final List<CartItem> cart;
  final CustomerModel? selectedCustomer;
  final String paymentMethod;
  final double discount; // Flat overall discount
  final double paidAmount;
  final bool isLoading;
  final String? errorMessage;
  final List<CustomerModel> customers;

  POSState({
    this.cart = const [],
    this.selectedCustomer,
    this.paymentMethod = 'Cash',
    this.discount = 0.0,
    this.paidAmount = 0.0,
    this.isLoading = false,
    this.errorMessage,
    this.customers = const [],
  });

  double get subtotal => cart.fold(0.0, (sum, item) => sum + item.subtotal);
  
  // Total discounts combined (item-level discounts + flat overall discount)
  double get totalDiscount => cart.fold(0.0, (sum, item) => sum + item.discount) + discount;
  
  double get grandTotal => subtotal - totalDiscount;
  double get changeAmount => paidAmount >= grandTotal ? paidAmount - grandTotal : 0.0;

  POSState copyWith({
    List<CartItem>? cart,
    CustomerModel? selectedCustomer,
    String? paymentMethod,
    double? discount,
    double? paidAmount,
    bool? isLoading,
    String? errorMessage,
    List<CustomerModel>? customers,
  }) {
    return POSState(
      cart: cart ?? this.cart,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      discount: discount ?? this.discount,
      paidAmount: paidAmount ?? this.paidAmount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      customers: customers ?? this.customers,
    );
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return SalesRepositoryImpl(db);
});

class POSController extends StateNotifier<POSState> {
  final SalesRepository _salesRepo;
  final Ref _ref;

  POSController(this._salesRepo, this._ref) : super(POSState()) {
    refreshCustomers();
  }

  Future<void> refreshCustomers() async {
    try {
      final list = await _salesRepo.getCustomers();
      state = state.copyWith(customers: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void addToCart(ProductModel product, [double quantity = 1.0]) {
    final existingIndex = state.cart.indexWhere((item) => item.product.productId == product.productId);
    final updatedCart = List<CartItem>.from(state.cart);

    if (existingIndex >= 0) {
      updatedCart[existingIndex].quantity += quantity;
    } else {
      updatedCart.add(CartItem(product: product, quantity: quantity));
    }
    state = state.copyWith(cart: updatedCart);
  }

  void updateQuantity(String productId, double quantity) {
    final index = state.cart.indexWhere((item) => item.product.productId == productId);
    if (index >= 0 && quantity > 0) {
      final updatedCart = List<CartItem>.from(state.cart);
      updatedCart[index].quantity = quantity;
      state = state.copyWith(cart: updatedCart);
    }
  }

  void removeFromCart(String productId) {
    final updatedCart = state.cart.where((item) => item.product.productId != productId).toList();
    state = state.copyWith(cart: updatedCart);
  }

  void selectCustomer(CustomerModel? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setFlatDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  void setPaidAmount(double paid) {
    state = state.copyWith(paidAmount: paid);
  }

  Future<void> scanAndAddBarcode(String barcode) async {
    try {
      final product = await _ref.read(inventoryControllerProvider.notifier).getProductByBarcode(barcode);
      if (product != null) {
        addToCart(product);
      } else {
        state = state.copyWith(errorMessage: 'Barcode product not found');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> addNewCustomer(String name, String phone, String address) async {
    final customer = CustomerModel()
      ..customerId = const Uuid().v4()
      ..name = name
      ..phone = phone.isEmpty ? null : phone
      ..address = address.isEmpty ? null : address
      ..balance = 0.0
      ..isDeleted = false;

    await _salesRepo.saveCustomer(customer);
    await refreshCustomers();
    selectCustomer(customer);
  }

  Future<void> checkout(BuildContext context, {bool printReceipt = true, String? customerName, String? customerPhone}) async {
    if (state.cart.isEmpty) {
      state = state.copyWith(errorMessage: 'Cart is empty');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final timestamp = DateTime.now();
      final invoice = 'INV-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.millisecondsSinceEpoch.toString().substring(8)}';
      
      final invState = _ref.read(inventoryControllerProvider);

      final itemsListJson = state.cart.map((item) {
        final brandName = item.product.brandId != null
            ? (invState.brands.where((b) => b.brandId == item.product.brandId).firstOrNull?.name ?? '')
            : '';
        final categoryName = item.product.categoryId != null
            ? (invState.categories.where((c) => c.categoryId == item.product.categoryId).firstOrNull?.name ?? '')
            : '';

        return {
          'productId': item.product.productId,
          'name': item.product.name,
          'brand': brandName,
          'category': categoryName,
          'quantity': item.quantity,
          'unitPrice': item.product.retailPrice,
          'purchasePrice': item.product.purchasePrice,
          'discount': item.discount,
          'total': item.total,
        };
      }).toList();

      final currentUser = _ref.read(currentUserProvider);

      final sale = SaleModel()
        ..saleId = const Uuid().v4()
        ..invoiceNumber = invoice
        ..cashierId = currentUser?.userId ?? 'admin-offline'
        ..customerId = state.selectedCustomer?.customerId
        ..subtotal = state.subtotal
        ..discount = state.totalDiscount
        ..total = state.grandTotal
        ..paidAmount = state.paidAmount
        ..changeAmount = state.changeAmount
        ..paymentMethod = state.paymentMethod
        ..timestamp = timestamp
        ..itemsJson = jsonEncode(itemsListJson)
        ..isDeleted = false;

      // 1. Save local transaction & trigger stock deductions
      await _salesRepo.saveSale(sale);

      // 2. Refresh Inventory State (Stock count changes)
      await _ref.read(inventoryControllerProvider.notifier).refreshAll();

      // 3. Print receipt asynchronously
      if (printReceipt) {
        final finalCustomerName = customerName ?? state.selectedCustomer?.name;
        final finalCustomerPhone = customerPhone ?? state.selectedCustomer?.phone;

        final pdfBytes = await PrintHelper.generateThermalReceipt(
          sale: sale,
          items: itemsListJson,
          cashierName: currentUser?.fullName ?? 'Cashier',
          customerName: finalCustomerName,
          customerPhone: finalCustomerPhone,
        );
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      }

      // Reset POS cart state after successful save
      state = POSState(customers: state.customers);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  void clearCart() {
    state = POSState(customers: state.customers);
  }
}

final posControllerProvider = StateNotifierProvider<POSController, POSState>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return POSController(repo, ref);
});
