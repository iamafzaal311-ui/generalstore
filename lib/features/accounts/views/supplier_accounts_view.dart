import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../viewmodels/accounts_controller.dart';
import '../../../data/models/supplier_model.dart';
import 'ledger_detail_view.dart';

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

  void _showSupplierDetails(SupplierModel supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LedgerDetailView(supplier: supplier),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Company Khata (Purchases)')),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierDialog,
        icon: const Icon(Icons.domain_add_rounded),
        label: const Text('Add Company'),
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Company'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Company Name*'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Person'),
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextFormField(
                  controller: balCtrl,
                  decoration: const InputDecoration(labelText: 'Opening Balance (Rs.)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final bal = double.tryParse(balCtrl.text) ?? 0;
                await ref.read(accountsControllerProvider.notifier).addSupplier(
                      nameCtrl.text.trim(),
                      contactCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                      addressCtrl.text.trim(),
                      bal,
                    );
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add Company'),
          ),
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
            onTap: () => _showSupplierDetails(supplier),
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
