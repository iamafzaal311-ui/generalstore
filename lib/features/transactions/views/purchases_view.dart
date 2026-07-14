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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(transactionsControllerProvider.notifier).refreshPurchases());
  }

  void _showNewPurchaseDialog() {
    final theme = Theme.of(context);
    final invState = ref.read(inventoryControllerProvider);

    ProductModel? selectedProduct;
    final cartonsCtrl = TextEditingController(text: '0');
    final piecesPerCartonCtrl = TextEditingController(text: '1');
    final loosePiecesCtrl = TextEditingController(text: '0');
    final cartonPriceCtrl = TextEditingController(text: '0');
    final loosePriceCtrl = TextEditingController(text: '0');
    
    final paidCtrl = TextEditingController(text: '0');
    final addFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final txState = ref.watch(transactionsControllerProvider);
            return AlertDialog(
              title: const Text('New Stock Purchase Entry'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<SupplierModel>(
                        initialValue: txState.selectedSupplier,
                        decoration: const InputDecoration(labelText: 'Select Supplier'),
                        items: invState.suppliers.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s.name));
                        }).toList(),
                        onChanged: (val) {
                          ref.read(transactionsControllerProvider.notifier).selectSupplier(val);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Form(
                        key: addFormKey,
                        child: Column(
                          children: [
                            DropdownButtonFormField<ProductModel>(
                              initialValue: selectedProduct,
                              decoration: const InputDecoration(labelText: 'Product'),
                              items: invState.products.map((p) {
                                return DropdownMenuItem(value: p, child: Text(p.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() {
                                    selectedProduct = val;
                                    loosePriceCtrl.text = val.purchasePrice.toString();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: cartonsCtrl,
                                    decoration: const InputDecoration(labelText: 'Cartons'),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: piecesPerCartonCtrl,
                                    decoration: const InputDecoration(labelText: 'Pieces in 1 Carton'),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: cartonPriceCtrl,
                                    decoration: const InputDecoration(labelText: 'Carton Price'),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: loosePiecesCtrl,
                                    decoration: const InputDecoration(labelText: 'Loose Pieces'),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: loosePriceCtrl,
                                    decoration: const InputDecoration(labelText: 'Loose Piece Price'),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_box_rounded),
                                  label: const Text("Add"),
                                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                                  onPressed: () {
                                    if (addFormKey.currentState!.validate() && selectedProduct != null) {
                                      final cartons = double.parse(cartonsCtrl.text);
                                      final ppc = double.parse(piecesPerCartonCtrl.text);
                                      final cPrice = double.parse(cartonPriceCtrl.text);
                                      
                                      final loose = double.parse(loosePiecesCtrl.text);
                                      final lPrice = double.parse(loosePriceCtrl.text);
                                      
                                      final totalQty = (cartons * ppc) + loose;
                                      final totalCost = (cartons * cPrice) + (loose * lPrice);
                                      
                                      if (totalQty > 0) {
                                        final unitPrice = totalCost / totalQty;
                                        
                                        ref.read(transactionsControllerProvider.notifier).addToCart(
                                              selectedProduct!,
                                              totalQty,
                                              unitPrice,
                                            );
                                            
                                        selectedProduct!.purchasePrice = unitPrice;
                                        selectedProduct!.wholesalePrice = unitPrice;
                                        selectedProduct!.lastUpdated = DateTime.now();
                                        selectedProduct!.isDirty = true;
                                        
                                        ref.read(inventoryControllerProvider.notifier).saveProduct(selectedProduct!);

                                        setStateDialog(() {
                                          selectedProduct = null;
                                          cartonsCtrl.text = '0';
                                          loosePiecesCtrl.text = '0';
                                          cartonPriceCtrl.text = '0';
                                          loosePriceCtrl.text = '0';
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
                          child: Text('Purchase Invoice Items:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                subtitle: Text('${item.quantity} units x Rs.${item.purchasePrice.toStringAsFixed(2)} = Rs.${item.total.toStringAsFixed(0)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    ref.read(transactionsControllerProvider.notifier).removeFromCart(item.product.productId);
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: paidCtrl,
                          decoration: const InputDecoration(labelText: 'Paid to Supplier (Rs.)'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final p = double.tryParse(val) ?? 0.0;
                            ref.read(transactionsControllerProvider.notifier).setPaidAmount(p);
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
                  onPressed: txState.cart.isEmpty || txState.selectedSupplier == null
                      ? null
                      : () async {
                          try {
                            await ref.read(transactionsControllerProvider.notifier).savePurchase();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Stock purchase recorded successfully!')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders & Inventory Entry'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: txState.purchases.isEmpty
                    ? const Center(child: Text('No stock purchases recorded.'))
                    : ListView.separated(
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemCount: txState.purchases.length,
                        itemBuilder: (context, index) {
                          final purchase = txState.purchases[index];
                          final unpaid = purchase.totalAmount - purchase.paidAmount;
                          
                          int totalUnits = 0;
                          try {
                            final items = jsonDecode(purchase.itemsJson) as List;
                            for (var item in items) {
                              totalUnits += (item['quantity'] as num).toInt();
                            }
                          } catch (_) {}

                          List<dynamic> itemsList = [];
                          try {
                            itemsList = jsonDecode(purchase.itemsJson) as List;
                          } catch (_) {}

                          return ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(Icons.shopping_bag_rounded, color: theme.colorScheme.primary),
                            ),
                            title: Text('Inv #: ${purchase.invoiceNumber} (Total Units: $totalUnits)'),
                            subtitle: Text('Date: ${purchase.timestamp.toLocal().toString().split(' ')[0]} | Total: Rs. ${purchase.totalAmount.toStringAsFixed(0)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Paid: Rs. ${purchase.paidAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    if (unpaid > 0)
                                      Text('Due: Rs. ${unpaid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    ref.read(transactionsControllerProvider.notifier).deletePurchase(purchase.purchaseId);
                                  },
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Table(
                                  border: TableBorder.all(color: Colors.grey.shade300),
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
                                      children: [
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('Unit Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                    ...itemsList.map((item) {
                                      return TableRow(
                                        children: [
                                          Padding(padding: const EdgeInsets.all(8.0), child: Text(item['name'] ?? '-')),
                                          Padding(padding: const EdgeInsets.all(8.0), child: Text('${item['quantity']}')),
                                          Padding(padding: const EdgeInsets.all(8.0), child: Text('Rs. ${(item['purchasePrice'] as num?)?.toStringAsFixed(0) ?? '0'}')),
                                          Padding(padding: const EdgeInsets.all(8.0), child: Text('Rs. ${(item['total'] as num?)?.toStringAsFixed(0) ?? '0'}')),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
