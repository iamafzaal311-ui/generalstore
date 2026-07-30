import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class SalesmanDeliveredItem {
  final String name;
  double quantity;
  double unitPrice;
  double totalWorth;

  SalesmanDeliveredItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalWorth,
  });
}

class LedgerDetailView extends ConsumerWidget {
  final CustomerModel? customer;
  final SupplierModel? supplier;
  final VoidCallback? onBack;

  const LedgerDetailView({super.key, this.customer, this.supplier, this.onBack})
    : assert(customer != null || supplier != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(accountsControllerProvider);
    final isCustomer = customer != null;

    // Always use the freshest model from state so edits (e.g. balance adjustment) are reflected live
    final freshCustomer = isCustomer
        ? state.customers.where((c) => c.customerId == customer!.customerId).firstOrNull ?? customer
        : null;
    final freshSupplier = !isCustomer
        ? state.suppliers.where((s) => s.supplierId == supplier!.supplierId).firstOrNull ?? supplier
        : null;

    final personName = isCustomer ? freshCustomer!.name : freshSupplier!.name;
    final personId = isCustomer ? freshCustomer!.customerId : freshSupplier!.supplierId;

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

    // Calculate total net transaction balance from recorded sales/purchases/payments
    double netTxnBalance = 0;
    for (var entry in entries) {
      netTxnBalance += entry.debit;
      netTxnBalance -= entry.credit;
    }

    final double storedAccountBalance = isCustomer ? (freshCustomer?.balance ?? 0.0) : (freshSupplier?.balance ?? 0.0);
    final double openingBalanceDiff = storedAccountBalance - netTxnBalance;

    // If there is an opening balance (old khata balance prior to app migration), insert Opening Balance entry at top
    if (openingBalanceDiff.abs() > 0.01) {
      final firstDate = entries.isNotEmpty
          ? entries.first.date.subtract(const Duration(seconds: 1))
          : DateTime.now().subtract(const Duration(days: 30));
      entries.insert(
        0,
        LedgerEntry(
          date: firstDate,
          description: 'Previous Opening Balance (Old Khata)',
          debit: openingBalanceDiff > 0 ? openingBalanceDiff : 0.0,
          credit: openingBalanceDiff < 0 ? openingBalanceDiff.abs() : 0.0,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to List',
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/');
            }
          },
        ),
        title: Text('$personName - ${!isCustomer ? "Company " : ""}Ledger'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            onPressed: () => GoRouter.of(context).go('/'),
            icon: const Icon(Icons.dashboard_rounded, size: 16),
            label: const Text('← Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
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
    final relevantProducts = _getRelevantProducts(ref, ref.read(accountsControllerProvider), personId, isCustomer);
    final stockWorth = relevantProducts.fold<double>(
      0,
      (sum, p) => sum + (p.stock * (p.retailPrice > 0 ? p.retailPrice : (p.wholesalePrice > 0 ? p.wholesalePrice : p.purchasePrice))),
    );
    final totalInvoiced = rowData.fold<double>(0, (sum, row) => sum + (row['debit'] as num).toDouble());
    final totalPaid = rowData.fold<double>(0, (sum, row) => sum + (row['credit'] as num).toDouble());
    final card1Title = isCustomer ? 'Total Stock Delivered / Invoices' : 'Company Stock Net Worth';
    final card1Amount = isCustomer ? totalInvoiced : stockWorth;

    return Column(
      children: [
        // --- 3 TOP SUMMARY CARDS ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 600;
                  return Flex(
                    direction: isCompact ? Axis.vertical : Axis.horizontal,
                    children: [
                      // 1. Net Stock Value Delivered / Net Worth
                      Expanded(
                        flex: isCompact ? 0 : 1,
                        child: Card(
                          elevation: 1.5,
                          color: Colors.blue.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_rounded, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      card1Title,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs. ${card1Amount.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isCompact ? 0 : 8, height: isCompact ? 8 : 0),
                      // 2. Total Paid Amount
                      Expanded(
                        flex: isCompact ? 0 : 1,
                        child: Card(
                          elevation: 1.5,
                          color: Colors.green.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payments_rounded, size: 16, color: Colors.green.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Total Paid Amount',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs. ${totalPaid.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isCompact ? 0 : 8, height: isCompact ? 8 : 0),
                      // 3. Pending / Payable Balance
                      Expanded(
                        flex: isCompact ? 0 : 1,
                        child: Card(
                          elevation: 1.5,
                          color: runningBalance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 16,
                                      color: runningBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCustomer ? 'Pending Receivable' : 'Pending Payable',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: runningBalance > 0 ? Colors.red.shade900 : Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs. ${runningBalance.abs().toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: runningBalance > 0 ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                          final qtyNum =
                                              (item['quantity'] as num?)?.toDouble() ?? 0.0;
                                          final totalNum =
                                              (item['totalPrice'] as num?)?.toDouble() ??
                                              (item['total'] as num?)?.toDouble() ??
                                              0.0;
                                          double priceNum = 0.0;
                                          if (isCustomer) {
                                            final rawPrice = item['unitPrice'] ?? item['price'] ?? item['retailPrice'] ?? item['salePrice'];
                                            if (rawPrice != null && (rawPrice as num).toDouble() > 0) {
                                              priceNum = (rawPrice as num).toDouble();
                                            } else if (qtyNum > 0 && totalNum > 0) {
                                              priceNum = totalNum / qtyNum;
                                            } else if (item['purchasePrice'] != null) {
                                              priceNum = (item['purchasePrice'] as num).toDouble();
                                            }
                                          } else {
                                            final rawPrice = item['purchasePrice'] ?? item['costPrice'] ?? item['buyPrice'] ?? item['unitCost'] ?? item['unitPrice'] ?? item['price'];
                                            if (rawPrice != null && (rawPrice as num).toDouble() > 0) {
                                              priceNum = (rawPrice as num).toDouble();
                                            } else if (qtyNum > 0 && totalNum > 0) {
                                              priceNum = totalNum / qtyNum;
                                            }
                                          }

                                          final formattedQty = qtyNum.truncateToDouble() == qtyNum
                                              ? qtyNum.toStringAsFixed(0)
                                              : qtyNum.toStringAsFixed(2);
                                          final formattedPrice = priceNum.truncateToDouble() == priceNum
                                              ? priceNum.toStringAsFixed(0)
                                              : priceNum.toStringAsFixed(2);
                                          final formattedTotal = totalNum.truncateToDouble() == totalNum
                                              ? totalNum.toStringAsFixed(0)
                                              : totalNum.toStringAsFixed(2);

                                          return TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(name.toString()),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text('$formattedQty @ Rs. $formattedPrice'),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text('Rs. $formattedTotal'),
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

  List<SalesmanDeliveredItem> _getSalesmanDeliveredStock(AccountsState state, String salesmanId) {
    final Map<String, SalesmanDeliveredItem> map = {};
    final salesmanSales = state.sales.where((s) => s.customerId == salesmanId);

    for (var sale in salesmanSales) {
      if (sale.itemsJson.isNotEmpty) {
        try {
          final items = jsonDecode(sale.itemsJson) as List<dynamic>;
          for (var item in items) {
            final name = item['name']?.toString() ?? item['productName']?.toString() ?? 'Unknown Item';
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final price = (item['unitPrice'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
            final total = (item['total'] as num?)?.toDouble() ?? (item['subtotal'] as num?)?.toDouble() ?? (qty * price);

            if (map.containsKey(name)) {
              map[name]!.quantity += qty;
              map[name]!.totalWorth += total;
              if (price > 0) map[name]!.unitPrice = price;
            } else {
              map[name] = SalesmanDeliveredItem(
                name: name,
                quantity: qty,
                unitPrice: price,
                totalWorth: total,
              );
            }
          }
        } catch (_) {}
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Widget _buildStockList(BuildContext context, WidgetRef ref, AccountsState state, String personId, String personName, bool isCustomer) {
    if (isCustomer) {
      // Salesman Khata: Show Stock Taken / Issued to Salesman
      final deliveredItems = _getSalesmanDeliveredStock(state, personId);

      if (deliveredItems.isEmpty) {
        return const Center(child: Text('No stock items issued to this salesman yet.'));
      }

      final totalDeliveredWorth = deliveredItems.fold<double>(0, (sum, i) => sum + i.totalWorth);

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Salesman Total Issued Stock: Rs. ${totalDeliveredWorth.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900),
                ),
                ElevatedButton.icon(
                  onPressed: () => _printSalesmanStockList(context, ref, personName, deliveredItems, totalDeliveredWorth),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print Stock List'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: deliveredItems.length,
              itemBuilder: (context, index) {
                final item = deliveredItems[index];
                final formattedQty = item.quantity.truncateToDouble() == item.quantity ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2);
                final formattedPrice = item.unitPrice.truncateToDouble() == item.unitPrice ? item.unitPrice.toStringAsFixed(0) : item.unitPrice.toStringAsFixed(2);
                final formattedWorth = item.totalWorth.truncateToDouble() == item.totalWorth ? item.totalWorth.toStringAsFixed(0) : item.totalWorth.toStringAsFixed(2);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.inventory_2_rounded, color: Colors.white),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Delivered Qty: $formattedQty | Unit Price: Rs. $formattedPrice'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Issued Worth', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          'Rs. $formattedWorth',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade800),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Company Khata: Show Store Remaining Inventory
    final productsToShow = _getRelevantProducts(ref, state, personId, isCustomer);

    if (productsToShow.isEmpty) {
      return const Center(child: Text('No stock found for this company.'));
    }

    final totalWorth = productsToShow.fold<double>(
      0,
      (sum, p) => sum + (p.stock * (p.retailPrice > 0 ? p.retailPrice : (p.wholesalePrice > 0 ? p.wholesalePrice : p.purchasePrice))),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stock Net Worth (Sale Price): Rs. ${totalWorth.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900),
              ),
              ElevatedButton.icon(
                onPressed: () => _printStockList(context, ref, personName, productsToShow),
                icon: const Icon(Icons.print_rounded, size: 18),
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
              final unitPrice = prod.retailPrice > 0
                  ? prod.retailPrice
                  : (prod.wholesalePrice > 0 ? prod.wholesalePrice : prod.purchasePrice);
              final itemTotalWorth = prod.stock * unitPrice;
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.inventory_2_rounded, color: Colors.white),
                  ),
                  title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Sale Price: Rs. ${unitPrice.toStringAsFixed(0)} | Stock: ${prod.stock.toStringAsFixed(1)} ${prod.unit}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Worth (Sale)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        'Rs. ${itemTotalWorth.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _printSalesmanStockList(BuildContext context, WidgetRef ref, String salesmanName, List<SalesmanDeliveredItem> items, double totalWorth) async {
    try {
      final doc = pw.Document();
      final storeProfile = ref.read(storeProfileProvider);
      final storeName = storeProfile?.storeName ?? 'General Store';
      final storeAddress = storeProfile?.address ?? '';
      final storePhone = storeProfile?.phone ?? '';
      final printDate = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context ctx) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(storeName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          if (storeAddress.isNotEmpty) pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          if (storePhone.isNotEmpty) pw.Text('Ph: $storePhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('SALESMAN STOCK REPORT', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                          pw.Text(printDate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(storeName, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                ],
              ),
            );
          },
          build: (pw.Context ctx) {
            return [
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Salesman: $salesmanName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Issued Stock Worth: Rs. ${totalWorth.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.TableHelper.fromTextArray(
                headers: ['Product Name', 'Total Issued Qty', 'Unit Price (Rs.)', 'Total Worth (Rs.)'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                data: items.map((i) {
                  return [
                    i.name,
                    i.quantity.toStringAsFixed(0),
                    'Rs. ${i.unitPrice.toStringAsFixed(0)}',
                    'Rs. ${i.totalWorth.toStringAsFixed(0)}',
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Salesman_Stock_List_${salesmanName.replaceAll(' ', '_')}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to print stock list: $e')));
      }
    }
  }

  Future<void> _printStockList(BuildContext context, WidgetRef ref, String companyName, List<ProductModel> products) async {
    try {
      final doc = pw.Document();
      final storeProfile = ref.read(storeProfileProvider);
      final storeName = storeProfile?.storeName ?? 'General Store';
      final storeAddress = storeProfile?.address ?? '';
      final storePhone = storeProfile?.phone ?? '';
      final printDate = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context ctx) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(storeName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      if (storeAddress.isNotEmpty) pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (storePhone.isNotEmpty) pw.Text('Ph: $storePhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('COMPANY STOCK LIST', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text(printDate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$storeName | Company: $companyName', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                ],
              ),
            );
          },
          build: (pw.Context ctx) {
            double totalWorth = 0;
            for (var p in products) {
              totalWorth += (p.stock * p.purchasePrice);
            }

            return [
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Company: $companyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Stock Worth (Cost): Rs. ${totalWorth.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.TableHelper.fromTextArray(
                headers: ['Product Name', 'Remaining Stock', 'Cost Price (Rs.)', 'Total Worth (Rs.)'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 9),
                data: products.map((p) {
                  return [
                    p.name,
                    p.stock.toStringAsFixed(1),
                    'Rs. ${p.purchasePrice.toStringAsFixed(0)}',
                    'Rs. ${(p.stock * p.purchasePrice).toStringAsFixed(0)}',
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
      final storeAddress = storeProfile?.address ?? '';
      final storePhone = storeProfile?.phone ?? '';
      final printDate = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (pw.Context ctx) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(storeName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      if (storeAddress.isNotEmpty) pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (storePhone.isNotEmpty) pw.Text('Ph: $storePhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        isCustomer ? 'SALESMAN LEDGER REPORT' : 'COMPANY LEDGER REPORT',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                      pw.Text(printDate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$storeName | Account: $personName', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            final pdfTotalInvoiced = rowData.fold<double>(0, (sum, row) => sum + (row['debit'] as double));
            final pdfTotalPaid = rowData.fold<double>(0, (sum, row) => sum + (row['credit'] as double));

            return [
              pw.SizedBox(height: 10),
              pw.Text('Account Name: $personName', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              // Summary Box in PDF
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(isCustomer ? 'Total Stock/Invoices' : 'Stock Net Worth', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Rs. ${(isCustomer ? pdfTotalInvoiced : totalWorth).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Total Payments Received', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Rs. ${pdfTotalPaid.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Net Pending Dues', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Rs. ${finalBalance.abs().toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: finalBalance > 0 ? PdfColors.red800 : PdfColors.green800)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              pw.Text('1. Financial Ledger & Invoice Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Invoice / Description', 'Debit (Total)', 'Credit (Paid)', 'Net Balance'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
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
                              return '${row['desc']}\n($itemsStr)';
                            } catch (_) {
                              return row['desc'];
                            }
                          })()
                        : row['desc'],
                    row['debit'] > 0 ? 'Rs. ${row['debit'].toStringAsFixed(0)}' : '-',
                    row['credit'] > 0 ? 'Rs. ${row['credit'].toStringAsFixed(0)}' : '-',
                    'Rs. ${row['balance'].toStringAsFixed(0)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('2. Stock Delivered & Product Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (products.isEmpty)
                pw.Text('No individual stock items recorded for this account.', style: const pw.TextStyle(fontSize: 9))
              else ...[
                pw.TableHelper.fromTextArray(
                  headers: ['Product Name', 'Stock Qty', 'Unit Price', 'Total Worth'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: products.map((p) {
                    final pPrice = p.retailPrice > 0 ? p.retailPrice : (p.wholesalePrice > 0 ? p.wholesalePrice : p.purchasePrice);
                    return [
                      p.name,
                      p.stock.toStringAsFixed(0),
                      'Rs. ${pPrice.toStringAsFixed(0)}',
                      'Rs. ${(p.stock * pPrice).toStringAsFixed(0)}',
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
