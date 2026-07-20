import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/customer_model.dart';
import '../viewmodels/pos_controller.dart';
import '../../products/viewmodels/inventory_controller.dart';

class POSView extends ConsumerStatefulWidget {
  const POSView({super.key});

  @override
  ConsumerState<POSView> createState() => _POSViewState();
}

class _POSViewState extends ConsumerState<POSView> {
  final FocusNode _barcodeFocusNode = FocusNode();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _cartCustomerNameCtrl = TextEditingController();
  final TextEditingController _cartCustomerPhoneCtrl = TextEditingController();
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _productSearchQuery = _searchCtrl.text.toLowerCase();
      });
    });
    // Request focus for barcode scanning on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeFocusNode.dispose();
    _barcodeCtrl.dispose();
    _searchCtrl.dispose();
    _cartCustomerNameCtrl.dispose();
    _cartCustomerPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout(bool printReceipt) async {
    try {
      await ref
          .read(posControllerProvider.notifier)
          .checkout(
            context,
            printReceipt: printReceipt,
            customerName: _cartCustomerNameCtrl.text.trim().isNotEmpty
                ? _cartCustomerNameCtrl.text.trim()
                : null,
            customerPhone: _cartCustomerPhoneCtrl.text.trim().isNotEmpty
                ? _cartCustomerPhoneCtrl.text.trim()
                : null,
          );
      if (context.mounted) {
        _cartCustomerNameCtrl.clear();
        _cartCustomerPhoneCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printReceipt
                  ? 'Bill printed & saved successfully!'
                  : 'Bill saved successfully!',
            ),
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
    _barcodeFocusNode.requestFocus();
  }

  void _handleBarcodeSubmit(String value) {
    if (value.trim().isNotEmpty) {
      ref.read(posControllerProvider.notifier).scanAndAddBarcode(value.trim());
      _barcodeCtrl.clear();
    }
    _barcodeFocusNode.requestFocus();
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Salesman'),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addrCtrl,
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
                  await ref
                      .read(posControllerProvider.notifier)
                      .addNewCustomer(
                        nameCtrl.text.trim(),
                        phoneCtrl.text.trim(),
                        addrCtrl.text.trim(),
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save Customer'),
            ),
          ],
        );
      },
    );
  }

  void _showManualItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'Pcs');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Manual Item'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name*'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Price per Unit*',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Quantity*',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unit (e.g. Kg, Pcs)',
                        ),
                      ),
                    ),
                  ],
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  ref
                      .read(posControllerProvider.notifier)
                      .addManualItem(
                        name: nameCtrl.text.trim(),
                        price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                        quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                        unit: unitCtrl.text.trim().isNotEmpty
                            ? unitCtrl.text.trim()
                            : 'Pcs',
                      );
                  Navigator.pop(context);
                  _barcodeFocusNode.requestFocus();
                }
              },
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateQuantityDialog(String productId, double currentQty) {
    final qtyText = currentQty.truncateToDouble() == currentQty
        ? currentQty.toStringAsFixed(0)
        : currentQty.toStringAsFixed(2);
    final qtyCtrl = TextEditingController(text: qtyText);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Quantity'),
          content: TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New Quantity'),
            onSubmitted: (val) {
              final newQty = double.tryParse(val) ?? currentQty;
              ref
                  .read(posControllerProvider.notifier)
                  .updateQuantity(productId, newQty);
              Navigator.pop(context);
              _barcodeFocusNode.requestFocus();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newQty = double.tryParse(qtyCtrl.text) ?? currentQty;
                ref
                    .read(posControllerProvider.notifier)
                    .updateQuantity(productId, newQty);
                Navigator.pop(context);
                _barcodeFocusNode.requestFocus();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posControllerProvider);
    final invState = ref.watch(inventoryControllerProvider);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final isWide = MediaQuery.of(context).size.width >= 800;

    // Filter product catalog for quick click selection
    final catalog = invState.products.where((p) {
      final q = _productSearchQuery;
      return p.name.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false) ||
          (p.sku?.toLowerCase().contains(q) ?? false);
    }).toList();

    final catalogPanel = Column(
      children: [
        // Quick Catalog Search
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search catalog by name, sku, or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: theme.colorScheme.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Grid of items
        Expanded(
          child: catalog.isEmpty
              ? const Center(child: Text('No products in catalog.'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 130)
                        .floor()
                        .clamp(2, 6);
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: catalog.length,
                      itemBuilder: (context, index) {
                        final p = catalog[index];
                        final outOfStock = p.stock <= 0;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: outOfStock
                                ? null
                                : () {
                                    ref
                                        .read(posControllerProvider.notifier)
                                        .addToCart(p);
                                    _barcodeFocusNode.requestFocus();
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child:
                                          p.imagePath != null &&
                                              p.imagePath!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                p.imagePath!,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Icon(
                                                      Icons.inventory_2,
                                                      size: 40,
                                                      color: outOfStock
                                                          ? Colors.grey
                                                          : theme
                                                                .colorScheme
                                                                .primary,
                                                    ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.inventory_2,
                                              size: 40,
                                              color: outOfStock
                                                  ? Colors.grey
                                                  : theme.colorScheme.primary,
                                            ),
                                    ),
                                  ),
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: outOfStock ? Colors.grey : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${invState.categories.where((c) => c.categoryId == p.categoryId).firstOrNull?.name ?? '-'} | ${invState.brands.where((b) => b.brandId == p.brandId).firstOrNull?.name ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${p.retailPrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stock: ${p.stock} ${p.unit}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: outOfStock
                                          ? Colors.red
                                          : (p.stock <= p.minimumStock
                                                ? Colors.orange
                                                : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );

    final cartPanel = Container(
      width: isWide ? (isDesktop ? 400 : 320) : double.infinity,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        color: theme.colorScheme.surface,
      ),
      child: CustomScrollView(
        slivers: [
          // Cart Header & Customer Inputs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cart Items (${posState.cart.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 16,
                            ),
                            label: const Text('Manual Item'),
                            onPressed: _showManualItemDialog,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Clear Cart',
                            onPressed: () {
                              ref
                                  .read(posControllerProvider.notifier)
                                  .clearCart();
                              _cartCustomerNameCtrl.clear();
                              _cartCustomerPhoneCtrl.clear();
                              _barcodeFocusNode.requestFocus();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cartCustomerNameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Customer Name',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cartCustomerPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Phone',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          // Cart Items List
          if (posState.cart.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('Cart is empty. Add products.')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = posState.cart[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${invState.categories.where((c) => c.categoryId == item.product.categoryId).firstOrNull?.name ?? '-'} | ${invState.brands.where((b) => b.brandId == item.product.brandId).firstOrNull?.name ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${item.product.retailPrice.toStringAsFixed(0)} each',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ref
                                    .read(posControllerProvider.notifier)
                                    .removeFromCart(item.product.productId);
                                _barcodeFocusNode.requestFocus();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rs. ${(item.quantity * item.product.retailPrice).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 22,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    ref
                                        .read(posControllerProvider.notifier)
                                        .updateQuantity(
                                          item.product.productId,
                                          item.quantity - 1,
                                        );
                                    _barcodeFocusNode.requestFocus();
                                  },
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showUpdateQuantityDialog(
                                    item.product.productId,
                                    item.quantity,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                    ),
                                    child: Text(
                                      item.quantity.truncateToDouble() ==
                                              item.quantity
                                          ? item.quantity.toStringAsFixed(0)
                                          : item.quantity.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 22,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    ref
                                        .read(posControllerProvider.notifier)
                                        .updateQuantity(
                                          item.product.productId,
                                          item.quantity + 1,
                                        );
                                    _barcodeFocusNode.requestFocus();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: posState.cart.length),
            ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          // Customer & Discount section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<CustomerModel?>(
                          initialValue: posState.selectedCustomer,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select Salesman',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          items: [
                            const DropdownMenuItem<CustomerModel?>(
                              value: null,
                              child: Text('Walk-in Customer'),
                            ),
                            ...posState.customers.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text('${c.name} (${c.phone ?? "-"})'),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            ref
                                .read(posControllerProvider.notifier)
                                .selectCustomer(val);
                            _barcodeFocusNode.requestFocus();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        onPressed: _showAddCustomerDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: posState.paymentMethod,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          items:
                              [
                                    'Cash',
                                    'Card',
                                    'Mobile Payment',
                                    'Credit (Khata)',
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
                              ref
                                  .read(posControllerProvider.notifier)
                                  .setPaymentMethod(val);
                            }
                            _barcodeFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Flat Discount (Rs.)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            ref
                                .read(posControllerProvider.notifier)
                                .setFlatDiscount(double.tryParse(val) ?? 0.0);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: '% Discount',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            ref
                                .read(posControllerProvider.notifier)
                                .setPercentageDiscount(
                                  double.tryParse(val) ?? 0.0,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Received Amount (Rs.)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final p = double.tryParse(val) ?? 0.0;
                            ref
                                .read(posControllerProvider.notifier)
                                .setPaidAmount(p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending:',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                'Rs. ${posState.changeAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Cart Totals and Save Button
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text('Rs. ${posState.subtotal.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Discount:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '- Rs. ${posState.totalDiscount.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Bill Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Rs. ${posState.grandTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded),
                          label: const Text(
                            'Save Bill',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: posState.cart.isEmpty
                              ? null
                              : () => _handleCheckout(false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print_rounded),
                          label: const Text(
                            'Print Bill',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: posState.cart.isEmpty
                              ? null
                              : () => _handleCheckout(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales POS Cashier'),
        actions: [
          // Barcode Scan field in App Bar for easy access
          Container(
            width: isWide ? 250 : 130,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: _barcodeCtrl,
              focusNode: _barcodeFocusNode,
              onSubmitted: _handleBarcodeSubmit,
              decoration: InputDecoration(
                hintText: 'Scan...',
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 6, child: catalogPanel),
                Container(
                  width: isDesktop ? 400 : 320,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: cartPanel,
                ),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: theme.colorScheme.primary,
                    tabs: [
                      const Tab(
                        text: 'Catalog',
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      Tab(
                        text: 'Cart (${posState.cart.length})',
                        icon: const Icon(Icons.shopping_cart_outlined),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [catalogPanel, cartPanel]),
                  ),
                ],
              ),
            ),
    );
  }
}
