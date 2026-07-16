import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/customer_model.dart';
import '../../../data/models/supplier_model.dart';
import '../viewmodels/accounts_controller.dart';

class LedgerEntry {
  final DateTime date;
  final String description;
  final double debit; // Increases debt
  final double credit; // Pays off debt
  final String? itemsJson;

  LedgerEntry({
    required this.date,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    this.itemsJson,
  });
}

class LedgerDetailView extends ConsumerWidget {
  final CustomerModel? customer;
  final SupplierModel? supplier;

  const LedgerDetailView({super.key, this.customer, this.supplier})
      : assert(customer != null || supplier != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(accountsControllerProvider);
    final isCustomer = customer != null;
    final personName = isCustomer ? customer!.name : supplier!.name;
    final personId = isCustomer ? customer!.customerId : supplier!.supplierId;

    // Filter relevant entries
    List<LedgerEntry> entries = [];

    if (isCustomer) {
      // 1. Sales (Invoices that increase debt)
      final relevantSales = state.sales.where((s) => s.customerId == personId);
      for (var sale in relevantSales) {
        entries.add(LedgerEntry(
          date: sale.timestamp,
          description: 'Invoice #${sale.invoiceNumber}',
          debit: sale.total,
          credit: sale.paidAmount,
          itemsJson: sale.itemsJson,
        ));
      }
    } else {
      // 1. Purchases (Invoices that increase debt)
      final relevantPurchases =
          state.purchases.where((p) => p.supplierId == personId);
      for (var purchase in relevantPurchases) {
        entries.add(LedgerEntry(
          date: purchase.timestamp,
          description: 'Purchase #${purchase.invoiceNumber}',
          debit: purchase.totalAmount,
          credit: purchase.paidAmount,
          itemsJson: purchase.itemsJson,
        ));
      }
    }

    // 2. Payments (Records that pay off debt)
    final relevantPayments = state.payments
        .where((p) => p.personId == personId && p.isCustomer == isCustomer);

    for (var payment in relevantPayments) {
      entries.add(LedgerEntry(
        date: payment.timestamp,
        description: 'Payment Received/Paid',
        credit: payment.amount,
      ));
    }

    // Sort entries chronologically
    entries.sort((a, b) => a.date.compareTo(b.date));

    // Calculate running balance
    double runningBalance = 0;
    final List<Map<String, dynamic>> rowData = [];
    for (var entry in entries) {
      runningBalance += entry.debit;
      runningBalance -= entry.credit;
      rowData.add({
        'date': entry.date,
        'desc': entry.description,
        'debit': entry.debit,
        'credit': entry.credit,
        'balance': runningBalance,
        'itemsJson': entry.itemsJson,
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$personName - Ledger'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: rowData.isEmpty
          ? const Center(child: Text('No ledger history found.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: rowData.length,
                    padding: const EdgeInsets.all(8.0),
                    itemBuilder: (context, index) {
                      final row = rowData[index];
                      final bool isBill = row['itemsJson'] != null;
                      List<dynamic> items = [];
                      if (isBill) {
                        try {
                          items = jsonDecode(row['itemsJson'] as String);
                        } catch (e) {
                          items = [];
                        }
                      }

                      final debit = row['debit'] as double;
                      final credit = row['credit'] as double;
                      final balance = row['balance'] as double;

                      final trailingWidget = Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (debit > 0)
                            Text(
                              'Total: Rs. ${debit.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (credit > 0)
                            Text(
                              'Paid: Rs. ${credit.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 12),
                            ),
                          if (isBill && debit - credit > 0)
                            Text(
                              'Due: Rs. ${(debit - credit).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Bal: Rs. ${balance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: balance > 0
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      );

                      if (isBill) {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8.0),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: const Icon(Icons.receipt),
                            ),
                            title: Text(
                              row['desc'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(DateFormat('dd MMM yyyy HH:mm')
                                .format(row['date'])),
                            trailing: trailingWidget,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Table(
                                  border: TableBorder.all(
                                      color: Colors.grey.shade300),
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(
                                          color: Color(0xFFF5F5F5)),
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('Product Name',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('Qty',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('Total',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    ...items.map((item) {
                                      final name = item['productName'] ?? item['name'] ?? 'Unknown';
                                      final qty = item['quantity'] ?? 0;
                                      final total = item['totalPrice'] ??
                                          item['total'] ??
                                          0;
                                      final price = item['price'] ?? item['unitPrice'] ?? item['unitCost'] ?? 0;
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(name),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('$qty @ Rs.$price'),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('Rs. $total'),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      } else {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: const Icon(Icons.payments, color: Colors.green),
                            ),
                            title: Text(
                              row['desc'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(DateFormat('dd MMM yyyy HH:mm')
                                .format(row['date'])),
                            trailing: trailingWidget,
                          ),
                        );
                      }
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Net Current Balance: ',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rs. ${runningBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: runningBalance > 0
                              ? Colors.red.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
