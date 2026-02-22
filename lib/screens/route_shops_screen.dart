import 'dart:ui';
import 'dart:async';
import 'package:pegas_cashcollector/screens/balance_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

class RouteShopsScreen extends StatefulWidget {
  final String routeId;
  final String routeName;

  const RouteShopsScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  @override
  State<RouteShopsScreen> createState() => _RouteShopsScreenState();
}

class _RouteShopsScreenState extends State<RouteShopsScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> allShops = [];
  List<Map<String, dynamic>> filteredShops = [];
  bool showUnpaid = true;
  bool isShopsLoading = true;
  Timer? _uiUpdateTimer;
  bool isUploading = false;
  
  // Countdown state
  Map<String, int> countdowns = {};
  Map<String, Timer> timers = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _startUiUpdater();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  void _startUiUpdater() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _uiUpdateTimer?.cancel();
    // Cancel all countdown timers
    for (var timer in timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() => isShopsLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final firestore = FirebaseFirestore.instance;
      final updatedShops = <Map<String, dynamic>>[];
      final now = DateTime.now();
      
      // Get branch ID from context
      final branchId = BranchContext().branchId;
      if (branchId == null) {
        print('❌ No branch ID available in context');
        setState(() => isShopsLoading = false);
        return;
      }

      print('📍 Loading shops for branch: $branchId, route: ${widget.routeId}');

      // Get shops for this specific route in this branch
      final shopsSnap = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .doc(widget.routeId)
          .collection('shops')
          .get();
          
      for (var shopDoc in shopsSnap.docs) {
        final data = shopDoc.data();
        
        // Filter: Only show shops with amount >= 1000
        final dynamic amountVal = data['amount'];
        double amount = 0.0;
        if (amountVal is num) amount = amountVal.toDouble();
        else if (amountVal is String) amount = double.tryParse(amountVal) ?? 0.0;
        
        if (amount < 1000) {
          print('⏭️  Skipping shop ${shopDoc.id}: amount ${amount} < 1000');
          continue; // Skip shops with amount < 1000
        }
        
        String status = (data['status'] as String?) ?? 'Unpaid';
        DateTime? paidAt;
        if (data['paidAt'] != null) {
          final v = data['paidAt'];
          if (v is Timestamp) paidAt = v.toDate();
          else if (v is DateTime) paidAt = v;
        }

        if (status == 'Paid' && paidAt != null) {
          final difference = now.difference(paidAt).inSeconds;
          if (difference >= 43200) {
            status = 'Unpaid';
          }
        }

        updatedShops.add({
          'id': shopDoc.id,
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'phone': data['phone'] ?? '',
          'status': status,
          'amount': amount,
          'totalPaid': data['totalPaid'] ?? 0,
          'paidAmount': data['paidAmount'] ?? 0,
          'paidAt': paidAt,
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'routeId': widget.routeId,
        });
        
        // Start countdown for paid shops
        if (status == 'Paid' && paidAt != null) {
          _startCountdown(shopDoc.id, data['name'] ?? '', paidAt);
        }
      }
      
      print('✅ Loaded ${updatedShops.length} shops (with amount >= 1000) for route ${widget.routeId}');

      setState(() {
        allShops = updatedShops;
        _filterShops();
      });
    } catch (e) {
      print('❌ Error loading shops: $e');
      setState(() {
        allShops = [];
        filteredShops = [];
      });
    } finally {
      if (mounted) setState(() => isShopsLoading = false);
    }
  }

  void _filterShops() {
    filteredShops = allShops.where((shop) {
      final matchStatus =
          showUnpaid ? shop['status'] == 'Unpaid' : shop['status'] == 'Paid';
      final matchSearch = shop['name']
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final hasValidAmount = showUnpaid || shop['amount'] != null;
      return matchStatus && matchSearch && hasValidAmount;
    }).toList();
  }

  Future<void> _refreshData() async {
    setState(() {
      isUploading = true;
    });
    await _loadShops();
    setState(() {
      isUploading = false;
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _startCountdown(String shopId, String shopName, DateTime paidAt) async {
    if (countdowns.containsKey(shopId)) {
      return;
    }

    final elapsed = DateTime.now().difference(paidAt).inSeconds;
    final totalSeconds = 43200; // 12 hours
    final remaining = totalSeconds - elapsed;

    if (remaining <= 0) {
      return; // Already expired
    }

    countdowns[shopId] = remaining;

    timers[shopId]?.cancel();
    timers[shopId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }

      if (countdowns.containsKey(shopId) && countdowns[shopId]! > 0) {
        setState(() {
          countdowns[shopId] = countdowns[shopId]! - 1;
        });
      } else if (countdowns.containsKey(shopId) && countdowns[shopId] == 0) {
        timer.cancel();
        countdowns.remove(shopId);
        timers.remove(shopId);
        _revertShopStatus(shopId, shopName);
      }
    });
  }

  Future<void> _revertShopStatus(String shopId, String shopName) async {
    try {
      final branchId = BranchContext().branchId;
      if (branchId == null) return;

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .doc(widget.routeId)
          .collection('shops')
          .doc(shopId)
          .update({
            'status': 'Unpaid',
            'paidAt': null,
          });

      // Update local state
      final shopIndex = allShops.indexWhere((s) => s['id'] == shopId);
      if (shopIndex != -1 && mounted) {
        setState(() {
          allShops[shopIndex]['status'] = 'Unpaid';
          allShops[shopIndex]['paidAt'] = null;
          _filterShops();
        });
      }
    } catch (e) {
      print('❌ Error reverting shop status: $e');
    }
  }

  Widget _buildCountdownText(int secondsRemaining) {
    final hours = secondsRemaining ~/ 3600;
    final minutes = (secondsRemaining % 3600) ~/ 60;
    final seconds = secondsRemaining % 60;

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
              fontWeight: FontWeight.w500,
              color: const Color(0xFFB0B8C1),
            ),
          ),
          Text(
            "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF20D9A3),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
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
              widget.routeName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.lightTextPrimary,
              ),
            ),
            Text(
              '${allShops.length} Shops',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.lightTextSecondary,
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
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
            // Shops List
            Expanded(
              child: isShopsLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.accentTealDark,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading shops...',
                            style: GoogleFonts.poppins(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: AppColors.accentTealDark,
                      child: filteredShops.isEmpty
                          ? _buildEmptyState()
                          : _buildShopsList(filteredShops),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _filterShops();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search shops...',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.lightTextSecondary, size: 22),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintStyle: GoogleFonts.poppins(
            color: AppColors.lightTextSecondary,
            fontSize: 14,
          ),
        ),
        style: GoogleFonts.poppins(
          color: AppColors.lightTextPrimary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showUnpaid = true;
                  _filterShops();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: showUnpaid
                      ? AppColors.accentTeal.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Unpaid',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: showUnpaid ? FontWeight.w600 : FontWeight.w500,
                      color: showUnpaid
                          ? AppColors.accentTeal
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showUnpaid = false;
                  _filterShops();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !showUnpaid
                      ? AppColors.accentTeal.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Paid',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: !showUnpaid ? FontWeight.w600 : FontWeight.w500,
                      color: !showUnpaid
                          ? AppColors.accentTeal
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                ? 'All shops in this route have been paid'
                : 'No shops with pending payments',
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        final shop = shops[index];
        return _buildShopCard(shop, index);
      },
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
                    routeName: widget.routeName,
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
                          _filterShops();
                        });
                        // Start countdown for revert after 12 hours
                        _startCountdown(shop['id'], shopName, now);
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
                      // Container(
                      //   padding: const EdgeInsets.all(8),
                      //   decoration: BoxDecoration(
                      //     color: const Color.fromARGB(255, 61, 161, 148),
                      //     borderRadius: BorderRadius.circular(8),
                      //   ),
                      //   child: const Icon(
                      //     Icons.storefront_rounded,
                      //     color: Color.fromARGB(255, 32, 217, 202),
                      //     size: 20,
                      //   ),
                      // ),
                      // const SizedBox(width: 10),
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
                              mainAxisAlignment: MainAxisAlignment.start,
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
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'No maps application found'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
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
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Location data not available'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
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
                          GestureDetector(
                            onTap: () async {
                              if (phone != 'N/A') {
                                try {
                                  final phoneUrl = 'tel:$phone';
                                  if (await canLaunchUrl(Uri.parse(phoneUrl))) {
                                    await launchUrl(
                                      Uri.parse(phoneUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Cannot call $phone - No phone app found'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error calling: $e'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Phone number not available'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A4D3E)
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF20D9A3)
                                      .withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.call_rounded,
                                color: const Color(0xFF20D9A3),
                                size: 20,
                              ),
                            ),
                          ),
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
}
