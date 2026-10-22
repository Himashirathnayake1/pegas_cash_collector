import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';
import 'balance_screen.dart';

class LowLevelShopsScreen extends StatefulWidget {
  const LowLevelShopsScreen({Key? key}) : super(key: key);

  @override
  State<LowLevelShopsScreen> createState() => _LowLevelShopsScreenState();
}

class _LowLevelShopsScreenState extends State<LowLevelShopsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool showUnpaid = true;
  List<Map<String, dynamic>> allShops = [];
  bool isLoading = true;
  Map<String, int> countdowns = {};

  @override
  void initState() {
    super.initState();
    _loadShops();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startCountdownTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          for (var shopId in countdowns.keys) {
            if (countdowns[shopId]! > 0) {
              countdowns[shopId] = countdowns[shopId]! - 1;
            }
          }
        });
        _startCountdownTimer();
      }
    });
  }

  Future<void> _loadShops() async {
    try {
      final branchId = BranchContext().branchId;
      print('📍 Loading shops for branch: $branchId');
      
      final firestore = FirebaseFirestore.instance;

      // First, get all routes
      final routesSnapshot = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .get();

      print('🗺️  Total routes found: ${routesSnapshot.docs.length}');

      final shops = <Map<String, dynamic>>[];

      // For each route, get all shops
      for (var routeDoc in routesSnapshot.docs) {
        final routeName = routeDoc.id;
        print('📍 Checking route: $routeName');
        
        final shopsSnapshot = await firestore
            .collection('branches')
            .doc(branchId)
            .collection('routes')
            .doc(routeName)
            .collection('shops')
            .get();

        print('📦 Shops in route $routeName: ${shopsSnapshot.docs.length}');

        for (var shopDoc in shopsSnapshot.docs) {
          final data = shopDoc.data();
          
          // Extract amount with detailed logging
          final dynamic amountVal = data['amount'];
          double amount = 0.0;
          
          if (amountVal is num) {
            amount = amountVal.toDouble();
          } else if (amountVal is String) {
            amount = double.tryParse(amountVal) ?? 0.0;
          } else {
            amount = 0.0;
          }

          print('🏪 Shop $routeName/${shopDoc.id}: name=${data['name']}, amount=$amount');

          // Filter: Only show shops with amount < 1000
          if (amount >= 1000) {
            print('⏭️  Skipping shop ${shopDoc.id}: amount $amount >= 1000');
            continue;
          }

          final shop = {
            'id': shopDoc.id,
            'name': data['name'] ?? 'Unknown',
            'address': data['address'] ?? 'Unknown',
            'phone': data['phone'] ?? 'N/A',
            'status': data['status'] ?? 'Unpaid',
            'amount': amount,
            'route': routeName,
            'paidAt': data['paidAt'] != null
                ? (data['paidAt'] as Timestamp).toDate()
                : null,
            'latitude': data['latitude'],
            'longitude': data['longitude'],
          };

          // Initialize countdown if Paid
          if (shop['status'] == 'Paid' && shop['paidAt'] != null) {
            final diff = DateTime.now().difference(shop['paidAt']).inSeconds;
            final remaining = 43200 - diff;
            if (remaining > 0) {
              countdowns[shop['id']] = remaining;
            }
          }

          shops.add(shop);
        }
      }

      if (mounted) {
        setState(() {
          allShops = shops;
          isLoading = false;
        });
      }
      print('✅ Loaded ${shops.length} low-level shops from all routes (amount < 1000)');
    } catch (e) {
      print('❌ Error loading shops: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadShops();
  }

  void _filterShops() {
    setState(() {});
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final filteredShops = allShops.where((shop) {
      final matchStatus =
          showUnpaid ? shop['status'] == 'Unpaid' : shop['status'] == 'Paid';
      final matchSearch = shop['name']
          .toString()
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();

    return Scaffold(
       appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          
            Text(
              ('Low Level Shops'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.lightTextPrimary),
          ),
        ],
      ),
    
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildFilterTabs(),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentTeal,
                    ),
                  )
                : filteredShops.isEmpty
                    ? _buildEmptyState()
                    : _buildShopsList(filteredShops),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightCardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(color: AppColors.lightTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search shops...',
          hintStyle: GoogleFonts.poppins(color: AppColors.lightTextMuted),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.lightTextMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              'Unpaid',
              showUnpaid,
              () => setState(() => showUnpaid = true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterTab(
              'Paid',
              !showUnpaid,
              () => setState(() => showUnpaid = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
      String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentTeal : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.lightTextMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showUnpaid ? Icons.shopping_bag_outlined : Icons.check_circle_outline,
            size: 80,
            color: AppColors.lightTextSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            showUnpaid ? 'No unpaid shops' : 'All paid up!',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showUnpaid
                ? 'All low-level shops have been paid'
                : 'No low-level shops with pending payments',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopsList(List<Map<String, dynamic>> shops) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.accentTealDark,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: shops.length,
        itemBuilder: (context, index) {
          return _buildShopCard(shops[index], index);
        },
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop, int index) {
    final name = shop['name'];
    final status = shop['status'];
    final paidAt = shop['paidAt'] as DateTime?;
    final phone = shop['phone'] ?? 'N/A';
    final address = shop['address'] ?? 'Unknown';
    final amount = shop['amount'] ?? 0;
    final latitude = shop['latitude'];
    final longitude = shop['longitude'];
    int remainingSeconds = 0;

    if (shop['status'] == 'Paid' && paidAt != null) {
      final diff = DateTime.now().difference(paidAt).inSeconds;
      remainingSeconds = 43200 - diff;
      if (remainingSeconds < 0) remainingSeconds = 0;
    }

    final isPaid = status == 'Paid';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BalanceScreen(
                    shopName: shop['name'],
                    routeName: shop['route'],
                    shopId: shop['id'],
                    onBalanceAdjusted: (shopName, reducedAmount) async {
                      final updatedShops =
                          List<Map<String, dynamic>>.from(allShops);
                      final shopIndex =
                          updatedShops.indexWhere((s) => s['name'] == shopName);
                      if (shopIndex != -1) {
                        final now = DateTime.now();
                        setState(() {
                          updatedShops[shopIndex]['status'] = 'Paid';
                          updatedShops[shopIndex]['amount'] = (updatedShops[shopIndex]['amount'] as num) - reducedAmount;
                          updatedShops[shopIndex]['paidAt'] = now;
                          updatedShops[shopIndex]['paidAmount'] = reducedAmount;
                          allShops = updatedShops;
                          countdowns[updatedShops[shopIndex]['id']] = 43200;
                        });
                      }
                    },
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 15, 57, 64),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color.fromARGB(255, 26, 82, 92),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Shop Icon + Shop Name + Action Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 61, 161, 148),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color.fromARGB(255, 32, 217, 202),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Shop Name - Expanded
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color.fromARGB(255, 32, 217, 202),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              address,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFFB0B8C1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFFB0B8C1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Balance and Status Tags Under Phone
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A3F0F).withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Rs.${amount.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFD4AF37),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? const Color(0xFF1A4D3E).withOpacity(0.8)
                                        : const Color(0xFF4A2E2E).withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPaid ? '✓ Paid' : 'Unpaid',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isPaid
                                          ? const Color(0xFF20D9A3)
                                          : const Color(0xFFD84040),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right Buttons Column
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Location Button
                          GestureDetector(
                            onTap: () async {
                              if (latitude != null && longitude != null) {
                                final mapsUrl =
                                    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
                                try {
                                  if (await canLaunchUrl(Uri.parse(mapsUrl))) {
                                    await launchUrl(
                                      Uri.parse(mapsUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    final geoUrl = 'geo:$latitude,$longitude';
                                    if (await canLaunchUrl(Uri.parse(geoUrl))) {
                                      await launchUrl(
                                        Uri.parse(geoUrl),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error opening maps: $e'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3A5C).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFD84040)
                                      .withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFD84040),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Phone Button
                          // GestureDetector(
                          //   onTap: () async {
                          //     if (phone != 'N/A') {
                          //       try {
                          //         final phoneUrl = 'tel:$phone';
                          //         if (await canLaunchUrl(Uri.parse(phoneUrl))) {
                          //           await launchUrl(
                          //             Uri.parse(phoneUrl),
                          //             mode: LaunchMode.externalApplication,
                          //           );
                          //         }
                          //       } catch (e) {
                          //         if (mounted) {
                          //           ScaffoldMessenger.of(context).showSnackBar(
                          //             SnackBar(
                          //               content: Text('Error calling: $e'),
                          //               duration: const Duration(seconds: 2),
                          //             ),
                          //           );
                          //         }
                          //       }
                          //     }
                          //   },
                          //   child: Container(
                          //     width: 40,
                          //     height: 40,
                          //     decoration: BoxDecoration(
                          //       color: const Color(0xFF1A4D3E)
                          //           .withOpacity(0.5),
                          //       borderRadius: BorderRadius.circular(10),
                          //       border: Border.all(
                          //         color: const Color(0xFF20D9A3)
                          //             .withOpacity(0.5),
                          //         width: 1,
                          //       ),
                          //     ),
                          //     child: const Icon(
                          //       Icons.call_rounded,
                          //       color: const Color(0xFF20D9A3),
                          //       size: 20,
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Countdown Timer Row (when Paid)
                  if (isPaid && countdowns.containsKey(shop['id']))
                    _buildCountdownText(countdowns[shop['id']]!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownText(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4D3E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF20D9A3).withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reverting',
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF20D9A3).withOpacity(0.8),
            ),
          ),
          Text(
            '$hours:$minutes:$secs',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF20D9A3),
            ),
          ),
        ],
      ),
    );
  }
}