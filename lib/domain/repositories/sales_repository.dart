import '../../data/models/sale_model.dart';
import '../../data/models/customer_model.dart';

abstract class SalesRepository {
  Future<List<SaleModel>> getSales();
  Future<void> saveSale(SaleModel sale);
  Future<void> updateSale(SaleModel oldSale, SaleModel newSale);
  Future<void> deleteSale(String saleId);
  Future<List<CustomerModel>> getCustomers();
  Future<void> saveCustomer(CustomerModel customer);
}
