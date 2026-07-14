import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../data/models/sale_model.dart';
import '../../pos/viewmodels/pos_controller.dart';
import '../../../core/utils/print_helper.dart';
import '../../../core/providers/global_providers.dart';

class SalesView extends ConsumerStatefulWidget {
  const SalesView({super.key});

  @override
  ConsumerState<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends ConsumerState<SalesView> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final repo = ref.read(salesRepositoryProvider);
    final sales = await repo.getSales();
    
    // Sort so newest is at the top
    sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    setState(() {
      _sales = sales;
      _isLoading = false;
    });
  }

  Future<void> _deleteSale(SaleModel sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text('Are you sure you want to delete invoice ${sale.invoiceNumber}? This will restock the sold items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(salesRepositoryProvider).deleteSale(sale.saleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted and stock reverted.')),
        );
        _loadSales();
      }
    }
  }

  void _reprintReceipt(SaleModel sale, bool isThermal) async {
    try {
      final items = jsonDecode(sale.itemsJson) as List;
      final currentUser = ref.read(currentUserProvider);
      final cashierName = currentUser?.fullName ?? 'Admin';

      if (isThermal) {
        final pdfBytes = await PrintHelper.generateThermalReceipt(
          sale: sale,
          items: items,
          cashierName: cashierName,
          customerName: sale.customerId != null ? 'Customer' : null,
        );
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      } else {
        final pdfBytes = await PrintHelper.generateA4Invoice(
          sale: sale,
          items: items,
          cashierName: cashierName,
          customerName: sale.customerId != null ? 'Customer' : null,
        );
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.role == 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Invoice History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const Center(child: Text('No sales invoices found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    List<dynamic> items = [];
                    try {
                      items = jsonDecode(sale.itemsJson) as List;
                    } catch (_) {}

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.receipt_long_rounded),
                          ),
                          title: Text(
                            'Invoice: ${sale.invoiceNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Date: ${sale.timestamp.toLocal().toString().split('.')[0]}\nItems: ${items.length}',
                            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total: Rs. ${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              Text('Paid: Rs. ${sale.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Purchased Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ...items.map((item) {
                                    final name = item['productName'] ?? item['name'] ?? 'Unknown';
                                    final qty = item['quantity']?.toString() ?? '0';
                                    final price = item['price']?.toString() ?? item['unitPrice']?.toString() ?? '0';
                                    final total = item['total']?.toString() ?? '0';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text('- $name (x$qty @ Rs.$price)', style: const TextStyle(fontSize: 13))),
                                          Text('Rs. $total', style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.print, size: 18),
                                        label: const Text('Thermal Print'),
                                        onPressed: () => _reprintReceipt(sale, true),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                                        label: const Text('A4 Print'),
                                        onPressed: () => _reprintReceipt(sale, false),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          onPressed: () => _deleteSale(sale),
                                        ),
                                      ],
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
