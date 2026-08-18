import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/branch_context.dart';
import '../utils/app_theme.dart';

double calculateRouteBalanceFromShops(List<Map<String, dynamic>> shops) {
  double total = 0.0;

  for (final shop in shops) {
    final value = shop['totalPaid'];
    if (value is num) {
      total += value.toDouble();
    } else if (value is String) {
      total += double.tryParse(value) ?? 0.0;
    }
  }

  return total;
}

class RouteBalanceInHandScreen extends StatefulWidget {
  const RouteBalanceInHandScreen({super.key});

  @override
  State<RouteBalanceInHandScreen> createState() => _RouteBalanceInHandScreenState();
}

class _RouteBalanceInHandScreenState extends State<RouteBalanceInHandScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final branchId = BranchContext().branchId;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      if (branchId == null) {
        setState(() {
          _routes = [];
          _isLoading = false;
        });
        return;
      }

      final routesSnap = await _firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .orderBy('order', descending: false)
          .get();

      final routeData = <Map<String, dynamic>>[];

      for (final routeDoc in routesSnap.docs) {
        final routeId = routeDoc.id;
        final shopsSnap = await routeDoc.reference.collection('shops').get();
        final shops = shopsSnap.docs
            .map((shopDoc) => shopDoc.data())
            .toList();

        final totalBalance = calculateRouteBalanceFromShops(shops);

        await routeDoc.reference.set({
          'routeBalanceInHand': totalBalance,
          'routeCollection': totalBalance,
          'cashCollection': totalBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        routeData.add({
          'id': routeId,
          'name': routeDoc.data()['name'] ?? routeId,
          'balance': totalBalance,
          'shopCount': shops.length,
        });
      }

      if (mounted) {
        setState(() {
          _routes = routeData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routes = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        title: Text(
          'Route Balance in Hand',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? Center(
                  child: Text(
                    'No route balances found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.lightCardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.route_rounded,
                              color: AppColors.accentTeal,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${route['shopCount']} shops',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Rs ${route['balance'].toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentBlueDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
