import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../data/models/sale_model.dart';
import '../../data/models/store_profile_model.dart';

class PrintHelper {
  static Future<pw.ThemeData> getUrduPdfTheme() async {
    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );
  }

  static pw.TextStyle _ts(pw.Font urduFont, {double? size, pw.FontWeight? weight, PdfColor? color}) {
    return pw.TextStyle(
      fontSize: size, 
      fontWeight: weight, 
      color: color, 
      fontFallback: [urduFont]
    );
  }

  static pw.Widget _buildPdfHeader(pw.Font urduFont, {bool isThermal = false, StoreProfileModel? profile, SaleModel? sale}) {
    final double qrSize = isThermal ? 16 * PdfPageFormat.mm : 22 * PdfPageFormat.mm;

    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      profile?.storeName ?? 'General Store',
                      style: _ts(urduFont, size: isThermal ? 16 : 22, weight: pw.FontWeight.bold, color: PdfColors.red700),
                      textAlign: pw.TextAlign.left,
                    ),
                    pw.SizedBox(height: 2),
                    if (profile?.tagline.isNotEmpty ?? false)
                      pw.Text('Proprietor: ${profile!.tagline}', style: _ts(urduFont, size: isThermal ? 8 : 11, color: PdfColors.blue800, weight: pw.FontWeight.bold)),
                    if (profile?.phone.isNotEmpty ?? false)
                      pw.Text(profile!.phone, style: _ts(urduFont, size: isThermal ? 8 : 11, weight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  ],
                ),
              ),
              if (sale != null) ...[
                pw.SizedBox(width: 4),
                pw.Container(
                  width: qrSize,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'Invoice: ${sale.invoiceNumber}\nTotal: Rs. ${sale.total}\nPSID: ${sale.saleId.hashCode.toString().replaceAll('-', '')}\nDate: ${DateFormat('dd-MM-yy HH:mm').format(sale.timestamp)}',
                        width: qrSize,
                        height: qrSize,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('PSID / Receipt', style: _ts(urduFont, size: isThermal ? 4.5 : 6)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 4),
          if (profile?.address.isNotEmpty ?? false)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(profile!.address,
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: _ts(urduFont, size: isThermal ? 7 : 10, color: PdfColors.white)),
            ),
        ],
      ),
    );
  }

  static Future<Uint8List> generateThermalReceipt({
    required SaleModel sale,
    required List<dynamic> items,
    required String cashierName,
    StoreProfileModel? storeProfile,
    String? customerName,
    String? customerPhone,
  }) async {
    final theme = await getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    
    final urduFontData = await rootBundle.load('assets/fonts/NotoNastaliqUrdu-Regular.ttf');
    final urduFont = pw.Font.ttf(urduFontData);

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
              _buildPdfHeader(urduFont, isThermal: true, profile: storeProfile, sale: sale),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: ${sale.invoiceNumber}', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd-MM-yy HH:mm').format(sale.timestamp), style: _ts(urduFont, size: 7)),
                ],
              ),
              if (customerName != null) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Customer: $customerName', style: _ts(urduFont, size: 8), textDirection: pw.TextDirection.rtl),
                ),
                if (customerPhone != null && customerPhone.isNotEmpty)
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Phone: $customerPhone', style: _ts(urduFont, size: 8)),
                  ),
              ],
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold), textAlign: pw.TextAlign.left)),
                  pw.Expanded(flex: 2, child: pw.Text('Qty x Price', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('Total', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 2),
              ...items.map((item) {
                final name = (item['name'] as String);
                final brand = (item['brand'] as String? ?? '');
                final qty = (item['quantity'] as num).toDouble();
                final price = (item['unitPrice'] as num).toDouble();
                final total = (item['total'] as num).toDouble();
                final displayName = brand.isNotEmpty ? '$name ($brand)' : name;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(displayName, style: _ts(urduFont, size: 6), textAlign: pw.TextAlign.left, textDirection: pw.TextDirection.rtl)),
                      pw.Expanded(flex: 2, child: pw.Text('${qty.toStringAsFixed(0)} x ${price.toStringAsFixed(0)}', style: _ts(urduFont, size: 6), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(total.toStringAsFixed(0), style: _ts(urduFont, size: 6), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold)), pw.Text('Rs. ${sale.subtotal.toStringAsFixed(0)}', style: _ts(urduFont, size: 7))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount:', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold)), pw.Text('- Rs. ${sale.discount.toStringAsFixed(0)}', style: _ts(urduFont, size: 7))]),
              pw.Divider(thickness: 1),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('GRAND TOTAL:', style: _ts(urduFont, size: 10, weight: pw.FontWeight.bold)),
                pw.Text('Rs. ${sale.total.toStringAsFixed(0)}', style: _ts(urduFont, size: 10, weight: pw.FontWeight.bold)),
              ]),
              pw.Divider(thickness: 1),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Paid Amount:', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold)), pw.Text('Rs. ${sale.paidAmount.toStringAsFixed(0)}', style: _ts(urduFont, size: 7))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Change:', style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold)), pw.Text('Rs. ${sale.changeAmount.toStringAsFixed(0)}', style: _ts(urduFont, size: 7))]),
              pw.SizedBox(height: 8),
              
              pw.Text('Thank You!', style: _ts(urduFont, size: 9, weight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.Text('Cashier: $cashierName', style: _ts(urduFont, size: 7), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('Developed by Vivid Digital Nexus', style: _ts(urduFont, size: 6), textAlign: pw.TextAlign.center),
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
    StoreProfileModel? storeProfile,
    String? customerName,
    String? customerPhone,
  }) async {
    final theme = await getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    
    final urduFontData = await rootBundle.load('assets/fonts/NotoNastaliqUrdu-Regular.ttf');
    final urduFont = pw.Font.ttf(urduFontData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(urduFont, isThermal: false, profile: storeProfile, sale: sale),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: _ts(urduFont, weight: pw.FontWeight.bold, size: 10)),
                      pw.Text(customerName ?? 'Walk-in Customer', style: _ts(urduFont, size: 13)),
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        pw.Text('Phone: $customerPhone', style: _ts(urduFont)),
                      pw.Text('Payment: ${sale.paymentMethod}', style: _ts(urduFont)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: _ts(urduFont, size: 22, weight: pw.FontWeight.bold, color: PdfColors.teal)),
                      pw.Text('No: ${sale.invoiceNumber}', style: _ts(urduFont, weight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy HH:mm').format(sale.timestamp)}', style: _ts(urduFont)),
                      pw.Text('Cashier: $cashierName', style: _ts(urduFont)),
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
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product', style: _ts(urduFont, weight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit Price', style: _ts(urduFont, weight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: _ts(urduFont, weight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Disc.', style: _ts(urduFont, weight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: _ts(urduFont, weight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...items.map((item) {
                    final name = (item['name'] as String);
                    final brand = (item['brand'] as String? ?? '');
                    final category = (item['category'] as String? ?? '');
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
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(displayName, style: _ts(urduFont), textDirection: pw.TextDirection.rtl)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs.${price.toStringAsFixed(0)}', style: _ts(urduFont))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(qty.toStringAsFixed(0), style: _ts(urduFont))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs.${disc.toStringAsFixed(0)}', style: _ts(urduFont))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs.${total.toStringAsFixed(0)}', style: _ts(urduFont))),
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
                        _summaryRow(urduFont, 'Subtotal:', 'Rs. ${sale.subtotal.toStringAsFixed(2)}'),
                        pw.SizedBox(height: 4),
                        _summaryRow(urduFont, 'Discount:', 'Rs. ${sale.discount.toStringAsFixed(2)}'),
                        pw.SizedBox(height: 6),
                        pw.Divider(thickness: 1.5),
                        _summaryRow(urduFont, 'TOTAL:', 'Rs. ${sale.total.toStringAsFixed(2)}', bold: true, fontSize: 14),
                        pw.Divider(thickness: 1),
                        pw.SizedBox(height: 4),
                        _summaryRow(urduFont, 'Paid Amount:', 'Rs. ${sale.paidAmount.toStringAsFixed(2)}'),
                        pw.SizedBox(height: 4),
                        _summaryRow(urduFont, 'Balance/Change:', 'Rs. ${sale.changeAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(child: pw.Text('Thank you for shopping with ${storeProfile?.storeName.toUpperCase() ?? 'US'}!', style: _ts(urduFont, weight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('Developed by Vivid Digital Nexus | WhatsApp: +923285753463', style: _ts(urduFont, size: 9, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _summaryRow(pw.Font urduFont, String label, String value, {bool bold = false, double fontSize = 11}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: _ts(urduFont, size: fontSize, weight: bold ? pw.FontWeight.bold : null)),
        pw.Text(value, style: _ts(urduFont, size: fontSize, weight: bold ? pw.FontWeight.bold : null)),
      ],
    );
  }
}
