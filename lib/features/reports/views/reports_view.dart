import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/global_providers.dart';
import '../../../core/utils/excel_pdf_export_helper.dart';
import '../../../core/utils/excel_helper.dart';
import '../../../core/utils/print_helper.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/models/sale_model.dart';
import '../../products/viewmodels/inventory_controller.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  late int _selectedMonth;
  late int _selectedYear;
  bool _deductExpensesFromProfit = false;

  String _salesSearch = '';
  String _salesPaymentFilter = 'All';

  String _purchaseSearch = '';
  String _expenseSearch = '';
  final String _expenseCategoryFilter = 'All';

  String _inventorySearch = '';

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  final List<int> _years = [2024, 2025, 2026, 2027, 2028, 2029, 2030];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    if (!_years.contains(_selectedYear)) {
      _years.add(_selectedYear);
      _years.sort();
    }
  }

  Future<void> _saveExcelFile(
    BuildContext context,
    List<int> bytes,
    String fileName,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}\\GeneralStore_Exports');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final file = File('${folder.path}\\$fileName.xlsx');
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved Successfully!\nLocation: ${file.path}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDetailModal(BuildContext context, int tabIndex) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final db = ref.watch(localDbServiceProvider);
            final invState = ref.watch(inventoryControllerProvider);

            final allSales = db.salesBox.values.where((s) => !s.isDeleted).toList();
            final allExpenses = db.expensesBox.values.where((e) => !e.isDeleted).toList();
            final allPurchases = db.purchasesBox.values.where((p) => !p.isDeleted).toList();
            final products = invState.products;

            final monthlySales = allSales
                .where((s) => s.timestamp.month == _selectedMonth && s.timestamp.year == _selectedYear)
                .toList();
            monthlySales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            final monthlyExpenses = allExpenses
                .where((e) => e.timestamp.month == _selectedMonth && e.timestamp.year == _selectedYear)
                .toList();
            monthlyExpenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            final monthlyPurchases = allPurchases
                .where((p) => p.timestamp.month == _selectedMonth && p.timestamp.year == _selectedYear)
                .toList();
            monthlyPurchases.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            final double totalSales = monthlySales.fold(0.0, (sum, s) => sum + s.total);
            final double totalExpenses = monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);

            double totalCogs = 0.0;
            final Map<String, int> productQtySold = {};
            final Map<String, double> productRevenue = {};

            for (final sale in monthlySales) {
              try {
                final List<dynamic> items = jsonDecode(sale.itemsJson);
                for (final item in items) {
                  final productId = item['productId'] as String?;
                  final name = item['name'] ?? item['productName'] ?? 'Item';
                  final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                  final revenue = (item['total'] as num?)?.toDouble() ?? 0.0;

                  double costPrice = 0.0;
                  if (item.containsKey('purchasePrice') && item['purchasePrice'] != null) {
                    costPrice = (item['purchasePrice'] as num).toDouble();
                  } else if (productId != null) {
                    final p = products.where((prod) => prod.productId == productId).firstOrNull;
                    if (p != null) costPrice = p.purchasePrice;
                  }

                  totalCogs += (costPrice * qty);
                  productQtySold[name] = (productQtySold[name] ?? 0) + qty.round();
                  productRevenue[name] = (productRevenue[name] ?? 0.0) + revenue;
                }
              } catch (_) {}
            }

            final double grossProfit = totalSales - totalCogs;
            final double netProfit = grossProfit - totalExpenses;
            final double profitMargin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

            final double stockWorthRetail = products.fold(
              0.0,
              (sum, p) => sum + (p.stock * (p.retailPrice > 0 ? p.retailPrice : p.purchasePrice)),
            );
            final double stockWorthCost = products.fold(
              0.0,
              (sum, p) => sum + (p.stock * p.purchasePrice),
            );
            final double potentialStockMargin = stockWorthRetail - stockWorthCost;
            final double totalStockUnits = products.fold(0.0, (sum, p) => sum + p.stock);

            final monthYearTitle = '${_months[_selectedMonth - 1]} $_selectedYear';

            Widget detailWidget;
            if (tabIndex == 0) {
              detailWidget = _buildFinancialsTab(
                monthYearTitle: monthYearTitle,
                monthlySales: monthlySales,
                products: products,
                totalSales: totalSales,
                totalCogs: totalCogs,
                grossProfit: grossProfit,
                totalExpenses: totalExpenses,
                netProfit: netProfit,
                profitMargin: profitMargin,
                stockWorthCost: stockWorthCost,
                stockWorthRetail: stockWorthRetail,
                potentialStockMargin: potentialStockMargin,
                productsCount: products.length,
                totalStockUnits: totalStockUnits,
                productQtySold: productQtySold,
                productRevenue: productRevenue,
              );
            } else if (tabIndex == 1) {
              detailWidget = _buildSalesTab(
                monthYearTitle: monthYearTitle,
                monthlySales: monthlySales,
                products: products,
              );
            } else if (tabIndex == 2) {
              detailWidget = _buildPurchasesTab(
                monthYearTitle: monthYearTitle,
                monthlyPurchases: monthlyPurchases,
              );
            } else if (tabIndex == 3) {
              detailWidget = _buildExpensesTab(
                monthYearTitle: monthYearTitle,
                monthlyExpenses: monthlyExpenses,
              );
            } else if (tabIndex == 4) {
              detailWidget = _buildInventoryTab(
                products: products,
              );
            } else {
              detailWidget = _buildDayByDayTab(
                monthYearTitle: monthYearTitle,
                monthlySales: monthlySales,
                monthlyPurchases: monthlyPurchases,
                monthlyExpenses: monthlyExpenses,
              );
            }

            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  elevation: 1,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back to Dashboard',
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        _getTabIcon(tabIndex),
                        color: Theme.of(context).colorScheme.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_getTabTitle(tabIndex)} ($monthYearTitle)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 24),
                      tooltip: 'Close Report',
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: detailWidget,
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.insights_rounded;
      case 1:
        return Icons.receipt_long_rounded;
      case 2:
        return Icons.shopping_cart_rounded;
      case 3:
        return Icons.payments_rounded;
      case 4:
        return Icons.inventory_2_rounded;
      default:
        return Icons.calendar_view_month_rounded;
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Financial Profit & Loss Statement';
      case 1:
        return 'Sales Transactions Record';
      case 2:
        return 'Stock Purchases Record';
      case 3:
        return 'Operating Expenses Record';
      case 4:
        return 'Current Inventory Stock Report';
      default:
        return 'Day-by-Day Performance Summary';
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(localDbServiceProvider);
    final invState = ref.watch(inventoryControllerProvider);

    final allSales = db.salesBox.values.where((s) => !s.isDeleted).toList();
    final allExpenses = db.expensesBox.values.where((e) => !e.isDeleted).toList();
    final allPurchases = db.purchasesBox.values.where((p) => !p.isDeleted).toList();
    final products = invState.products;

    final monthlySales = allSales
        .where((s) => s.timestamp.month == _selectedMonth && s.timestamp.year == _selectedYear)
        .toList();

    final monthlyExpenses = allExpenses
        .where((e) => e.timestamp.month == _selectedMonth && e.timestamp.year == _selectedYear)
        .toList();

    final monthlyPurchases = allPurchases
        .where((p) => p.timestamp.month == _selectedMonth && p.timestamp.year == _selectedYear)
        .toList();

    final double totalSales = monthlySales.fold(0.0, (sum, s) => sum + s.total);
    final double totalExpenses = monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final double totalPurchases = monthlyPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);

    double totalCogs = 0.0;
    for (final sale in monthlySales) {
      try {
        final List<dynamic> items = jsonDecode(sale.itemsJson);
        for (final item in items) {
          final productId = item['productId'] as String?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;

          double costPrice = 0.0;
          if (item.containsKey('purchasePrice') && item['purchasePrice'] != null) {
            costPrice = (item['purchasePrice'] as num).toDouble();
          } else if (productId != null) {
            final p = products.where((prod) => prod.productId == productId).firstOrNull;
            if (p != null) costPrice = p.purchasePrice;
          }
          totalCogs += (costPrice * qty);
        }
      } catch (_) {}
    }

    final double grossProfit = totalSales - totalCogs;
    final double netProfit = grossProfit - totalExpenses;

    final double stockWorthRetail = products.fold(
      0.0,
      (sum, p) => sum + (p.stock * (p.retailPrice > 0 ? p.retailPrice : p.purchasePrice)),
    );
    final double totalStockUnits = products.fold(0.0, (sum, p) => sum + p.stock);

    final monthYearTitle = '${_months[_selectedMonth - 1]} $_selectedYear';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics Center'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP CONTROLS & MONTH/YEAR FILTER HEADER ─────────────────────
            _buildMonthYearHeader(
              context: context,
              monthYearTitle: monthYearTitle,
            ),

            const SizedBox(height: 24),

            // ── 6 CLEAN INTERACTIVE REPORT CARDS GRID ───────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1100
                    ? 3
                    : (constraints.maxWidth > 700 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth > 1100
                      ? 3.2
                      : (constraints.maxWidth > 700 ? 2.8 : 3.0),
                  children: [
                    _buildReportCard(
                      index: 0,
                      title: 'Financials & P&L',
                      value: _deductExpensesFromProfit
                          ? 'Rs. ${netProfit.toStringAsFixed(0)} (Net)'
                          : 'Rs. ${grossProfit.toStringAsFixed(0)} (Gross)',
                      subtitle: _deductExpensesFromProfit
                          ? 'Gross: Rs. ${grossProfit.toStringAsFixed(0)} - Exp: Rs. ${totalExpenses.toStringAsFixed(0)}'
                          : 'Sales: Rs. ${totalSales.toStringAsFixed(0)} | COGS: Rs. ${totalCogs.toStringAsFixed(0)}',
                      icon: Icons.insights_rounded,
                      color: (_deductExpensesFromProfit ? netProfit : grossProfit) >= 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    _buildReportCard(
                      index: 1,
                      title: 'Sales Transactions',
                      value: 'Rs. ${totalSales.toStringAsFixed(0)}',
                      subtitle: '${monthlySales.length} Sales Invoices Recorded',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF0284C7),
                    ),
                    _buildReportCard(
                      index: 2,
                      title: 'Stock Purchases',
                      value: 'Rs. ${totalPurchases.toStringAsFixed(0)}',
                      subtitle: '${monthlyPurchases.length} Purchase Bills Recorded',
                      icon: Icons.shopping_cart_rounded,
                      color: const Color(0xFFD97706),
                    ),
                    _buildReportCard(
                      index: 3,
                      title: 'Operating Expenses',
                      value: 'Rs. ${totalExpenses.toStringAsFixed(0)}',
                      subtitle: '${monthlyExpenses.length} Expense Records',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                    _buildReportCard(
                      index: 4,
                      title: 'Inventory Stock',
                      value: 'Rs. ${stockWorthRetail.toStringAsFixed(0)}',
                      subtitle: '${products.length} Products | ${totalStockUnits.toStringAsFixed(0)} Units',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF059669),
                    ),
                    _buildReportCard(
                      index: 5,
                      title: 'Day-by-Day Summary',
                      value: '${_months[_selectedMonth - 1]} Summary',
                      subtitle: '31 Days Monthly Activity Breakdown',
                      icon: Icons.calendar_view_month_rounded,
                      color: const Color(0xFF9333EA),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── MONTH & YEAR FILTER HEADER ─────────────────────────────────────────────
  Widget _buildMonthYearHeader({
    required BuildContext context,
    required String monthYearTitle,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reports & Analytics Dashboard',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Click any report card to open full-screen view & print',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Controls (Expenses Toggle + Month and Year Selectors)
            Row(
              children: [
                // Expenses Deduction Toggle Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _deductExpensesFromProfit = !_deductExpensesFromProfit;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _deductExpensesFromProfit
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _deductExpensesFromProfit
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _deductExpensesFromProfit
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 18,
                          color: _deductExpensesFromProfit
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Deduct Expenses in Profit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _deductExpensesFromProfit
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Month Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(
                            _months[index],
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMonth = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Year Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: _years.map((y) {
                        return DropdownMenuItem(
                          value: y,
                          child: Text(
                            y.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedYear = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── CLEAN INTERACTIVE REPORT CARD WIDGET ───────────────────────────────────
  Widget _buildReportCard({
    required int index,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          _showReportDetailModal(context, index);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(
                          icon,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 11, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          'OPEN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB 0: FINANCIALS & PNL DETAIL SCREEN ─────────────────────────────────
  Widget _buildFinancialsTab({
    required String monthYearTitle,
    required List<SaleModel> monthlySales,
    required List<ProductModel> products,
    required double totalSales,
    required double totalCogs,
    required double grossProfit,
    required double totalExpenses,
    required double netProfit,
    required double profitMargin,
    required double stockWorthCost,
    required double stockWorthRetail,
    required double potentialStockMargin,
    required int productsCount,
    required double totalStockUnits,
    required Map<String, int> productQtySold,
    required Map<String, double> productRevenue,
  }) {
    final sortedProductNames = productQtySold.keys.toList()
      ..sort((a, b) => productQtySold[b]!.compareTo(productQtySold[a]!));

    return Column(
      children: [
        // Tab Action Header (Print / Export PDF & Excel)
        _buildTabActionHeader(
          title: 'Financial Profit & Loss Statement ($monthYearTitle)',
          onPdfPrint: () async {
            final paper = await PrintHelper.showPaperSizeMenu(context);
            if (paper == null) return;
            final pdfBytes = await ExcelPdfExportHelper.exportBusinessReportToPdf(
              sales: monthlySales,
              currentProducts: products,
              monthYearTitle: 'Report for $monthYearTitle',
              totalExpenses: totalExpenses,
              storeProfile: ref.read(storeProfileProvider),
              pageFormat: paper.format,
            );
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          },
        ),

        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue & Profit Breakdown Card
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          const Text(
                            'Monthly Income Statement',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow('Gross Sales Revenue', totalSales, isBold: true),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Cost of Goods Sold (COGS)', -totalCogs, isNegative: true),
                      const Divider(height: 20),
                      _buildSummaryRow(
                        'Gross Profit (Before Expenses)',
                        grossProfit,
                        isBold: true,
                        color: grossProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Total Operating Expenses Deducted', -totalExpenses, isNegative: true),
                      const Divider(height: 24, thickness: 1.5),
                      _buildSummaryRow(
                        'Grand Net Profit / (Loss)',
                        netProfit,
                        isBold: true,
                        fontSize: 18,
                        color: netProfit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: netProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: netProfit >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grand Profit Formula:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gross Profit (Rs. ${grossProfit.toStringAsFixed(0)}) - Expenses (Rs. ${totalExpenses.toStringAsFixed(0)}) = Net Profit (Rs. ${netProfit.toStringAsFixed(0)})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Profit Margin', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${profitMargin.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: profitMargin >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Stock Valuation Summary Card
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_rounded, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          const Text(
                            'Current Inventory Valuation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow('Total Unique Products (SKUs)', productsCount.toDouble(), isCurrency: false),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Total Stock Units', totalStockUnits, isCurrency: false),
                      const Divider(height: 20),
                      _buildSummaryRow('Stock Worth (At Cost Price)', stockWorthCost),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Stock Worth (At Retail/Sale Price)', stockWorthRetail, isBold: true),
                      const Divider(height: 24, thickness: 1.5),
                      _buildSummaryRow(
                        'Expected Inventory Margin',
                        potentialStockMargin,
                        isBold: true,
                        fontSize: 16,
                        color: const Color(0xFF059669),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Top Selling Products Table
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text(
                          'Top Selling Items in Selected Month',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    Text(
                      '${sortedProductNames.length} Items Sold',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (sortedProductNames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No sales records found for this month.')),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Text('Quantity Sold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Text('Total Revenue Generated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                        ...sortedProductNames.take(15).map((name) {
                          final qty = productQtySold[name]!;
                          final rev = productRevenue[name]!;
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(name, style: const TextStyle(fontSize: 13)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text('$qty', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  'Rs. ${rev.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 1: SALES LIST DETAIL SCREEN ───────────────────────────────────────
  Widget _buildSalesTab({
    required String monthYearTitle,
    required List<SaleModel> monthlySales,
    required List<ProductModel> products,
  }) {
    final filteredSales = monthlySales.where((s) {
      final matchesSearch = _salesSearch.isEmpty ||
          s.invoiceNumber.toLowerCase().contains(_salesSearch.toLowerCase());
      final matchesPayment = _salesPaymentFilter == 'All' || s.paymentMethod == _salesPaymentFilter;
      return matchesSearch && matchesPayment;
    }).toList();

    final double totalFilteredAmount = filteredSales.fold(0.0, (sum, s) => sum + s.total);

    return Column(
      children: [
        _buildTabActionHeader(
          title: 'Sales Transactions List ($monthYearTitle)',
          onPdfPrint: () async {
            final paper = await PrintHelper.showPaperSizeMenu(context);
            if (paper == null) return;
            final pdfBytes = await ExcelPdfExportHelper.exportSalesToPdf(
              filteredSales,
              reportTitle: 'SALES REPORT - $monthYearTitle',
              storeProfile: ref.read(storeProfileProvider),
              pageFormat: paper.format,
            );
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          },
          onExcelExport: () async {
            final bytes = await ExcelPdfExportHelper.exportSalesToExcel(filteredSales);
            if (context.mounted) {
              await _saveExcelFile(context, bytes, 'Sales_Report_${_selectedMonth}_$_selectedYear');
            }
          },
        ),

        const SizedBox(height: 16),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search Invoice Number...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) => setState(() => _salesSearch = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _salesPaymentFilter,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Payments')),
                            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'Card', child: Text('Card')),
                            DropdownMenuItem(value: 'Credit', child: Text('Credit / Khata')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _salesPaymentFilter = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Sales Records: ${filteredSales.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Revenue: Rs. ${totalFilteredAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontSize: 16),
                    ),
                  ],
                ),

                const Divider(height: 24),

                if (filteredSales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No sale transactions found.')),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredSales.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final sale = filteredSales[i];
                      double saleCogs = 0.0;
                      int itemCount = 0;
                      try {
                        final items = jsonDecode(sale.itemsJson) as List;
                        itemCount = items.length;
                        for (var item in items) {
                          final qty = (item['quantity'] as num).toDouble();
                          double cost = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;
                          saleCogs += (cost * qty);
                        }
                      } catch (_) {}

                      final saleProfit = sale.total - saleCogs;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.receipt_rounded, color: Colors.blue),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sale.invoiceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Rs. ${sale.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp)} | $itemCount Items | ${sale.paymentMethod}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Profit: Rs. ${saleProfit.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: saleProfit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.print_rounded, size: 20),
                          tooltip: 'Re-print Receipt',
                          onPressed: () async {
                            final paper = await PrintHelper.showPaperSizeMenu(context);
                            if (paper == null) return;
                            final itemsList = jsonDecode(sale.itemsJson) as List;
                            final pdfBytes = await PrintHelper.generateInvoiceForPaperSize(
                              paperSize: paper,
                              sale: sale,
                              items: itemsList,
                              cashierName: 'Cashier',
                              storeProfile: ref.read(storeProfileProvider),
                            );
                            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 2: STOCK PURCHASES LIST DETAIL SCREEN ─────────────────────────────
  Widget _buildPurchasesTab({
    required String monthYearTitle,
    required List<PurchaseModel> monthlyPurchases,
  }) {
    final db = ref.watch(localDbServiceProvider);
    final filteredPurchases = monthlyPurchases.where((p) {
      return _purchaseSearch.isEmpty ||
          p.invoiceNumber.toLowerCase().contains(_purchaseSearch.toLowerCase());
    }).toList();

    final double totalAmount = filteredPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);

    return Column(
      children: [
        _buildTabActionHeader(
          title: 'Stock Purchases List ($monthYearTitle)',
          onPdfPrint: () async {
            final paper = await PrintHelper.showPaperSizeMenu(context);
            if (paper == null) return;
            final pdfBytes = await ExcelPdfExportHelper.exportPurchasesToPdf(
              filteredPurchases,
              reportTitle: 'PURCHASES REPORT - $monthYearTitle',
              storeProfile: ref.read(storeProfileProvider),
              pageFormat: paper.format,
            );
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          },
          onExcelExport: () async {
            final bytes = await ExcelPdfExportHelper.exportPurchasesToExcel(filteredPurchases);
            if (context.mounted) {
              await _saveExcelFile(context, bytes, 'Purchases_Report_${_selectedMonth}_$_selectedYear');
            }
          },
        ),

        const SizedBox(height: 16),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Purchase Invoice Number...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => setState(() => _purchaseSearch = val),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Purchases Bills: ${filteredPurchases.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Purchasing: Rs. ${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 16),
                    ),
                  ],
                ),

                const Divider(height: 24),

                if (filteredPurchases.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No stock purchase bills found.')),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPurchases.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = filteredPurchases[i];
                      final supp = db.suppliersBox.get(p.supplierId);
                      final companyName = (supp != null && supp.name.isNotEmpty) ? supp.name : 'General / Manual Entry';

                      String stockItemsStr = '';
                      double totalUnits = 0;
                      try {
                        final List<dynamic> items = jsonDecode(p.itemsJson);
                        final List<String> names = [];
                        for (final item in items) {
                          final name = item['name'] ?? item['productName'] ?? 'Item';
                          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                          totalUnits += qty;
                          names.add('$name ($qty)');
                        }
                        stockItemsStr = names.join(', ');
                      } catch (_) {}

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade50,
                          child: const Icon(Icons.shopping_bag_rounded, color: Colors.amber),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Company: $companyName (${p.invoiceNumber})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Rs. ${p.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 3),
                            Text(
                              '📦 Stock Purchased: ${stockItemsStr.isNotEmpty ? stockItemsStr : "$totalUnits Units"}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '📅 ${DateFormat('dd MMM yyyy, hh:mm a').format(p.timestamp)} | Paid: Rs. ${p.paidAmount.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 3: EXPENSES LIST DETAIL SCREEN ────────────────────────────────────
  Widget _buildExpensesTab({
    required String monthYearTitle,
    required List<ExpenseModel> monthlyExpenses,
  }) {
    final filteredExpenses = monthlyExpenses.where((e) {
      final matchesSearch = _expenseSearch.isEmpty ||
          e.title.toLowerCase().contains(_expenseSearch.toLowerCase());
      final matchesCat = _expenseCategoryFilter == 'All' || e.category == _expenseCategoryFilter;
      return matchesSearch && matchesCat;
    }).toList();

    final double totalExp = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        _buildTabActionHeader(
          title: 'Expenses List ($monthYearTitle)',
          onPdfPrint: () async {
            final paper = await PrintHelper.showPaperSizeMenu(context);
            if (paper == null) return;
            final pdfBytes = await ExcelPdfExportHelper.exportExpensesToPdf(
              filteredExpenses,
              reportTitle: 'EXPENSES REPORT - $monthYearTitle',
              storeProfile: ref.read(storeProfileProvider),
              pageFormat: paper.format,
            );
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          },
          onExcelExport: () async {
            final bytes = await ExcelPdfExportHelper.exportExpensesToExcel(filteredExpenses);
            if (context.mounted) {
              await _saveExcelFile(context, bytes, 'Expenses_Report_${_selectedMonth}_$_selectedYear');
            }
          },
        ),

        const SizedBox(height: 16),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search Expense Title...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) => setState(() => _expenseSearch = val),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Expenses Entries: ${filteredExpenses.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Expense: Rs. ${totalExp.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 16),
                    ),
                  ],
                ),

                const Divider(height: 24),

                if (filteredExpenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No expense records found.')),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredExpenses.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = filteredExpenses[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.red),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Rs. ${e.amount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${e.category} | ${DateFormat('dd MMM yyyy, hh:mm a').format(e.timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 4: INVENTORY STOCK VALUATION DETAIL SCREEN ─────────────────────────
  Widget _buildInventoryTab({
    required List<ProductModel> products,
  }) {
    final filteredProducts = products.where((p) {
      final matchesSearch = _inventorySearch.isEmpty ||
          p.name.toLowerCase().contains(_inventorySearch.toLowerCase()) ||
          (p.sku != null && p.sku!.toLowerCase().contains(_inventorySearch.toLowerCase()));
      return matchesSearch;
    }).toList();

    final double totalCostVal = filteredProducts.fold(0.0, (sum, p) => sum + (p.stock * p.purchasePrice));
    final double totalRetailVal = filteredProducts.fold(0.0, (sum, p) => sum + (p.stock * p.retailPrice));

    return Column(
      children: [
        _buildTabActionHeader(
          title: 'Current Inventory Stock Report',
          onPdfPrint: () async {
            final paper = await PrintHelper.showPaperSizeMenu(context);
            if (paper == null) return;
            final pdfBytes = await ExcelPdfExportHelper.exportInventoryToPdf(
              filteredProducts,
              storeProfile: ref.read(storeProfileProvider),
              pageFormat: paper.format,
            );
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          },
          onExcelExport: () async {
            final bytes = await ExcelHelper.exportProductsToExcel(filteredProducts);
            if (context.mounted) {
              await _saveExcelFile(context, bytes, 'Inventory_Stock_Report_${DateTime.now().millisecondsSinceEpoch}');
            }
          },
        ),

        const SizedBox(height: 16),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Product Name or SKU...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => setState(() => _inventorySearch = val),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Products Count: ${filteredProducts.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Stock Retail Value: Rs. ${totalRetailVal.toStringAsFixed(0)} (Cost: Rs. ${totalCostVal.toStringAsFixed(0)})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 14),
                    ),
                  ],
                ),

                const Divider(height: 24),

                if (filteredProducts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No inventory products found.')),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(10), child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(10), child: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Sale Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Stock Units', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Stock Worth (Retail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                          ],
                        ),
                        ...filteredProducts.map((p) {
                          final worth = p.stock * p.retailPrice;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(p.name, style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(p.sku ?? '-', style: const TextStyle(fontSize: 13))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Rs. ${p.purchasePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Rs. ${p.retailPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${p.stock} ${p.unit}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Rs. ${worth.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 5: DAY-BY-DAY MONTHLY SUMMARY SCREEN ─────────────────────────────
  Widget _buildDayByDayTab({
    required String monthYearTitle,
    required List<SaleModel> monthlySales,
    required List<PurchaseModel> monthlyPurchases,
    required List<ExpenseModel> monthlyExpenses,
  }) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final List<Map<String, dynamic>> dailySummary = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final daySales = monthlySales.where((s) => s.timestamp.day == day).toList();
      final dayPurchases = monthlyPurchases.where((p) => p.timestamp.day == day).toList();
      final dayExpenses = monthlyExpenses.where((e) => e.timestamp.day == day).toList();

      final double salesTotal = daySales.fold(0.0, (sum, s) => sum + s.total);
      final double purTotal = dayPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
      final double expTotal = dayExpenses.fold(0.0, (sum, e) => sum + e.amount);

      double dayCogs = 0.0;
      for (final sale in daySales) {
        try {
          final items = jsonDecode(sale.itemsJson) as List;
          for (final item in items) {
            final qty = (item['quantity'] as num).toDouble();
            double cost = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;
            dayCogs += (cost * qty);
          }
        } catch (_) {}
      }

      final dayProfit = salesTotal - dayCogs - expTotal;

      if (daySales.isNotEmpty || dayPurchases.isNotEmpty || dayExpenses.isNotEmpty) {
        dailySummary.add({
          'day': day,
          'date': DateTime(_selectedYear, _selectedMonth, day),
          'invoicesCount': daySales.length,
          'sales': salesTotal,
          'purchases': purTotal,
          'expenses': expTotal,
          'profit': dayProfit,
        });
      }
    }

    return Column(
      children: [
        _buildTabActionHeader(
          title: 'Day-by-Day Monthly Performance ($monthYearTitle)',
          onPdfPrint: () async {
            final paper = await PrintHelper.showPaperSizeMenu(context);
            if (paper == null) return;
            final pdfBytes = await ExcelPdfExportHelper.exportBusinessReportToPdf(
              sales: monthlySales,
              currentProducts: [],
              monthYearTitle: 'Daily Performance - $monthYearTitle',
              storeProfile: ref.read(storeProfileProvider),
              pageFormat: paper.format,
            );
            await Printing.layoutPdf(onLayout: (format) => pdfBytes);
          },
        ),

        const SizedBox(height: 16),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFF9333EA)),
                    const SizedBox(width: 8),
                    const Text(
                      'Day-by-Day Performance Summary Table',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (dailySummary.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No daily activity found for this month.')),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(10), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Sales (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Purchases (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Expenses (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(10), child: Text('Day Profit (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                          ],
                        ),
                        ...dailySummary.map((d) {
                          final DateTime dt = d['date'];
                          final double profit = d['profit'];
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(DateFormat('dd MMM (EEE)').format(dt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${d['invoicesCount']}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Rs. ${(d['sales'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Rs. ${(d['purchases'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Rs. ${(d['expenses'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  'Rs. ${profit.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: profit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── REUSABLE TAB ACTION HEADER WIDGET ──────────────────────────────────────
  Widget _buildTabActionHeader({
    required String title,
    required VoidCallback onPdfPrint,
    VoidCallback? onExcelExport,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onPdfPrint,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print / PDF Report'),
                ),
                if (onExcelExport != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onExcelExport,
                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                    label: const Text('Export Excel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    bool isNegative = false,
    bool isCurrency = true,
    double fontSize = 14,
    Color? color,
  }) {
    final displayVal = isCurrency
        ? '${isNegative ? "- " : ""}Rs. ${value.abs().toStringAsFixed(0)}'
        : value.toStringAsFixed(0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          displayVal,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isNegative ? Colors.red.shade700 : null),
          ),
        ),
      ],
    );
  }
}
