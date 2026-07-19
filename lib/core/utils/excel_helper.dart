import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../data/models/product_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/sale_model.dart';

/// Helper for generating Excel exports (products, expenses, sales).
class ExcelHelper {
  /// Generate an Excel workbook for current product stock.
  static Future<Uint8List> exportProductsToExcel(
    List<ProductModel> products,
  ) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Product Stock'];
    excel.delete('Sheet1');

    // Header row
    final headers = [
      'Product Name',
      'SKU',
      'Barcode',
      'Category ID',
      'Unit',
      'Stock',
      'Min Stock',
      'Max Stock',
      'Purchase Price',
      'Wholesale Price',
      'Retail Price',
      'Min Price',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
    }

    // Data rows
    for (int row = 0; row < products.length; row++) {
      final p = products[row];
      final rowData = [
        p.name,
        p.sku ?? '',
        p.barcode ?? '',
        p.categoryId ?? '',
        p.unit,
        p.stock,
        p.minimumStock,
        p.maximumStock,
        p.purchasePrice,
        p.wholesalePrice,
        p.retailPrice,
        p.minimumPrice,
      ];
      for (int col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
        );
        final val = rowData[col];
        if (val is num) {
          cell.value = DoubleCellValue(val.toDouble());
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// Generate an Excel workbook for expenses.
  static Future<Uint8List> exportExpensesToExcel(
    List<ExpenseModel> expenses,
  ) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Expenses'];
    excel.delete('Sheet1');

    final headers = [
      'Title',
      'Category',
      'Amount (Rs.)',
      'Description',
      'Date',
    ];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
    }

    for (int row = 0; row < expenses.length; row++) {
      final e = expenses[row];
      final rowData = [
        e.title,
        e.category,
        e.amount,
        e.description ?? '',
        e.timestamp.toLocal().toString().split(' ')[0],
      ];
      for (int col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
        );
        final val = rowData[col];
        if (val is num) {
          cell.value = DoubleCellValue(val.toDouble());
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// Generate an Excel workbook for sales.
  static Future<Uint8List> exportSalesToExcel(List<SaleModel> sales) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Sales'];
    excel.delete('Sheet1');

    final headers = [
      'Invoice #',
      'Date',
      'Cashier ID',
      'Customer ID',
      'Subtotal',
      'Discount',
      'Total',
      'Paid',
      'Change',
      'Payment Method',
    ];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
    }

    for (int row = 0; row < sales.length; row++) {
      final s = sales[row];
      final rowData = [
        s.invoiceNumber,
        s.timestamp.toLocal().toString().split(' ')[0],
        s.cashierId,
        s.customerId ?? '',
        s.subtotal,
        s.discount,
        s.total,
        s.paidAmount,
        s.changeAmount,
        s.paymentMethod,
      ];
      for (int col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
        );
        final val = rowData[col];
        if (val is num) {
          cell.value = DoubleCellValue(val.toDouble());
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }
}
