import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/excel_pdf_export_helper.dart';
import '../../pos/viewmodels/pos_controller.dart';
import '../../products/viewmodels/inventory_controller.dart';

class ReportsView extends ConsumerWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Center'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Formats & Ledger Logs',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a report category to download or print ledger metrics.',
              style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildReportCard(
                    context: context,
                    title: 'Monthly Sales Report',
                    description: 'Transactions and revenue for the current month.',
                    icon: Icons.calendar_month_rounded,
                    color: theme.colorScheme.primary,
                    onPdfPressed: () async {
                      final allSales = await ref.read(salesRepositoryProvider).getSales();
                      final now = DateTime.now();
                      final monthlySales = allSales.where((s) => s.timestamp.month == now.month && s.timestamp.year == now.year).toList();
                      final pdfBytes = await ExcelPdfExportHelper.exportSalesToPdf(monthlySales, reportTitle: 'MONTHLY SALES REPORT');
                      await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                    },
                    onExcelPressed: () async {
                      final allSales = await ref.read(salesRepositoryProvider).getSales();
                      final now = DateTime.now();
                      final monthlySales = allSales.where((s) => s.timestamp.month == now.month && s.timestamp.year == now.year).toList();
                      await ExcelPdfExportHelper.exportSalesToExcel(monthlySales);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Monthly Excel generated successfully.')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildReportCard(
                    context: context,
                    title: 'All Sales & Revenue',
                    description: 'Detailed record of all transactions ever processed.',
                    icon: Icons.analytics_rounded,
                    color: Colors.blueAccent,
                    onPdfPressed: () async {
                      final sales = await ref.read(salesRepositoryProvider).getSales();
                      final pdfBytes = await ExcelPdfExportHelper.exportSalesToPdf(sales, reportTitle: 'ALL SALES REPORT');
                      await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                    },
                    onExcelPressed: () async {
                      final sales = await ref.read(salesRepositoryProvider).getSales();
                      await ExcelPdfExportHelper.exportSalesToExcel(sales);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All Sales report generated.')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildReportCard(
                    context: context,
                    title: 'Current Inventory',
                    description: 'Complete stock inventory listing including values and quantities.',
                    icon: Icons.inventory_2_rounded,
                    color: theme.colorScheme.secondary,
                    onPdfPressed: () async {
                      final products = ref.read(inventoryControllerProvider).products;
                      final pdfBytes = await ExcelPdfExportHelper.exportInventoryToPdf(products);
                      await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                    },
                    onExcelPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Excel Stock export triggered successfully.')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildReportCard(
                    context: context,
                    title: 'Business Profit & Loss Report',
                    description: 'Comprehensive month-wise business report including profit, loss, and product sales history.',
                    icon: Icons.query_stats_rounded,
                    color: Colors.purple,
                    onPdfPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        helpText: 'Select Month & Year for Report',
                      );

                      if (selectedDate != null) {
                        final allSales = await ref.read(salesRepositoryProvider).getSales();
                        final monthlySales = allSales.where((s) => s.timestamp.month == selectedDate.month && s.timestamp.year == selectedDate.year).toList();
                        final currentProducts = ref.read(inventoryControllerProvider).products;
                        
                        final title = 'For ${DateFormat('MMMM yyyy').format(selectedDate)}';
                        final pdfBytes = await ExcelPdfExportHelper.exportBusinessReportToPdf(
                          sales: monthlySales, 
                          currentProducts: currentProducts,
                          monthYearTitle: title
                        );
                        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                      }
                    },
                    onExcelPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Excel export not available for Business Reports yet.')),
                      );
                    },
                  ),
                ),
                const Spacer(),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPdfPressed,
    required VoidCallback onExcelPressed,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onPdfPressed,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Export PDF / Print'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onExcelPressed,
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text('Export Excel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
