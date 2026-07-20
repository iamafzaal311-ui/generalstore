import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/product_model.dart';
import '../../products/viewmodels/inventory_controller.dart';
import '../../accounts/viewmodels/accounts_controller.dart';
import '../../pos/viewmodels/pos_controller.dart';

class EditSaleDialog extends ConsumerStatefulWidget {
  final SaleModel sale;
  const EditSaleDialog({super.key, required this.sale});

  @override
  ConsumerState<EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends ConsumerState<EditSaleDialog> {
  late List<Map<String, dynamic>> _items;
  late double _discount;
  late double _paidAmount;

  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _paidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(jsonDecode(widget.sale.itemsJson));
    _discount = widget.sale.discount;
    _paidAmount = widget.sale.paidAmount;

    _discountCtrl.text = _discount.toString();
    _paidCtrl.text = _paidAmount.toString();
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) {
      final qty = (item['quantity'] as num).toDouble();
      final price = (item['unitPrice'] as num).toDouble();
      return sum + (qty * price);
    });
  }

  double get _total => _subtotal - _discount;

  void _updateItemQuantity(int index, double newQty) {
    if (newQty < 1) return;
    setState(() {
      _items[index]['quantity'] = newQty;
      _items[index]['total'] = newQty * (_items[index]['unitPrice'] as num).toDouble();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _items[index]['unitPrice'] = newPrice;
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
          'unitPrice': product.retailPrice,
          'purchasePrice': product.purchasePrice,
          'discount': 0.0,
          'total': product.retailPrice,
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

  Future<void> _saveChanges() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill cannot be empty')));
      return;
    }

    final repo = ref.read(salesRepositoryProvider);
    
    final newSale = SaleModel()
      ..saleId = widget.sale.saleId
      ..invoiceNumber = widget.sale.invoiceNumber
      ..cashierId = widget.sale.cashierId
      ..customerId = widget.sale.customerId
      ..subtotal = _subtotal
      ..discount = _discount
      ..total = _total
      ..paidAmount = _paidAmount
      ..changeAmount = _paidAmount > _total ? _paidAmount - _total : 0.0
      ..paymentMethod = widget.sale.paymentMethod
      ..timestamp = widget.sale.timestamp
      ..itemsJson = jsonEncode(_items)
      ..isDeleted = false
      ..isDirty = true
      ..lastUpdated = DateTime.now();

    await repo.updateSale(widget.sale, newSale);
    
    ref.read(inventoryControllerProvider.notifier).refreshAll();
    ref.read(accountsControllerProvider.notifier).refreshAccounts();

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
                Text('Edit Sale Invoice: ${widget.sale.invoiceNumber}', style: theme.textTheme.headlineSmall),
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
                        ElevatedButton.icon(
                          onPressed: _showAddProductSearch,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add Product to Bill'),
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
                                      initialValue: item['unitPrice'].toString(),
                                      decoration: const InputDecoration(labelText: 'Price', isDense: true),
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
                            const Text('Subtotal:'),
                            Text('Rs. ${_subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _discountCtrl,
                          decoration: const InputDecoration(labelText: 'Discount'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _discount = double.tryParse(val) ?? 0.0),
                        ),
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
                  subtitle: Text('Price: Rs. ${p.retailPrice} | Stock: ${p.stock}'),
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
