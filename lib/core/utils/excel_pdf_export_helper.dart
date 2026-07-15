import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'print_helper.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/product_model.dart';

class ExcelPdfExportHelper {
  static Future<Uint8List> exportSalesToExcel(List<SaleModel> sales) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Sales Report'];

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

  static Future<Uint8List> exportSalesToPdf(List<SaleModel> sales, {String reportTitle = 'SALES REPORT'}) async {
    await PrintHelper.loadFonts();
    final pdf = pw.Document(theme: PrintHelper.pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('GENERAL STORE - $reportTitle',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Report Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}'),
            pw.SizedBox(height: 24),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Invoice No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Subtotal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Discount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Pay', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...sales.map((s) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s.invoiceNumber)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('dd-MM-yy').format(s.timestamp))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${s.subtotal.toStringAsFixed(0)}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${s.discount.toStringAsFixed(0)}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${s.total.toStringAsFixed(0)}')),
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

  static Future<Uint8List> exportInventoryToPdf(List<ProductModel> products) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('GENERAL STORE - INVENTORY STOCK REPORT',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            ),
            pw.SizedBox(height: 24),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('SKU', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Purchase Cost', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Retail Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Current Stock', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...products.map((p) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(p.name)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(p.sku ?? '-')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${p.purchasePrice.toStringAsFixed(0)}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${p.retailPrice.toStringAsFixed(0)}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${p.stock} ${p.unit}')),
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
  }) async {
    final pdf = pw.Document();

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
          if (item.containsKey('purchasePrice') && item['purchasePrice'] != null) {
            costPrice = (item['purchasePrice'] as num).toDouble();
          } else if (productId != null) {
            final product = currentProducts.where((p) => p.productId == productId).firstOrNull;
            if (product != null) {
              costPrice = product.purchasePrice;
            }
          }

          totalCost += (costPrice * qty);

          productSalesCount[name] = (productSalesCount[name] ?? 0) + qty;
          productSalesRevenue[name] = (productSalesRevenue[name] ?? 0.0) + revenue;
        }
      } catch (e) {
        // skip invalid json
      }
    }

    final totalProfit = totalRevenue - totalCost;

    // Sort products by quantity sold
    final sortedProducts = productSalesCount.keys.toList()
      ..sort((a, b) => productSalesCount[b]!.compareTo(productSalesCount[a]!));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('MONTHLY BUSINESS REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(monthYearTitle, style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
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
                  pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Revenue (Sales):'),
                      pw.Text('Rs. ${totalRevenue.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Cost of Goods Sold:'),
                      pw.Text('Rs. ${totalCost.toStringAsFixed(0)}'),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Profit / Loss:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Rs. ${totalProfit.toStringAsFixed(0)}', style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, 
                        color: totalProfit >= 0 ? PdfColors.green700 : PdfColors.red700,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text('PRODUCT SALES ANALYSIS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...sortedProducts.map((name) {
                  final qty = productSalesCount[name]!;
                  final rev = productSalesRevenue[name]!;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${rev.toStringAsFixed(0)}', textAlign: pw.TextAlign.right)),
                    ],
                  );
                }),
                if (sortedProducts.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(16), child: pw.Text('No sales data found for this period.', textAlign: pw.TextAlign.center)),
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
}
