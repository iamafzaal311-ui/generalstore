import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../viewmodels/accounts_controller.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/sale_model.dart';

class CustomerAccountsView extends ConsumerStatefulWidget {
  const CustomerAccountsView({super.key});

  @override
  ConsumerState<CustomerAccountsView> createState() =>
      _CustomerAccountsViewState();
}

class _CustomerAccountsViewState extends ConsumerState<CustomerAccountsView> {
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
          title: Text('Receive Payment from $name'),
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
                      .receiveCustomerPayment(personId, amt);
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

  void _showCustomerDetails(
    CustomerModel customer,
    List<SaleModel> allSales,
  ) {
    final customerSales = allSales
        .where((s) => s.customerId == customer.customerId)
        .toList();
    customerSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
                    '${customer.name} - Sales History',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Pending Balance: Rs. ${customer.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Expanded(
                    child: customerSales.isEmpty
                        ? const Center(child: Text('No sales bills found.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: customerSales.length,
                            itemBuilder: (context, index) {
                              final s = customerSales[index];
                              final pending = s.total - s.paidAmount;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(
                                    'Bill #${s.invoiceNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Date: ${DateFormat('dd-MM-yyyy HH:mm').format(s.timestamp)}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Total: Rs. ${s.total.toStringAsFixed(0)}',
                                      ),
                                      Text(
                                        'Paid: Rs. ${s.paidAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'Pending: Rs. ${pending.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
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
      appBar: AppBar(title: const Text('Customer Khata (Accounts)')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(child: _buildCustomerLedger(state)),
              ],
            ),
    );
  }

  Widget _buildCustomerLedger(AccountsState state) {
    final filtered = state.customers
        .where((c) => c.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No customers found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cust = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            onTap: () => _showCustomerDetails(cust, state.sales),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cust.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Due Balance:',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            'Rs. ${cust.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cust.balance > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phone: ${cust.phone ?? "-"} | Address: ${cust.address ?? "-"}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view bill history',
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showRecordPaymentDialog(cust.customerId, cust.name),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Receive Payment'),
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
