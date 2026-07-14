import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/models/sale_model.dart';
import '../constants/app_constants.dart';

class PrintHelper {
  static Future<void> _loadFonts() async {
    // Fonts are not needed if using standard courier
  }

  static pw.TextStyle _ts(pw.Font? f, {double? size, pw.FontWeight? weight, PdfColor? color}) {
    final base = pw.Font.helvetica();
    return pw.TextStyle(font: base, fontSize: size, fontWeight: weight, color: color);
  }

  static pw.Widget _buildPdfHeader(pw.Font? f, {bool isThermal = false}) {
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'HUSSNAIN TRADERS',
            style: _ts(null, size: isThermal ? 16 : 24, weight: pw.FontWeight.bold, color: PdfColors.red700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text('Proprietor: ${StoreDetails.proprietorEnglish}',
              style: _ts(f, size: isThermal ? 9 : 12, color: PdfColors.blue800)),
          pw.Text(StoreDetails.contact,
              style: _ts(f, size: isThermal ? 9 : 12, weight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Ghosia Market Sikandar Chowk Pakpattan',
                textAlign: pw.TextAlign.center,
                style: _ts(null, size: isThermal ? 7 : 10, color: PdfColors.white)),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> generateThermalReceipt({
    required SaleModel sale,
    required List<dynamic> items,
    required String cashierName,
    String? customerName,
    String? customerPhone,
  }) async {
    await _loadFonts();
    pw.Font? f;
    final fb = pw.Font.helvetica();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(
          marginLeft: 2 * PdfPageFormat.mm,
          marginRight: 2 * PdfPageFormat.mm,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildPdfHeader(f, isThermal: true),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv: ${sale.invoiceNumber}', style: pw.TextStyle(fontSize: 7, font: fb)),
                  pw.Text(DateFormat('dd-MM-yy HH:mm').format(sale.timestamp), style: pw.TextStyle(fontSize: 7, font: fb)),
                ],
              ),
              if (customerName != null) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Customer: $customerName', style: pw.TextStyle(fontSize: 8, font: fb)),
                ),
                if (customerPhone != null && customerPhone.isNotEmpty)
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Phone: $customerPhone', style: pw.TextStyle(fontSize: 8, font: fb)),
                  ),
              ],
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, font: fb))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty x Price', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, font: fb), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, font: fb), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 2),
              ...items.map((item) {
                final name = (item['name'] as String).replaceAll(RegExp(r'[^\x20-\x7E]'), '');
                final brand = (item['brand'] as String? ?? '').replaceAll(RegExp(r'[^\x20-\x7E]'), '');
                final qty = (item['quantity'] as num).toDouble();
                final price = (item['unitPrice'] as num).toDouble();
                final total = (item['total'] as num).toDouble();
                final displayName = brand.isNotEmpty ? '$name ($brand)' : name;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(displayName, style: pw.TextStyle(fontSize: 6, font: fb))),
                      pw.Expanded(flex: 2, child: pw.Text('${qty.toStringAsFixed(0)}x${price.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 6, font: fb), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(total.toStringAsFixed(0), style: pw.TextStyle(fontSize: 6, font: fb), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 7, font: fb)), pw.Text('Rs. ${sale.subtotal.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 7, font: fb))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount:', style: pw.TextStyle(fontSize: 7, font: fb)), pw.Text('Rs. ${sale.discount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 7, font: fb))]),
              pw.Divider(thickness: 1),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fb)),
                pw.Text('Rs. ${sale.total.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fb)),
              ]),
              pw.Divider(thickness: 1),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Paid:', style: pw.TextStyle(fontSize: 7, font: fb)), pw.Text('Rs. ${sale.paidAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 7, font: fb))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Change:', style: pw.TextStyle(fontSize: 7, font: fb)), pw.Text('Rs. ${sale.changeAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 7, font: fb))]),
              pw.SizedBox(height: 8),
              pw.Text('Thank you!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: fb), textAlign: pw.TextAlign.center),
              pw.Text('Cashier: $cashierName', style: pw.TextStyle(fontSize: 7, font: fb), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('Developed by Vivid Digital Nexus', style: pw.TextStyle(fontSize: 6, font: fb), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateA4Invoice({
    required SaleModel sale,
    required List<dynamic> items,
    required String cashierName,
    String? customerName,
    String? customerPhone,
  }) async {
    await _loadFonts();
    pw.Font? f;
    final fb = pw.Font.helvetica();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(f, isThermal: false),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb, fontSize: 10)),
                      pw.Text(customerName ?? 'Walk-in Customer', style: pw.TextStyle(fontSize: 13, font: fb)),
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        pw.Text('Phone: $customerPhone', style: pw.TextStyle(font: fb)),
                      pw.Text('Payment: ${sale.paymentMethod}', style: pw.TextStyle(font: fb)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal, font: fb)),
                      pw.Text('No: ${sale.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy HH:mm').format(sale.timestamp)}', style: pw.TextStyle(font: fb)),
                      pw.Text('Cashier: $cashierName', style: pw.TextStyle(font: fb)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: const pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                  outside: const pw.BorderSide(width: 1, color: PdfColors.grey400),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.5),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Disc.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fb))),
                    ],
                  ),
                  ...items.map((item) {
                    final name = (item['name'] as String).replaceAll(RegExp(r'[^\x20-\x7E]'), '');
                    final brand = (item['brand'] as String? ?? '').replaceAll(RegExp(r'[^\x20-\x7E]'), '');
                    final category = (item['category'] as String? ?? '').replaceAll(RegExp(r'[^\x20-\x7E]'), '');
                    String displayName = name;
                    if (brand.isNotEmpty || category.isNotEmpty) {
                      final parts = [if (brand.isNotEmpty) brand, if (category.isNotEmpty) category].join(' - ');
                      displayName = '$name ($parts)';
                    }
                    final price = (item['unitPrice'] as num).toDouble();
                    final qty = (item['quantity'] as num).toDouble();
                    final disc = ((item['discount'] as num?) ?? 0.0).toDouble();
                    final total = (item['total'] as num).toDouble();
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(displayName, style: pw.TextStyle(font: fb))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs.${price.toStringAsFixed(0)}', style: pw.TextStyle(font: fb))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(qty.toStringAsFixed(0), style: pw.TextStyle(font: fb))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs.${disc.toStringAsFixed(0)}', style: pw.TextStyle(font: fb))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs.${total.toStringAsFixed(0)}', style: pw.TextStyle(font: fb))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _summaryRow('Subtotal:', 'Rs. ${sale.subtotal.toStringAsFixed(2)}', fb),
                        pw.SizedBox(height: 4),
                        _summaryRow('Discount:', 'Rs. ${sale.discount.toStringAsFixed(2)}', fb),
                        pw.SizedBox(height: 6),
                        pw.Divider(thickness: 1.5),
                        _summaryRow('TOTAL:', 'Rs. ${sale.total.toStringAsFixed(2)}', fb, bold: true, fontSize: 14),
                        pw.Divider(thickness: 1),
                        pw.SizedBox(height: 4),
                        _summaryRow('Paid Amount:', 'Rs. ${sale.paidAmount.toStringAsFixed(2)}', fb),
                        pw.SizedBox(height: 4),
                        _summaryRow('Balance/Change:', 'Rs. ${sale.changeAmount.toStringAsFixed(2)}', fb),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(child: pw.Text('Thank you for shopping with HUSSNAIN TRADERS!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic, font: fb))),
              pw.Center(child: pw.Text('Developed by Vivid Digital Nexus | WhatsApp: +923285753463', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, font: fb))),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _summaryRow(String label, String value, pw.Font fb, {bool bold = false, double fontSize = 11}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: fb, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : null)),
        pw.Text(value, style: pw.TextStyle(font: fb, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : null)),
      ],
    );
  }
}
