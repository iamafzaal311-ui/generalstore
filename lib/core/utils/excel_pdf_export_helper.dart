import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'print_helper.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/store_profile_model.dart';

class ExcelPdfExportHelper {
  static Future<Uint8List> exportSalesToExcel(List<SaleModel> sales) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Sales Report'];
    excel.delete('Sheet1');

    sheet.appendRow([
      ex.TextCellValue('Invoice Number'),
      ex.TextCellValue('Date'),
      ex.TextCellValue('Subtotal'),
      ex.TextCellValue('Discount'),
      ex.TextCellValue('Grand Total'),
      ex.TextCellValue('Payment Method'),
    ]);

    for (final sale in sales) {
      sheet.appendRow([
        ex.TextCellValue(sale.invoiceNumber),
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp)),
        ex.DoubleCellValue(sale.subtotal),
        ex.DoubleCellValue(sale.discount),
        ex.DoubleCellValue(sale.total),
        ex.TextCellValue(sale.paymentMethod),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  static Future<Uint8List> exportSalesToPdf(
    List<SaleModel> sales, {
    String reportTitle = 'SALES REPORT',
    StoreProfileModel? storeProfile,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.a4;
    final theme = await PrintHelper.getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    final urduFont = await PrintHelper.getUrduFont();
    final vdnLogo = await PrintHelper.getVdnLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => PrintHelper.buildPdfFooter(urduFont, vdnLogo, isThermal: false),
        build: (pw.Context context) {
          return [
            PrintHelper.buildPdfHeader(
              urduFont,
              isThermal: false,
              profile: storeProfile,
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  width: 0.5,
                  color: PdfColors.grey300,
                ),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Invoice No',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Date',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Subtotal',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Discount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Total Pay',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...sales.map((s) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(s.invoiceNumber),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          DateFormat('dd-MM-yy').format(s.timestamp),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Rs. ${s.subtotal.toStringAsFixed(0)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Rs. ${s.discount.toStringAsFixed(0)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Rs. ${s.total.toStringAsFixed(0)}'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> exportInventoryToPdf(
    List<ProductModel> products, {
    StoreProfileModel? storeProfile,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.a4;
    final theme = await PrintHelper.getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    final urduFont = await PrintHelper.getUrduFont();
    final vdnLogo = await PrintHelper.getVdnLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => PrintHelper.buildPdfFooter(urduFont, vdnLogo, isThermal: false),
        build: (pw.Context context) {
          return [
            PrintHelper.buildPdfHeader(
              urduFont,
              isThermal: false,
              profile: storeProfile,
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'INVENTORY STOCK REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  width: 0.5,
                  color: PdfColors.grey300,
                ),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Product Name',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'SKU',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Purchase Cost',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Retail Price',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Current Stock',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...products.map((p) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          p.name,
                          textDirection: PrintHelper.hasUrdu(p.name) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                          textAlign: PrintHelper.hasUrdu(p.name) ? pw.TextAlign.right : pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(p.sku ?? '-'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Rs. ${p.purchasePrice.toStringAsFixed(0)}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Rs. ${p.retailPrice.toStringAsFixed(0)}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${p.stock} ${p.unit}'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> exportBusinessReportToPdf({
    required List<SaleModel> sales,
    required List<ProductModel> currentProducts,
    required String monthYearTitle,
    double totalExpenses = 0.0,
    StoreProfileModel? storeProfile,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.a4;
    final theme = await PrintHelper.getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    final urduFont = await PrintHelper.getUrduFont();
    final vdnLogo = await PrintHelper.getVdnLogo();

    double totalRevenue = 0.0;
    double totalCost = 0.0;
    final Map<String, int> productSalesCount = {};
    final Map<String, double> productSalesRevenue = {};

    for (final sale in sales) {
      totalRevenue += sale.total;

      try {
        final List<dynamic> items = jsonDecode(sale.itemsJson);
        for (final item in items) {
          final productId = item['productId'] as String?;
          final name = item['name'] ?? item['productName'] ?? 'Unknown Item';
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final revenue = (item['total'] as num?)?.toDouble() ?? 0.0;

          double costPrice = 0.0;
          if (item.containsKey('purchasePrice') &&
              item['purchasePrice'] != null) {
            costPrice = (item['purchasePrice'] as num).toDouble();
          } else if (productId != null) {
            final product = currentProducts
                .where((p) => p.productId == productId)
                .firstOrNull;
            if (product != null) {
              costPrice = product.purchasePrice;
            }
          }

          totalCost += (costPrice * qty);

          productSalesCount[name] = (productSalesCount[name] ?? 0) + qty;
          productSalesRevenue[name] =
              (productSalesRevenue[name] ?? 0.0) + revenue;
        }
      } catch (e) {
        // skip invalid json
      }
    }

    final grossProfit = totalRevenue - totalCost;
    final netGrandProfit = grossProfit - totalExpenses;

    // Sort products by quantity sold
    final sortedProducts = productSalesCount.keys.toList()
      ..sort((a, b) => productSalesCount[b]!.compareTo(productSalesCount[a]!));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => PrintHelper.buildPdfFooter(urduFont, vdnLogo, isThermal: false),
        build: (pw.Context context) {
          return [
            PrintHelper.buildPdfHeader(
              urduFont,
              isThermal: false,
              profile: storeProfile,
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MONTHLY BUSINESS REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  monthYearTitle,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FINANCIAL STATEMENT & PROFIT SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Gross Sales Revenue:'),
                      pw.Text(
                        'Rs. ${totalRevenue.toStringAsFixed(0)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cost of Goods Sold (COGS):'),
                      pw.Text('- Rs. ${totalCost.toStringAsFixed(0)}'),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Gross Profit (Before Expense Deduction):',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Rs. ${grossProfit.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: grossProfit >= 0 ? PdfColors.green800 : PdfColors.red800),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Operating Expenses Deducted:'),
                      pw.Text('- Rs. ${totalExpenses.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: netGrandProfit >= 0 ? PdfColors.green100 : PdfColors.red50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: netGrandProfit >= 0 ? PdfColors.green300 : PdfColors.red200),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Grand Net Profit (After Expense Deduction):',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Text(
                          'Rs. ${netGrandProfit.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: netGrandProfit >= 0 ? PdfColors.green900 : PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'PRODUCT SALES ANALYSIS',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Product Name',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Qty Sold',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Revenue',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                ...sortedProducts.map((name) {
                  final qty = productSalesCount[name]!;
                  final rev = productSalesRevenue[name]!;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          name,
                          textDirection: PrintHelper.hasUrdu(name) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                          textAlign: PrintHelper.hasUrdu(name) ? pw.TextAlign.right : pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          qty.toString(),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Rs. ${rev.toStringAsFixed(0)}',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
                if (sortedProducts.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          'No sales data found for this period.',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(),
                      pw.SizedBox(),
                    ],
                  ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> exportFullMonthlyReportToExcel({
    required String monthYearTitle,
    required List<SaleModel> sales,
    required List<ExpenseModel> expenses,
    required List<PurchaseModel> purchases,
    required List<ProductModel> products,
    required double totalSales,
    required double totalCogs,
    required double grossProfit,
    required double totalExpenses,
    required double netProfit,
    required double totalPurchases,
    required double stockWorthCost,
    required double stockWorthRetail,
  }) async {
    final excel = ex.Excel.createExcel();

    // Sheet 1: Financial Summary
    final summarySheet = excel['Financial Summary'];
    excel.delete('Sheet1');

    summarySheet.appendRow([ex.TextCellValue('MONTHLY BUSINESS REPORT'), ex.TextCellValue(monthYearTitle)]);
    summarySheet.appendRow([ex.TextCellValue('')]);
    summarySheet.appendRow([ex.TextCellValue('Metric'), ex.TextCellValue('Amount (PKR)')]);
    summarySheet.appendRow([ex.TextCellValue('Total Sales Revenue'), ex.DoubleCellValue(totalSales)]);
    summarySheet.appendRow([ex.TextCellValue('Cost of Goods Sold (COGS)'), ex.DoubleCellValue(totalCogs)]);
    summarySheet.appendRow([ex.TextCellValue('Gross Profit'), ex.DoubleCellValue(grossProfit)]);
    summarySheet.appendRow([ex.TextCellValue('Total Operating Expenses'), ex.DoubleCellValue(totalExpenses)]);
    summarySheet.appendRow([ex.TextCellValue('Net Profit / (Loss)'), ex.DoubleCellValue(netProfit)]);
    summarySheet.appendRow([ex.TextCellValue('Total Stock Purchases (This Month)'), ex.DoubleCellValue(totalPurchases)]);
    summarySheet.appendRow([ex.TextCellValue('Current Inventory Worth (Purchase Price)'), ex.DoubleCellValue(stockWorthCost)]);
    summarySheet.appendRow([ex.TextCellValue('Current Inventory Worth (Retail Price)'), ex.DoubleCellValue(stockWorthRetail)]);

    // Sheet 2: Sales History
    final salesSheet = excel['Sales Record'];
    salesSheet.appendRow([
      ex.TextCellValue('Invoice Number'),
      ex.TextCellValue('Date'),
      ex.TextCellValue('Subtotal'),
      ex.TextCellValue('Discount'),
      ex.TextCellValue('Grand Total'),
      ex.TextCellValue('Payment Method'),
    ]);
    for (final sale in sales) {
      salesSheet.appendRow([
        ex.TextCellValue(sale.invoiceNumber),
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp)),
        ex.DoubleCellValue(sale.subtotal),
        ex.DoubleCellValue(sale.discount),
        ex.DoubleCellValue(sale.total),
        ex.TextCellValue(sale.paymentMethod),
      ]);
    }

    // Sheet 3: Expenses Record
    final expSheet = excel['Expenses Record'];
    expSheet.appendRow([
      ex.TextCellValue('Title'),
      ex.TextCellValue('Category'),
      ex.TextCellValue('Amount'),
      ex.TextCellValue('Date'),
    ]);
    for (final exp in expenses) {
      expSheet.appendRow([
        ex.TextCellValue(exp.title),
        ex.TextCellValue(exp.category),
        ex.DoubleCellValue(exp.amount),
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(exp.timestamp)),
      ]);
    }

    // Sheet 4: Stock Purchases Record
    final purSheet = excel['Stock Purchases'];
    purSheet.appendRow([
      ex.TextCellValue('Invoice Number'),
      ex.TextCellValue('Total Amount'),
      ex.TextCellValue('Paid Amount'),
      ex.TextCellValue('Date'),
    ]);
    for (final pur in purchases) {
      purSheet.appendRow([
        ex.TextCellValue(pur.invoiceNumber),
        ex.DoubleCellValue(pur.totalAmount),
        ex.DoubleCellValue(pur.paidAmount),
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(pur.timestamp)),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  static Future<Uint8List> exportPurchasesToPdf(
    List<PurchaseModel> purchases, {
    Map<String, String>? supplierNamesMap,
    String reportTitle = 'STOCK PURCHASES REPORT',
    StoreProfileModel? storeProfile,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.a4;
    final theme = await PrintHelper.getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    final urduFont = await PrintHelper.getUrduFont();
    final vdnLogo = await PrintHelper.getVdnLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => PrintHelper.buildPdfFooter(urduFont, vdnLogo, isThermal: false),
        build: (pw.Context context) {
          return [
            PrintHelper.buildPdfHeader(urduFont, isThermal: false, profile: storeProfile),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(reportTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            ...purchases.map((p) {
              final companyName = supplierNamesMap?[p.supplierId] ?? 'General / Company Supplier';
              List<dynamic> items = [];
              try {
                items = jsonDecode(p.itemsJson) as List<dynamic>;
              } catch (_) {}

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Company Name & Invoice Info
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.amber100,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(5),
                          topRight: pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'COMPANY: $companyName',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                          pw.Text(
                            'Inv #: ${p.invoiceNumber}  |  ${DateFormat('dd MMM yyyy, hh:mm a').format(p.timestamp)}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ),

                    // Items Purchased List Table
                    pw.Table(
                      border: const pw.TableBorder(
                        horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey200),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1.5),
                        3: const pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: pw.Text('Item / Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: pw.Text('Total Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                            ),
                          ],
                        ),
                        ...items.map((item) {
                          final name = item['name'] ?? item['productName'] ?? 'Item';
                          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                          final price = (item['purchasePrice'] as num?)?.toDouble() ?? (item['unitPrice'] as num?)?.toDouble() ?? 0;
                          final total = (item['total'] as num?)?.toDouble() ?? (price * qty);

                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: pw.Text(
                                  name,
                                  textDirection: PrintHelper.hasUrdu(name) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                                  textAlign: PrintHelper.hasUrdu(name) ? pw.TextAlign.right : pw.TextAlign.left,
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: pw.Text('Rs. ${price.toStringAsFixed(0)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: pw.Text('Rs. ${total.toStringAsFixed(0)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),

                    // Invoice Footer Bar
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey50,
                        border: pw.Border(top: pw.BorderSide(width: 0.5, color: PdfColors.grey300)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Paid: Rs. ${p.paidAmount.toStringAsFixed(0)}  |  Balance Due: Rs. ${(p.totalAmount - p.paidAmount).toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            'Total Purchasing: Rs. ${p.totalAmount.toStringAsFixed(0)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.amber900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> exportExpensesToPdf(
    List<ExpenseModel> expenses, {
    String reportTitle = 'EXPENSES REPORT',
    StoreProfileModel? storeProfile,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.a4;
    final theme = await PrintHelper.getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    final urduFont = await PrintHelper.getUrduFont();
    final vdnLogo = await PrintHelper.getVdnLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => PrintHelper.buildPdfFooter(urduFont, vdnLogo, isThermal: false),
        build: (pw.Context context) {
          return [
            PrintHelper.buildPdfHeader(urduFont, isThermal: false, profile: storeProfile),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(reportTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.red50),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...expenses.map((e) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.title)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.category)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('dd MMM yyyy').format(e.timestamp))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${e.amount.toStringAsFixed(0)}')),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> exportExpensesToExcel(List<ExpenseModel> expenses) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Expenses Report'];
    excel.delete('Sheet1');

    sheet.appendRow([
      ex.TextCellValue('Title'),
      ex.TextCellValue('Category'),
      ex.TextCellValue('Amount'),
      ex.TextCellValue('Date'),
    ]);

    for (final e in expenses) {
      sheet.appendRow([
        ex.TextCellValue(e.title),
        ex.TextCellValue(e.category),
        ex.DoubleCellValue(e.amount),
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(e.timestamp)),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  static Future<Uint8List> exportPurchasesToExcel(List<PurchaseModel> purchases) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Purchases Report'];
    excel.delete('Sheet1');

    sheet.appendRow([
      ex.TextCellValue('Invoice Number'),
      ex.TextCellValue('Total Amount'),
      ex.TextCellValue('Paid Amount'),
      ex.TextCellValue('Date'),
    ]);

    for (final p in purchases) {
      sheet.appendRow([
        ex.TextCellValue(p.invoiceNumber),
        ex.DoubleCellValue(p.totalAmount),
        ex.DoubleCellValue(p.paidAmount),
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(p.timestamp)),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }
}
