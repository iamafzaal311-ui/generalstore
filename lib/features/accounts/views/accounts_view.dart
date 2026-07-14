import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/accounts_controller.dart';

class AccountsView extends ConsumerStatefulWidget {
  const AccountsView({super.key});

  @override
  ConsumerState<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends ConsumerState<AccountsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Utilities';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Record New Expense'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Expense Title*'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount (Rs.)*'),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ['Rent', 'Salaries', 'Utilities', 'Stationery', 'Other']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            category = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await ref.read(accountsControllerProvider.notifier).addExpense(
                            title: titleCtrl.text.trim(),
                            category: category,
                            amount: double.parse(amountCtrl.text),
                            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordPaymentDialog(String personId, String name, bool isCustomer) {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isCustomer ? 'Receive Payment from $name' : 'Pay to $name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Payment Amount (Rs.)*'),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final amt = double.parse(amountCtrl.text);
                  if (isCustomer) {
                    await ref.read(accountsControllerProvider.notifier).receiveCustomerPayment(personId, amt);
                  } else {
                    await ref.read(accountsControllerProvider.notifier).paySupplier(personId, amt);
                  }
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Financial Ledgers'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Cashbook Summary'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Customer Ledgers'),
            Tab(icon: Icon(Icons.local_shipping_rounded), text: 'Supplier Ledgers'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Expenses'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar for Ledgers & Expenses
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search ledger accounts or expenses...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      if (_tabController.index == 3) ...[
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _showAddExpenseDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('New Expense'),
                        ),
                      ]
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCashbookSummary(state),
                      _buildCustomerLedger(state),
                      _buildSupplierLedger(state),
                      _buildExpenses(state),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- CASHBOOK TAB ---
  Widget _buildCashbookSummary(AccountsState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'CASH IN (SALES)',
                  value: state.totalSalesCash,
                  icon: Icons.trending_up_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'CASH OUT (PURCHASES)',
                  value: state.totalPurchasesCash,
                  icon: Icons.trending_down_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'EXPENSES PAID',
                  value: state.totalExpensesCash,
                  icon: Icons.receipt_long_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NET CASH IN HAND',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${state.netCashInHand.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CUSTOMER LEDGER TAB ---
  Widget _buildCustomerLedger(AccountsState state) {
    final filtered = state.customers.where((c) => c.name.toLowerCase().contains(_searchQuery)).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cust = filtered[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Phone: ${cust.phone ?? "-"} | Address: ${cust.address ?? "-"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Due Balance:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      'Rs. ${cust.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cust.balance > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _showRecordPaymentDialog(cust.customerId, cust.name, true),
                  child: const Text('Pay Off'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- SUPPLIER LEDGER TAB ---
  Widget _buildSupplierLedger(AccountsState state) {
    final filtered = state.suppliers.where((s) => s.name.toLowerCase().contains(_searchQuery)).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final supplier = filtered[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
            title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Contact: ${supplier.contactName ?? "-"} | Phone: ${supplier.phone ?? "-"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('We Owe:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      'Rs. ${supplier.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: supplier.balance > 0 ? Colors.orange[800] : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _showRecordPaymentDialog(supplier.supplierId, supplier.name, false),
                  child: const Text('Settle'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- EXPENSES TAB ---
  Widget _buildExpenses(AccountsState state) {
    final filtered = state.expenses.where((e) {
      return e.title.toLowerCase().contains(_searchQuery) || e.category.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final exp = filtered[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
            title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Category: ${exp.category} | Description: ${exp.description ?? "-"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rs. ${exp.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    ref.read(accountsControllerProvider.notifier).deleteExpense(exp.expenseId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
