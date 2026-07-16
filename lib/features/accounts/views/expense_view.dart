import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/accounts_controller.dart';
import 'package:intl/intl.dart';

class ExpenseView extends ConsumerWidget {
  const ExpenseView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense History',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(accountsControllerProvider.notifier).refreshAccounts(),
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.expenses.isEmpty
          ? const Center(child: Text('No expenses recorded.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.expenses.length,
              itemBuilder: (context, index) {
                final expense = state.expenses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: const Icon(Icons.money_off, color: Colors.red),
                    ),
                    title: Text(
                      expense.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${expense.category} | ${DateFormat('dd MMM yyyy, hh:mm a').format(expense.timestamp)}\n${expense.description ?? "No details"}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      'Rs. ${expense.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      // Optional: Show detail or delete dialog
                    },
                  ),
                );
              },
            ),
    );
  }
}
