import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> fetchProductsFromCloud();
  Future<void> pushProductToCloud(ProductModel product);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final FirebaseFirestore _firestore;

  ProductRemoteDataSourceImpl(this._firestore);

  @override
  Future<List<ProductModel>> fetchProductsFromCloud() async {
    // Note: Sync is primarily handled by SyncService.
    throw UnimplementedError('Direct cloud fetch not yet implemented');
  }

  @override
  Future<void> pushProductToCloud(ProductModel product) async {
    await _firestore.collection('products').doc(product.productId).set({
      'productId': product.productId,
      'name': product.name,
      'sku': product.sku,
      'barcode': product.barcode,
      'stock': product.stock,
      'retailPrice': product.retailPrice,
      'lastUpdated': product.lastUpdated.toUtc().toIso8601String(),
      'isDeleted': product.isDeleted,
    }, SetOptions(merge: true));
  }
}
