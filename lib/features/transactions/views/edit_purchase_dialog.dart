import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../data/models/brand_model.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/models/product_model.dart';
import '../../products/viewmodels/inventory_controller.dart';
import '../../accounts/viewmodels/accounts_controller.dart';
import '../viewmodels/transactions_controller.dart';

class EditPurchaseDialog extends ConsumerStatefulWidget {
  final PurchaseModel purchase;
  const EditPurchaseDialog({super.key, required this.purchase});

  @override
  ConsumerState<EditPurchaseDialog> createState() => _EditPurchaseDialogState();
}

class _EditPurchaseDialogState extends ConsumerState<EditPurchaseDialog> {
  late List<Map<String, dynamic>> _items;
  late double _paidAmount;

  final TextEditingController _paidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(jsonDecode(widget.purchase.itemsJson));
    _paidAmount = widget.purchase.paidAmount;

    _paidCtrl.text = _paidAmount.toString();
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  double get _total {
    return _items.fold(0.0, (sum, item) {
      final qty = (item['quantity'] as num).toDouble();
      final price = (item['purchasePrice'] as num).toDouble();
      return sum + (qty * price);
    });
  }

  void _updateItemQuantity(int index, double newQty) {
    if (newQty < 1) return;
    setState(() {
      _items[index]['quantity'] = newQty;
      _items[index]['total'] = newQty * (_items[index]['purchasePrice'] as num).toDouble();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _items[index]['purchasePrice'] = newPrice;
      _items[index]['total'] = (_items[index]['quantity'] as num).toDouble() * newPrice;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addProduct(ProductModel product) {
    setState(() {
      final existingIndex = _items.indexWhere((i) => i['productId'] == product.productId);
      if (existingIndex >= 0) {
        _updateItemQuantity(existingIndex, (_items[existingIndex]['quantity'] as num).toDouble() + 1);
      } else {
        _items.add({
          'productId': product.productId,
          'name': product.name,
          'brand': '',
          'category': '',
          'quantity': 1.0,
          'purchasePrice': product.purchasePrice,
          'total': product.purchasePrice,
        });
      }
    });
  }

  void _showAddProductSearch() {
    final invState = ref.read(inventoryControllerProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return _ProductSearchSheet(
          products: invState.products,
          onSelect: (p) {
            _addProduct(p);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showManualEntryDialog() {
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
        return Consumer(
          builder: (context, ref, child) {
            final invState = ref.watch(inventoryControllerProvider);
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF9333EA)),
                      SizedBox(width: 8),
                      Text('Add Manual Item to Purchase Bill'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: 480,
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Item Name / Detail*',
                                hintText: 'e.g. Special Item',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
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
                              hintText: 'Search or select company/brand...',
                              initialValue: selectedBrand,
                              items: BrandModel.withLocal(invState.brands),
                              itemAsString: (b) => b.name,
                              prefixIcon: const Icon(Icons.business_outlined, size: 20),
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
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add to Bill'),
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
                          final brandName = (selectedBrand?.brandId == 'LOCAL') ? '' : (selectedBrand?.name ?? '');

                          final resolvedBrandId = (selectedBrand?.brandId == 'LOCAL') ? null : selectedBrand?.brandId;
                          final manualProductId = 'MANUAL-${const Uuid().v4()}';
                          final dbProduct = ProductModel()
                            ..productId = manualProductId
                            ..name = name
                            ..brandId = resolvedBrandId
                            ..purchasePrice = purchasePrice
                            ..retailPrice = salePrice
                            ..wholesalePrice = salePrice
                            ..minimumPrice = purchasePrice
                            ..stock = qty
                            ..unit = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Pcs'
                            ..minimumStock = 0
                            ..maximumStock = 999999
                            ..openingStock = qty
                            ..isDeleted = false
                            ..isDirty = true
                            ..lastUpdated = DateTime.now();

                          final db = ref.read(localDbServiceProvider);
                          await db.productsBox.put(dbProduct.productId, dbProduct);

                          setState(() {
                            _items.add({
                              'productId': manualProductId,
                              'name': name,
                              'brand': brandName,
                              'category': '',
                              'quantity': qty,
                              'purchasePrice': purchasePrice,
                              'total': qty * purchasePrice,
                            });
                          });

                          if (mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill cannot be empty')));
      return;
    }

    final repo = ref.read(transactionsRepositoryProvider);
    
    final newPurchase = PurchaseModel()
      ..purchaseId = widget.purchase.purchaseId
      ..invoiceNumber = widget.purchase.invoiceNumber
      ..supplierId = widget.purchase.supplierId
      ..totalAmount = _total
      ..paidAmount = _paidAmount
      ..timestamp = widget.purchase.timestamp
      ..itemsJson = jsonEncode(_items)
      ..isDeleted = false
      ..isDirty = true
      ..lastUpdated = DateTime.now();

    await repo.updatePurchase(widget.purchase, newPurchase);
    
    ref.read(inventoryControllerProvider.notifier).refreshAll();
    ref.read(accountsControllerProvider.notifier).refreshAccounts();
    ref.read(transactionsControllerProvider.notifier).refreshPurchases();

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Purchase Invoice: ${widget.purchase.invoiceNumber}', style: theme.textTheme.headlineSmall),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showAddProductSearch,
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Add Product to Bill'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _showManualEntryDialog,
                              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF9333EA)),
                              label: const Text('Add Manual Item', style: TextStyle(color: Color(0xFF9333EA))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (c, i) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          onPressed: () => _updateItemQuantity(index, (item['quantity'] as num).toDouble() - 1),
                                        ),
                                        Text('${item['quantity']}'),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          onPressed: () => _updateItemQuantity(index, (item['quantity'] as num).toDouble() + 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item['purchasePrice'].toString(),
                                      decoration: const InputDecoration(labelText: 'Cost Price', isDense: true),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        final newPrice = double.tryParse(val) ?? 0.0;
                                        _updateItemPrice(index, newPrice);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Rs. ${item['total']}'),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 32),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Totals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('Rs. ${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _paidCtrl,
                          decoration: const InputDecoration(labelText: 'Paid Amount'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _paidAmount = double.tryParse(val) ?? 0.0),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            onPressed: _saveChanges,
                            child: const Text('Save Changes', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final List<ProductModel> products;
  final Function(ProductModel) onSelect;

  const _ProductSearchSheet({required this.products, required this.onSelect});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
             (p.sku ?? '').toLowerCase().contains(q) ||
             (p.barcode ?? '').toLowerCase().contains(q);
    }).toList();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Search Product', prefixIcon: Icon(Icons.search)),
            onChanged: (val) => setState(() => _query = val),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final p = filtered[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('Cost: Rs. ${p.purchasePrice} | Stock: ${p.stock}'),
                  onTap: () => widget.onSelect(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
