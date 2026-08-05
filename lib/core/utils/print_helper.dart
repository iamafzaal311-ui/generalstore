import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../data/models/sale_model.dart';
import '../../data/models/store_profile_model.dart';
import '../../data/datasources/local_db_service.dart';

enum AppPaperSize {
  thermal80(
    name: 'Thermal 80mm',
    description: 'Standard Thermal Receipt (80mm width)',
    icon: Icons.receipt_long,
    format: PdfPageFormat.roll80,
    isThermal: true,
  ),
  thermal58(
    name: 'Thermal 58mm',
    description: 'Mini Thermal Receipt (58mm width)',
    icon: Icons.receipt,
    format: PdfPageFormat.roll57,
    isThermal: true,
  ),
  a4(
    name: 'A4',
    description: 'Standard Document (210 x 297 mm)',
    icon: Icons.description,
    format: PdfPageFormat.a4,
    isThermal: false,
  ),
  a3(
    name: 'A3',
    description: 'Large Sheet (297 x 420 mm)',
    icon: Icons.note,
    format: PdfPageFormat.a3,
    isThermal: false,
  ),
  a5(
    name: 'A5',
    description: 'Half Sheet (148 x 210 mm)',
    icon: Icons.notes,
    format: PdfPageFormat.a5,
    isThermal: false,
  ),
  letter(
    name: 'Letter',
    description: 'US Letter (8.5 x 11 in)',
    icon: Icons.article,
    format: PdfPageFormat.letter,
    isThermal: false,
  ),
  legal(
    name: 'Legal',
    description: 'US Legal (8.5 x 14 in)',
    icon: Icons.assignment,
    format: PdfPageFormat.legal,
    isThermal: false,
  );

  final String name;
  final String description;
  final IconData icon;
  final PdfPageFormat format;
  final bool isThermal;

  const AppPaperSize({
    required this.name,
    required this.description,
    required this.icon,
    required this.format,
    required this.isThermal,
  });
}

class PrintHelper {
  static pw.Font? _cachedUrduFont;

  static bool hasUrdu(String text) {
    final RegExp urduRegExp = RegExp(r'[\u0600-\u06FF]');
    return urduRegExp.hasMatch(text);
  }

  static Future<pw.Font> getUrduFont() async {
    if (_cachedUrduFont != null) return _cachedUrduFont!;
    final urduFontData = await rootBundle.load(
      'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
    );
    _cachedUrduFont = pw.Font.ttf(urduFontData);
    return _cachedUrduFont!;
  }

  static pw.MemoryImage? _cachedVdnLogo;

  static Future<pw.MemoryImage> getVdnLogo() async {
    if (_cachedVdnLogo != null) return _cachedVdnLogo!;
    final byteData = await rootBundle.load('assets/images/vdn_logo.png');
    _cachedVdnLogo = pw.MemoryImage(byteData.buffer.asUint8List());
    return _cachedVdnLogo!;
  }

  static Future<pw.ThemeData> getUrduPdfTheme() async {
    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );
  }

  static pw.TextStyle _ts(
    pw.Font urduFont, {
    double? size,
    pw.FontWeight? weight,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFallback: [urduFont],
    );
  }

  static pw.Widget buildPdfHeader(
    pw.Font urduFont, {
    bool isThermal = false,
    StoreProfileModel? profile,
    SaleModel? sale,
  }) {
    final double qrSize = isThermal
        ? 16 * PdfPageFormat.mm
        : 22 * PdfPageFormat.mm;

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
                      style: _ts(
                        urduFont,
                        size: isThermal ? 16 : 22,
                        weight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                      textAlign: pw.TextAlign.left,
                    ),
                    pw.SizedBox(height: 2),
                    if (profile?.tagline.isNotEmpty ?? false)
                      pw.Wrap(
                        crossAxisAlignment: pw.WrapCrossAlignment.center,
                        children: [
                          pw.Text(
                            'Proprietor: ',
                            style: _ts(
                              urduFont,
                              size: isThermal ? 8 : 10,
                              color: PdfColors.blue800,
                              weight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            profile!.tagline,
                            textDirection: pw.TextDirection.rtl,
                            style: _ts(
                              urduFont,
                              size: isThermal ? 8 : 10,
                              color: PdfColors.blue800,
                              weight: pw.FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    if (profile?.phone.isNotEmpty ?? false)
                      pw.Text(
                        'Ph: ${profile!.phone.replaceAll(',', ' -')}',
                        textDirection: pw.TextDirection.ltr,
                        style: _ts(
                          urduFont,
                          size: isThermal ? 8 : 10,
                          weight: pw.FontWeight.normal,
                          color: PdfColors.grey800,
                        ),
                      ),
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
                        data:
                            'Invoice: ${sale.invoiceNumber}\nTotal: Rs. ${sale.total}\nPSID: ${sale.saleId.hashCode.toString().replaceAll('-', '')}\nDate: ${DateFormat('dd-MM-yy HH:mm').format(sale.timestamp)}',
                        width: qrSize,
                        height: qrSize,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'PSID / Receipt',
                        style: _ts(urduFont, size: isThermal ? 4.5 : 6),
                      ),
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
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                profile!.address,
                textAlign: pw.TextAlign.center,
                textDirection: pw.TextDirection.rtl,
                style: _ts(
                  urduFont,
                  size: isThermal ? 9 : 10,
                  color: PdfColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget buildPdfFooter(
    pw.Font urduFont,
    pw.MemoryImage logo, {
    bool isThermal = false,
  }) {
    final fontSize = isThermal ? 7.0 : 10.0;
    final logoSize = isThermal ? 16.0 : 24.0;
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 8),
          if (isThermal) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(logo, width: logoSize, height: logoSize),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Developed by Vivid Digital Nexus',
                  style: _ts(
                    urduFont,
                    size: fontSize,
                    weight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Ph no: +92 328 5753463',
              style: _ts(urduFont, size: fontSize, weight: pw.FontWeight.bold),
            ),
          ] else ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(logo, width: logoSize, height: logoSize),
                pw.SizedBox(width: 4),
                pw.Text(
                  'Developed by Vivid Digital Nexus | Ph no: +92 328 5753463',
                  style: _ts(
                    urduFont,
                    size: fontSize,
                    weight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static AppPaperSize getDefaultPaperSize() {
    try {
      final name = LocalDbService().settingsBox.get('default_paper_size');
      if (name != null) {
        return AppPaperSize.values.firstWhere(
          (e) => e.name == name || e.name.toLowerCase() == name.toLowerCase(),
          orElse: () => AppPaperSize.thermal80,
        );
      }
    } catch (_) {}
    return AppPaperSize.thermal80;
  }

  static Future<void> setDefaultPaperSize(AppPaperSize size) async {
    try {
      await LocalDbService().settingsBox.put('default_paper_size', size.name);
    } catch (_) {}
  }

  static bool isRememberChoiceEnabled() {
    try {
      final val = LocalDbService().settingsBox.get('remember_paper_choice');
      return val == 'true';
    } catch (_) {}
    return false;
  }

  static Future<void> setRememberChoice(bool remember) async {
    try {
      await LocalDbService().settingsBox.put('remember_paper_choice', remember ? 'true' : 'false');
    } catch (_) {}
  }

  static Future<AppPaperSize?> getEffectivePaperSize(
    BuildContext context, {
    bool forcePicker = false,
  }) async {
    if (!forcePicker && isRememberChoiceEnabled()) {
      return getDefaultPaperSize();
    }
    return showPaperSizeDialog(context);
  }

  static Future<AppPaperSize?> showPaperSizeMenu(
    BuildContext context, {
    RelativeRect? position,
  }) {
    return showPaperSizeDialog(context);
  }

  static Future<AppPaperSize?> showPaperSizeDialog(
    BuildContext context, {
    AppPaperSize? initialSize,
  }) async {
    AppPaperSize selected = initialSize ?? getDefaultPaperSize();
    bool setAsDefault = isRememberChoiceEnabled();

    return showDialog<AppPaperSize>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: Colors.indigo.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Paper Size',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose paper size for printing receipt / document:',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Scrollbar(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: AppPaperSize.values.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final paper = AppPaperSize.values[index];
                            final isSelected = paper == selected;
                            return InkWell(
                              onTap: () => setState(() => selected = paper),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (paper.isThermal
                                          ? Colors.orange.shade50
                                          : Colors.blue.shade50)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? (paper.isThermal
                                            ? Colors.orange.shade600
                                            : Colors.blue.shade600)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      paper.icon,
                                      size: 22,
                                      color: paper.isThermal
                                          ? Colors.orange.shade800
                                          : Colors.blue.shade800,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            paper.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.black87
                                                  : Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            paper.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Radio<AppPaperSize>(
                                      value: paper,
                                      groupValue: selected,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => selected = val);
                                        }
                                      },
                                      activeColor: paper.isThermal
                                          ? Colors.orange.shade800
                                          : Colors.blue.shade800,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    // Default Checkbox
                    CheckboxListTile(
                      value: setAsDefault,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.indigo.shade700,
                      title: const Text(
                        'Set print size as default',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: const Text(
                        'Save selected paper size as default for future prints',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onChanged: (val) {
                        setState(() {
                          setAsDefault = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'Print',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (setAsDefault) {
                      await setDefaultPaperSize(selected);
                      await setRememberChoice(true);
                    } else {
                      await setRememberChoice(false);
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx, selected);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<Uint8List> generateThermalReceipt({
    required SaleModel sale,
    required List<dynamic> items,
    required String cashierName,
    StoreProfileModel? storeProfile,
    String? customerName,
    String? customerPhone,
    double? previousDues,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.roll80;
    final theme = await getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);

    final urduFont = await getUrduFont();
    final vdnLogo = await getVdnLogo();

    pdf.addPage(
      pw.Page(
        pageFormat: targetFormat.copyWith(
          marginLeft: 2 * PdfPageFormat.mm,
          marginRight: 2 * PdfPageFormat.mm,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              buildPdfHeader(
                urduFont,
                isThermal: true,
                profile: storeProfile,
                sale: sale,
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Top Details Section
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (customerName != null)
                    pw.Text(
                      'Customer: $customerName',
                      style: _ts(urduFont, size: 8, weight: pw.FontWeight.bold),
                    ),
                  if (customerPhone != null && customerPhone.isNotEmpty)
                    pw.Text(
                      'Phone: $customerPhone',
                      style: _ts(urduFont, size: 8),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Bill No: ${sale.invoiceNumber}',
                        style: _ts(urduFont, size: 7),
                      ),
                      pw.Text(
                        'Type: ${sale.paymentMethod}',
                        style: _ts(urduFont, size: 7),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('dd-MM-yy').format(sale.timestamp)}',
                        style: _ts(urduFont, size: 7),
                      ),
                      pw.Text(
                        'Time: ${DateFormat('HH:mm').format(sale.timestamp)}',
                        style: _ts(urduFont, size: 7),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Item',
                      style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Qty x Price',
                      style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              ...items.map((item) {
                final Map<String, dynamic> map = item is Map ? Map<String, dynamic>.from(item) : {};
                final name = map['name']?.toString() ?? 'Item';
                final brand = map['brand']?.toString() ?? '';
                final qty = (map['quantity'] as num?)?.toDouble() ?? (map['qty'] as num?)?.toDouble() ?? 1.0;
                final price = (map['unitPrice'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble() ?? 0.0;
                final disc = (map['discount'] as num?)?.toDouble() ?? 0.0;
                final total = (map['total'] as num?)?.toDouble() ?? (map['subtotal'] as num?)?.toDouble() ?? (qty * price - disc);
                final displayName = brand.isNotEmpty ? '$name ($brand)' : name;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          displayName,
                          style: _ts(urduFont, size: 6),
                          textAlign: pw.TextAlign.left,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${qty.toStringAsFixed(0)} x ${price.toStringAsFixed(0)}',
                          style: _ts(urduFont, size: 6),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          total.toStringAsFixed(0),
                          style: _ts(urduFont, size: 6),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Subtotal:',
                    style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${sale.subtotal.toStringAsFixed(0)}',
                    style: _ts(urduFont, size: 7),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Discount:',
                    style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '- Rs. ${sale.discount.toStringAsFixed(0)}',
                    style: _ts(urduFont, size: 7),
                  ),
                ],
              ),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CURRENT BILL TOTAL:',
                    style: _ts(urduFont, size: 10, weight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${sale.total.toStringAsFixed(0)}',
                    style: _ts(urduFont, size: 10, weight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Received Amount:',
                    style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${sale.paidAmount.toStringAsFixed(0)}',
                    style: _ts(urduFont, size: 7),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Current Bill Pending:',
                    style: _ts(urduFont, size: 7, weight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${(sale.total - sale.paidAmount > 0 ? sale.total - sale.paidAmount : 0).toStringAsFixed(0)}',
                    style: _ts(urduFont, size: 7),
                  ),
                ],
              ),

              if (previousDues != null && previousDues > 0) ...[
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Previous Dues:',
                      style: _ts(urduFont, size: 8, weight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Rs. ${previousDues.toStringAsFixed(0)}',
                      style: _ts(
                        urduFont,
                        size: 8,
                        weight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL:',
                      style: _ts(urduFont, size: 9, weight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Rs. ${(sale.total + previousDues - sale.paidAmount).toStringAsFixed(0)}',
                      style: _ts(urduFont, size: 9, weight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 8),

              pw.Text(
                'Thank You!',
                style: _ts(urduFont, size: 9, weight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Cashier: $cashierName',
                style: _ts(urduFont, size: 7),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              buildPdfFooter(urduFont, vdnLogo, isThermal: true),
              pw.SizedBox(height: 10 * PdfPageFormat.mm), // Extra space for thermal cutter
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
    double? previousDues,
    PdfPageFormat? pageFormat,
  }) async {
    final targetFormat = pageFormat ?? PdfPageFormat.a4;
    final theme = await getUrduPdfTheme();
    final pdf = pw.Document(theme: theme);
    final urduFont = await getUrduFont();
    final vdnLogo = await getVdnLogo();

    pdf.addPage(
      pw.Page(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPdfHeader(
                urduFont,
                isThermal: false,
                profile: storeProfile,
                sale: sale,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILL TO:',
                        style: _ts(
                          urduFont,
                          weight: pw.FontWeight.bold,
                          size: 10,
                        ),
                      ),
                      pw.Text(
                        customerName ?? 'Walk-in Customer',
                        style: _ts(urduFont, size: 13),
                      ),
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        pw.Text('Phone: $customerPhone', style: _ts(urduFont)),
                      pw.Text(
                        'Payment: ${sale.paymentMethod}',
                        style: _ts(urduFont),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: _ts(
                          urduFont,
                          size: 22,
                          weight: pw.FontWeight.bold,
                          color: PdfColors.teal,
                        ),
                      ),
                      pw.Text(
                        'No: ${sale.invoiceNumber}',
                        style: _ts(urduFont, weight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Date: ${DateFormat('dd MMM yyyy HH:mm').format(sale.timestamp)}',
                        style: _ts(urduFont),
                      ),
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
                  inside: const pw.BorderSide(
                    width: 0.5,
                    color: PdfColors.grey300,
                  ),
                  outside: const pw.BorderSide(
                    width: 1,
                    color: PdfColors.grey400,
                  ),
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
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Product',
                          style: _ts(urduFont, weight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Unit Price',
                          style: _ts(urduFont, weight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Qty',
                          style: _ts(urduFont, weight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Disc.',
                          style: _ts(urduFont, weight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Total',
                          style: _ts(urduFont, weight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    final Map<String, dynamic> map = item is Map ? Map<String, dynamic>.from(item) : {};
                    final name = map['name']?.toString() ?? 'Item';
                    final brand = map['brand']?.toString() ?? '';
                    final category = map['category']?.toString() ?? '';
                    String displayName = name;
                    if (brand.isNotEmpty || category.isNotEmpty) {
                      final parts = [
                        if (brand.isNotEmpty) brand,
                        if (category.isNotEmpty) category,
                      ].join(' - ');
                      displayName = '$name ($parts)';
                    }
                    final price = (map['unitPrice'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble() ?? 0.0;
                    final qty = (map['quantity'] as num?)?.toDouble() ?? (map['qty'] as num?)?.toDouble() ?? 1.0;
                    final disc = (map['discount'] as num?)?.toDouble() ?? 0.0;
                    final total = (map['total'] as num?)?.toDouble() ?? (map['subtotal'] as num?)?.toDouble() ?? (qty * price - disc);
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            displayName,
                            style: _ts(urduFont),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Rs.${price.toStringAsFixed(0)}',
                            style: _ts(urduFont),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            qty.toStringAsFixed(0),
                            style: _ts(urduFont),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Rs.${disc.toStringAsFixed(0)}',
                            style: _ts(urduFont),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Rs.${total.toStringAsFixed(0)}',
                            style: _ts(urduFont),
                          ),
                        ),
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
                        _summaryRow(
                          urduFont,
                          'Subtotal:',
                          'Rs. ${sale.subtotal.toStringAsFixed(2)}',
                        ),
                        pw.SizedBox(height: 4),
                        _summaryRow(
                          urduFont,
                          'Discount:',
                          'Rs. ${sale.discount.toStringAsFixed(2)}',
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(thickness: 1.5),
                        _summaryRow(
                          urduFont,
                          'CURRENT BILL TOTAL:',
                          'Rs. ${sale.total.toStringAsFixed(2)}',
                          bold: true,
                          fontSize: 14,
                        ),
                        pw.Divider(thickness: 1),
                        pw.SizedBox(height: 4),
                        _summaryRow(
                          urduFont,
                          'Received Amount:',
                          'Rs. ${sale.paidAmount.toStringAsFixed(2)}',
                        ),
                        pw.SizedBox(height: 4),
                        _summaryRow(
                          urduFont,
                          'Current Bill Pending:',
                          'Rs. ${(sale.total - sale.paidAmount > 0 ? sale.total - sale.paidAmount : 0).toStringAsFixed(2)}',
                        ),
                        if (previousDues != null && previousDues > 0) ...[
                          pw.SizedBox(height: 6),
                          pw.Divider(
                            thickness: 1,
                            borderStyle: pw.BorderStyle.dashed,
                          ),
                          pw.SizedBox(height: 6),
                          _summaryRow(
                            urduFont,
                            'Previous Dues:',
                            'Rs. ${previousDues.toStringAsFixed(2)}',
                            bold: true,
                          ),
                          pw.SizedBox(height: 6),
                          pw.Divider(thickness: 1),
                          pw.SizedBox(height: 6),
                          _summaryRow(
                            urduFont,
                            'GRAND TOTAL:',
                            'Rs. ${(sale.total + previousDues - sale.paidAmount).toStringAsFixed(2)}',
                            bold: true,
                            fontSize: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with ${storeProfile?.storeName.toUpperCase() ?? 'US'}!',
                  style: _ts(urduFont, weight: pw.FontWeight.bold),
                ),
              ),
              buildPdfFooter(urduFont, vdnLogo, isThermal: false),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _summaryRow(
    pw.Font urduFont,
    String label,
    String value, {
    bool bold = false,
    double fontSize = 11,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: _ts(
            urduFont,
            size: fontSize,
            weight: bold ? pw.FontWeight.bold : null,
          ),
        ),
        pw.Text(
          value,
          style: _ts(
            urduFont,
            size: fontSize,
            weight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  static Future<Uint8List> generateInvoiceForPaperSize({
    required AppPaperSize paperSize,
    required SaleModel sale,
    required List<dynamic> items,
    required String cashierName,
    StoreProfileModel? storeProfile,
    String? customerName,
    String? customerPhone,
    double? previousDues,
  }) {
    if (paperSize.isThermal) {
      return generateThermalReceipt(
        sale: sale,
        items: items,
        cashierName: cashierName,
        storeProfile: storeProfile,
        customerName: customerName,
        customerPhone: customerPhone,
        previousDues: previousDues,
        pageFormat: paperSize.format,
      );
    } else {
      return generateA4Invoice(
        sale: sale,
        items: items,
        cashierName: cashierName,
        storeProfile: storeProfile,
        customerName: customerName,
        customerPhone: customerPhone,
        previousDues: previousDues,
        pageFormat: paperSize.format,
      );
    }
  }

  static Future<Uint8List> generateReturnSlipPdf({
    StoreProfileModel? storeProfile,
    required String returnInvoiceNumber,
    required String originalInvoiceNumber,
    required String customerName,
    required List<Map<String, dynamic>> returnedItems,
    required double grossTotal,
    required double deductionPercentage,
    required double deductionAmount,
    required double netRefund,
    required String refundMethod,
    required String reason,
    PdfPageFormat? pageFormat,
  }) async {
    final pdf = pw.Document();
    final urduFont = await getUrduFont();
    final dateStr = DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now());
    final targetFormat = pageFormat ?? PdfPageFormat.roll80;

    pdf.addPage(
      pw.Page(
        pageFormat: targetFormat,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  storeProfile?.storeName ?? 'General Store',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    fontFallback: [urduFont],
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '*** OFFICIAL RETURN INVOICE ***',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    fontFallback: [urduFont],
                  ),
                ),
              ),
              pw.Divider(thickness: 1),
              pw.Text('RETURN INVOICE #: $returnInvoiceNumber', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, fontFallback: [urduFont])),
              pw.Text('Ref Original Bill: $originalInvoiceNumber', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
              pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
              pw.Text('Customer: $customerName', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
              if (reason.isNotEmpty)
                pw.Text('Reason: $reason', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
              pw.Divider(thickness: 1),
              pw.Text('Returned Items List:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, fontFallback: [urduFont])),
              pw.SizedBox(height: 4),
              ...returnedItems.map((item) {
                final name = item['name']?.toString() ?? 'Item';
                final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
                final sub = qty * price;
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '$name (${qty.toStringAsFixed(0)}x @ ${price.toStringAsFixed(0)})',
                        style: pw.TextStyle(fontSize: 8.5, fontFallback: [urduFont]),
                      ),
                    ),
                    pw.Text('Rs. ${sub.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 8.5, fontFallback: [urduFont])),
                  ],
                );
              }),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Gross Items Total:', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
                  pw.Text('Rs. ${grossTotal.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
                ],
              ),
              if (deductionAmount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deduction Fee (${deductionPercentage.toStringAsFixed(0)}%):', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700, fontFallback: [urduFont])),
                    pw.Text('- Rs. ${deductionAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700, fontFallback: [urduFont])),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET REFUND PAID:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, fontFallback: [urduFont])),
                  pw.Text('Rs. ${netRefund.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, fontFallback: [urduFont])),
                ],
              ),
              pw.Text('Refund Method: $refundMethod', style: pw.TextStyle(fontSize: 9, fontFallback: [urduFont])),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Stock Restocked & Refund Invoice Recorded', style: pw.TextStyle(fontSize: 7.5, fontFallback: [urduFont])),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
}

class PrintButtonWithMenu extends StatelessWidget {
  final String label;
  final Function(AppPaperSize paperSize) onSelectSize;

  const PrintButtonWithMenu({
    super.key,
    this.label = 'Print Receipt',
    required this.onSelectSize,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppPaperSize>(
      tooltip: 'Select Paper Size',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 42),
      onSelected: (paperSize) => onSelectSize(paperSize),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.indigo.shade700,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
      itemBuilder: (ctx) {
        return AppPaperSize.values.map((paper) {
          return PopupMenuItem<AppPaperSize>(
            value: paper,
            height: 44,
            child: Row(
              children: [
                Icon(
                  paper.icon,
                  size: 20,
                  color: paper.isThermal
                      ? Colors.orange.shade800
                      : Colors.blue.shade800,
                ),
                const SizedBox(width: 12),
                Text(
                  paper.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
