import '../../data/models/purchase_model.dart';
import '../../data/models/sale_model.dart';

abstract class TransactionsRepository {
  // Purchases
  Future<List<PurchaseModel>> getPurchases();
  Future<void> savePurchase(PurchaseModel purchase);
  Future<void> deletePurchase(String purchaseId);
  
  // Sales (additional logs access)
  Future<List<SaleModel>> getSalesLogs();
}
