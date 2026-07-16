import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/product_model.dart';
import '../../pos/viewmodels/pos_controller.dart';
import '../../products/viewmodels/inventory_controller.dart';
import '../../../core/utils/print_helper.dart';
import '../../../core/providers/global_providers.dart';

class SalesView extends ConsumerStatefulWidget {
  const SalesView({super.key});

  @override
  ConsumerState<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends ConsumerState<SalesView> {
  List<SaleModel> _sales = [];
  List<CustomerModel> _customers = [];
  Map<String, String> _customerNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final repo = ref.read(salesRepositoryProvider);
    final sales = await repo.getSales();

    final customers = await repo.getCustomers();
    final Map<String, String> cNames = {};
    for (var c in customers) {
      cNames[c.customerId] = c.name;
    }

    // Sort so newest is at the top
    sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _sales = sales;
      _customers = customers;
      _customerNames = cNames;
      _isLoading = false;
    });
  }

  Future<void> _deleteSale(SaleModel sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text(
          'Are you sure you want to delete invoice ${sale.invoiceNumber}? This will restock the sold items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(salesRepositoryProvider).deleteSale(sale.saleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted and stock reverted.')),
        );
        _loadSales();
      }
    }
  }

  void _reprintReceipt(SaleModel sale, bool isThermal) async {
    try {
      final items = jsonDecode(sale.itemsJson) as List;
      final currentUser = ref.read(currentUserProvider);
      final cashierName = currentUser?.fullName ?? 'Admin';

      final storeProfile = ref.read(storeProfileProvider);

      String? cName;
      String? cPhone;
      double? cDues;

      if (sale.customerId != null) {
        final customers = await ref
            .read(salesRepositoryProvider)
            .getCustomers();
        final c = customers
            .where((e) => e.customerId == sale.customerId)
            .firstOrNull;
        if (c != null) {
          cName = c.name;
          cPhone = c.phone;
          final unpaidOfThisSale = sale.total - sale.paidAmount;
          final priorDues = c.balance - unpaidOfThisSale;
          cDues = priorDues > 0 ? priorDues : null;
        }
      }

      if (isThermal) {
        final pdfBytes = await PrintHelper.generateThermalReceipt(
          sale: sale,
          items: items,
          cashierName: cashierName,
          storeProfile: storeProfile,
          customerName: cName,
          customerPhone: cPhone,
          previousDues: cDues,
        );
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      } else {
        final pdfBytes = await PrintHelper.generateA4Invoice(
          sale: sale,
          items: items,
          cashierName: cashierName,
          storeProfile: storeProfile,
          customerName: cName,
          customerPhone: cPhone,
          previousDues: cDues,
        );
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  void _showQuickAddCustomerDialog(
    void Function(void Function()) setStateDialog,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quick Add Customer'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name*',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final customer = CustomerModel()
                    ..customerId = const Uuid().v4()
                    ..name = nameCtrl.text.trim()
                    ..phone = phoneCtrl.text.trim()
                    ..address = addressCtrl.text.trim()
                    ..balance = 0.0
                    ..isDeleted = false;

                  await ref
                      .read(salesRepositoryProvider)
                      .saveCustomer(customer);

                  if (context.mounted) {
                    Navigator.pop(context);
                    await _loadSales();
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSaleDialog() {
    CustomerModel? selectedCustomer;
    ProductModel? selectedProduct;

    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '0');
    final paidCtrl = TextEditingController(text: '0');
    final invoiceCtrl = TextEditingController();
    final addFormKey = GlobalKey<FormState>();

    List<Map<String, dynamic>> cart = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final invState = ref.watch(inventoryControllerProvider);
            double cartTotal = cart.fold(0.0, (sum, i) => sum + i['total']);

            return AlertDialog(
              title: const Text('New Manual Sale Entry'),
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
                            child: DropdownButtonFormField<CustomerModel>(
                              value: selectedCustomer,
                              decoration: const InputDecoration(
                                labelText:
                                    'Select Customer (Optional for Walk-in)',
                              ),
                              items: _customers.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setStateDialog(() {
                                  selectedCustomer = val;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add New Customer',
                            onPressed: () {
                              _showQuickAddCustomerDialog(setStateDialog);
                            },
                          ),
                        ],
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
                            DropdownButtonFormField<ProductModel>(
                              value: selectedProduct,
                              decoration: const InputDecoration(
                                labelText: 'Product',
                              ),
                              items: invState.products.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    '${p.name} (Stock: ${p.stock.toStringAsFixed(1)})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() {
                                    selectedProduct = val;
                                    priceCtrl.text = val.retailPrice.toString();
                                    qtyCtrl.text = '1';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: qtyCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity',
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
                                    controller: priceCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Price',
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
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_box_rounded),
                                  label: const Text("Add Item"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (addFormKey.currentState!.validate() &&
                                        selectedProduct != null) {
                                      final qty = double.parse(qtyCtrl.text);
                                      final price = double.parse(
                                        priceCtrl.text,
                                      );

                                      if (qty > 0) {
                                        final existingIndex = cart.indexWhere(
                                          (i) =>
                                              i['productId'] ==
                                              selectedProduct!.productId,
                                        );
                                        if (existingIndex >= 0) {
                                          cart[existingIndex]['quantity'] +=
                                              qty;
                                          cart[existingIndex]['unitPrice'] =
                                              price;
                                          cart[existingIndex]['total'] =
                                              cart[existingIndex]['quantity'] *
                                              price;
                                        } else {
                                          cart.add({
                                            'productId':
                                                selectedProduct!.productId,
                                            'name': selectedProduct!.name,
                                            'quantity': qty,
                                            'unitPrice': price,
                                            'purchasePrice':
                                                selectedProduct!.purchasePrice,
                                            'discount': 0.0,
                                            'total': qty * price,
                                          });
                                        }
                                        setStateDialog(() {
                                          selectedProduct = null;
                                          qtyCtrl.text = '1';
                                          priceCtrl.text = '0';
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
                            'Cart Items:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cart.length,
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final item = cart[i];
                              return ListTile(
                                dense: true,
                                title: Text(item['name']),
                                subtitle: Text(
                                  'Qty: ${item['quantity']} @ Rs.${item['unitPrice']}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs. ${item['total'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setStateDialog(() {
                                          cart.removeAt(i);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Grand Total:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Rs. ${cartTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: paidCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Amount Paid Now',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
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
                if (cart.isNotEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        final paidAmt = double.tryParse(paidCtrl.text) ?? 0.0;
                        final timestamp = DateTime.now();
                        final invoice = invoiceCtrl.text.trim().isNotEmpty
                            ? invoiceCtrl.text.trim()
                            : 'INV-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.millisecondsSinceEpoch.toString().substring(8)}';

                        final sale = SaleModel()
                          ..saleId = const Uuid().v4()
                          ..invoiceNumber = invoice
                          ..cashierId =
                              ref.read(currentUserProvider)?.userId ?? 'admin'
                          ..customerId = selectedCustomer?.customerId
                          ..subtotal = cartTotal
                          ..discount = 0.0
                          ..total = cartTotal
                          ..paidAmount = paidAmt
                          ..changeAmount = 0.0
                          ..paymentMethod = paidAmt > 0
                              ? 'Cash'
                              : 'Credit (Khata)'
                          ..timestamp = timestamp
                          ..itemsJson = jsonEncode(cart)
                          ..isDeleted = false;

                        await ref.read(salesRepositoryProvider).saveSale(sale);
                        await ref
                            .read(inventoryControllerProvider.notifier)
                            .refreshAll();
                        await _loadSales();

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sale recorded successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: const Text('Save Sale'),
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
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.role == 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales & Invoice History',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Refresh History',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSaleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Sale Record'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
          ? const Center(child: Text('No sales invoices found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sales.length,
              itemBuilder: (context, index) {
                final sale = _sales[index];
                final unpaid = sale.total - sale.paidAmount;
                final cName =
                    sale.customerId != null && sale.customerId!.isNotEmpty
                    ? (_customerNames[sale.customerId] ?? 'Walk-in Customer')
                    : 'Walk-in Customer';
                List<dynamic> items = [];
                try {
                  items = jsonDecode(sale.itemsJson) as List;
                } catch (_) {}

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: const Icon(Icons.receipt_long_rounded),
                      ),
                      title: Text(
                        'Customer: $cName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Inv #: ${sale.invoiceNumber} | Date: ${sale.timestamp.toLocal().toString().split(' ')[0]} | Total: Rs. ${sale.total.toStringAsFixed(0)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Paid: Rs. ${sale.paidAmount.toStringAsFixed(0)}',
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
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteSale(sale),
                            ),
                        ],
                      ),
                      children: [
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: theme.scaffoldBackgroundColor.withValues(
                            alpha: 0.5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Purchased Items:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...items.map((item) {
                                final name =
                                    item['productName'] ??
                                    item['name'] ??
                                    'Unknown';
                                final qty = item['quantity']?.toString() ?? '0';
                                final price =
                                    item['price']?.toString() ??
                                    item['unitPrice']?.toString() ??
                                    '0';
                                final total = item['total']?.toString() ?? '0';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '- $name (x$qty @ Rs.$price)',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        'Rs. $total',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.print, size: 18),
                                    label: const Text('Thermal Print'),
                                    onPressed: () =>
                                        _reprintReceipt(sale, true),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      size: 18,
                                    ),
                                    label: const Text('A4 Print'),
                                    onPressed: () =>
                                        _reprintReceipt(sale, false),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () => _deleteSale(sale),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
