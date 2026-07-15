import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/product_model.dart';

import '../utils/print_helper.dart';

class BarcodePrintService {
  /// Generates a PDF document with barcode labels for the given product.
  /// This can be sent to a label printer.
  static Future<void> printProductBarcodeLabel(ProductModel product, {int count = 1}) async {
    final theme = await PrintHelper.getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);

    final barcodeData = product.barcode ?? product.sku ?? product.productId;

    pdf.addPage(
      pw.MultiPage(
        // Typically label printers use a custom small page format, e.g., 50mm x 30mm
        pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          final List<pw.Widget> labels = [];
          for (int i = 0; i < count; i++) {
            labels.add(
              pw.Container(
                width: 46 * PdfPageFormat.mm,
                height: 26 * PdfPageFormat.mm,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      product.name,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Rs. ${product.retailPrice.toStringAsFixed(0)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: barcodeData,
                      width: 40 * PdfPageFormat.mm,
                      height: 10 * PdfPageFormat.mm,
                      drawText: true,
                      textStyle: const pw.TextStyle(fontSize: 6),
                    ),
                  ],
                ),
              ),
            );
          }
          return labels;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
