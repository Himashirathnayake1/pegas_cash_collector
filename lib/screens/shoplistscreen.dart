import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'balance_screen.dart';
import '../services/mock_data_service.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

class ShopListScreen extends StatefulWidget {
  final String routeName;
  const ShopListScreen({super.key, required this.routeName});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool showUnpaid = true;

  List<Map<String, dynamic>> allShops = [];
  double totalPaidAcrossRoutes = 0.0;
  double routeTotalPaid = 0.0;
  bool isLoading = true;

  Map<String, int> countdowns = {};
  Map<String, Timer> timers = {};
  Timer? _uiUpdateTimer;
  final mockService = MockDataService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _startUiUpdater();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
    _uiUpdateTimer?.cancel();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() => isLoading = true);

    await Future.delayed(const Duration(milliseconds: 300));

    final shops = mockService.getShopsForRoute(widget.routeName);
    final now = DateTime.now();

    final updatedShops = <Map<String, dynamic>>[];

    for (var shop in shops) {
      String status = shop.status;

      if (status == 'Paid' && shop.paidAt != null) {
        final difference = now.difference(shop.paidAt!).inSeconds;
        if (difference >= 43200) {
          mockService.revertShopToUnpaid(widget.routeName, shop.id);
          status = 'Unpaid';
        }
      }

      updatedShops.add({
        "id": shop.id,
        "name": shop.name,
        "address": shop.address,
        "phone": shop.phone,
        "status": status,
        "amount": shop.amount,
        "totalPaid": shop.totalPaid,
        "paidAmount": shop.paidAmount ?? 0,
        "paidAt": shop.paidAt,
        "latitude": shop.latitude,
        "longitude": shop.longitude,
      });
    }

    setState(() {
      allShops = updatedShops;
      isLoading = false;
    });
    for (var shop in allShops) {
      if (shop['status'] == 'Paid') {
        _startCountdown(shop['name']);
      }
    }
  }

  Future<void> _startCountdown(String shopName, {DateTime? paidAt}) async {
    if (countdowns.containsKey(shopName)) return;

    final startTime = paidAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final totalSeconds = 43200;
    final remaining = totalSeconds - elapsed;

    if (remaining <= 0) return;

    countdowns[shopName] = remaining;

    timers[shopName]?.cancel();
    timers[shopName] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (countdowns[shopName]! > 0) {
          countdowns[shopName] = countdowns[shopName]! - 1;
        } else {
          timer.cancel();
          countdowns.remove(shopName);
          timers.remove(shopName);

          final shopIndex = allShops.indexWhere((s) => s['name'] == shopName);
          if (shopIndex != -1) {
            final shopId = allShops[shopIndex]['id'];
            allShops[shopIndex]['status'] = 'Unpaid';
            mockService.revertShopToUnpaid(widget.routeName, shopId);
            setState(() {});
          }
        }
      });
    });
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
    List<Map<String, dynamic>> filteredShops = allShops.where((shop) {
      final matchStatus =
          showUnpaid ? shop['status'] == 'Unpaid' : shop['status'] == 'Paid';
      final matchSearch = shop['name']
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final hasValidAmount = showUnpaid || shop['amount'] != null;
      return matchStatus && matchSearch && hasValidAmount;
    }).toList();

    // int totalPaidAmount = 0;
    // If you need to use totalPaidAmount, uncomment and use it in your widget.
    // if (!showUnpaid) {
    //   totalPaidAmount = filteredShops.fold<int>(
    //     0,
    //     (sum, shop) => sum + ((shop['totalPaid'] ?? 0) as num).toInt(),
    //   );
    // }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: Container(
        color: AppColors.lightBackground,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      _buildFilterTabs(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isLoading
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
                          onRefresh: _loadShops,
                          color: AppColors.accentTealDark,
                          child: filteredShops.isEmpty
                              ? _buildEmptyState()
                              : _buildShopsList(filteredShops),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.lightTextPrimary),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightCardBorder,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.routeName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
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
          ),
          IconButton(
            onPressed: _loadShops,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.lightTextPrimary),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightCardBorder,
              padding: const EdgeInsets.all(12),
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            child: _buildFilterTab('Unpaid', showUnpaid, () {
              setState(() => showUnpaid = true);
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterTab('Paid', !showUnpaid, () {
              setState(() => showUnpaid = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "🔴 Refresh the page to see the time remaining 🔴",
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.lightTextPrimary,
                  duration: const Duration(seconds: 3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: label == 'Unpaid'
                      ? [AppColors.accentBlueDark, AppColors.accentTealDark]
                      : [AppColors.successDark, AppColors.success],
                )
              : null,
          color: isActive ? null : AppColors.lightBackground,
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
            showUnpaid
                ? Icons.check_circle_outline_rounded
                : Icons.store_outlined,
            size: 64,
            color: AppColors.lightTextMuted,
          ),
          const SizedBox(height: 16),
          Text(
            showUnpaid ? 'All shops are paid!' : 'No paid shops yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopsList(List<Map<String, dynamic>> shops) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
        margin: const EdgeInsets.only(bottom: 14),
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
                      final shopIndex = updatedShops
                          .indexWhere((shop) => shop['name'] == shopName);
                      if (shopIndex != -1) {
                        final shopId = updatedShops[shopIndex]['id'];
                        final currentAmount = updatedShops[shopIndex]['amount'];
                        final newAmount = currentAmount - reducedAmount;

                        mockService.updateShopBalance(
                            widget.routeName, shopId, reducedAmount);

                        setState(() {
                          updatedShops[shopIndex]['status'] = 'Paid';
                          updatedShops[shopIndex]['amount'] = newAmount;
                          allShops = updatedShops;
                        });

                        _startCountdown(shopName);
                      }
                    },
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPaid
                      ? AppColors.successDark.withOpacity(0.3)
                      : AppColors.lightCardBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPaid
                        ? AppColors.successDark.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Shop Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? AppColors.successDark.withOpacity(0.15)
                          : AppColors.accentBlueDark.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.store_rounded,
                      color: isPaid
                          ? AppColors.successDark
                          : AppColors.accentBlueDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Shop Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isPaid
                                ? AppColors.successDark
                                : AppColors.accentTealDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop['address'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shop['phone'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isPaid && shop['paidAmount'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.successDark.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Paid: Rs.${shop['paidAmount']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.successDark,
                              ),
                            ),
                          )
                        else if (!isPaid && shop['amount'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningDark.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Balance: Rs.${shop['amount']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warningDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isPaid && remainingSeconds > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.errorDark.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formatDuration(Duration(seconds: remainingSeconds)),
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.errorDark,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () {
                            final lat = shop['latitude'];
                            final lng = shop['longitude'];

                            if (lat == null || lng == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Location not available for this shop",
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: AppColors.lightTextPrimary,
                                ),
                              );
                            } else {
                              final googleMapsUrl = Uri.parse(
                                  "https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                              launchUrl(googleMapsUrl,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.location_on_rounded),
                          color: AppColors.accentPinkDark,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.accentPinkDark.withOpacity(0.12),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
