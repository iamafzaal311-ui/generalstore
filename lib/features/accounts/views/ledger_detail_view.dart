import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/customer_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/models/product_model.dart';
import '../../products/viewmodels/inventory_controller.dart';
import '../viewmodels/accounts_controller.dart';
import '../../transactions/views/edit_sale_dialog.dart';
import '../../transactions/views/edit_purchase_dialog.dart';
import '../../../core/providers/global_providers.dart';

class LedgerEntry {
  final DateTime date;
  final String description;
  final double debit; // Increases debt
  final double credit; // Pays off debt
  final String? itemsJson;
  final dynamic model; // SaleModel or PurchaseModel

  LedgerEntry({
    required this.date,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    this.itemsJson,
    this.model,
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
        entries.add(
          LedgerEntry(
            date: sale.timestamp,
            description: 'Invoice #${sale.invoiceNumber}',
            debit: sale.total,
            credit: sale.paidAmount,
            itemsJson: sale.itemsJson,
            model: sale,
          ),
        );
      }
    } else {
      // 1. Purchases (Invoices that increase debt)
      final relevantPurchases = state.purchases.where(
        (p) => p.supplierId == personId,
      );
      for (var purchase in relevantPurchases) {
        entries.add(
          LedgerEntry(
            date: purchase.timestamp,
            description: 'Purchase #${purchase.invoiceNumber}',
            debit: purchase.totalAmount,
            credit: purchase.paidAmount,
            itemsJson: purchase.itemsJson,
            model: purchase,
          ),
        );
      }
    }

    // 2. Payments (Records that pay off debt)
    final relevantPayments = state.payments.where(
      (p) => p.personId == personId && p.isCustomer == isCustomer,
    );

    for (var payment in relevantPayments) {
      entries.add(
        LedgerEntry(
          date: payment.timestamp,
          description: 'Payment Received/Paid',
          credit: payment.amount,
        ),
      );
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
        'model': entry.model,
      });
    }

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text('$personName - ${!isCustomer ? "Company " : ""}Ledger'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print Ledger & Stock',
            onPressed: () => _printLedger(context, ref, state, personId, personName, runningBalance, rowData, isCustomer),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Ledger'),
            Tab(text: 'Stock List'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _buildLedgerBody(context, theme, runningBalance, isCustomer, personName, personId, ref, rowData),
          _buildStockList(context, ref, state, personId, personName, isCustomer),
        ],
      ),
    );

    return DefaultTabController(length: 2, child: scaffold);
  }

  Widget _buildLedgerBody(BuildContext context, ThemeData theme, double runningBalance, bool isCustomer, String personName, String personId, WidgetRef ref, List<Map<String, dynamic>> rowData) {
    return Column(
        children: [
          // --- TOP SUMMARY CARD & ADD PAYMENT BUTTON ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCustomer
                          ? (runningBalance > 0 ? 'You have to Receive' : 'You have to Pay')
                          : (runningBalance > 0 ? 'You have to Pay' : 'You have to Receive'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${runningBalance.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: runningBalance > 0
                            ? Colors.red.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    final formKey = GlobalKey<FormState>();
                    final amountCtrl = TextEditingController();

                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(
                            isCustomer
                                ? 'Receive Payment from $personName'
                                : 'Pay to $personName',
                          ),
                          content: Form(
                            key: formKey,
                            child: TextFormField(
                              controller: amountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Payment Amount (Rs.)*',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) =>
                                  val == null || double.tryParse(val) == null
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
                                  if (isCustomer) {
                                    await ref
                                        .read(accountsControllerProvider.notifier)
                                        .receiveCustomerPayment(personId, amt);
                                  } else {
                                    await ref
                                        .read(accountsControllerProvider.notifier)
                                        .paySupplier(personId, amt);
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Payment recorded successfully!'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Record Payment'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Add Payment'),
                ),
              ],
            ),
          ),
          
          // --- LEDGER TIMELINE ---
          Expanded(
            child: rowData.isEmpty
                ? const Center(child: Text('No ledger history found.'))
                : ListView.builder(
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

                      final titleWidget = Text(
                        row['desc'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );

                      final subtitleWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy HH:mm').format(row['date']),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
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
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              if (isBill && debit - credit > 0)
                                Text(
                                  'Due: Rs. ${(debit - credit).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          if (isBill && items.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              items.map((i) => '${i['quantity']}x ${i['name']}').join(', '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      );

                      final trailingWidget = Text(
                        'Bal:\nRs. ${balance.toStringAsFixed(0)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balance > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      );

                      if (isBill) {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: const Icon(Icons.receipt),
                            ),
                            title: titleWidget,
                            subtitle: subtitleWidget,
                            trailing: trailingWidget,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Table(
                                      border: TableBorder.all(
                                        color: Colors.grey.shade300,
                                      ),
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF5F5F5),
                                      ),
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Product Name',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Qty',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...items.map((item) {
                                      final name =
                                          item['productName'] ??
                                          item['name'] ??
                                          'Unknown';
                                      final qty = item['quantity'] ?? 0;
                                      final total =
                                          item['totalPrice'] ??
                                          item['total'] ??
                                          0;
                                      final price =
                                          item['price'] ??
                                          item['unitPrice'] ??
                                          item['unitCost'] ??
                                          0;
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
                                if (row['model'] != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.edit_document),
                                        label: const Text('Edit Bill'),
                                        onPressed: () {
                                          if (row['model'] is SaleModel) {
                                            showDialog(
                                              context: context,
                                              builder: (_) => EditSaleDialog(sale: row['model'] as SaleModel),
                                            );
                                          } else if (row['model'] is PurchaseModel) {
                                            showDialog(
                                              context: context,
                                              builder: (_) => EditPurchaseDialog(purchase: row['model'] as PurchaseModel),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: const Icon(
                                Icons.payments,
                                color: Colors.green,
                              ),
                            ),
                            title: titleWidget,
                            subtitle: subtitleWidget,
                            trailing: trailingWidget,
                          ),
                        );
                      }
                    },
                  ),
          ),
        ],
      );
  }

  List<ProductModel> _getRelevantProducts(WidgetRef ref, AccountsState state, String personId, bool isCustomer) {
    final invState = ref.watch(inventoryControllerProvider);
    final Set<String> relevantProductIds = {};
    
    if (isCustomer) {
      final customerSales = state.sales.where((s) => s.customerId == personId);
      for (var sale in customerSales) {
        if (sale.itemsJson.isNotEmpty) {
          try {
            final items = jsonDecode(sale.itemsJson) as List<dynamic>;
            for (var item in items) {
              final pId = item['productId'];
              if (pId != null) relevantProductIds.add(pId);
            }
          } catch (_) {}
        }
      }
    } else {
      for (var p in invState.products) {
        if (p.supplierId == personId) relevantProductIds.add(p.productId);
      }
      final supplierPurchases = state.purchases.where((p) => p.supplierId == personId);
      for (var purchase in supplierPurchases) {
        if (purchase.itemsJson.isNotEmpty) {
          try {
            final items = jsonDecode(purchase.itemsJson) as List<dynamic>;
            for (var item in items) {
              final pId = item['productId'];
              if (pId != null) relevantProductIds.add(pId);
            }
          } catch (_) {}
        }
      }
    }

    final List<ProductModel> productsToShow = [];
    for (var pId in relevantProductIds) {
      final prod = invState.products.where((p) => p.productId == pId).firstOrNull;
      if (prod != null) productsToShow.add(prod);
    }
    productsToShow.sort((a, b) => a.name.compareTo(b.name));
    return productsToShow;
  }

  Widget _buildStockList(BuildContext context, WidgetRef ref, AccountsState state, String personId, String personName, bool isCustomer) {
    final productsToShow = _getRelevantProducts(ref, state, personId, isCustomer);

    if (productsToShow.isEmpty) {
      return const Center(child: Text('No stock found for this company.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _printStockList(context, ref, personName, productsToShow),
                icon: const Icon(Icons.print),
                label: const Text('Print Stock List'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: productsToShow.length,
            itemBuilder: (context, index) {
              final prod = productsToShow[index];
              final totalWorth = prod.stock * prod.purchasePrice;
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.inventory_2_rounded, color: Colors.white),
                  ),
                  title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Remaining Stock: ${prod.stock.toStringAsFixed(1)}'),
                  trailing: Text('Total Worth:\nRs. ${totalWorth.toStringAsFixed(0)}', textAlign: TextAlign.right),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _printStockList(BuildContext context, WidgetRef ref, String companyName, List<ProductModel> products) async {
    try {
      final doc = pw.Document();
      final storeProfile = ref.read(storeProfileProvider);
      final storeName = storeProfile?.storeName ?? 'General Store';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10.0),
              child: pw.Text(
                '$storeName - Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) {
            double totalWorth = 0;
            for (var p in products) {
              totalWorth += (p.stock * p.purchasePrice);
            }

            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Company Stock List', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Company: $companyName', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Total Stock Worth: Rs. ${totalWorth.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Product Name', 'Remaining Stock', 'Cost Price', 'Total Worth'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                data: products.map((p) {
                  return [
                    p.name,
                    p.stock.toStringAsFixed(2),
                    p.purchasePrice.toStringAsFixed(2),
                    (p.stock * p.purchasePrice).toStringAsFixed(2),
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Company_Stock_List_${companyName.replaceAll(' ', '_')}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to print stock list: $e')));
      }
    }
  }

  Future<void> _printLedger(BuildContext context, WidgetRef ref, AccountsState state, String personId, String personName, double finalBalance, List<Map<String, dynamic>> rowData, bool isCustomer) async {
    try {
      final doc = pw.Document();
      final products = _getRelevantProducts(ref, state, personId, isCustomer);
      double totalWorth = 0;
      for (var p in products) {
        totalWorth += (p.stock * p.purchasePrice);
      }

      final storeProfile = ref.read(storeProfileProvider);
      final storeName = storeProfile?.storeName ?? 'General Store';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10.0),
              child: pw.Text(
                '$storeName - Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) {
            final balanceText = isCustomer
                ? (finalBalance > 0 ? 'You have to Receive: Rs. ${finalBalance.abs().toStringAsFixed(2)}' : 'You have to Pay: Rs. ${finalBalance.abs().toStringAsFixed(2)}')
                : (finalBalance > 0 ? 'You have to Pay: Rs. ${finalBalance.abs().toStringAsFixed(2)}' : 'You have to Receive: Rs. ${finalBalance.abs().toStringAsFixed(2)}');

            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${!isCustomer ? "Company " : "Salesman "}Ledger & Stock', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Account: $personName', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Net Due Balance: $balanceText', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Text('1. Financial Ledger', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Description', 'Total (Debit)', 'Paid (Credit)', 'Balance'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                data: rowData.map((row) {
                  return [
                    DateFormat('dd-MM-yyyy HH:mm').format(row['date']),
                    row['itemsJson'] != null
                        ? (() {
                            try {
                              final items = jsonDecode(row['itemsJson'] as String) as List<dynamic>;
                              if (items.isEmpty) return row['desc'];
                              final itemsStr = items.map((i) => '${i['quantity']}x ${i['name']}').join(', ');
                              return '${row['desc']}\n$itemsStr';
                            } catch (_) {
                              return row['desc'];
                            }
                          })()
                        : row['desc'],
                    row['debit'] > 0 ? row['debit'].toStringAsFixed(2) : '-',
                    row['credit'] > 0 ? row['credit'].toStringAsFixed(2) : '-',
                    row['balance'].toStringAsFixed(2),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 30),
              pw.Text('2. Remaining Stock Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              if (products.isEmpty)
                pw.Text('No stock found for this account.')
              else ...[
                pw.Text('Total Stock Worth: Rs. ${totalWorth.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ['Product Name', 'Remaining Stock', 'Cost Price', 'Total Worth'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: products.map((p) {
                    return [
                      p.name,
                      p.stock.toStringAsFixed(2),
                      p.purchasePrice.toStringAsFixed(2),
                      (p.stock * p.purchasePrice).toStringAsFixed(2),
                    ];
                  }).toList(),
                ),
              ],
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '${personName}_Ledger.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing ledger: $e')));
      }
    }
  }
}
