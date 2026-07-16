import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/supplier_model.dart';
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
    final quantityCtrl = TextEditingController(text: '1');
    final purchasePriceCtrl = TextEditingController(text: '0');
    final minStockCtrl = TextEditingController(text: '0');
    final expiryCtrl = TextEditingController();

    final paidCtrl = TextEditingController(text: '0');
    final invoiceCtrl = TextEditingController();
    final productSearchCtrl = TextEditingController();
    final addFormKey = GlobalKey<FormState>();
    String productSearchQuery = '';

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
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<SupplierModel>(
                              initialValue: txState.selectedSupplier,
                              decoration: const InputDecoration(
                                labelText: 'Select Supplier',
                              ),
                              items: invState.suppliers.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                ref
                                    .read(
                                      transactionsControllerProvider.notifier,
                                    )
                                    .selectSupplier(val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add New Supplier',
                            onPressed: () {
                              Navigator.pop(
                                context,
                              ); // Close purchase dialog temporarily
                              // TODO: Trigger a quick add supplier dialog and re-open this.
                              // Since we don't have a global method for it here, we'll prompt the user to use Accounts for full setup, or we can just push a quick dialog.
                              _showQuickAddSupplierDialog();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: invoiceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Supplier Invoice Number (Optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Form(
                        key: addFormKey,
                        child: Column(
                          children: [
                            // ── Product Search + Dropdown ──────────────────
                            TextField(
                              controller: productSearchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search product by name or SKU...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                suffixIcon: productSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          productSearchCtrl.clear();
                                          setStateDialog(() {
                                            productSearchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) => setStateDialog(() {
                                productSearchQuery = val.toLowerCase();
                              }),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<ProductModel>(
                              isExpanded: true,
                              value: selectedProduct,
                              decoration: const InputDecoration(
                                labelText: 'Select Product',
                                isDense: true,
                              ),
                              items: invState.products
                                  .where(
                                    (p) =>
                                        productSearchQuery.isEmpty ||
                                        p.name.toLowerCase().contains(
                                          productSearchQuery,
                                        ) ||
                                        (p.sku ?? '').toLowerCase().contains(
                                          productSearchQuery,
                                        ) ||
                                        (p.barcode ?? '')
                                            .toLowerCase()
                                            .contains(productSearchQuery),
                                  )
                                  .map((p) {
                                    return DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() {
                                    selectedProduct = val;
                                    purchasePriceCtrl.text = val.purchasePrice
                                        .toString();
                                    // Clear search after selection
                                    productSearchCtrl.clear();
                                    productSearchQuery = '';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
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
                                        val == null || double.tryParse(val) == null
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
                                        val == null || double.tryParse(val) == null
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
                                      final totalQty = double.parse(quantityCtrl.text);
                                      final unitPrice = double.parse(purchasePriceCtrl.text);

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
                                        if (minS != null)
                                          selectedProduct!.minimumStock = minS;

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
                            labelText: 'Paid to Supplier (Rs.)',
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

  @override
  Widget build(BuildContext context) {
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
                      hintText: 'Search by Invoice # or Supplier Name...',
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

                                    int totalUnits = 0;
                                    try {
                                      final items =
                                          jsonDecode(purchase.itemsJson)
                                              as List;
                                      for (var item in items) {
                                        totalUnits += (item['quantity'] as num)
                                            .toInt();
                                      }
                                    } catch (_) {}

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
                                        supplier?.name ?? 'Unknown Supplier';

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
                                        'Supplier: $supplierName',
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
                                                        'Are you sure you want to completely delete Invoice ${purchase.invoiceNumber}?\n\nWARNING: This will subtract the stock of these items back to what they were before, and revert the supplier balance.',
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

  void _showQuickAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Add Quick Supplier'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name*',
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
