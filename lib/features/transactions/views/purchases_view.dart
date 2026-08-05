import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/brand_model.dart';
import '../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../core/providers/global_providers.dart';
import '../viewmodels/transactions_controller.dart';
import '../../products/viewmodels/inventory_controller.dart';

class PurchasesView extends ConsumerStatefulWidget {
  const PurchasesView({super.key});

  @override
  ConsumerState<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends ConsumerState<PurchasesView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
      });
    });
    Future.microtask(
      () =>
          ref.read(transactionsControllerProvider.notifier).refreshPurchases(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNewPurchaseDialog() {
    final theme = Theme.of(context);
    final invState = ref.read(inventoryControllerProvider);

    ProductModel? selectedProduct;
    CategoryModel? selectedCategory;
    final quantityCtrl = TextEditingController(text: '1');
    final purchasePriceCtrl = TextEditingController(text: '0');
    final minStockCtrl = TextEditingController(text: '0');
    final expiryCtrl = TextEditingController();

    final paidCtrl = TextEditingController(text: '0');
    final invoiceCtrl = TextEditingController();
    final addFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final txState = ref.watch(transactionsControllerProvider);
            return AlertDialog(
              title: const Text('New Stock Purchase Entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width > 800
                      ? 700
                      : double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. Company / Supplier Search Dropdown ────────────
                      SearchableAutocompleteField<SupplierModel>(
                        labelText: 'Search Company / Supplier',
                        hintText: 'Type company name or phone...',
                        initialValue: txState.selectedSupplier,
                        items: invState.suppliers,
                        itemAsString: (s) => s.name,
                        itemSubtitle: (s) => (s.phone != null && s.phone!.isNotEmpty)
                            ? 'Phone: ${s.phone}'
                            : 'Supplier ID: ${s.supplierId}',
                        onSelected: (val) {
                          ref
                              .read(transactionsControllerProvider.notifier)
                              .selectSupplier(val);
                          setStateDialog(() {});
                        },
                        suffixAction: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                          tooltip: 'Add New Company',
                          onPressed: () {
                            Navigator.pop(context);
                            _showQuickAddSupplierDialog();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: invoiceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Invoice Number (Optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Form(
                        key: addFormKey,
                        child: Column(
                          children: [
                            // ── 2. Category Search Filter ──────────────────────
                            SearchableAutocompleteField<CategoryModel>(
                              labelText: 'Filter Category (Optional)',
                              hintText: 'Type category name to filter products...',
                              initialValue: selectedCategory,
                              items: invState.categories,
                              itemAsString: (c) => c.name,
                              itemSubtitle: (c) => c.description ?? 'Category',
                              prefixIcon: const Icon(Icons.category_outlined, size: 20),
                              onSelected: (val) {
                                setStateDialog(() {
                                  selectedCategory = val;
                                  selectedProduct = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            // ── 3. Product Search Dropdown ────────────────────
                            SearchableAutocompleteField<ProductModel>(
                              labelText: 'Search Product (Name / SKU / Barcode)',
                              hintText: 'Type product name, SKU, or barcode...',
                              initialValue: selectedProduct,
                              items: invState.products.where((p) {
                                if (selectedCategory == null) return true;
                                return p.categoryId == selectedCategory!.categoryId;
                              }).toList(),
                              itemAsString: (p) => p.name,
                              itemSubtitle: (p) {
                                final cat = invState.categories
                                    .where((c) => c.categoryId == p.categoryId)
                                    .firstOrNull
                                    ?.name;
                                return '${cat != null ? "$cat | " : ""}SKU: ${p.sku ?? "-"} | Stock: ${p.stock}';
                              },
                              itemTrailing: (p) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rs.${p.purchasePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              filterFn: (p, query) {
                                final nameMatch = p.name.toLowerCase().contains(query);
                                final skuMatch = (p.sku ?? '').toLowerCase().contains(query);
                                final barcodeMatch = (p.barcode ?? '').toLowerCase().contains(query);
                                return nameMatch || skuMatch || barcodeMatch;
                              },
                              onSelected: (val) {
                                setStateDialog(() {
                                  selectedProduct = val;
                                  if (val != null) {
                                    purchasePriceCtrl.text = val.purchasePrice.toString();
                                    minStockCtrl.text = val.minimumStock.toString();
                                  }
                                });
                              },
                              suffixAction: Tooltip(
                                message: 'Add Manual Item (Purchase & Sale)',
                                child: IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF9333EA)),
                                  onPressed: () {
                                    _showManualEntryDialogForPurchase(context, () {
                                      setStateDialog(() {});
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: quantityCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Total Quantity',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) =>
                                        val == null ||
                                            double.tryParse(val) == null
                                        ? 'Invalid'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: purchasePriceCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Purchase Price (Rs.)',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) =>
                                        val == null ||
                                            double.tryParse(val) == null
                                        ? 'Invalid'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: minStockCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Low Stock Limit',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: expiryCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Expiry (YYYY-MM-DD)',
                                      hintText: 'Optional',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_box_rounded),
                                  label: const Text("Add"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (addFormKey.currentState!.validate() &&
                                        selectedProduct != null) {
                                      final totalQty = double.parse(
                                        quantityCtrl.text,
                                      );
                                      final unitPrice = double.parse(
                                        purchasePriceCtrl.text,
                                      );

                                      if (totalQty > 0) {
                                        ref
                                            .read(
                                              transactionsControllerProvider
                                                  .notifier,
                                            )
                                            .addToCart(
                                              selectedProduct!,
                                              totalQty,
                                              unitPrice,
                                            );

                                        selectedProduct!.purchasePrice =
                                            unitPrice;
                                        selectedProduct!.wholesalePrice =
                                            unitPrice;
                                        selectedProduct!.lastUpdated =
                                            DateTime.now();
                                        selectedProduct!.isDirty = true;

                                        final minS = double.tryParse(
                                          minStockCtrl.text,
                                        );
                                        if (minS != null) {
                                          selectedProduct!.minimumStock = minS;
                                        }

                                        if (expiryCtrl.text.trim().isNotEmpty) {
                                          try {
                                            selectedProduct!.expiryDate =
                                                DateTime.parse(
                                                  expiryCtrl.text.trim(),
                                                );
                                          } catch (_) {}
                                        }

                                        ref
                                            .read(
                                              inventoryControllerProvider
                                                  .notifier,
                                            )
                                            .saveProduct(selectedProduct!);

                                        setStateDialog(() {
                                          selectedProduct = null;
                                          quantityCtrl.text = '1';
                                          purchasePriceCtrl.text = '0';
                                        });
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (txState.cart.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Purchase Invoice Items:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: txState.cart.length,
                            itemBuilder: (context, index) {
                              final item = txState.cart[index];
                              return ListTile(
                                dense: true,
                                title: Text(item.product.name),
                                subtitle: Text(
                                  '${item.quantity} units x Rs.${item.purchasePrice.toStringAsFixed(2)} = Rs.${item.total.toStringAsFixed(0)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(
                                          transactionsControllerProvider
                                              .notifier,
                                        )
                                        .removeFromCart(item.product.productId);
                                    setStateDialog(() {});
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total: Rs. ${txState.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: paidCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paid to Company (Rs.)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final p = double.tryParse(val) ?? 0.0;
                            ref
                                .read(transactionsControllerProvider.notifier)
                                .setPaidAmount(p);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      txState.cart.isEmpty || txState.selectedSupplier == null
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(transactionsControllerProvider.notifier)
                                .savePurchase(invoiceCtrl.text);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Stock purchase recorded successfully!',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Record Purchase'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showEditPurchaseDialog(PurchaseModel purchase) {
    SupplierModel? selectedSupplier;
    ProductModel? selectedProduct;

    final invState = ref.read(inventoryControllerProvider);
    selectedSupplier = invState.suppliers
        .where((s) => s.supplierId == purchase.supplierId)
        .firstOrNull;

    final quantityCtrl = TextEditingController(text: '1');
    final purchasePriceCtrl = TextEditingController(text: '0');
    final invoiceCtrl = TextEditingController(text: purchase.invoiceNumber);
    final paidCtrl = TextEditingController(text: purchase.paidAmount.toString());

    final addFormKey = GlobalKey<FormState>();

    List<Map<String, dynamic>> cart = [];
    try {
      final items = jsonDecode(purchase.itemsJson) as List;
      for (var item in items) {
        cart.add(Map<String, dynamic>.from(item));
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final invState = ref.watch(inventoryControllerProvider);
            double cartTotal = cart.fold(0.0, (sum, i) => sum + i['total']);

            return AlertDialog(
              title: const Text('Edit Stock Purchase'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width > 800
                      ? 700
                      : double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. Company / Supplier Search Dropdown ────────────
                      SearchableAutocompleteField<SupplierModel>(
                        labelText: 'Search Company / Supplier',
                        hintText: 'Type company name or phone...',
                        initialValue: selectedSupplier,
                        items: invState.suppliers,
                        itemAsString: (s) => s.name,
                        itemSubtitle: (s) => (s.phone != null && s.phone!.isNotEmpty)
                            ? 'Phone: ${s.phone}'
                            : 'Supplier ID: ${s.supplierId}',
                        onSelected: (val) {
                          setStateDialog(() {
                            selectedSupplier = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: invoiceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Custom Invoice Number (Optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Form(
                        key: addFormKey,
                        child: Column(
                          children: [
                            // ── 2. Product Search Dropdown ────────────────────
                            SearchableAutocompleteField<ProductModel>(
                              labelText: 'Search Product (Name / SKU / Barcode)',
                              hintText: 'Type product name, SKU, or barcode...',
                              initialValue: selectedProduct,
                              items: invState.products,
                              itemAsString: (p) => p.name,
                              itemSubtitle: (p) {
                                final cat = invState.categories
                                    .where((c) => c.categoryId == p.categoryId)
                                    .firstOrNull
                                    ?.name;
                                return '${cat != null ? "$cat | " : ""}SKU: ${p.sku ?? "-"} | Stock: ${p.stock}';
                              },
                              itemTrailing: (p) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rs.${p.purchasePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              filterFn: (p, query) {
                                final nameMatch = p.name.toLowerCase().contains(query);
                                final skuMatch = (p.sku ?? '').toLowerCase().contains(query);
                                final barcodeMatch = (p.barcode ?? '').toLowerCase().contains(query);
                                return nameMatch || skuMatch || barcodeMatch;
                              },
                              onSelected: (val) {
                                setStateDialog(() {
                                  selectedProduct = val;
                                  if (val != null) {
                                    purchasePriceCtrl.text = val.purchasePrice.toString();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: quantityCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Total Quantity',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null ||
                                            double.tryParse(val) == null
                                        ? 'Invalid'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: purchasePriceCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Purchase Price (Rs.)',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null ||
                                            double.tryParse(val) == null
                                        ? 'Invalid'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_box_rounded),
                                  label: const Text("Add"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (addFormKey.currentState!.validate() &&
                                        selectedProduct != null) {
                                      final totalQty =
                                          double.parse(quantityCtrl.text);
                                      final unitPrice =
                                          double.parse(purchasePriceCtrl.text);

                                      if (totalQty > 0) {
                                        final existingIndex = cart.indexWhere(
                                          (i) =>
                                              i['productId'] ==
                                              selectedProduct!.productId,
                                        );
                                        if (existingIndex >= 0) {
                                          cart[existingIndex]['quantity'] +=
                                              totalQty;
                                          cart[existingIndex]['purchasePrice'] =
                                              unitPrice;
                                          cart[existingIndex]['total'] =
                                              cart[existingIndex]['quantity'] *
                                              unitPrice;
                                        } else {
                                          cart.add({
                                            'productId':
                                                selectedProduct!.productId,
                                            'name': selectedProduct!.name,
                                            'quantity': totalQty,
                                            'purchasePrice': unitPrice,
                                            'total': totalQty * unitPrice,
                                          });
                                        }

                                        setStateDialog(() {
                                          selectedProduct = null;
                                          quantityCtrl.text = '1';
                                          purchasePriceCtrl.text = '0';
                                        });
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (cart.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Purchase Invoice Items:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: cart.length,
                            itemBuilder: (context, index) {
                              final item = cart[index];
                              return ListTile(
                                dense: true,
                                title: Text(item['name']),
                                subtitle: Text(
                                  '${item['quantity']} units x Rs.${item['purchasePrice']} = Rs.${item['total']}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setStateDialog(() {
                                      cart.removeAt(index);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total: Rs. ${cartTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: paidCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paid to Company (Rs.)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: cart.isEmpty || selectedSupplier == null
                      ? null
                      : () async {
                          try {
                            final paidAmt =
                                double.tryParse(paidCtrl.text) ?? 0.0;
                            final invoice = invoiceCtrl.text.trim().isNotEmpty
                                ? invoiceCtrl.text.trim()
                                : purchase.invoiceNumber;
                            
                            final actualRepo = ref.read(transactionsRepositoryProvider);

                            // 1. Delete old purchase
                            await actualRepo.deletePurchase(purchase.purchaseId);

                            // 2. Create updated purchase
                            final updatedPurchase = PurchaseModel()
                              ..purchaseId = purchase.purchaseId
                              ..invoiceNumber = invoice
                              ..supplierId = selectedSupplier!.supplierId
                              ..totalAmount = cartTotal
                              ..paidAmount = paidAmt
                              ..timestamp = purchase.timestamp
                              ..itemsJson = jsonEncode(cart)
                              ..isDeleted = false;

                            // 3. Save it
                            await actualRepo.savePurchase(updatedPurchase);
                            
                            await ref
                                .read(inventoryControllerProvider.notifier)
                                .refreshAll();
                            await ref
                                .read(transactionsControllerProvider.notifier)
                                .refreshPurchases();

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Stock purchase updated successfully!',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Update Purchase'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser?.role == 'Staff') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Restricted'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block_rounded, size: 64, color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Staff users are not allowed to view or manage Purchases.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final txState = ref.watch(transactionsControllerProvider);
    final invState = ref.watch(inventoryControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders & Inventory Entry'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _showNewPurchaseDialog,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Record New Purchase'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: txState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by Invoice # or Company Name...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: txState.purchases.isEmpty
                          ? const Center(
                              child: Text('No stock purchases recorded.'),
                            )
                          : Builder(
                              builder: (context) {
                                final filteredPurchases = txState.purchases
                                    .where((p) {
                                      final supplier = invState.suppliers
                                          .where(
                                            (s) => s.supplierId == p.supplierId,
                                          )
                                          .firstOrNull;
                                      final supplierName =
                                          supplier?.name.toLowerCase() ?? '';
                                      final invNo = p.invoiceNumber
                                          .toLowerCase();
                                      return supplierName.contains(
                                            _searchQuery,
                                          ) ||
                                          invNo.contains(_searchQuery);
                                    })
                                    .toList();

                                if (filteredPurchases.isEmpty) {
                                  return const Center(
                                    child: Text('No purchases match search.'),
                                  );
                                }

                                return ListView.separated(
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemCount: filteredPurchases.length,
                                  itemBuilder: (context, index) {
                                    final purchase = filteredPurchases[index];
                                    final unpaid =
                                        purchase.totalAmount -
                                        purchase.paidAmount;



                                    List<dynamic> itemsList = [];
                                    try {
                                      itemsList =
                                          jsonDecode(purchase.itemsJson)
                                              as List;
                                    } catch (_) {}

                                    final supplier = invState.suppliers
                                        .where(
                                          (s) =>
                                              s.supplierId ==
                                              purchase.supplierId,
                                        )
                                        .firstOrNull;
                                    final supplierName =
                                        supplier?.name ?? 'Unknown Company';

                                    return ExpansionTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.local_shipping_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      title: Text(
                                        'Company: $supplierName',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Inv #: ${purchase.invoiceNumber} | Date: ${purchase.timestamp.toLocal().toString().split(' ')[0]} | Total: Rs. ${purchase.totalAmount.toStringAsFixed(0)}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Paid: Rs. ${purchase.paidAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (unpaid > 0)
                                                Text(
                                                  'Due: Rs. ${unpaid.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () => _showEditPurchaseDialog(purchase),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text(
                                                        'Delete Purchase?',
                                                      ),
                                                      content: Text(
                                                        'Are you sure you want to completely delete Invoice ${purchase.invoiceNumber}?\n\nWARNING: This will subtract the stock of these items back to what they were before, and revert the company balance.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                c,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                c,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Complete Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                              if (confirm == true) {
                                                ref
                                                    .read(
                                                      transactionsControllerProvider
                                                          .notifier,
                                                    )
                                                    .deletePurchase(
                                                      purchase.purchaseId,
                                                    );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Purchase deleted and stock reverted.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          child: Table(
                                            border: TableBorder.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            children: [
                                              const TableRow(
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFF5F5F5),
                                                ),
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.all(
                                                      8.0,
                                                    ),
                                                    child: Text(
                                                      'Product Name',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.all(
                                                      8.0,
                                                    ),
                                                    child: Text(
                                                      'Quantity',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.all(
                                                      8.0,
                                                    ),
                                                    child: Text(
                                                      'Unit Cost',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.all(
                                                      8.0,
                                                    ),
                                                    child: Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              ...itemsList.map((item) {
                                                return TableRow(
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: Text(
                                                        item['name'] ?? '-',
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: Text(
                                                        '${item['quantity']}',
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: Text(
                                                        'Rs. ${(item['purchasePrice'] as num?)?.toStringAsFixed(0) ?? '0'}',
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: Text(
                                                        'Rs. ${(item['total'] as num?)?.toStringAsFixed(0) ?? '0'}',
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showQuickAddBrandDialog(BuildContext context, Function(BrandModel) onCreated) {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Add New Company / Brand'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company / Brand Name*',
                    hintText: 'e.g. Unilever, Nestle, Shan',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameCtrl.text.trim();
                  final newBrand = BrandModel()
                    ..brandId = const Uuid().v4()
                    ..name = name
                    ..isDirty = true
                    ..lastUpdated = DateTime.now()
                    ..isDeleted = false;

                  await ref.read(inventoryControllerProvider.notifier).saveBrand(newBrand);
                  if (mounted) {
                    Navigator.pop(c);
                    onCreated(newBrand);
                  }
                }
              },
              child: const Text('Save & Select'),
            ),
          ],
        );
      },
    );
  }

  void _showManualEntryDialogForPurchase(BuildContext context, VoidCallback onAdded) {
    final nameCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final salePriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'Pcs');
    final formKey = GlobalKey<FormState>();
    BrandModel? selectedBrand;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final invState = ref.watch(inventoryControllerProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF9333EA)),
                  SizedBox(width: 8),
                  Text('Add Manual Item (Purchase & Sale Price)'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Item Name / Detail*',
                            hintText: 'e.g. Special Item',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: purchasePriceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Purchase Price (Khareed)*',
                                  prefixText: 'Rs. ',
                                  prefixIcon: Icon(Icons.arrow_downward, color: Colors.red),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  if (double.tryParse(val.trim()) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: salePriceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Sale Price (Frokht)*',
                                  prefixText: 'Rs. ',
                                  prefixIcon: Icon(Icons.arrow_upward, color: Colors.green),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  if (double.tryParse(val.trim()) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity*',
                                  prefixIcon: Icon(Icons.format_list_numbered),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  if (double.tryParse(val.trim()) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: unitCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Unit (e.g. Kg, Pcs, Pack)',
                                  prefixIcon: Icon(Icons.straighten),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SearchableAutocompleteField<BrandModel>(
                          labelText: 'Company / Brand (Optional)',
                          hintText: 'Search company/brand...',
                          initialValue: selectedBrand,
                          items: BrandModel.withLocal(invState.brands),
                          itemAsString: (b) => b.name,
                          prefixIcon: const Icon(Icons.business_outlined, size: 20),
                          suffixAction: Tooltip(
                            message: 'Add New Company / Brand',
                            child: IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF9333EA)),
                              onPressed: () {
                                _showQuickAddBrandDialog(context, (newBrand) {
                                  setStateDialog(() {
                                    selectedBrand = newBrand;
                                  });
                                });
                              },
                            ),
                          ),
                          onSelected: (val) {
                            setStateDialog(() {
                              selectedBrand = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameCtrl.text.trim();
                      final purchasePrice = double.tryParse(purchasePriceCtrl.text.trim()) ?? 0.0;
                      final salePrice = double.tryParse(salePriceCtrl.text.trim()) ?? 0.0;
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                      final unit = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Pcs';

                      final resolvedBrandId = (selectedBrand?.brandId == 'LOCAL') ? null : selectedBrand?.brandId;
                      final manualProduct = ProductModel()
                        ..productId = 'MANUAL-${const Uuid().v4()}'
                        ..name = name
                        ..brandId = resolvedBrandId
                        ..purchasePrice = purchasePrice
                        ..retailPrice = salePrice
                        ..wholesalePrice = salePrice
                        ..minimumPrice = purchasePrice
                        ..stock = qty
                        ..unit = unit
                        ..minimumStock = 0
                        ..maximumStock = 999999
                        ..openingStock = qty
                        ..isDeleted = false
                        ..isDirty = true
                        ..lastUpdated = DateTime.now();

                      final db = ref.read(localDbServiceProvider);
                      await db.productsBox.put(manualProduct.productId, manualProduct);
                      await ref.read(inventoryControllerProvider.notifier).refreshAll();
                      onAdded();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQuickAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Add Quick Company'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company Name*',
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newSupplier = SupplierModel()
                    ..supplierId = DateTime.now().millisecondsSinceEpoch
                        .toString()
                    ..name = nameCtrl.text.trim()
                    ..phone = phoneCtrl.text.trim()
                    ..balance = 0.0
                    ..isDirty = true
                    ..lastUpdated = DateTime.now()
                    ..isDeleted = false;
                  await ref
                      .read(inventoryControllerProvider.notifier)
                      .saveSupplier(newSupplier);
                  if (mounted) {
                    Navigator.pop(c);
                    _showNewPurchaseDialog(); // reopen purchase dialog
                  }
                }
              },
              child: const Text('Add & Continue'),
            ),
          ],
        );
      },
    );
  }
}
