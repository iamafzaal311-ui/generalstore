import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_model.dart';

abstract class SalesRemoteDataSource {
  Future<void> pushSaleToCloud(SaleModel sale);
}

class SalesRemoteDataSourceImpl implements SalesRemoteDataSource {
  final FirebaseFirestore _firestore;

  SalesRemoteDataSourceImpl(this._firestore);

  @override
  Future<void> pushSaleToCloud(SaleModel sale) async {
    await _firestore.collection('sales').doc(sale.saleId).set({
      'saleId': sale.saleId,
      'invoiceNumber': sale.invoiceNumber,
      'total': sale.total,
      'timestamp': sale.timestamp.toUtc().toIso8601String(),
      'itemsJson': sale.itemsJson,
      'isDeleted': sale.isDeleted,
    }, SetOptions(merge: true));
  }
}
