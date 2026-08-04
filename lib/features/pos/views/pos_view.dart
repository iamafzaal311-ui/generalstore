import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/customer_model.dart';
import '../../../core/utils/print_helper.dart';
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
    // Request focus for barcode scanning and refresh customers list on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
      ref.read(posControllerProvider.notifier).refreshCustomers();
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

  Future<void> _handleCheckout(bool printReceipt, [AppPaperSize? paperSize]) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(posControllerProvider.notifier)
          .checkout(
            context,
            printReceipt: printReceipt,
            paperSize: paperSize,
            customerName: _cartCustomerNameCtrl.text.trim().isNotEmpty
                ? _cartCustomerNameCtrl.text.trim()
                : null,
            customerPhone: _cartCustomerPhoneCtrl.text.trim().isNotEmpty
                ? _cartCustomerPhoneCtrl.text.trim()
                : null,
          );
      if (mounted) {
        _cartCustomerNameCtrl.clear();
        _cartCustomerPhoneCtrl.clear();
        messenger.showSnackBar(
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
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) _barcodeFocusNode.requestFocus();
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
    String accountType = 'Customer'; // 'Customer' or 'Salesman'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add Khata Account / Salesman'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Customer'),
                            selected: accountType == 'Customer',
                            onSelected: (sel) {
                              if (sel) setDlgState(() => accountType = 'Customer');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Salesman'),
                            selected: accountType == 'Salesman',
                            onSelected: (sel) {
                              if (sel) setDlgState(() => accountType = 'Salesman');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: accountType == 'Salesman' ? 'Salesman Name*' : 'Customer Name*',
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
                      decoration: const InputDecoration(labelText: 'Address / Dues Dtl'),
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
                      final finalName = accountType == 'Salesman'
                          ? (nameCtrl.text.trim().startsWith('[Salesman]')
                              ? nameCtrl.text.trim()
                              : '[Salesman] ${nameCtrl.text.trim()}')
                          : nameCtrl.text.trim();
                      await ref
                          .read(posControllerProvider.notifier)
                          .addNewCustomer(
                            finalName,
                            phoneCtrl.text.trim(),
                            addrCtrl.text.trim(),
                          );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: Text('Save $accountType'),
                ),
              ],
            );
          },
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
    final cartList = ref.read(posControllerProvider).cart;
    final itemIndex = cartList.indexWhere((i) => i.product.productId == productId);
    final item = itemIndex >= 0 ? cartList[itemIndex] : null;
    final maxStock = item?.product.stock ?? 999999.0;
    final unit = item?.product.unit ?? '';

    final qtyText = currentQty.truncateToDouble() == currentQty
        ? currentQty.toStringAsFixed(0)
        : currentQty.toStringAsFixed(2);
    final qtyCtrl = TextEditingController(text: qtyText);
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final formattedStock = maxStock.truncateToDouble() == maxStock
                ? maxStock.toStringAsFixed(0)
                : maxStock.toStringAsFixed(2);
            return AlertDialog(
              title: const Text('Update Quantity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'New Quantity',
                      helperText: 'Max available stock: $formattedStock $unit',
                      errorText: dialogError,
                    ),
                    onChanged: (val) {
                      final n = double.tryParse(val);
                      if (n != null && n > maxStock) {
                        setDialogState(() {
                          dialogError = 'Cannot exceed stock limit ($formattedStock $unit)';
                        });
                      } else {
                        if (dialogError != null) {
                          setDialogState(() {
                            dialogError = null;
                          });
                        }
                      }
                    },
                    onSubmitted: (val) {
                      final newQty = double.tryParse(val) ?? currentQty;
                      if (newQty > maxStock) {
                        setDialogState(() {
                          dialogError = 'Cannot exceed stock limit ($formattedStock $unit)';
                        });
                        return;
                      }
                      ref
                          .read(posControllerProvider.notifier)
                          .updateQuantity(productId, newQty);
                      Navigator.pop(context);
                      _barcodeFocusNode.requestFocus();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newQty = double.tryParse(qtyCtrl.text) ?? currentQty;
                    if (newQty > maxStock) {
                      setDialogState(() {
                        dialogError = 'Cannot exceed stock limit ($formattedStock $unit)';
                      });
                      return;
                    }
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
      },
    );
  }

  void _showUpdateUnitPriceDialog(String productId, double currentPrice) {
    final priceText = currentPrice.truncateToDouble() == currentPrice
        ? currentPrice.toStringAsFixed(0)
        : currentPrice.toStringAsFixed(2);
    final priceCtrl = TextEditingController(text: priceText);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Unit Price'),
          content: TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New Price per Unit',
              prefixText: 'Rs. ',
            ),
            onSubmitted: (val) {
              final newPrice = double.tryParse(val);
              if (newPrice != null && newPrice >= 0) {
                ref
                    .read(posControllerProvider.notifier)
                    .updateUnitPrice(productId, newPrice);
              }
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
                final newPrice = double.tryParse(priceCtrl.text);
                if (newPrice != null && newPrice >= 0) {
                  ref
                      .read(posControllerProvider.notifier)
                      .updateUnitPrice(productId, newPrice);
                }
                Navigator.pop(context);
                _barcodeFocusNode.requestFocus();
              },
              child: const Text('Update Price'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateItemDiscountDialog(
    String productId,
    double currentFlatDisc,
    double currentPctDisc,
  ) {
    final pctCtrl = TextEditingController(
      text: currentPctDisc > 0
          ? (currentPctDisc.truncateToDouble() == currentPctDisc
              ? currentPctDisc.toStringAsFixed(0)
              : currentPctDisc.toStringAsFixed(2))
          : '',
    );
    final flatCtrl = TextEditingController(
      text: currentFlatDisc > 0
          ? (currentFlatDisc.truncateToDouble() == currentFlatDisc
              ? currentFlatDisc.toStringAsFixed(0)
              : currentFlatDisc.toStringAsFixed(2))
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Single Item Discount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pctCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Discount (%)',
                  suffixText: '%',
                  hintText: 'e.g. 5 or 10',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: flatCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Flat Discount (Rs.)',
                  prefixText: 'Rs. ',
                  hintText: 'e.g. 20',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final pct = double.tryParse(pctCtrl.text) ?? 0.0;
                final flat = double.tryParse(flatCtrl.text) ?? 0.0;
                ref
                    .read(posControllerProvider.notifier)
                    .updateItemDiscount(
                      productId,
                      discountRs: flat,
                      discountPercentage: pct,
                    );
                Navigator.pop(context);
              },
              child: const Text('Apply Discount'),
            ),
          ],
        );
      },
    );
  }

  void _showCheckoutPreviewDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        AppPaperSize selectedPaper = PrintHelper.getDefaultPaperSize();
        bool setAsDefaultPaperSize = PrintHelper.isRememberChoiceEnabled();

        return Consumer(
          builder: (context, ref, child) {
            final posState = ref.watch(posControllerProvider);
            final theme = Theme.of(context);
            final cName = _cartCustomerNameCtrl.text.trim().isNotEmpty
                ? _cartCustomerNameCtrl.text.trim()
                : (posState.selectedCustomer?.name ?? 'Walk-in Customer');
            final cPhone = _cartCustomerPhoneCtrl.text.trim().isNotEmpty
                ? _cartCustomerPhoneCtrl.text.trim()
                : (posState.selectedCustomer?.phone ?? '');
            final isKhata = posState.selectedCustomer != null;

            return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: 650,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.92,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fixed Header
                        Row(
                          children: [
                            Icon(
                              Icons.point_of_sale_rounded,
                              color: theme.colorScheme.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Bill Checkout & Sale Preview',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Customer Details Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isKhata
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isKhata
                                  ? Colors.orange.withValues(alpha: 0.3)
                                  : Colors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isKhata
                                        ? Icons.account_balance_wallet_rounded
                                        : Icons.person_rounded,
                                    size: 16,
                                    color: isKhata
                                        ? Colors.orange.shade800
                                        : Colors.blue.shade800,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Customer: $cName ${cPhone.isNotEmpty ? "($cPhone)" : ""}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isKhata
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isKhata ? 'Khata Customer' : 'Walk-in Customer',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Scrollable Items List Container (Only items scroll if cart is large)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: ListView.separated(
                              itemCount: posState.cart.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 4, endIndent: 4),
                              itemBuilder: (context, index) {
                                final item = posState.cart[index];
                                final isManual =
                                    item.product.productId.startsWith('MANUAL-');
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isManual
                                        ? const Color(0xFFFAF5FF)
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isManual
                                          ? const Color(0xFFD8B4FE)
                                          : theme.colorScheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                      width: isManual ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Row(
                                          children: [
                                            if (isManual) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF9333EA),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'MANUAL',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            Expanded(
                                              child: Text(
                                                item.product.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                  color: isManual
                                                      ? const Color(0xFF581C87)
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Clickable Qty in Preview (Highlighted)
                                      InkWell(
                                        onTap: () => _showUpdateQuantityDialog(
                                          item.product.productId,
                                          item.quantity,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.amber.shade700,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Text(
                                            '${item.quantity.truncateToDouble() == item.quantity ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)} x',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Clickable Price in Preview (Highlighted)
                                      InkWell(
                                        onTap: () => _showUpdateUnitPriceDialog(
                                          item.product.productId,
                                          item.unitPrice,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF0284C7),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Rs. ${item.unitPrice.truncateToDouble() == item.unitPrice ? item.unitPrice.toStringAsFixed(0) : item.unitPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0369A1),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.edit_rounded,
                                                size: 11,
                                                color: Color(0xFF0369A1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Clickable Single Item Discount Button (Highlighted)
                                      InkWell(
                                        onTap: () => _showUpdateItemDiscountDialog(
                                          item.product.productId,
                                          item.discount,
                                          item.discountPercentage,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: item.itemDiscountAmount > 0
                                                ? Colors.green.shade100
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: item.itemDiscountAmount > 0
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade400,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.local_offer_rounded,
                                                size: 12,
                                                color: item.itemDiscountAmount > 0
                                                    ? Colors.green.shade800
                                                    : Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.itemDiscountAmount > 0
                                                    ? (item.discountPercentage > 0
                                                        ? '-${item.discountPercentage.truncateToDouble() == item.discountPercentage ? item.discountPercentage.toStringAsFixed(0) : item.discountPercentage.toStringAsFixed(1)}%'
                                                        : '-Rs.${item.discount.toStringAsFixed(0)}')
                                                    : '% Disc',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: item.itemDiscountAmount > 0
                                                      ? Colors.green.shade900
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '= Rs. ${item.total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Fixed Subtotal & Discounts Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs. ${posState.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Discount Inputs (% and Flat)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: posState.discount > 0
                                    ? posState.discount.toString()
                                    : '',
                                decoration: const InputDecoration(
                                  labelText: 'Flat Discount (Rs.)',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  ref
                                      .read(posControllerProvider.notifier)
                                      .setFlatDiscount(
                                        double.tryParse(val) ?? 0.0,
                                      );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: posState.discountPercentage > 0
                                    ? posState.discountPercentage.toString()
                                    : '',
                                decoration: const InputDecoration(
                                  labelText: 'Overall Discount (%)',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
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
                        const SizedBox(height: 10),

                        // FINAL GRAND TOTAL Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E56B4),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade900.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'FINAL GRAND TOTAL:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Rs. ${posState.grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Payment Method & Received Amount
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: posState.paymentMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Method',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                items: [
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
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: posState.paidAmount > 0
                                    ? posState.paidAmount.toString()
                                    : '',
                                decoration: const InputDecoration(
                                  labelText: 'Received Amount (Rs.)',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  ref
                                      .read(posControllerProvider.notifier)
                                      .setPaidAmount(
                                        double.tryParse(val) ?? 0.0,
                                      );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Prominent Exact Paid Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: Text(
                              'Exact Paid (Rs. ${posState.grandTotal.toStringAsFixed(0)})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 1,
                            ),
                            onPressed: () {
                              ref
                                  .read(posControllerProvider.notifier)
                                  .setPaidAmount(posState.grandTotal);
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Change / Pending Dues Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              posState.paidAmount >= posState.grandTotal
                                  ? 'Change to Return:'
                                  : 'Current Bill Pending (Due):',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: posState.paidAmount >= posState.grandTotal
                                    ? Colors.green.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                            Text(
                              'Rs. ${posState.paidAmount >= posState.grandTotal ? posState.changeAmount.toStringAsFixed(0) : (posState.grandTotal - posState.paidAmount).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: posState.paidAmount >= posState.grandTotal
                                    ? Colors.green.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Print Paper Size & Default Checkbox Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.print_rounded, size: 18, color: Colors.indigo.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Print Size:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<AppPaperSize>(
                                      value: selectedPaper,
                                      isDense: true,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        border: OutlineInputBorder(),
                                      ),
                                      style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                                      items: AppPaperSize.values.map((paper) {
                                        return DropdownMenuItem<AppPaperSize>(
                                          value: paper,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                paper.icon,
                                                size: 16,
                                                color: paper.isThermal ? Colors.orange.shade800 : Colors.blue.shade800,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(paper.name),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => selectedPaper = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Checkbox(
                                    value: setAsDefaultPaperSize,
                                    visualDensity: VisualDensity.compact,
                                    activeColor: Colors.indigo.shade700,
                                    onChanged: (val) {
                                      setState(() => setAsDefaultPaperSize = val ?? false);
                                    },
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => setAsDefaultPaperSize = !setAsDefaultPaperSize);
                                    },
                                    child: const Text(
                                      'Set print size as default',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons (Highlighted & Prominent)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text(
                                'Edit Bill',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save_rounded, size: 16),
                              label: const Text(
                                'Save Only',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _handleCheckout(false);
                              },
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text(
                                'Save & Print Bill Receipt',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD92525),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                if (setAsDefaultPaperSize) {
                                  await PrintHelper.setDefaultPaperSize(selectedPaper);
                                  await PrintHelper.setRememberChoice(true);
                                } else {
                                  await PrintHelper.setRememberChoice(false);
                                }
                                await _handleCheckout(true, selectedPaper);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<POSState>(posControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next.errorMessage!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(posControllerProvider.notifier).clearError();
      }
    });

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
      width: isWide ? (isDesktop ? 410 : 330) : double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 1. TOP FIXED HEADER: Order Info & Customer Selection
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Current Order',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${posState.cart.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'Manual Item',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: _showManualItemDialog,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Clear Cart',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: posState.cart.isEmpty
                              ? null
                              : () {
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
                const SizedBox(height: 10),

                // Customer Selection Dropdown
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CustomerModel?>(
                        initialValue: posState.selectedCustomer,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Select Customer / Khata',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        items: [
                          const DropdownMenuItem<CustomerModel?>(
                            value: null,
                            child: Text('Walk-in Customer (Cash)'),
                          ),
                          ...posState.customers.map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.name} (${c.phone ?? "No Phone"})${c.balance > 0 ? " | Khata: Rs. ${c.balance.toStringAsFixed(0)}" : ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          ref
                              .read(posControllerProvider.notifier)
                              .selectCustomer(val);
                          if (val != null) {
                            _cartCustomerNameCtrl.text = val.name;
                            _cartCustomerPhoneCtrl.text = val.phone ?? '';
                          } else {
                            _cartCustomerNameCtrl.clear();
                            _cartCustomerPhoneCtrl.clear();
                          }
                          _barcodeFocusNode.requestFocus();
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      tooltip: 'Add Customer',
                      onPressed: _showAddCustomerDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Name, Phone & Khata Tag Row at TOP
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _cartCustomerNameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Customer Name',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _cartCustomerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Phone',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Customer Type Tag (Walk-in vs Khata) at TOP
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: posState.selectedCustomer == null
                            ? Colors.blue.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: posState.selectedCustomer == null
                              ? Colors.blue.shade400
                              : Colors.orange.shade400,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        posState.selectedCustomer == null ? 'Walk-in' : 'Khata',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: posState.selectedCustomer == null
                              ? Colors.blue.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. MIDDLE SCROLLABLE CART ITEMS LIST
          Expanded(
            child: posState.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove_shopping_cart_outlined,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cart is empty',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan barcode or tap products to add',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Line Items Header Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'PRODUCT NAME',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'PRICE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'QTY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'TOTAL',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 26),
                          ],
                        ),
                      ),
                      // Items ListView
                      Expanded(
                        child: ListView.separated(
                          itemCount: posState.cart.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: 12, endIndent: 12),
                          itemBuilder: (context, index) {
                            final item = posState.cart[index];
                            return Container(
                              color: theme.colorScheme.surface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  // Product Name
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Price Box (Editable)
                                  Expanded(
                                    flex: 3,
                                    child: InkWell(
                                      onTap: () => _showUpdateUnitPriceDialog(
                                        item.product.productId,
                                        item.unitPrice,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Rs.${item.unitPrice.truncateToDouble() == item.unitPrice ? item.unitPrice.toStringAsFixed(0) : item.unitPrice.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(
                                              Icons.edit_note_rounded,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Quantity Counter
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: theme.colorScheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              ref
                                                  .read(
                                                    posControllerProvider
                                                        .notifier,
                                                  )
                                                  .updateQuantity(
                                                    item.product.productId,
                                                    item.quantity - 1,
                                                  );
                                              _barcodeFocusNode.requestFocus();
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(3.0),
                                              child: Icon(
                                                Icons.remove_rounded,
                                                size: 14,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: InkWell(
                                              onTap: () =>
                                                  _showUpdateQuantityDialog(
                                                    item.product.productId,
                                                    item.quantity,
                                                  ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  item.quantity
                                                              .truncateToDouble() ==
                                                          item.quantity
                                                      ? item.quantity
                                                          .toStringAsFixed(0)
                                                      : item.quantity
                                                          .toStringAsFixed(2),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              ref
                                                  .read(
                                                    posControllerProvider
                                                        .notifier,
                                                  )
                                                  .updateQuantity(
                                                    item.product.productId,
                                                    item.quantity + 1,
                                                  );
                                              _barcodeFocusNode.requestFocus();
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(3.0),
                                              child: Icon(
                                                Icons.add_rounded,
                                                size: 14,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Line Total
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Rs. ${item.subtotal.toStringAsFixed(0)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),

                                  // Remove Button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    tooltip: 'Remove',
                                    onPressed: () {
                                      ref
                                          .read(posControllerProvider.notifier)
                                          .removeFromCart(
                                            item.product.productId,
                                          );
                                      _barcodeFocusNode.requestFocus();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // 3. FIXED BOTTOM FOOTER: Always Pinned at Bottom
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal (${posState.cart.length} items):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Rs. ${posState.subtotal.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 20),
                  label: const Text(
                    'Preview & Checkout Bill',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: posState.cart.isEmpty
                      ? null
                      : () => _showCheckoutPreviewDialog(),
                ),
              ],
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
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
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
