import 'package:cloud_firestore/cloud_firestore.dart';
import 'branch_context.dart';

/// Helper class to simplify branch-scoped Firestore queries
/// All reads/writes are automatically namespaced under branches/{branchId}
class BranchFirestore {
  static final BranchFirestore _instance = BranchFirestore._internal();

  factory BranchFirestore() {
    return _instance;
  }

  BranchFirestore._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the current branch ID from context
  String get _branchId {
    final branchId = BranchContext().branchId;
    if (branchId == null) {
      throw Exception('❌ No branch selected. Please login first.');
    }
    return branchId;
  }

  /// Reference to admin/stats for this branch
  DocumentReference statsRef() =>
      _firestore
          .collection('branches')
          .doc(_branchId)
          .collection('admin')
          .doc('stats');

  /// Reference to admin/summary for this branch
  DocumentReference summaryRef() =>
      _firestore
          .collection('branches')
          .doc(_branchId)
          .collection('admin')
          .doc('summary');

  /// Collection reference for orders
  CollectionReference ordersCollection() =>
      _firestore
          .collection('branches')
          .doc(_branchId)
          .collection('orders');

  /// Collection reference for storeorders (secondary copy)
  CollectionReference storeordersCollection() =>
      _firestore
          .collection('branches')
          .doc(_branchId)
          .collection('storeorders');

  /// Collection reference for routes
  CollectionReference routesCollection() =>
      _firestore
          .collection('branches')
          .doc(_branchId)
          .collection('routes');

  /// Get reference to a specific route
  DocumentReference routeRef(String routeName) =>
      routesCollection().doc(routeName) as DocumentReference;

  /// Get reference to shops under a route
  CollectionReference shopsInRoute(String routeName) =>
      routeRef(routeName).collection('shops');

  /// Get reference to a specific shop
  DocumentReference shopRef(String routeName, String shopId) =>
      shopsInRoute(routeName).doc(shopId);

  /// Get transactions under a shop
  CollectionReference shopTransactions(String routeName, String shopId) =>
      shopRef(routeName, shopId).collection('transactions');

  /// Get cashAdditions under a shop
  CollectionReference shopCashAdditions(String routeName, String shopId) =>
      shopRef(routeName, shopId).collection('cashAdditions');

  /// Generic collection reference
  CollectionReference collection(String name) =>
      _firestore
          .collection('branches')
          .doc(_branchId)
          .collection(name);

  /// Helper: fetch all shops across all routes in this branch
  Future<List<Map<String, dynamic>>> allShops() async {
    try {
      final snapshot = await _firestore
          .collection('branches')
          .doc(_branchId)
          .collection('routes')
          .get();

      List<Map<String, dynamic>> allShops = [];

      for (var routeDoc in snapshot.docs) {
        final shopsSnapshot = await routeDoc.reference
            .collection('shops')
            .get();

        for (var shopDoc in shopsSnapshot.docs) {
          allShops.add({
            'id': shopDoc.id,
            'routeName': routeDoc.id,
            'data': shopDoc.data(),
          });
        }
      }

      print('✅ Fetched ${allShops.length} shops from branch: $_branchId');
      return allShops;
    } catch (e) {
      print('❌ Error fetching all shops: $e');
      return [];
    }
  }

  /// Helper: sum totalPaid across all shops (for latestTotalPaid calculation)
  Future<double> sumTotalPaidAcrossShops() async {
    try {
      double total = 0.0;
      final shops = await allShops();

      for (var shop in shops) {
        final totalPaid = (shop['data']?['totalPaid'] ?? 0.0) as num;
        total += totalPaid.toDouble();
      }

      print('✅ Total paid across all shops in $_branchId: $total');
      return total;
    } catch (e) {
      print('❌ Error summing total paid: $e');
      return 0.0;
    }
  }

  /// Get the current branch ID (for logging/debugging)
  String getCurrentBranchId() => _branchId;
}
