import 'package:flutter/foundation.dart';

/// Mock data service to replace Firebase
/// This service provides local in-memory data storage for the app
class MockDataService extends ChangeNotifier {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal() {
    _initializeData();
  }

  // Access code for the app
  String accessCode = '1234';

  // Admin stats
  double targetWeekAmount = 50000.0;
  double latestTotalPaid = 0.0;
  double todayTotalPaid = 0.0;
  double weekPaid = 0.0;
  int todayPaidShopsCount = 0;
  int monthPaidShopsCount = 0;

  // Routes and shops data
  Map<String, List<Shop>> routes = {};

  // Receipts
  List<Receipt> receipts = [];

  // Stocks
  List<Stock> stocks = [];

  // Feedbacks
  List<Feedback> feedbacks = [];

  // Deductions
  List<Deduction> deductions = [];

  void _initializeData() {
    // Initialize routes with sample shops matching the app's routes
    routes = {
      'Kinniya': [
        Shop(
          id: 'k_shop1',
          name: 'Al-Madina Grocery',
          address: '45 Main Street, Kinniya',
          phone: '0771234567',
          amount: 15000.0,
          totalPaid: 5000.0,
          status: 'Unpaid',
          latitude: 8.4882,
          longitude: 81.1678,
        ),
        Shop(
          id: 'k_shop2',
          name: 'Fathima Textiles',
          address: '78 Beach Road, Kinniya',
          phone: '0779876543',
          amount: 8500.0,
          totalPaid: 3500.0,
          status: 'Unpaid',
          latitude: 8.4895,
          longitude: 81.1690,
        ),
        Shop(
          id: 'k_shop3',
          name: 'Fresh Fish Market',
          address: '23 Harbor Junction, Kinniya',
          phone: '0765432100',
          amount: 12000.0,
          totalPaid: 8000.0,
          status: 'Paid',
          paidAt: DateTime.now().subtract(const Duration(hours: 2)),
          paidAmount: 2000.0,
          latitude: 8.4870,
          longitude: 81.1655,
        ),
        Shop(
          id: 'k_shop4',
          name: 'Kinniya Hardware',
          address: '156 Junction Road, Kinniya',
          phone: '0712223344',
          amount: 22000,
          totalPaid: 10000,
          status: 'Unpaid',
          latitude: 8.4900,
          longitude: 81.1700,
        ),
        Shop(
          id: 'k_shop5',
          name: 'Bismillah Restaurant',
          address: '89 Central Road, Kinniya',
          phone: '0778889900',
          amount: 9500.0,
          totalPaid: 4500.0,
          status: 'Unpaid',
          latitude: 8.4860,
          longitude: 81.1640,
        ),
        Shop(
          id: 'k_shop6',
          name: 'Lucky Mobile Shop',
          address: '12 Market Street, Kinniya',
          phone: '0761112233',
          amount: 18000.0,
          totalPaid: 6000.0,
          status: 'Paid',
          paidAt: DateTime.now().subtract(const Duration(hours: 6)),
          paidAmount: 3000.0,
          latitude: 8.4875,
          longitude: 81.1665,
        ),
      ],
      'Mutur': [
        Shop(
          id: 'm_shop1',
          name: 'Mutur Super Market',
          address: '10 Main Road, Mutur',
          phone: '0712345678',
          amount: 25000.0,
          totalPaid: 15000.0,
          status: 'Unpaid',
          latitude: 8.4478,
          longitude: 81.2637,
        ),
        Shop(
          id: 'm_shop2',
          name: 'Rahman Electronics',
          address: '22 Station Road, Mutur',
          phone: '0778765432',
          amount: 18000.0,
          totalPaid: 12000.0,
          status: 'Unpaid',
          latitude: 8.4490,
          longitude: 81.2650,
        ),
        Shop(
          id: 'm_shop3',
          name: 'New Life Pharmacy',
          address: '55 Hospital Road, Mutur',
          phone: '0761234567',
          amount: 9500.0,
          totalPaid: 4500.0,
          status: 'Paid',
          paidAt: DateTime.now().subtract(const Duration(hours: 5)),
          paidAmount: 1500.0,
          latitude: 8.4465,
          longitude: 81.2620,
        ),
        Shop(
          id: 'm_shop4',
          name: 'Mutur Jewellers',
          address: '88 Gold Street, Mutur',
          phone: '0723456789',
          amount: 45000.0,
          totalPaid: 20000.0,
          status: 'Unpaid',
          latitude: 8.4500,
          longitude: 81.2670,
        ),
        Shop(
          id: 'm_shop5',
          name: 'Harbor View Restaurant',
          address: '5 Beach Road, Mutur',
          phone: '0754321098',
          amount: 12500.0,
          totalPaid: 7500.0,
          status: 'Unpaid',
          latitude: 8.4455,
          longitude: 81.2600,
        ),
      ],
      'Kantale': [
        Shop(
          id: 'kt_shop1',
          name: 'Kantale Trade Center',
          address: '100 Main Road, Kantale',
          phone: '0756789012',
          amount: 35000.0,
          totalPaid: 20000.0,
          status: 'Unpaid',
          latitude: 8.3579,
          longitude: 81.0012,
        ),
        Shop(
          id: 'kt_shop2',
          name: 'Green Valley Agro',
          address: '200 Tank Road, Kantale',
          phone: '0723456789',
          amount: 22000.0,
          totalPaid: 10000.0,
          status: 'Unpaid',
          latitude: 8.3590,
          longitude: 81.003,
        ),
        Shop(
          id: 'kt_shop3',
          name: 'Lakshmi Stores',
          address: '45 Market Junction, Kantale',
          phone: '0711234567',
          amount: 16000,
          totalPaid: 8000,
          status: 'Paid',
          paidAt: DateTime.now().subtract(const Duration(hours: 3)),
          paidAmount: 4000,
          latitude: 8.3565,
          longitude: 80.9995,
        ),
        Shop(
          id: 'kt_shop4',
          name: 'Kantale Pharmacy',
          address: '78 Hospital Lane, Kantale',
          phone: '0769876543',
          amount: 8500,
          totalPaid: 5500,
          status: 'Unpaid',
          latitude: 8.3600,
          longitude: 81.005,
        ),
      ],
      'Matale': [
        Shop(
          id: 'mt_shop1',
          name: 'Matale City Mart',
          address: '15 King Street, Matale',
          phone: '0662222333',
          amount: 28000.0,
          totalPaid: 15000.0,
          status: 'Unpaid',
          latitude: 7.4697,
          longitude: 80.6239,
        ),
        Shop(
          id: 'mt_shop2',
          name: 'Spice Garden Exports',
          address: '50 Spice Lane, Matale',
          phone: '0663334444',
          amount: 55000.0,
          totalPaid: 35000.0,
          status: 'Unpaid',
          latitude: 7.4710,
          longitude: 80.6255,
        ),
        Shop(
          id: 'mt_shop3',
          name: 'Heritage Jewellers',
          address: '88 Temple Road, Matale',
          phone: '0664445555',
          amount: 75000.0,
          totalPaid: 45000.0,
          status: 'Paid',
          paidAt: DateTime.now().subtract(const Duration(hours: 4)),
          paidAmount: 10000.0,
          latitude: 7.4685,
          longitude: 80.6220,
        ),
        Shop(
          id: 'mt_shop4',
          name: 'Cool Breeze Electronics',
          address: '120 Main Street, Matale',
          phone: '0665556666',
          amount: 32000.0,
          totalPaid: 18000.0,
          status: 'Unpaid',
          latitude: 7.4720,
          longitude: 80.6270,
        ),
        Shop(
          id: 'mt_shop5',
          name: 'Matale Textile House',
          address: '200 Market Road, Matale',
          phone: '0666667777',
          amount: 19500.0,
          totalPaid: 9500.0,
          status: 'Unpaid',
          latitude: 7.4675,
          longitude: 80.6200,
        ),
        Shop(
          id: 'mt_shop6',
          name: 'New Fashion Garments',
          address: '33 Clock Tower Road, Matale',
          phone: '0667778888',
          amount: 24000.0,
          totalPaid: 12000.0,
          status: 'Paid',
          paidAt: DateTime.now().subtract(const Duration(hours: 8)),
          paidAmount: 5000.0,
          latitude: 7.4690,
          longitude: 80.6230,
        ),
      ],
    };

    // Initialize stocks with more items
    stocks = [
      Stock(
        id: 'stock1',
        name: 'Basmati Rice 5kg',
        originalPrice: 2500.0,
        discountedPrice: 2250.0,
        lastLowerPrice: 2300.0,
        imageUrl: '',
        isAvailable: true,
      ),
      Stock(
        id: 'stock2',
        name: 'White Sugar 1kg',
        originalPrice: 250.0,
        discountedPrice: 220.0,
        lastLowerPrice: 230.0,
        imageUrl: '',
        isAvailable: true,
      ),
      Stock(
        id: 'stock3',
        name: 'Coconut Oil 1L',
        originalPrice: 850.0,
        discountedPrice: 780.0,
        lastLowerPrice: 800.0,
        imageUrl: '',
        isAvailable: true,
      ),
      Stock(
        id: 'stock4',
        name: 'Wheat Flour 1kg',
        originalPrice: 180.0,
        discountedPrice: 160.0,
        lastLowerPrice: 170.0,
        imageUrl: '',
        isAvailable: true,
      ),
      Stock(
        id: 'stock5',
        name: 'Red Lentils 500g',
        originalPrice: 450.0,
        discountedPrice: 400.0,
        lastLowerPrice: 420.0,
        imageUrl: '',
        isAvailable: true,
      ),
      Stock(
        id: 'stock6',
        name: 'Milk Powder 400g',
        originalPrice: 1200.0,
        discountedPrice: 1100.0,
        lastLowerPrice: 1150.0,
        imageUrl: '',
        isAvailable: false,
      ),
      Stock(
        id: 'stock7',
        name: 'Tea Leaves 200g',
        originalPrice: 380.0,
        discountedPrice: 350.0,
        lastLowerPrice: 360.0,
        imageUrl: '',
        isAvailable: true,
      ),
      Stock(
        id: 'stock8',
        name: 'Chili Powder 250g',
        originalPrice: 320.0,
        discountedPrice: 290.0,
        lastLowerPrice: 300.0,
        imageUrl: '',
        isAvailable: true,
      ),
    ];

    // Initialize some sample receipts
    receipts = [
      Receipt(
        id: 'receipt_1',
        amount: '5000',
        imageUrl: null,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Receipt(
        id: 'receipt_2',
        amount: '12500',
        imageUrl: null,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    // Initialize sample deductions
    deductions = [
      Deduction(
        id: 'ded_1',
        amount: 2500.0,
        type: 'Bank Transfer',
        sentAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Deduction(
        id: 'ded_2',
        amount: 5000.0,
        type: 'Cash Handover',
        sentAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    _calculateTotals();
  }

  void _calculateTotals() {
    double total = 0;
    double todayTotal = 0;
    int todayPaidCount = 0;
    int monthPaidCount = 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    for (var shops in routes.values) {
      for (var shop in shops) {
        total += shop.amount;

        if (shop.status == 'Paid' && shop.paidAt != null) {
          if (shop.paidAt!.isAfter(todayStart)) {
            todayTotal += shop.paidAmount ?? 0;
            todayPaidCount++;
          }
          if (shop.paidAt!.isAfter(monthStart)) {
            monthPaidCount++;
          }
        }
      }
    }

    latestTotalPaid = total;
    todayTotalPaid = todayTotal;
    todayPaidShopsCount = todayPaidCount;
    monthPaidShopsCount = monthPaidCount;
  }

  // Verify access code
  bool verifyAccessCode(String code) {
    return code == accessCode;
  }

  // Get all routes
  List<String> getRoutes() {
    return routes.keys.toList();
  }

  // Get shops for a route
  List<Shop> getShopsForRoute(String routeName) {
    return routes[routeName] ?? [];
  }

  // Update shop balance
  void updateShopBalance(
      String routeName, String shopId, double reducedAmount) {
    final shops = routes[routeName];
    if (shops != null) {
      final shopIndex = shops.indexWhere((s) => s.id == shopId);
      if (shopIndex != -1) {
        final shop = shops[shopIndex];
        shop.amount -= reducedAmount;
        shop.totalPaid += reducedAmount;
        shop.paidAmount = reducedAmount;
        shop.paidAt = DateTime.now();
        shop.status = 'Paid';

        // Add transaction
        shop.transactions.add(Transaction(
          amount: reducedAmount,
          timestamp: DateTime.now(),
          type: 'Cash',
        ));

        _calculateTotals();
        notifyListeners();
      }
    }
  }

  // Revert shop to unpaid
  void revertShopToUnpaid(String routeName, String shopId) {
    final shops = routes[routeName];
    if (shops != null) {
      final shopIndex = shops.indexWhere((s) => s.id == shopId);
      if (shopIndex != -1) {
        final shop = shops[shopIndex];
        shop.status = 'Unpaid';
        shop.paidAt = null;
        _calculateTotals();
        notifyListeners();
      }
    }
  }

  // Add receipt
  void addReceipt(String amount, String? imageUrl) {
    receipts.add(Receipt(
      id: 'receipt_${receipts.length + 1}',
      amount: amount,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // Add feedback
  void addFeedback(String routeName, String shopName, String shopId,
      String reason, String note) {
    feedbacks.add(Feedback(
      id: 'feedback_${feedbacks.length + 1}',
      routeName: routeName,
      shopName: shopName,
      shopId: shopId,
      reason: reason,
      note: note,
      submittedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // Get stock list
  List<Stock> getStocks() {
    return stocks;
  }

  // Get all receipts
  List<Receipt> getReceipts() {
    return receipts;
  }

  // Get all feedbacks
  List<Feedback> getFeedbacks() {
    return feedbacks;
  }

  // Get all deductions
  List<Deduction> getDeductions() {
    return deductions;
  }

  // Add deduction
  void addDeduction(double amount, String type) {
    deductions.add(Deduction(
      id: 'ded_${deductions.length + 1}',
      amount: amount,
      type: type,
      sentAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // Get total outstanding balance across all routes
  double getTotalOutstanding() {
    double total = 0;
    for (var shops in routes.values) {
      for (var shop in shops) {
        total += shop.amount;
      }
    }
    return total;
  }

  // Get total collected today
  double getTodayCollection() {
    double todayTotal = 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (var shops in routes.values) {
      for (var shop in shops) {
        if (shop.status == 'Paid' && shop.paidAt != null) {
          if (shop.paidAt!.isAfter(todayStart)) {
            todayTotal += shop.paidAmount ?? 0;
          }
        }
      }
    }
    return todayTotal;
  }

  // Get shop count by status for a route
  Map<String, int> getShopCountByStatus(String routeName) {
    final shops = routes[routeName] ?? [];
    int paid = 0;
    int unpaid = 0;
    for (var shop in shops) {
      if (shop.status == 'Paid') {
        paid++;
      } else {
        unpaid++;
      }
    }
    return {'paid': paid, 'unpaid': unpaid, 'total': shops.length};
  }

  // Get total shops count across all routes
  int getTotalShopsCount() {
    int count = 0;
    for (var shops in routes.values) {
      count += shops.length;
    }
    return count;
  }

  // Get paid shops count today
  int getTodayPaidShopsCount() {
    int count = 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (var shops in routes.values) {
      for (var shop in shops) {
        if (shop.status == 'Paid' && shop.paidAt != null) {
          if (shop.paidAt!.isAfter(todayStart)) {
            count++;
          }
        }
      }
    }
    return count;
  }

  // Calculate week paid amount
  double getWeekPaid() {
    double weekTotal = 0;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    for (var shops in routes.values) {
      for (var shop in shops) {
        if (shop.status == 'Paid' && shop.paidAt != null) {
          if (shop.paidAt!.isAfter(weekStartDate)) {
            weekTotal += shop.paidAmount ?? 0;
          }
        }
      }
    }

    // Add some base value for demo purposes
    return weekTotal + 25000.0;
  }

  // Search shops across all routes
  List<Map<String, dynamic>> searchShops(String query) {
    final results = <Map<String, dynamic>>[];
    final lowerQuery = query.toLowerCase();

    routes.forEach((routeName, shops) {
      for (var shop in shops) {
        if (shop.name.toLowerCase().contains(lowerQuery) ||
            shop.address.toLowerCase().contains(lowerQuery) ||
            shop.phone.contains(query)) {
          results.add({
            'shop': shop,
            'route': routeName,
          });
        }
      }
    });

    return results;
  }

  // Get shop by ID
  Shop? getShopById(String shopId) {
    for (var shops in routes.values) {
      for (var shop in shops) {
        if (shop.id == shopId) {
          return shop;
        }
      }
    }
    return null;
  }

  // Update stock availability
  void updateStockAvailability(String stockId, bool isAvailable) {
    final stockIndex = stocks.indexWhere((s) => s.id == stockId);
    if (stockIndex != -1) {
      stocks[stockIndex].isAvailable = isAvailable;
      notifyListeners();
    }
  }

  // Get available stocks count
  int getAvailableStocksCount() {
    return stocks.where((s) => s.isAvailable).length;
  }

  // Get route statistics
  Map<String, dynamic> getRouteStatistics(String routeName) {
    final shops = routes[routeName] ?? [];
    double totalAmount = 0;
    double totalCollected = 0;
    int paidCount = 0;
    int unpaidCount = 0;

    for (var shop in shops) {
      totalAmount += shop.amount;
      totalCollected += shop.totalPaid;
      if (shop.status == 'Paid') {
        paidCount++;
      } else {
        unpaidCount++;
      }
    }

    return {
      'totalShops': shops.length,
      'paidShops': paidCount,
      'unpaidShops': unpaidCount,
      'totalOutstanding': totalAmount,
      'totalCollected': totalCollected,
      'completionRate': shops.isEmpty ? 0.0 : (paidCount / shops.length) * 100,
    };
  }
}

// Data Models
class Shop {
  String id;
  String name;
  String address;
  String phone;
  double amount;
  double totalPaid;
  String status;
  DateTime? paidAt;
  double? paidAmount;
  double? latitude;
  double? longitude;
  List<Transaction> transactions;

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.amount,
    required this.totalPaid,
    required this.status,
    this.paidAt,
    this.paidAmount,
    this.latitude,
    this.longitude,
    List<Transaction>? transactions,
  }) : transactions = transactions ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'amount': amount,
      'totalPaid': totalPaid,
      'status': status,
      'paidAt': paidAt,
      'paidAmount': paidAmount,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class Transaction {
  double amount;
  DateTime timestamp;
  String type;

  Transaction({
    required this.amount,
    required this.timestamp,
    required this.type,
  });
}

class Receipt {
  String id;
  String amount;
  String? imageUrl;
  DateTime createdAt;

  Receipt({
    required this.id,
    required this.amount,
    this.imageUrl,
    required this.createdAt,
  });
}

class Stock {
  String id;
  String name;
  double originalPrice;
  double discountedPrice;
  double lastLowerPrice;
  String imageUrl;
  bool isAvailable;

  Stock({
    required this.id,
    required this.name,
    required this.originalPrice,
    required this.discountedPrice,
    required this.lastLowerPrice,
    required this.imageUrl,
    required this.isAvailable,
  });
}

class Feedback {
  String id;
  String routeName;
  String shopName;
  String shopId;
  String reason;
  String note;
  DateTime submittedAt;

  Feedback({
    required this.id,
    required this.routeName,
    required this.shopName,
    required this.shopId,
    required this.reason,
    required this.note,
    required this.submittedAt,
  });
}

class Deduction {
  String id;
  double amount;
  String type;
  DateTime sentAt;

  Deduction({
    required this.id,
    required this.amount,
    required this.type,
    required this.sentAt,
  });
}
