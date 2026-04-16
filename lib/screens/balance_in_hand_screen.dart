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

  bool hasBalanceValue = false;
  bool hasTodayCollectionValue = false;
  bool hasWeekCollectionValue = false;

  double totalBalance = 0.0;
  double todayCollection = 0.0;
  double weekCollection = 0.0;

  DateTime selectedTodayCollectionDate = DateTime.now();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _initializeBalance();
  }

  /// Initialize all balance data fetches - runs in parallel for faster loading
  Future<void> _initializeBalance() async {
    try {
      await _refreshAllBalances(loadCachedFirst: true);
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
      await _refreshAllBalances();
    } catch (e) {
      print('ERROR in _loadData: $e');
    }
  }

  Future<void> _refreshAllBalances({bool loadCachedFirst = false}) async {
    final branchId = BranchContext().branchId;
    if (branchId == null) {
      print('❌ No branch ID available');
      return;
    }

    if (loadCachedFirst) {
      await _loadCachedValues(branchId);
    }

    final shopDocs = await _getBranchShops(branchId);

    await Future.wait([
      _fetchTotalPaidAcrossAllRoutes(branchId, shopDocs),
      _fetchTotalPaidToday(
        branchId,
        shopDocs,
        targetDate: selectedTodayCollectionDate,
      ),
      _fetchWeekPaid(branchId, shopDocs),
    ]);
  }

  Future<void> _loadCachedValues(String branchId) async {
    try {
      final results = await Future.wait([
        firestore
            .collection('branches')
            .doc(branchId)
            .collection('admin')
            .doc('stats')
            .get(),
        firestore
            .collection('branches')
            .doc(branchId)
            .collection('admin')
            .doc('summary')
            .get(),
      ]);

      final statsData = results[0].data();
      final summaryData = results[1].data();

      if (!mounted) return;
      setState(() {
        if (statsData != null) {
          if (statsData.containsKey('cashcollector_balance')) {
            totalBalance = _toDouble(statsData['cashcollector_balance']);
            hasBalanceValue = true;
          }
          if (statsData.containsKey('cashcollector_week_paid')) {
            weekCollection = _toDouble(statsData['cashcollector_week_paid']);
            hasWeekCollectionValue = true;
          }
        }

        if (summaryData != null && summaryData.containsKey('todaytotalPaid')) {
          todayCollection = _toDouble(summaryData['todaytotalPaid']);
          hasTodayCollectionValue = true;
        }
      });
    } catch (e) {
      print('⚠️ Error loading cached balance values: $e');
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getBranchShops(
    String branchId,
  ) async {
    final routesSnapshot =
        await firestore
            .collection('branches')
            .doc(branchId)
            .collection('routes')
            .get();

    final shopSnapshots = await Future.wait(
      routesSnapshot.docs.map(
        (routeDoc) => routeDoc.reference.collection('shops').get(),
      ),
    );

    return [for (final shopSnapshot in shopSnapshots) ...shopSnapshot.docs];
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatSelectedDateLabel() {
    if (_isSameDate(selectedTodayCollectionDate, DateTime.now())) {
      return 'Today';
    }
    return MaterialLocalizations.of(
      context,
    ).formatMediumDate(selectedTodayCollectionDate);
  }

  Future<void> _pickTodayCollectionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedTodayCollectionDate,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: now,
      helpText: 'Select Collection Date',
    );

    if (picked == null) return;

    final normalizedPicked = _dateOnly(picked);
    if (_isSameDate(normalizedPicked, selectedTodayCollectionDate)) return;

    if (mounted) {
      setState(() {
        selectedTodayCollectionDate = normalizedPicked;
        isTodayCollectionLoading = true;
      });
    }

    final branchId = BranchContext().branchId;
    if (branchId == null) {
      print('❌ No branch ID available');
      return;
    }

    final shopDocs = await _getBranchShops(branchId);
    await _fetchTotalPaidToday(
      branchId,
      shopDocs,
      targetDate: selectedTodayCollectionDate,
    );
  }

  Future<double> _sumTransactionsInBatches({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> shopDocs,
    required Timestamp start,
    Timestamp? end,
    required bool Function(String? type) includeType,
  }) async {
    const int batchSize = 20;
    double total = 0.0;

    for (int i = 0; i < shopDocs.length; i += batchSize) {
      final batch = shopDocs.skip(i).take(batchSize).toList();

      final snapshots = await Future.wait(
        batch.map((shopDoc) {
          Query<Map<String, dynamic>> q = shopDoc.reference
              .collection('transactions')
              .where('timestamp', isGreaterThanOrEqualTo: start);
          if (end != null) {
            q = q.where('timestamp', isLessThanOrEqualTo: end);
          }
          return q.get();
        }),
      );

      for (final txSnapshot in snapshots) {
        for (final txDoc in txSnapshot.docs) {
          final txData = txDoc.data();
          final type = txData['type']?.toString();
          if (includeType(type)) {
            total += _toDouble(txData['amount']);
          }
        }
      }
    }

    return total;
  }

  /// Fetch total paid across all routes in this branch
  Future<void> _fetchTotalPaidAcrossAllRoutes(
    String branchId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> shopDocs,
  ) async {
    if (mounted) {
      setState(() => isBalanceLoading = true);
    }
    try {
      double totalPaid = 0;

      for (final shopDoc in shopDocs) {
        final shopData = shopDoc.data();
        totalPaid += _toDouble(shopData['totalPaid']);
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
          })
          .catchError((error) {
            print('⚠️ Error updating cashcollector_balance: $error');
          });

      if (mounted) {
        setState(() {
          totalBalance = totalPaid;
          hasBalanceValue = true;
        });
      }
      print('✅ Saved cashcollector_balance to Firestore: Rs $totalPaid');
    } catch (e) {
      print('Error in _fetchTotalPaidAcrossAllRoutes: $e');
    } finally {
      if (mounted) {
        setState(() => isBalanceLoading = false);
      }
    }
  }

  /// Fetch total paid today in this branch
  Future<void> _fetchTotalPaidToday(
    String branchId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> shopDocs, {
    DateTime? targetDate,
  }) async {
    if (mounted) {
      setState(() => isTodayCollectionLoading = true);
    }
    try {
      final selectedDate = _dateOnly(targetDate ?? DateTime.now());
      final dateStartTs = Timestamp.fromDate(selectedDate);
      final dateEndTs = Timestamp.fromDate(
        DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          23,
          59,
          59,
          999,
        ),
      );
      final isToday = _isSameDate(selectedDate, DateTime.now());

      final totalPaidToday = await _sumTransactionsInBatches(
        shopDocs: shopDocs,
        start: dateStartTs,
        end: dateEndTs,
        includeType: (type) => type == null || type == 'paid',
      );

      // Persist only real today's collection, avoid overwriting cache when viewing older dates.
      if (isToday) {
        await firestore
            .collection('branches')
            .doc(branchId)
            .collection('admin')
            .doc('summary')
            .update({
              'todaytotalPaid': totalPaidToday,
              'lastUpdated': Timestamp.now(),
            })
            .catchError((error) {
              print('⚠️ Error updating todaytotalPaid: $error');
            });
      }

      if (mounted) {
        setState(() {
          todayCollection = totalPaidToday;
          hasTodayCollectionValue = true;
        });
      }
      if (isToday) {
        print('✅ Saved todaytotalPaid to Firestore: Rs $totalPaidToday');
      } else {
        print('✅ Loaded selected date collection: Rs $totalPaidToday');
      }
    } catch (e) {
      print('Error in _fetchTotalPaidToday: $e');
    } finally {
      if (mounted) {
        setState(() => isTodayCollectionLoading = false);
      }
    }
  }

  /// Fetch total paid this week in this branch
  Future<void> _fetchWeekPaid(
    String branchId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> shopDocs,
  ) async {
    if (mounted) {
      setState(() => isWeekCollectionLoading = true);
    }
    try {
      final now = DateTime.now();
      final int currentWeekday = now.weekday;
      final DateTime mondayThisWeek = now.subtract(
        Duration(days: currentWeekday - 1),
      );

      final Timestamp startOfWeek = Timestamp.fromDate(
        DateTime(
          mondayThisWeek.year,
          mondayThisWeek.month,
          mondayThisWeek.day,
          0,
          0,
          0,
        ),
      );

      // Week-to-date: include only completed time from Monday 00:00 up to now.
      final Timestamp endOfWeek = Timestamp.fromDate(now);

      final total = await _sumTransactionsInBatches(
        shopDocs: shopDocs,
        start: startOfWeek,
        end: endOfWeek,
        includeType:
            (type) => type == null || type != 'Credit' || type == 'paid',
      );

      // Save week's collection to Firestore
      await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('stats')
          .update({
            'cashcollector_week_paid': total,
            'lastUpdated': Timestamp.now(),
          })
          .catchError((error) {
            print('⚠️ Error updating cashcollector_week_paid: $error');
          });

      print('✅ Saved cashcollector_week_paid to Firestore: Rs $total');

      if (mounted) {
        setState(() {
          weekCollection = total;
          hasWeekCollectionValue = true;
        });
      }
    } catch (e) {
      print('Error in _fetchWeekPaid: $e');
    } finally {
      if (mounted) {
        setState(() => isWeekCollectionLoading = false);
      }
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
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.lightTextPrimary,
            ),
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
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.lightTextPrimary,
            ),
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
          colors: [AppColors.accentTealDark, AppColors.accentBlueDark],
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
          (isBalanceLoading && !hasBalanceValue)
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
        Expanded(child: _buildTodayCollectionCard()),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'This Week',
            weekCollection,
            Icons.date_range_rounded,
            AppColors.accentPurpleDark,
            isWeekCollectionLoading && !hasWeekCollectionValue,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCollectionCard() {
    final color = AppColors.successDark;
    final isLoading = isTodayCollectionLoading;

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
                  'Today\'s Collection',
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
                child: Icon(Icons.today_rounded, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _pickTodayCollectionDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    _formatSelectedDateLabel(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          isLoading
              ? SpinKitThreeBounce(color: color, size: 18)
              : Text(
                'Rs. $todayCollection',
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

  Widget _buildStatCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    bool isLoading,
  ) {
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
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.accentBlueDark,
                  size: 22,
                ),
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
            'Total Collected',
            totalBalance,
            AppColors.accentTealDark,
            isBalanceLoading && !hasBalanceValue,
          ),
          const Divider(height: 24, color: AppColors.lightCardBorder),
          _buildSummaryRow(
            '${_formatSelectedDateLabel()} Amount',
            todayCollection,
            AppColors.successDark,
            isTodayCollectionLoading,
          ),
          const Divider(height: 24, color: AppColors.lightCardBorder),
          _buildSummaryRow(
            'Week\'s Amount',
            weekCollection,
            AppColors.accentPurpleDark,
            isWeekCollectionLoading && !hasWeekCollectionValue,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    Color color,
    bool isLoading,
  ) {
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
