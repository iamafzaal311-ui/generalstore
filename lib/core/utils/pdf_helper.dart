import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/models/product_model.dart';
import 'print_helper.dart';
import '../../data/models/expense_model.dart';

/// Helper for generating simple summary PDF documents (for products/expenses).
/// For sales invoices and receipt printing, see [PrintHelper].
class PdfHelper {
  /// Generate a products stock report in PDF format.
  static Future<Uint8List> generateProductStockReport(
    List<ProductModel> products, {
    String title = 'Product Stock Report',
  }) async {
    await PrintHelper.loadFonts();
    final pdf = pw.Document(theme: PrintHelper.pdfTheme);
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AL-MAKKAH GENERAL STORE',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(now)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _tableHeader('Product Name'),
                  _tableHeader('SKU'),
                  _tableHeader('Unit'),
                  _tableHeader('Stock'),
                  _tableHeader('Purchase Price'),
                  _tableHeader('Retail Price'),
                ],
              ),
              // Rows
              ...products.map(
                (p) => pw.TableRow(
                  children: [
                    _tableCell(p.name),
                    _tableCell(p.sku ?? '-'),
                    _tableCell(p.unit),
                    _tableCell(p.stock.toStringAsFixed(2)),
                    _tableCell('Rs. ${p.purchasePrice.toStringAsFixed(2)}'),
                    _tableCell('Rs. ${p.retailPrice.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Total Products: ${products.length}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generate an expenses report in PDF format.
  static Future<Uint8List> generateExpensesReport(
    List<ExpenseModel> expenses, {
    String title = 'Expenses Report',
  }) async {
    await PrintHelper.loadFonts();
    final pdf = pw.Document(theme: PrintHelper.pdfTheme);
    final now = DateTime.now();
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AL-MAKKAH GENERAL STORE',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(now)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.orange50),
                children: [
                  _tableHeader('Title'),
                  _tableHeader('Category'),
                  _tableHeader('Date'),
                  _tableHeader('Amount'),
                ],
              ),
              ...expenses.map(
                (e) => pw.TableRow(
                  children: [
                    _tableCell(e.title),
                    _tableCell(e.category),
                    _tableCell(DateFormat('dd-MM-yyyy').format(e.timestamp)),
                    _tableCell('Rs. ${e.amount.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total Expenses: Rs. ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}
