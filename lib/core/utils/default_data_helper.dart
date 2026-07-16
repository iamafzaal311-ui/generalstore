import 'package:uuid/uuid.dart';
import '../../data/models/product_model.dart';

class DefaultDataHelper {
  static List<ProductModel> getDefaultPakistaniProducts() {
    final List<Map<String, dynamic>> rawData = [
      // Cosmetics & Skincare
      {'name': 'Fair & Lovely Face Cream 50g', 'price': 350.0, 'cost': 320.0},
      {'name': 'Ponds White Beauty Cream 35g', 'price': 400.0, 'cost': 370.0},
      {
        'name': 'Nivea Soft Moisturizing Cream 100ml',
        'price': 650.0,
        'cost': 600.0,
      },
      {'name': 'Olay Natural White Cream 50g', 'price': 950.0, 'cost': 900.0},
      {
        'name': 'Garnier Light Complete Face Wash 100g',
        'price': 450.0,
        'cost': 410.0,
      },
      {'name': 'Clean & Clear Face Wash 100ml', 'price': 500.0, 'cost': 460.0},
      {'name': 'Himalaya Neem Face Wash 100ml', 'price': 450.0, 'cost': 420.0},
      {'name': 'Tibet Snow Cream', 'price': 150.0, 'cost': 130.0},
      {'name': 'Care Honey Lotion 100ml', 'price': 250.0, 'cost': 220.0},
      {
        'name': 'Veet Hair Removal Cream Normal 25g',
        'price': 220.0,
        'cost': 200.0,
      },

      // Hair Care
      {
        'name': 'Sunsilk Black Shine Shampoo 200ml',
        'price': 450.0,
        'cost': 420.0,
      },
      {
        'name': 'Dove Intense Repair Shampoo 200ml',
        'price': 550.0,
        'cost': 510.0,
      },
      {'name': 'Pantene Pro-V Shampoo 200ml', 'price': 500.0, 'cost': 470.0},
      {
        'name': 'Head & Shoulders Anti-Dandruff 200ml',
        'price': 600.0,
        'cost': 560.0,
      },
      {'name': 'Lifebuoy Shampoo 175ml', 'price': 300.0, 'cost': 280.0},
      {'name': 'Vatika Hair Oil 200ml', 'price': 400.0, 'cost': 370.0},
      {'name': 'Parachute Coconut Oil 200ml', 'price': 500.0, 'cost': 460.0},

      // Personal Care & Soaps
      {'name': 'Lux Soap Pink 150g', 'price': 120.0, 'cost': 110.0},
      {'name': 'Safeguard Soap White 130g', 'price': 140.0, 'cost': 125.0},
      {'name': 'Dettol Soap Original 120g', 'price': 135.0, 'cost': 120.0},
      {'name': 'Lifebuoy Soap Red 130g', 'price': 100.0, 'cost': 90.0},
      {'name': 'Capri Soap 100g', 'price': 110.0, 'cost': 100.0},
      {
        'name': 'Always Ultra Sanitary Pads (Large)',
        'price': 450.0,
        'cost': 420.0,
      },
      {'name': 'Pampers Baby Dry Size 4', 'price': 2800.0, 'cost': 2600.0},
      {
        'name': 'Colgate Toothpaste Maximum Cavity 120g',
        'price': 250.0,
        'cost': 230.0,
      },
      {
        'name': 'Sensodyne Fluoride Toothpaste 100g',
        'price': 650.0,
        'cost': 600.0,
      },
      {'name': 'English Toothbrush (Soft)', 'price': 100.0, 'cost': 80.0},

      // Laundry & Cleaning
      {'name': 'Surf Excel Washing Powder 1Kg', 'price': 700.0, 'cost': 660.0},
      {'name': 'Ariel Washing Powder 1Kg', 'price': 680.0, 'cost': 640.0},
      {
        'name': 'Bonus Tristar Washing Powder 1Kg',
        'price': 450.0,
        'cost': 420.0,
      },
      {'name': 'Brite Washing Powder 1Kg', 'price': 550.0, 'cost': 520.0},
      {'name': 'Lemon Max Paste 400g', 'price': 150.0, 'cost': 135.0},
      {'name': 'Vim Dishwash Liquid 500ml', 'price': 350.0, 'cost': 320.0},
      {'name': 'Harpic Toilet Cleaner 500ml', 'price': 300.0, 'cost': 270.0},
      {
        'name': 'Dettol Liquid Surface Cleaner 500ml',
        'price': 600.0,
        'cost': 560.0,
      },
      {
        'name': 'Mortein Mosquito Repellent Coil',
        'price': 120.0,
        'cost': 105.0,
      },

      // Groceries & Food Items
      {'name': 'Lipton Yellow Label Tea 190g', 'price': 450.0, 'cost': 420.0},
      {'name': 'Tapal Danedar Tea 190g', 'price': 440.0, 'cost': 410.0},
      {'name': 'Mezan Cooking Oil 1 Ltr', 'price': 500.0, 'cost': 480.0},
      {'name': 'Dalda Banaspati Ghee 1 Kg', 'price': 520.0, 'cost': 500.0},
      {'name': 'National Tomato Ketchup 800g', 'price': 450.0, 'cost': 410.0},
      {
        'name': 'Mitchells Chilli Garlic Sauce 800g',
        'price': 460.0,
        'cost': 420.0,
      },
      {'name': 'Shan Biryani Masala 50g', 'price': 120.0, 'cost': 105.0},
      {'name': 'National Chilli Powder 200g', 'price': 300.0, 'cost': 270.0},
      {'name': 'National Salt (Iodized) 800g', 'price': 60.0, 'cost': 50.0},
      {'name': 'Nestle Milkpak 1 Ltr', 'price': 280.0, 'cost': 260.0},
      {'name': 'Olpers Milk 1 Ltr', 'price': 280.0, 'cost': 260.0},
      {'name': 'Rooh Afza 800ml', 'price': 450.0, 'cost': 410.0},
      {'name': 'Jam-e-Shirin 800ml', 'price': 440.0, 'cost': 400.0},
      {'name': 'Super Crisp Salted Chips', 'price': 50.0, 'cost': 40.0},
      {'name': 'Lays French Cheese Chips', 'price': 50.0, 'cost': 40.0},
      {'name': 'Prince Biscuits Half Roll', 'price': 30.0, 'cost': 25.0},
      {'name': 'Sooper Biscuits Half Roll', 'price': 30.0, 'cost': 25.0},
      {'name': 'Cocomo Chocolate Biscuits', 'price': 20.0, 'cost': 16.0},
      {'name': 'Coca Cola 1.5 Ltr', 'price': 200.0, 'cost': 180.0},
      {'name': 'Sprite 1.5 Ltr', 'price': 200.0, 'cost': 180.0},
    ];

    final now = DateTime.now();
    return rawData.map((data) {
      return ProductModel()
        ..productId = const Uuid().v4()
        ..name = data['name'] as String
        ..sku = ''
        ..barcode = ''
        ..purchasePrice = data['cost'] as double
        ..wholesalePrice = (data['price'] as double) * 0.95
        ..retailPrice = data['price'] as double
        ..minimumPrice = data['cost'] as double
        ..stock = 10.0
        ..unit = 'pcs'
        ..openingStock = 10.0
        ..minimumStock = 2.0
        ..maximumStock = 100.0
        ..isDirty = true
        ..lastUpdated = now
        ..isDeleted = false;
    }).toList();
  }
}
