import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/product_model.dart';
import '../../../core/providers/global_providers.dart';
import '../../pos/viewmodels/pos_controller.dart';
import '../../products/viewmodels/inventory_controller.dart';
import '../../accounts/viewmodels/accounts_controller.dart';
import '../../../core/utils/print_helper.dart';

class ReturnsView extends ConsumerStatefulWidget {
  const ReturnsView({super.key});

  @override
  ConsumerState<ReturnsView> createState() => _ReturnsViewState();
}

class _ReturnsViewState extends ConsumerState<ReturnsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _productSearchCtrl = TextEditingController();
  final TextEditingController _deductionCtrl = TextEditingController(text: '0');
  final TextEditingController _reasonCtrl = TextEditingController();

  List<SaleModel> _allSales = [];
  List<CustomerModel> _allCustomers = [];
  SaleModel? _selectedSale;
  CustomerModel? _selectedCustomer;

  // Mode: false = Return from Existing Bill, true = Direct New Return Invoice
  bool _isDirectReturnMode = false;

  // Existing Bill Return Mode Items State
  List<Map<String, dynamic>> _saleItems = [];
  Map<int, bool> _selectedItemMap = {};
  Map<int, double> _returnQtyMap = {};

  // Direct Return Mode Items State
  List<Map<String, dynamic>> _directReturnItems = [];

  String _refundMethod = 'Cash';
  double _deductionPercentage = 0.0;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSalesAndCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _productSearchCtrl.dispose();
    _deductionCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSalesAndCustomers() async {
    setState(() => _isLoading = true);
    final repo = ref.read(salesRepositoryProvider);
    final sales = await repo.getSales();
    final db = ref.read(localDbServiceProvider);
    final customers = db.customersBox.values.toList();

    // Exclude return invoices from selection pool (only original sales)
    final originalSales =
        sales.where((s) => !s.invoiceNumber.startsWith('RET-')).toList();
    originalSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _allSales = originalSales;
      _allCustomers = customers;
      _isLoading = false;
    });
  }

  void _startDirectReturnMode() {
    setState(() {
      _isDirectReturnMode = true;
      _selectedSale = null;
      _selectedCustomer = null;
      _directReturnItems = [];
      _deductionPercentage = 0.0;
      _deductionCtrl.text = '0';
      _refundMethod = 'Cash';
      _reasonCtrl.clear();
    });
  }

  void _selectInvoice(SaleModel sale) async {
    try {
      final items = jsonDecode(sale.itemsJson) as List;
      final parsedItems =
          items.map((i) => Map<String, dynamic>.from(i)).toList();

      CustomerModel? cust;
      if (sale.customerId != null) {
        final db = ref.read(localDbServiceProvider);
        cust = db.customersBox.get(sale.customerId);
      }

      final Map<int, bool> selMap = {};
      final Map<int, double> qtyMap = {};
      for (int i = 0; i < parsedItems.length; i++) {
        selMap[i] = true;
        qtyMap[i] = ((parsedItems[i]['quantity'] as num?)?.toDouble() ?? 1.0);
      }

      setState(() {
        _isDirectReturnMode = false;
        _selectedSale = sale;
        _selectedCustomer = cust;
        _saleItems = parsedItems;
        _selectedItemMap = selMap;
        _returnQtyMap = qtyMap;
        _deductionPercentage = 0.0;
        _deductionCtrl.text = '0';
        _refundMethod = cust != null ? 'Credit (Khata Adjustment)' : 'Cash';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoice items: $e')),
      );
    }
  }

  void _addDirectProductToReturn(ProductModel product) {
    final existingIdx = _directReturnItems.indexWhere(
      (item) => item['productId'] == product.productId,
    );

    setState(() {
      if (existingIdx >= 0) {
        _directReturnItems[existingIdx]['quantity'] =
            (_directReturnItems[existingIdx]['quantity'] as double) + 1.0;
        _directReturnItems[existingIdx]['subtotal'] =
            (_directReturnItems[existingIdx]['quantity'] as double) *
                (_directReturnItems[existingIdx]['unitPrice'] as double);
      } else {
        _directReturnItems.add({
          'productId': product.productId,
          'name': product.name,
          'unitPrice': product.retailPrice,
          'quantity': 1.0,
          'subtotal': product.retailPrice,
        });
      }
    });
    _productSearchCtrl.clear();
  }

  void _showEditQtyDialog({
    required int index,
    required double currentQty,
    required double maxQty,
    required bool isDirectMode,
  }) {
    final controller =
        TextEditingController(text: currentQty.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Return Quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Quantity (Max: ${maxQty > 0 ? maxQty.toStringAsFixed(0) : "Unlimited"})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text) ?? 1.0;
              final finalQty = parsed < 1.0
                  ? 1.0
                  : (maxQty > 0 && parsed > maxQty ? maxQty : parsed);
              setState(() {
                if (isDirectMode) {
                  _directReturnItems[index]['quantity'] = finalQty;
                  _directReturnItems[index]['subtotal'] = finalQty *
                      (_directReturnItems[index]['unitPrice'] as double);
                } else {
                  _returnQtyMap[index] = finalQty;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  double get _grossReturnTotal {
    if (_isDirectReturnMode) {
      double sum = 0.0;
      for (final item in _directReturnItems) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
        sum += qty * price;
      }
      return sum;
    } else {
      if (_selectedSale == null) return 0.0;
      double sum = 0.0;
      for (int i = 0; i < _saleItems.length; i++) {
        if (_selectedItemMap[i] == true) {
          final retQty = _returnQtyMap[i] ?? 0.0;
          final unitPrice =
              (_saleItems[i]['unitPrice'] as num?)?.toDouble() ?? 0.0;
          final itemDisc =
              (_saleItems[i]['discount'] as num?)?.toDouble() ?? 0.0;
          final origQty =
              (_saleItems[i]['quantity'] as num?)?.toDouble() ?? 1.0;
          final discPerUnit = origQty > 0 ? (itemDisc / origQty) : 0.0;

          sum += (unitPrice - discPerUnit) * retQty;
        }
      }
      return sum < 0 ? 0.0 : sum;
    }
  }

  double get _deductionAmount {
    return (_grossReturnTotal * _deductionPercentage) / 100.0;
  }

  double get _netRefundAmount {
    final net = _grossReturnTotal - _deductionAmount;
    return net < 0 ? 0.0 : net;
  }

  Future<void> _processReturn() async {
    if (!_isDirectReturnMode && _selectedSale == null) return;
    if (_grossReturnTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to return.'),
        ),
      );
      return;
    }

    final timestamp = DateTime.now();
    final returnInvoiceNo =
        'RET-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.millisecondsSinceEpoch.toString().substring(8)}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment_return_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirm Return Invoice ($returnInvoiceNo)',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isDirectReturnMode
                  ? 'Mode: Direct New Return Invoice'
                  : 'Ref Original Bill: ${_selectedSale!.invoiceNumber}'),
              const SizedBox(height: 8),
              Text(
                  '• Gross Items Returned: Rs. ${_grossReturnTotal.toStringAsFixed(0)}'),
              if (_deductionPercentage > 0)
                Text(
                  '• Deduction Fee (${_deductionPercentage.toStringAsFixed(0)}%): - Rs. ${_deductionAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                '• NET REFUND PAID: Rs. ${_netRefundAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  '• Restock: Returned items will be added back into inventory stock immediately.\n'
                  '• Refund Method: $_refundMethod'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Process & Issue Return Invoice'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final db = ref.read(localDbServiceProvider);

    try {
      final List<Map<String, dynamic>> returnedItemsSummary = [];

      if (_isDirectReturnMode) {
        for (final item in _directReturnItems) {
          final productId = item['productId']?.toString() ?? '';
          final productName = item['name']?.toString() ?? 'Item';
          final retQty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;

          if (productId.isNotEmpty && !productId.startsWith('MANUAL-')) {
            final product = db.productsBox.get(productId);
            if (product != null) {
              product.stock += retQty;
              await db.productsBox.put(productId, product);
            }
          }

          returnedItemsSummary.add({
            'productId': productId,
            'name': productName,
            'quantity': retQty,
            'unitPrice': unitPrice,
            'subtotal': unitPrice * retQty,
          });
        }
      } else {
        for (int i = 0; i < _saleItems.length; i++) {
          if (_selectedItemMap[i] == true) {
            final retQty = _returnQtyMap[i] ?? 0.0;
            if (retQty <= 0) continue;

            final productId = _saleItems[i]['productId']?.toString() ?? '';
            final productName = _saleItems[i]['name']?.toString() ?? 'Item';
            final unitPrice =
                (_saleItems[i]['unitPrice'] as num?)?.toDouble() ?? 0.0;

            if (productId.isNotEmpty && !productId.startsWith('MANUAL-')) {
              final product = db.productsBox.get(productId);
              if (product != null) {
                product.stock += retQty;
                await db.productsBox.put(productId, product);
              }
            }

            returnedItemsSummary.add({
              'productId': productId,
              'name': productName,
              'quantity': retQty,
              'unitPrice': unitPrice,
              'subtotal': unitPrice * retQty,
            });
          }
        }
      }

      // 2. Adjust Customer Khata if selected
      double newCustomerBalance = 0.0;
      bool khataUpdated = false;
      if (_selectedCustomer != null) {
        final cust = db.customersBox.get(_selectedCustomer!.customerId);
        if (cust != null) {
          if (_refundMethod == 'Credit (Khata Adjustment)') {
            cust.balance -= _netRefundAmount;
            khataUpdated = true;
          }
          cust.isDirty = true;
          cust.lastUpdated = DateTime.now();
          await db.customersBox.put(cust.customerId, cust);
          newCustomerBalance = cust.balance;

          try {
            await ref
                .read(accountsControllerProvider.notifier)
                .refreshAccounts();
          } catch (_) {}
        }
      }

      // 3. Save Dedicated Return Invoice Sale Record in salesBox
      final currentUser = ref.read(currentUserProvider);
      final returnSaleRecord = SaleModel()
        ..saleId = const Uuid().v4()
        ..invoiceNumber = returnInvoiceNo
        ..cashierId = currentUser?.userId ?? 'admin-offline'
        ..customerId = _selectedCustomer?.customerId
        ..subtotal = -_grossReturnTotal
        ..discount = _deductionAmount
        ..total = -_netRefundAmount
        ..paidAmount = -_netRefundAmount
        ..changeAmount = 0.0
        ..paymentMethod = _refundMethod
        ..timestamp = timestamp
        ..itemsJson = jsonEncode(returnedItemsSummary)
        ..isDirty = true
        ..lastUpdated = timestamp
        ..isDeleted = false;

      await db.salesBox.put(returnSaleRecord.saleId, returnSaleRecord);

      // 4. Refresh Inventory Riverpod State
      ref.read(inventoryControllerProvider.notifier).refreshAll();

      setState(() => _isProcessing = false);

      if (mounted) {
        final String khataSummary = khataUpdated
            ? '✓ Customer Khata Credited: ${_selectedCustomer!.name}\n'
                '✓ Updated Khata Debt Balance: Rs. ${newCustomerBalance.toStringAsFixed(0)}\n'
            : (_selectedCustomer != null
                ? '✓ Customer: ${_selectedCustomer!.name} (Refunded via Cash)\n'
                : '');

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Expanded(child: Text('Return Invoice Generated!')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✓ Return Invoice #: $returnInvoiceNo\n'
                  '✓ Items restocked into inventory stock.\n'
                  '$khataSummary'
                  '✓ Net Refund: Rs. ${_netRefundAmount.toStringAsFixed(0)} (${_deductionPercentage > 0 ? "${_deductionPercentage.toStringAsFixed(0)}% deduction fee applied" : "No deduction"})\n'
                  '✓ Refund Method: $_refundMethod',
                  style: const TextStyle(height: 1.5, fontSize: 13.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedSale = null;
                    _selectedCustomer = null;
                    _saleItems = [];
                    _directReturnItems = [];
                    _isDirectReturnMode = false;
                  });
                  _loadSalesAndCustomers();
                },
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print Return Slip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD92525),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _printReturnSlip(returnInvoiceNo, returnedItemsSummary);
                  setState(() {
                    _selectedSale = null;
                    _selectedCustomer = null;
                    _saleItems = [];
                    _directReturnItems = [];
                    _isDirectReturnMode = false;
                  });
                  _loadSalesAndCustomers();
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process return: $e')),
        );
      }
    }
  }

  void _printReturnSlip(
    String returnInvNo,
    List<Map<String, dynamic>> returnedItems,
  ) async {
    final storeProfile = ref.read(storeProfileProvider);
    final pdfBytes = await PrintHelper.generateReturnSlipPdf(
      storeProfile: storeProfile,
      returnInvoiceNumber: returnInvNo,
      originalInvoiceNumber:
          _isDirectReturnMode ? 'Direct Return' : (_selectedSale?.invoiceNumber ?? 'N/A'),
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      returnedItems: returnedItems,
      grossTotal: _grossReturnTotal,
      deductionPercentage: _deductionPercentage,
      deductionAmount: _deductionAmount,
      netRefund: _netRefundAmount,
      refundMethod: _refundMethod,
      reason: _reasonCtrl.text.trim(),
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Return_Invoice_$returnInvNo.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryState = ref.watch(inventoryControllerProvider);

    final filteredSales = _allSales.where((s) {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return s.invoiceNumber.toLowerCase().contains(q) ||
          (s.customerId?.toLowerCase().contains(q) ?? false);
    }).toList();

    final filteredProducts = inventoryState.products.where((p) {
      final pq = _productSearchCtrl.text.trim().toLowerCase();
      if (pq.isEmpty) return false;
      return p.name.toLowerCase().contains(pq) ||
          (p.sku?.toLowerCase().contains(pq) ?? false) ||
          (p.barcode != null && p.barcode!.toLowerCase().contains(pq));
    }).take(6).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Returns & Invoices'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: _isDirectReturnMode ? Colors.green : null,
            ),
            onPressed: _startDirectReturnMode,
            tooltip: '+ Direct Return Invoice',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSalesAndCustomers,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth >= 900;

                Widget leftInvoicesPanel = Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prominent Direct New Return Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                            label: Text(
                              _isDirectReturnMode ? 'Direct Mode Active' : '+ Direct New Return',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDirectReturnMode
                                  ? Colors.green.shade700
                                  : theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _startDirectReturnMode,
                          ),
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'Or Return from Past Bill:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search bill #...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildInvoicesListView(filteredSales, theme),
                        ),
                      ],
                    ),
                  ),
                );

                Widget rightWorkspacePanel = Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Header
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isDirectReturnMode
                                ? Colors.green.shade50
                                : theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isDirectReturnMode
                                  ? Colors.green.shade400
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 450),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isDirectReturnMode
                                          ? '➕ Direct New Return Invoice'
                                          : (_selectedSale != null
                                              ? 'Original Bill: ${_selectedSale!.invoiceNumber}'
                                              : 'No Bill Selected'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _isDirectReturnMode
                                            ? Colors.green.shade900
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isDirectReturnMode
                                          ? 'Add products directly from inventory below'
                                          : (_selectedSale != null
                                              ? 'Customer: ${_selectedCustomer?.name ?? 'Walk-in Customer'} • ${_selectedSale!.timestamp.toString().substring(0, 10)}'
                                              : 'Select a bill from the left or click Direct Return'),
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isDirectReturnMode && _selectedSale != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Original Total: Rs. ${_selectedSale!.total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      'Payment: ${_selectedSale!.paymentMethod}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_isDirectReturnMode) ...[
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<CustomerModel?>(
                                  value: _selectedCustomer,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer (Optional)',
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<CustomerModel?>(
                                      value: null,
                                      child: Text('Walk-in Customer'),
                                    ),
                                    ..._allCustomers.map(
                                      (c) => DropdownMenuItem<CustomerModel?>(
                                        value: c,
                                        child: Text('${c.name} (${c.phone})'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (cust) {
                                    setState(() {
                                      _selectedCustomer = cust;
                                      if (cust != null) {
                                        _refundMethod =
                                            'Credit (Khata Adjustment)';
                                      }
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _productSearchCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Search Product to Return...',
                                    hintText: 'Name, SKU or Barcode',
                                    prefixIcon: Icon(Icons.search_rounded),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          if (filteredProducts.isNotEmpty &&
                              _productSearchCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 140),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredProducts.length,
                                itemBuilder: (ctx, idx) {
                                  final prod = filteredProducts[idx];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      prod.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Stock: ${prod.stock} • Price: Rs. ${prod.retailPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Colors.green,
                                    ),
                                    onTap: () => _addDirectProductToReturn(prod),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],

                        const Text(
                          'Returned Items List:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Professional Data Table / List Container for Returned Items
                        Expanded(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Clean Data Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.35),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'ITEM NAME',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'PRICE',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            'RETURN QTY',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 44),
                                    ],
                                  ),
                                ),

                                // Clean Data Table Content List
                                Expanded(
                                  child: _isDirectReturnMode
                                      ? (_directReturnItems.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Search and click products above to add to Return Invoice.',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount:
                                                  _directReturnItems.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(
                                                height: 1,
                                                color: Color(0xFFEEEEEE),
                                              ),
                                              itemBuilder: (context, idx) {
                                                final item =
                                                    _directReturnItems[idx];
                                                final name =
                                                    item['name']?.toString() ??
                                                        'Item';
                                                final unitPrice =
                                                    (item['unitPrice'] as num?)
                                                            ?.toDouble() ??
                                                        0.0;
                                                final retQty =
                                                    (item['quantity'] as num?)
                                                            ?.toDouble() ??
                                                        1.0;
                                                final total = unitPrice * retQty;

                                                return _buildReturnItemTableRow(
                                                  idx: idx,
                                                  name: name,
                                                  unitPrice: unitPrice,
                                                  retQty: retQty,
                                                  total: total,
                                                  origQty: 0.0,
                                                  isChecked: true,
                                                  isDirectMode: true,
                                                  theme: theme,
                                                );
                                              },
                                            ))
                                      : (_selectedSale == null
                                          ? const Center(
                                              child: Text(
                                                'Select a past bill from the left or click Direct Return.',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount: _saleItems.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(
                                                height: 1,
                                                color: Color(0xFFEEEEEE),
                                              ),
                                              itemBuilder: (context, idx) {
                                                final item = _saleItems[idx];
                                                final name =
                                                    item['name']?.toString() ??
                                                        'Product';
                                                final origQty =
                                                    (item['quantity'] as num?)
                                                            ?.toDouble() ??
                                                        1.0;
                                                final unitPrice =
                                                    (item['unitPrice'] as num?)
                                                            ?.toDouble() ??
                                                        0.0;
                                                final isChecked =
                                                    _selectedItemMap[idx] ??
                                                        false;
                                                final retQty =
                                                    _returnQtyMap[idx] ?? origQty;
                                                final total = unitPrice * retQty;

                                                return _buildReturnItemTableRow(
                                                  idx: idx,
                                                  name: name,
                                                  unitPrice: unitPrice,
                                                  retQty: retQty,
                                                  total: total,
                                                  origQty: origQty,
                                                  isChecked: isChecked,
                                                  isDirectMode: false,
                                                  theme: theme,
                                                );
                                              },
                                            )),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // High-Contrast Professional Summary & Net Refund Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<String>(
                                      value: _refundMethod,
                                      decoration: const InputDecoration(
                                        labelText: 'Refund Method',
                                        isDense: true,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                      items: [
                                        'Cash',
                                        'Credit (Khata Adjustment)',
                                      ]
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m,
                                              child: Text(m),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _refundMethod = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _deductionCtrl,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Deduction',
                                        suffixText: '%',
                                        isDense: true,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                      onChanged: (val) {
                                        final d = double.tryParse(val) ?? 0.0;
                                        setState(() {
                                          _deductionPercentage = d < 0
                                              ? 0.0
                                              : (d > 100 ? 100.0 : d);
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: TextField(
                                      controller: _reasonCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Reason (Optional)',
                                        isDense: true,
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD92525),
                                      Color(0xFFB91C1C),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_deductionPercentage > 0) ...[
                                      Text(
                                        'Gross: Rs. ${_grossReturnTotal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                      Text(
                                        'Deduction (${_deductionPercentage.toStringAsFixed(0)}%): -Rs. ${_deductionAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.yellowAccent,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    const Text(
                                      'NET REFUND',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Rs. ${_netRefundAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.assignment_return_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                              _isProcessing
                                  ? 'Generating Return Invoice...'
                                  : 'Generate Return Invoice & Restock Inventory',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD92525),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isProcessing ? null : _processReturn,
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (isWideScreen) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 320,
                          child: leftInvoicesPanel,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: rightWorkspacePanel),
                      ],
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        SizedBox(height: 350, child: leftInvoicesPanel),
                        const SizedBox(height: 12),
                        rightWorkspacePanel,
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }

  Widget _buildReturnItemTableRow({
    required int idx,
    required String name,
    required double unitPrice,
    required double retQty,
    required double total,
    required double origQty,
    required bool isChecked,
    required bool isDirectMode,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: isChecked
          ? (idx % 2 == 0 ? Colors.white : Colors.grey.shade50)
          : Colors.grey.shade100,
      child: Row(
        children: [
          // Checkbox for past bill mode
          if (!isDirectMode)
            Checkbox(
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  _selectedItemMap[idx] = val ?? false;
                });
              },
            ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isChecked ? Colors.black87 : Colors.grey,
                  ),
                ),
                if (!isDirectMode && origQty > 0)
                  Text(
                    'Sold Qty: ${origQty.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Rs. ${unitPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: isChecked ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: isChecked
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (retQty > 1) {
                            setState(() {
                              if (isDirectMode) {
                                _directReturnItems[idx]['quantity'] = retQty - 1;
                                _directReturnItems[idx]['subtotal'] =
                                    (retQty - 1) * unitPrice;
                              } else {
                                _returnQtyMap[idx] = retQty - 1;
                              }
                            });
                          } else if (isDirectMode) {
                            setState(() {
                              _directReturnItems.removeAt(idx);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      // Editable Chip on Tap
                      InkWell(
                        onTap: () => _showEditQtyDialog(
                          index: idx,
                          currentQty: retQty,
                          maxQty: isDirectMode ? 0.0 : origQty,
                          isDirectMode: isDirectMode,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            retQty.toStringAsFixed(0),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: Colors.green,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (isDirectMode || retQty < origQty) {
                            setState(() {
                              if (isDirectMode) {
                                _directReturnItems[idx]['quantity'] = retQty + 1;
                                _directReturnItems[idx]['subtotal'] =
                                    (retQty + 1) * unitPrice;
                              } else {
                                _returnQtyMap[idx] = retQty + 1;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      '-',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Rs. ${isChecked ? total.toStringAsFixed(0) : "0"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isChecked ? Colors.green.shade800 : Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: isDirectMode
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _directReturnItems.removeAt(idx);
                      });
                    },
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesListView(
    List<SaleModel> filteredSales,
    ThemeData theme,
  ) {
    if (filteredSales.isEmpty) {
      return const Center(child: Text('No sales invoices found.'));
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: filteredSales.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = filteredSales[index];
        final isSelected =
            !_isDirectReturnMode && _selectedSale?.saleId == s.saleId;
        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor:
              theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          title: Text(
            s.invoiceNumber,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            '${s.timestamp.toString().substring(0, 10)} • Rs. ${s.total.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 18,
          ),
          onTap: () => _selectInvoice(s),
        );
      },
    );
  }
}
