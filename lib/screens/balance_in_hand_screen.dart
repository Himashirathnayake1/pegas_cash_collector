import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

class BalanceInHandScreen extends StatefulWidget {
  const BalanceInHandScreen({super.key});

  @override
  State<BalanceInHandScreen> createState() => _BalanceInHandScreenState();
}

class _BalanceInHandScreenState extends State<BalanceInHandScreen>
    with SingleTickerProviderStateMixin {
  final firestore = FirebaseFirestore.instance;

  bool isBalanceLoading = false;
  bool isTodayCollectionLoading = false;
  bool isWeekCollectionLoading = false;
  bool isInitializing = true;

  double totalBalance = 0.0;
  double todayCollection = 0.0;
  double weekCollection = 0.0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _initializeBalance();
  }

  /// Initialize all balance data fetches - runs in parallel for faster loading
  Future<void> _initializeBalance() async {
    try {
      await Future.wait([
        _fetchTotalPaidAcrossAllRoutes(),
        _fetchTotalPaidToday(),
        _fetchWeekPaid(),
      ]);
    } catch (e) {
      print('ERROR in _initializeBalance: $e');
    } finally {
      if (mounted) {
        setState(() {
          isInitializing = false;
        });
      }
    }
  }

  /// Refresh all balance data
  Future<void> _loadData() async {
    try {
      await Future.wait([
        _fetchTotalPaidAcrossAllRoutes(),
        _fetchTotalPaidToday(),
        _fetchWeekPaid(),
      ]);
    } catch (e) {
      print('ERROR in _loadData: $e');
    }
  }

  /// Fetch total paid across all routes in this branch
  Future<void> _fetchTotalPaidAcrossAllRoutes() async {
    setState(() => isBalanceLoading = true);
    try {
      final branchId = BranchContext().branchId;
      if (branchId == null) {
        print('❌ No branch ID available');
        setState(() => isBalanceLoading = false);
        return;
      }

      double totalPaid = 0;

      // Get all routes in this branch
      final routesSnapshot = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .get();

      // For each route, get all shops and sum totalPaid
      for (var routeDoc in routesSnapshot.docs) {
        final shopsSnapshot = await routeDoc.reference
            .collection('shops')
            .get();

        for (var shopDoc in shopsSnapshot.docs) {
          final shopData = shopDoc.data();
          final dynamic paidVal = shopData['totalPaid'];
          double shopTotalPaid = 0.0;
          if (paidVal is num) shopTotalPaid = paidVal.toDouble();
          else if (paidVal is String) shopTotalPaid = double.tryParse(paidVal) ?? 0.0;
          totalPaid += shopTotalPaid;
        }
      }

      // Save calculated balance to Firestore
      await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('stats')
          .update({
        'cashcollector_balance': totalPaid,
        'lastUpdated': Timestamp.now(),
      }).catchError((error) {
        print('⚠️ Error updating cashcollector_balance: $error');
      });

      setState(() {
        totalBalance = totalPaid;
      });
      print('✅ Saved cashcollector_balance to Firestore: Rs $totalPaid');
    } catch (e) {
      print('Error in _fetchTotalPaidAcrossAllRoutes: $e');
    } finally {
      setState(() => isBalanceLoading = false);
    }
  }

  /// Fetch total paid today in this branch
  Future<void> _fetchTotalPaidToday() async {
    setState(() => isTodayCollectionLoading = true);
    try {
      final branchId = BranchContext().branchId;
      if (branchId == null) {
        print('❌ No branch ID available');
        setState(() => isTodayCollectionLoading = false);
        return;
      }

      double totalPaidToday = 0;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayStartTs = Timestamp.fromDate(todayStart);

      // Get all routes in this branch
      final routesSnapshot = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .get();

      // For each route, get all shops and their transactions
      for (var routeDoc in routesSnapshot.docs) {
        final shopsSnapshot = await routeDoc.reference
            .collection('shops')
            .get();

        for (var shopDoc in shopsSnapshot.docs) {
          final txSnapshot = await shopDoc.reference
              .collection('transactions')
              .where('timestamp', isGreaterThanOrEqualTo: todayStartTs)
              .get();

          for (var txDoc in txSnapshot.docs) {
            final txData = txDoc.data();
            final type = txData['type'];
            final dynamic amtVal = txData['amount'];
            double amount = 0.0;
            if (amtVal is num) amount = amtVal.toDouble();
            else if (amtVal is String) amount = double.tryParse(amtVal) ?? 0.0;
            if (type == 'paid' || type == null) {
              totalPaidToday += amount;
            }
          }
        }
      }

      // Save today's collection to Firestore
      await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('summary')
          .update({
        'todaytotalPaid': totalPaidToday,
        'lastUpdated': Timestamp.now(),
      }).catchError((error) {
        print('⚠️ Error updating todaytotalPaid: $error');
      });

      setState(() {
        todayCollection = totalPaidToday;
      });
      print('✅ Saved todaytotalPaid to Firestore: Rs $totalPaidToday');
    } catch (e) {
      print('Error in _fetchTotalPaidToday: $e');
    } finally {
      setState(() => isTodayCollectionLoading = false);
    }
  }

  /// Fetch total paid this week in this branch
  Future<void> _fetchWeekPaid() async {
    setState(() => isWeekCollectionLoading = true);
    try {
      final branchId = BranchContext().branchId;
      if (branchId == null) {
        print('❌ No branch ID available');
        setState(() => isWeekCollectionLoading = false);
        return;
      }

      final now = DateTime.now();
      final int currentWeekday = now.weekday;
      final DateTime mondayThisWeek = now.subtract(Duration(days: currentWeekday - 1));
      final DateTime sundayThisWeek = mondayThisWeek.add(const Duration(days: 6));

      final Timestamp startOfWeek = Timestamp.fromDate(DateTime(
        mondayThisWeek.year,
        mondayThisWeek.month,
        mondayThisWeek.day,
        0,
        0,
        0,
      ));

      final Timestamp endOfWeek = Timestamp.fromDate(DateTime(
        sundayThisWeek.year,
        sundayThisWeek.month,
        sundayThisWeek.day,
        23,
        59,
        59,
      ));

      double total = 0;

      // Get all routes in this branch
      final routesSnapshot = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .get();

      // For each route, get all shops and their transactions in week range
      for (var routeDoc in routesSnapshot.docs) {
        final shopsSnapshot = await routeDoc.reference
            .collection('shops')
            .get();

        for (var shopDoc in shopsSnapshot.docs) {
          final txSnapshot = await shopDoc.reference
              .collection('transactions')
              .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
              .where('timestamp', isLessThanOrEqualTo: endOfWeek)
              .get();

          for (var txDoc in txSnapshot.docs) {
            final txData = txDoc.data();
            final type = txData['type'];
            final dynamic amtVal = txData['amount'];
            double amount = 0.0;
            if (amtVal is num) amount = amtVal.toDouble();
            else if (amtVal is String) amount = double.tryParse(amtVal) ?? 0.0;
            if (type == null || type == 'paid' || type != 'Credit') {
              total += amount;
            }
          }
        }
      }

      // Save week's collection to Firestore
      await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('stats')
          .update({
        'cashcollector_week_paid': total,
        'lastUpdated': Timestamp.now(),
      }).catchError((error) {
        print('⚠️ Error updating cashcollector_week_paid: $error');
      });

      print('✅ Saved cashcollector_week_paid to Firestore: Rs $total');

      setState(() {
        weekCollection = total;
      });
    } catch (e) {
      print('Error in _fetchWeekPaid: $e');
    } finally {
      setState(() => isWeekCollectionLoading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.accentTealDark,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildMainBalanceCard(),
                        const SizedBox(height: 24),
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        _buildRecentActivityCard(),
                      ],
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
          Text(
            'Balance in Hand',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadData,
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

  Widget _buildMainBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentTealDark,
            AppColors.accentBlueDark,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTealDark.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Balance In Hand ',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          isBalanceLoading
              ? const SpinKitThreeBounce(color: Colors.white, size: 28)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rs.',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      totalBalance % 1 == 0
                          ? totalBalance.toInt().toString()
                          : totalBalance.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 8),
          Text(
            'Total amount collected',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
          'Today\'s Collection',
          todayCollection,
          Icons.today_rounded,
          AppColors.successDark,
          isTodayCollectionLoading,
        )),
        const SizedBox(width: 16),
        Expanded(
            child: _buildStatCard(
          'This Week',
          weekCollection,
          Icons.date_range_rounded,
          AppColors.accentPurpleDark,
          isWeekCollectionLoading,
        )),
      ],
    );
  }

  Widget _buildStatCard(
      String title, double amount, IconData icon, Color color, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isLoading
              ? SpinKitThreeBounce(color: color, size: 18)
              : Text(
                  'Rs. $amount',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentBlueDark.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded,
                    color: AppColors.accentBlueDark, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                'Balance Summary',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow(
              'Total Collected', totalBalance, AppColors.accentTealDark, isBalanceLoading),
          const Divider(height: 24, color: AppColors.lightCardBorder),
          _buildSummaryRow(
              'Today\'s Amount', todayCollection, AppColors.successDark, isTodayCollectionLoading),
          const Divider(height: 24, color: AppColors.lightCardBorder),
          _buildSummaryRow(
              'Week\'s Amount', weekCollection, AppColors.accentPurpleDark, isWeekCollectionLoading),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        isLoading
            ? SpinKitThreeBounce(color: color, size: 14)
            : Text(
                'Rs. $amount',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
      ],
    );
  }
}
