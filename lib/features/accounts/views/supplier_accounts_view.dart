import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../viewmodels/accounts_controller.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/purchase_model.dart';

class SupplierAccountsView extends ConsumerStatefulWidget {
  const SupplierAccountsView({super.key});

  @override
  ConsumerState<SupplierAccountsView> createState() =>
      _SupplierAccountsViewState();
}

class _SupplierAccountsViewState extends ConsumerState<SupplierAccountsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(accountsControllerProvider.notifier).refreshAccounts();
      }
    });
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showRecordPaymentDialog(String personId, String name) {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pay to $name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment Amount (Rs.)*',
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || double.tryParse(val) == null
                  ? 'Invalid'
                  : null,
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final amt = double.parse(amountCtrl.text);
                  await ref
                      .read(accountsControllerProvider.notifier)
                      .paySupplier(personId, amt);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        );
      },
    );
  }

  void _showSupplierDetails(
    SupplierModel supplier,
    List<PurchaseModel> allPurchases,
  ) {
    final supplierPurchases = allPurchases
        .where((p) => p.supplierId == supplier.supplierId)
        .toList();
    supplierPurchases.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${supplier.name} - Purchase History',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Pending Balance: Rs. ${supplier.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Expanded(
                    child: supplierPurchases.isEmpty
                        ? const Center(child: Text('No purchase bills found.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: supplierPurchases.length,
                            itemBuilder: (context, index) {
                              final p = supplierPurchases[index];
                              final pending = p.totalAmount - p.paidAmount;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(
                                    'Purchase #${p.purchaseId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat(
                                          'dd MMM yyyy HH:mm',
                                        ).format(p.timestamp),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Text(
                                            'Total: Rs. ${p.totalAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Paid: Rs. ${p.paidAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (pending > 0)
                                            Text(
                                              'Pending: Rs. ${pending.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    pending > 0
                                        ? 'Due:\nRs. ${pending.toStringAsFixed(0)}'
                                        : 'Cleared',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: pending > 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                  onTap: () {
                                    // Navigate to purchase details
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Khata (Purchases)')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search suppliers...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(child: _buildSupplierLedger(state)),
              ],
            ),
    );
  }

  Widget _buildSupplierLedger(AccountsState state) {
    final filtered = state.suppliers
        .where((s) => s.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No suppliers found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final supplier = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            onTap: () => _showSupplierDetails(supplier, state.purchases),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.local_shipping)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          supplier.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'We Owe:',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            'Rs. ${supplier.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: supplier.balance > 0
                                  ? Colors.orange[800]
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact: ${supplier.contactName ?? "-"} | Phone: ${supplier.phone ?? "-"}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view bill history',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRecordPaymentDialog(
                        supplier.supplierId,
                        supplier.name,
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Settle Balance'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
