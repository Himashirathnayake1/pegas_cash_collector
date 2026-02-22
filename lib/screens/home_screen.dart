import 'dart:ui';
import 'dart:async';
import 'package:pegas_cashcollector/screens/addReceipts.dart';
import 'package:pegas_cashcollector/screens/balance_in_hand_screen.dart';
import 'package:pegas_cashcollector/screens/balance_screen.dart';
import 'package:pegas_cashcollector/screens/codeEntryScreen.dart';
import 'package:pegas_cashcollector/screens/stocklist.dart';
import 'package:pegas_cashcollector/screens/termsandconditions.dart';
import 'package:pegas_cashcollector/screens/achievements_screen.dart';
import 'package:pegas_cashcollector/screens/route_shops_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'low_level_shops_screen.dart';
import '../services/mock_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

class RoutePage extends StatefulWidget {
  final String selectedArea;

  const RoutePage({super.key, required this.selectedArea});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final String googleFormUrl =
      "https://docs.google.com/forms/d/e/1FAIpQLSfZOSjqEHGOQuRZeCr6XF7JWrqLbFronAMdiHJ28d853Nau8g/viewform?usp=header";

  bool isBalanceLoading = false;
  bool isTodayCollectionLoading = false;
  bool isWeekCollectionLoading = false;
  double totalPaidAcrossRoutes = 0;
  bool isUploading = false;
  double totalPaidTodayAmount = 0;
  double totalPaidThisWeekAmount = 0;
  double targetCollectAmount = 0.0;
  final mockService = MockDataService();

  // Routes list variables
  List<Map<String, dynamic>> allRoutes = [];
  bool isRoutesLoading = true;
  Timer? _uiUpdateTimer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadMockData();
    _fetchDailyTarget();
    _loadRoutes();
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
    super.dispose();
  }

  void _loadMockData() {
    setState(() {
      totalPaidAcrossRoutes = mockService.latestTotalPaid;
      totalPaidTodayAmount = mockService.todayTotalPaid;
      totalPaidThisWeekAmount = mockService.getWeekPaid();
      // targetCollectAmount is now fetched from Firestore
    });
  }

  Future<void> _fetchDailyTarget() async {
    try {
      final branchId = BranchContext().branchId;
      print('📊 Fetching daily target for branch: $branchId');

      final firestore = FirebaseFirestore.instance;
      final targetDoc = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('stats')
          .get();

      if (targetDoc.exists) {
        final data = targetDoc.data();
        final target = data?['cashcollector_target'];
        
        setState(() {
          targetCollectAmount = (target is num) ? target.toDouble() : 0.0;
        });
        print('✅ Daily target loaded: Rs. $targetCollectAmount');
      } else {
        print('⚠️ Target document not found');
        setState(() {
          targetCollectAmount = mockService.targetWeekAmount;
        });
      }
    } catch (e) {
      print('❌ Error fetching daily target: $e');
      setState(() {
        targetCollectAmount = mockService.targetWeekAmount;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isUploading = true;
    });
    await _loadRoutes();
    _loadMockData();
    await _fetchDailyTarget();
    setState(() {
      isUploading = false;
    });
  }

  Future<void> _loadRoutes() async {
    setState(() => isRoutesLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final firestore = FirebaseFirestore.instance;
      final updatedRoutes = <Map<String, dynamic>>[];
      
      // Get branch ID from context
      final branchId = BranchContext().branchId;
      if (branchId == null) {
        print('❌ No branch ID available in context');
        setState(() => isRoutesLoading = false);
        return;
      }

      print('📍 Loading routes for branch: $branchId');

      // Get all routes for this branch
      final routesSnap = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .get();
          
      if (routesSnap.docs.isEmpty) {
        print('⚠️ No routes found for branch $branchId');
        updatedRoutes.add({
          'id': 'default',
          'name': 'Default Route',
          'shopCount': 0,
        });
      } else {
        for (var routeDoc in routesSnap.docs) {
          int shopCount = 0;
          // Count shops in this route
          final shopsSnap = await firestore
              .collection('branches')
              .doc(branchId)
              .collection('routes')
              .doc(routeDoc.id)
              .collection('shops')
              .get();
          shopCount = shopsSnap.docs.length;

          updatedRoutes.add({
            'id': routeDoc.id,
            'name': routeDoc.data()['name'] ?? routeDoc.id,
            'shopCount': shopCount,
          });
          
          print('✅ Loaded route: ${routeDoc.id} with $shopCount shops');
        }
      }

      setState(() {
        allRoutes = updatedRoutes;
      });
    } catch (e) {
      print('❌ Error loading routes: $e');
      // On error, fallback to empty list
      setState(() {
        allRoutes = [];
      });
    } finally {
      if (mounted) setState(() => isRoutesLoading = false);
    }
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      drawer: _buildDrawer(),
      body: Container(
        color: AppColors.lightBackground,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                // Search and Filter
                // Routes List
                Expanded(
                  child: isRoutesLoading
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
                                'Loading routes...',
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
                          child: allRoutes.isEmpty
                              ? _buildEmptyState()
                              : _buildRoutesList(allRoutes),
                        ),
                ),
                // Fixed bottom target card
                _buildTargetCard(),
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
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: const Icon(Icons.menu_rounded,
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
                  widget.selectedArea,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  '${allRoutes.length} Routes',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshData,
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

  Widget _buildDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isMediumScreen = screenHeight >= 700 && screenHeight < 850;

    // Responsive drawer width: 80% of screen but max 320, min 280
    final drawerWidth = (screenWidth * 0.80).clamp(280.0, 320.0);

    // Responsive spacing values
    final headerPadding = isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0);
    final iconSize = isSmallScreen ? 36.0 : (isMediumScreen ? 42.0 : 48.0);
    final titleFontSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
    final subtitleFontSize =
        isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0);
    final menuItemFontSize =
        isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);
    final menuIconSize = isSmallScreen ? 22.0 : (isMediumScreen ? 24.0 : 26.0);
    final menuItemPaddingV =
        isSmallScreen ? 4.0 : (isMediumScreen ? 8.0 : 12.0);
    final menuItemPaddingH =
        isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0);
    final sectionGap = isSmallScreen ? 8.0 : (isMediumScreen ? 12.0 : 16.0);

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: AppColors.lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(headerPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentTealDark,
                      AppColors.accentBlueDark,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.account_circle_rounded,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 14 : 18),
                    Text(
                      'Pegas Flex',
                      style: GoogleFonts.orbitron(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          widget.selectedArea,
                        style: GoogleFonts.poppins(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: sectionGap),

              // Menu Items Section
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDrawerMenuItem(
                        icon: Icons.home_rounded,
                        title: 'Home',
                        onTap: () {
                          Navigator.pop(context);
                          // showUnpaid reset removed - now using route view
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      _buildDrawerMenuItem(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Balance in Hand',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BalanceInHandScreen()),
                          );
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),

                      _buildDrawerMenuItem(
                        icon: Icons.inventory_2_rounded,
                        title: 'Stock List',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CollectorStockListPage()),
                          );
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      _buildDrawerMenuItem(
                        icon: Icons.receipt_long_rounded,
                        title: 'Add Receipt',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddReceipts()),
                          );
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),

                      // ...existing code...
                      // ...existing code...
                      _buildDrawerMenuItem(
                        icon: Icons.store_rounded,
                        title: 'Low Level Shops',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LowLevelShopsScreen(),
                            ),
                          );
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),
                      _buildDrawerMenuItem(
                        icon: Icons.emoji_events_rounded,
                        title: 'Achievements',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AchievementsScreen()),
                          );
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      _buildDrawerMenuItem(
                        icon: Icons.description_rounded,
                        title: 'Terms & Conditions',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TermsAndConditionsPage()),
                          );
                        },
                        fontSize: menuItemFontSize,
                        iconSize: menuIconSize,
                        paddingH: menuItemPaddingH,
                        paddingV: menuItemPaddingV,
                      ),
                    ],
                  ),
                ),
              ),

              // Logout Section
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  border: Border(
                    top: BorderSide(color: AppColors.lightCardBorder, width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccessCodeEntryScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorDark,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double fontSize,
    required double iconSize,
    required double paddingH,
    required double paddingV,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: paddingH, vertical: paddingV + 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentTealDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.accentTealDark,
                  size: iconSize,
                ),
              ),
              SizedBox(width: paddingH * 0.6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.lightTextMuted,
                size: iconSize * 0.9,
              ),
            ],
          ),
        ),
      ),
    );
  }  // Search and filter methods removed - now using route view instead of shop view

  Widget _buildEmptyState() {
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.route,
            size: 64,
            color: AppColors.lightTextMuted,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No routes found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesList(List<Map<String, dynamic>> routes) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return _buildRouteCard(route, index);
      },
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route, int index) {
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
                  builder: (context) => RouteShopsScreen(
                    routeId: route['id'],
                    routeName: route['name'],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2137),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1A3A5C),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D2137).withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Route Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.route,
                      color: AppColors.accentTeal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Route Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route['name'] ?? 'Unknown Route',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
                  // Arrow Icon
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.accentTeal,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
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
                    routeName: widget.selectedArea,
                    shopId: shop['id'],
                    onBalanceAdjusted: (shopName, reducedAmount) async {
                      // allShops reference removed - this method is no longer used
                      // final updatedShops =
                      //     List<Map<String, dynamic>>.from(allShops);
                      // final shopIndex =
                      //     updatedShops.indexWhere((s) => s['name'] == shopName);
                      // if (shopIndex != -1) {
                      //   final shopId = updatedShops[shopIndex]['id'];
                      //   final currentAmount = updatedShops[shopIndex]['amount'];
                      //   final newAmount = currentAmount - reducedAmount;

                      //   mockService.updateShopBalance(
                      //     widget.selectedArea, shopId, reducedAmount);

                        // setState(() {
                        //   // allShops = updatedShops; // removed - method no longer used
                        // });
                      // }
                    },
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2137),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPaid
                      ? AppColors.successDark.withOpacity(0.5)
                      : const Color(0xFF1A3A5C),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPaid
                        ? AppColors.successDark.withOpacity(0.2)
                        : const Color(0xFF0D2137).withOpacity(0.5),
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
                          ? AppColors.successDark.withOpacity(0.2)
                          : AppColors.accentTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.store_rounded,
                      color: isPaid ? AppColors.success : AppColors.accentTeal,
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
                                ? AppColors.success
                                : AppColors.accentTeal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop['address'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shop['phone'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isPaid && shop['paidAmount'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Paid: Rs.${shop['paidAmount']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          )
                        else if (!isPaid && shop['amount'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Balance: Rs.${shop['amount']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
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
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (isPaid && remainingSeconds > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formatDuration(Duration(seconds: remainingSeconds)),
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        )
                      else ...[
                        // Location icon (moved up)
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
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
                            icon:
                                const Icon(Icons.location_on_rounded, size: 24),
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Call icon
                        SizedBox(
                          height: 36,
                          width: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final phone = shop['phone'];
                              if (phone != null &&
                                  phone.toString().isNotEmpty) {
                                final phoneUrl = Uri.parse("tel:$phone");
                                launchUrl(phoneUrl);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Phone number not available for this shop",
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: AppColors.lightTextPrimary,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.call_rounded, size: 20),
                            color: AppColors.accentTeal,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.accentTeal.withOpacity(0.2),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildTargetCard() {
    final progress = totalPaidThisWeekAmount / targetCollectAmount;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warningDark.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.warningDark.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningDark.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.star_rounded,
                    color: AppColors.warningDark, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Target',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. $targetCollectAmount',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
              // Container(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: progress >= 1
              //         ? AppColors.successDark.withOpacity(0.15)
              //         : AppColors.accentBlueDark.withOpacity(0.15),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Text(
              //     '${(progress * 100)}%',
              //     style: GoogleFonts.poppins(
              //       fontSize: 14,
              //       fontWeight: FontWeight.w700,
              //       color: progress >= 1
              //           ? AppColors.successDark
              //           : AppColors.accentBlueDark,
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.lightCardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1 ? AppColors.successDark : AppColors.warningDark,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

Widget paidShopsSummaryCard() {
  final mockService = MockDataService();

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.successDark.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                "Today's Paid",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${mockService.todayPaidShopsCount}",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.accentBlueDark.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                "Month's Paid",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${mockService.monthPaidShopsCount}",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentBlueDark,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
