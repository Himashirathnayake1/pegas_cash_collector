import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen>
    with TickerProviderStateMixin {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  bool get _isSingleDay =>
      _startDate.year == _endDate.year &&
      _startDate.month == _endDate.month &&
      _startDate.day == _endDate.day;

  int get _numberOfDays =>
      _endDate.difference(_startDate).inDays + 1;

  bool get _isToday {
    final now = DateTime.now();
    return _isSingleDay &&
        _startDate.year == now.year &&
        _startDate.month == now.month &&
        _startDate.day == now.day;
  }

  String _dateKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DateTime> get _daysInRange {
    final days = <DateTime>[];
    var d = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!d.isAfter(end)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  Future<Map<String, dynamic>> _fetchAggregateData() async {
    final branchId = BranchContext().branchId;
    if (branchId == null) return {};

    final fs = FirebaseFirestore.instance;

    double totalCollection = 0.0;
    int totalVisited = 0;
    int totalPaid = 0;
    int totalFeedback = 0;
    double totalIncentive = 0.0;
    double totalBasicEarned = 0.0;
    double lastCommissionPct = 0.0;
    double lastBasicSalary = 0.0;
    int lastTarget = 0;

    // Fetch stats defaults once
    try {
      final statsDoc = await fs
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('stats')
          .get();
      if (statsDoc.exists) {
        final s = statsDoc.data() ?? {};
        lastTarget = (s['cashcollector_target'] ?? 0) as int;
        lastCommissionPct = _asDouble(
            s['default_commission_percent'] ?? s['commission_percent']);
        lastBasicSalary = _asDouble(
            s['cashcollector_basic_salary'] ?? s['basic_salary']);
      }
    } catch (_) {}

    for (final day in _daysInRange) {
      final key = _dateKeyFor(day);
      final dayStart =
          DateTime(day.year, day.month, day.day, 0, 0, 0);
      final dayEnd =
          DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

      // 1. Try saved salary doc
      try {
        final salarySnap = await fs
            .collection('branches')
            .doc(branchId)
            .collection('cashcollector_salary')
            .doc(key)
            .get();
        if (salarySnap.exists) {
          final sd = salarySnap.data()!;
          totalCollection += _asDouble(sd['todayCollection']);
          totalVisited += (sd['shopsVisitedToday'] ?? 0) as int;
          totalPaid += (sd['paidShopCount'] ?? 0) as int;
          totalFeedback += (sd['feedbackShopCount'] ?? 0) as int;
          totalIncentive += _asDouble(sd['incentiveSalary'] ?? sd['finalSalary']);
          totalBasicEarned += _asDouble(sd['basicSalaryEarned']);
          if (sd['commissionPercent'] != null) {
            lastCommissionPct = _asDouble(sd['commissionPercent']);
          }
          if (sd['basicSalary'] != null) {
            lastBasicSalary = _asDouble(sd['basicSalary']);
          }
          if (sd['shopVisitTarget'] != null) {
            lastTarget = (sd['shopVisitTarget'] as num).toInt();
          }
          continue;
        }
      } catch (_) {}

      // 2. Try saved visits doc
      int dayVisited = 0;
      int dayPaid = 0;
      int dayFeedback = 0;
      bool hasVisitsDoc = false;

      try {
        final visitsSnap = await fs
            .collection('branches')
            .doc(branchId)
            .collection('cashcollector_visits')
            .doc(key)
            .get();
        if (visitsSnap.exists) {
          hasVisitsDoc = true;
          final vd = visitsSnap.data()!;
          dayVisited = (vd['totalVisited'] ?? 0) as int;
          dayPaid = (vd['paidShopCount'] ?? 0) as int;
          dayFeedback = (vd['feedbackShopCount'] ?? 0) as int;
        }
      } catch (_) {}

      // 3. Live: transactions
      double dayCollection = 0.0;
      final paidShopIdsSet = <String>{};
      final visitedShopIdsSet = <String>{};

      try {
        final routesSnap = await fs
            .collection('branches')
            .doc(branchId)
            .collection('routes')
            .get();
        for (final routeDoc in routesSnap.docs) {
          final shopsSnap =
              await routeDoc.reference.collection('shops').get();
          for (final shopDoc in shopsSnap.docs) {
            final shopId = shopDoc.id;
            try {
              final txSnap = await shopDoc.reference
                  .collection('transactions')
                  .get();
              for (final txDoc in txSnap.docs) {
                final txData = txDoc.data();
                final type = txData['type']?.toString();
                final tsRaw = txData['timestamp'] ??
                    txData['resetAt'] ??
                    txData['submittedAt'] ??
                    txData['createdAt'] ??
                    txData['date'];
                DateTime? txTime;
                if (tsRaw is Timestamp) txTime = tsRaw.toDate();
                else if (tsRaw is String) txTime = DateTime.tryParse(tsRaw);

                if (txTime != null &&
                    txTime.isAfter(
                        dayStart.subtract(const Duration(seconds: 1))) &&
                    txTime.isBefore(
                        dayEnd.add(const Duration(seconds: 1)))) {
                  if (type == null ||
                      type == 'paid' ||
                      type == 'partialPaid' ||
                      type == 'Cash') {
                    dayCollection += _asDouble(txData['amount']);
                    paidShopIdsSet.add(shopId);
                    visitedShopIdsSet.add(shopId);
                  }
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // 4. Live: feedback (if no visits doc)
      if (!hasVisitsDoc) {
        final feedbackShopIdsSet = <String>{};
        try {
          final fbSnap = await fs
              .collection('branches')
              .doc(branchId)
              .collection('feedback')
              .get();
          for (final fbDoc in fbSnap.docs) {
            final fbData = fbDoc.data();
            final tsRaw = fbData['createdAt'] ??
                fbData['timestamp'] ??
                fbData['time'];
            DateTime? fbTime;
            if (tsRaw is Timestamp) fbTime = tsRaw.toDate();
            else if (tsRaw is DateTime) fbTime = tsRaw;
            else if (tsRaw is String) fbTime = DateTime.tryParse(tsRaw);

            if (fbTime != null &&
                fbTime.isAfter(
                    dayStart.subtract(const Duration(seconds: 1))) &&
                fbTime.isBefore(
                    dayEnd.add(const Duration(seconds: 1)))) {
              final shopId = (fbData['shopId'] ??
                      fbData['shopName'] ??
                      fbData['name'] ??
                      fbDoc.id)
                  .toString()
                  .trim();
              if (shopId.isNotEmpty) {
                feedbackShopIdsSet.add(shopId);
                visitedShopIdsSet.add(shopId);
              }
            }
          }
        } catch (_) {}

        dayVisited = visitedShopIdsSet.length;
        dayPaid = paidShopIdsSet.length;
        dayFeedback = feedbackShopIdsSet.length;
      }

      final isThisToday = _isDateToday(day);
      if (dayCollection == 0 && isThisToday) {
        try {
          final summaryDoc = await fs
              .collection('branches')
              .doc(branchId)
              .collection('admin')
              .doc('summary')
              .get();
          if (summaryDoc.exists) {
            dayCollection =
                _asDouble(summaryDoc.data()?['todaytotalPaid']);
          }
        } catch (_) {}
      }

      final dayIncentive = lastCommissionPct > 0
          ? dayCollection * lastCommissionPct / 100.0
          : 0.0;
      final dayVisitPct = lastTarget > 0
          ? (dayVisited / lastTarget).clamp(0.0, 1.0)
          : 0.0;
      final dayBasicEarned = lastBasicSalary > 0
          ? lastBasicSalary * dayVisitPct
          : 0.0;

      totalCollection += dayCollection;
      totalVisited += dayVisited;
      totalPaid += dayPaid;
      totalFeedback += dayFeedback;
      totalIncentive += dayIncentive;
      totalBasicEarned += dayBasicEarned;
    }

    final totalSalary = totalIncentive + totalBasicEarned;
    final totalTargetRange = lastTarget * _numberOfDays;
    final visitPct = totalTargetRange > 0
        ? (totalVisited / totalTargetRange).clamp(0.0, 1.0)
        : 0.0;

    String status = 'below';
    if (visitPct >= 1.0) status = 'full';
    else if (visitPct >= 0.5) status = 'half';

    return {
      'todayCollection': totalCollection,
      'commissionPercent': lastCommissionPct,
      'incentiveSalary': totalIncentive,
      'basicSalary': lastBasicSalary,
      'basicSalaryEarned': totalBasicEarned,
      'visitAchievementPercent': visitPct * 100,
      'finalSalary': totalSalary,
      'shopVisitTarget': lastTarget * _numberOfDays,
      'shopsVisitedToday': totalVisited,
      'paidShopCount': totalPaid,
      'feedbackShopCount': totalFeedback,
      'dayStatus': status,
      'numberOfDays': _numberOfDays,
    };
  }

  bool _isDateToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange:
          DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: Colors.white,
          dialogBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryDark,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1A2744),
            secondary: AppColors.accentBlueDark,
            onSecondary: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fadeController
        ..reset()
        ..forward();
    }
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _fetchAggregateData(),
                    key: ValueKey('$_startDate-$_endDate'),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accentBlue),
                        );
                      }

                      final data = snap.data ?? {};
                      if ((data['todayCollection'] ?? 0.0) == 0.0 &&
                          (data['shopsVisitedToday'] ?? 0) == 0 &&
                          !_isToday) {
                        return _buildEmptyState();
                      }
                      return _buildContent(data);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.12),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Salary',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _rangeLabel(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
         
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _isSingleDay
                        ? (_isToday ? 'Today' : _shortFmt(_startDate))
                        : '$_numberOfDays days',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────

  Widget _buildContent(Map<String, dynamic> data) {
    final collection = _asDouble(data['todayCollection']);
    final pct = _asDouble(data['commissionPercent']);
    final incentiveSalary = _asDouble(data['incentiveSalary']);
    final basicSalary = _asDouble(data['basicSalary']);
    final basicEarned = _asDouble(data['basicSalaryEarned']);
    final visitPct = _asDouble(data['visitAchievementPercent']);
    final totalSalary = _asDouble(data['finalSalary']);
    final target = (data['shopVisitTarget'] ?? 0) as int;
    final visited = (data['shopsVisitedToday'] ?? 0) as int;
    final paidCnt = (data['paidShopCount'] ?? 0) as int;
    final fbCnt = (data['feedbackShopCount'] ?? 0) as int;
    final status = data['dayStatus'] as String? ?? 'below';
    final statusInfo = _statusInfo(status);
    final visitProgress =
        target > 0 ? (visited / target).clamp(0.0, 1.0) : 0.0;
    final hasBasic = basicSalary > 0 || basicEarned > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        children: [
          // ── STEP 1: Date Range Selector ─────────────────
          _buildDateRangeBanner(),
          const SizedBox(height: 12),

          // ── STEP 4: Part 2 - Basic Salary & Visits ─────
          if (hasBasic) ...[
            _buildBasicCard(basicSalary, basicEarned, visitPct, visited,
                target, paidCnt, fbCnt, statusInfo, visitProgress),
            const SizedBox(height: 16),
          ],
         

          // ── STEP 3: Part 1 - Incentive Salary ───────────
          _buildIncentiveCard(collection, pct, incentiveSalary),
          const SizedBox(height: 16),

 // ── STEP 6: Day Status Banner ───────────────────
          _buildDayStatusBanner(statusInfo, status),
          const SizedBox(height: 16),
          // ── STEP 5: Step 3 - Final Total Salary ─────────
          _buildTotalHeroCard(totalSalary, incentiveSalary, basicEarned,
              hasBasic),
          const SizedBox(height: 16),

          // ── STEP 7: Full Summary Breakdown ──────────────
          _buildBreakdownCard(collection, pct, incentiveSalary,
              basicSalary, basicEarned, visitPct, totalSalary, visited,
              target, paidCnt, fbCnt, hasBasic),
        ],
      ),
    );
  }

  /// 1. Date Range Banner Widget
  Widget _buildDateRangeBanner() {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentBlueDark.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.date_range_rounded,
                  color: AppColors.accentBlueDark, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSingleDay ? 'Selected Date' : 'Selected Date Range',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    _rangeLabel(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF1A2744),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isSingleDay)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlueDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_numberOfDays days',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            else if (_isToday)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'TODAY',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromARGB(255, 209, 40, 40),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.edit_calendar_rounded,
                color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }



  /// Incentive Salary Card
  Widget _buildIncentiveCard(
      double collection, double pct, double incentive) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTealDark.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.percent_rounded,
                    color: AppColors.accentTealDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Incentive Salary',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF1A2744),
                      ),
                    ),
                   Text(
                      'This is your Commision ased on TODAY COLLECTION. Collect more to Earn more',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.red[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded,
                    color: Color(0xFF1B5E5C), size: 18),
                const SizedBox(width: 8),
                Text(
                  _isSingleDay ? 'Your Cash Collection:' : 'Total Collection ($_numberOfDays days):',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs ${collection.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E5C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                'Incentive Earned:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2744),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentTealDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accentTealDark.withOpacity(0.3)),
                ),
                child: Text(
                  'Rs ${incentive.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentTealDark,
                  ),
                ),
              ),
            ],
          ),

         
        ],
      ),
    );
  }

  /// Basic Salary & Shop Visits Card
  Widget _buildBasicCard(
    double basicSalary,
    double basicEarned,
    double visitPct,
    int visited,
    int target,
    int paidCnt,
    int fbCnt,
    Map<String, dynamic> statusInfo,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlueDark.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: AppColors.accentBlueDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Basic Salary & Shop Visits',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF1A2744),
                      ),
                    ),
                    Text(
                      'this is your basic salary based on shop visits (FEEDBACKED AND PAID SHOPS). Visit more to Earn more',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.red[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Shops Visited Count:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2744),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusInfo['color'] as Color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${statusInfo['icon']} ${statusInfo['label']}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid Shops: $paidCnt',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successDark,
                      ),
                    ),
                    Text(
                      'Feedback Shops: $fbCnt',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentBlueDark,
                      ),
                    ),
                    Text(
                      'Total: $visited',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A2744),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        statusInfo['color'] as Color),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Achievement Rate:',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$visited of $target shops (${visitPct.toStringAsFixed(1)}%)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A2744),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Text(
                'Basic Earned:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2744),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlueDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accentBlueDark.withOpacity(0.3)),
                ),
                child: Text(
                  'Rs ${basicEarned.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentBlueDark,
                  ),
                ),
              ),
            ],
          ),

         
        ],
      ),
    );
  }

  /// Total Salary Hero Card
  Widget _buildTotalHeroCard(double totalSalary, double incentive,
      double basic, bool hasBasic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF1A2744)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                _isSingleDay
                    ? ' Your Total Final Salary'
                    : ' Your Total Final Salary ($_numberOfDays days)',
                style: GoogleFonts.poppins(
                  color: Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Rs ${totalSalary.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (hasBasic) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   Expanded(
                      child: _chip(
                          'Part 1: Basic Earned',
                          'Rs ${basic.toStringAsFixed(2)}',
                          Colors.amber)),
                  Container(
                    height: 36,
                    width: 1,
                    color: Colors.white12,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  const Text('+',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 16)),
                  Container(
                    height: 36,
                    width: 1,
                    color: Colors.white12,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Expanded(
                      child: _chip('Part 2: Incentive',
                          'Rs ${incentive.toStringAsFixed(2)}',
                          AppColors.accentTeal)),
                 
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Incentive: Rs ${incentive.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                  color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: color.withOpacity(0.8))),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  /// Day Status Banner
  Widget _buildDayStatusBanner(
      Map<String, dynamic> statusInfo, String status) {
    final descriptions = {
      'full': _isSingleDay
          ? 'Excellent! You completed your full daily target. 🎉'
          : 'Great work! Overall target fully achieved in this range. 🎉',
      'half': _isSingleDay
          ? 'Half of daily target completed. Keep going!'
          : 'Half of range target completed. Keep it up!',
      'below': _isSingleDay
          ? 'Visits are below the target threshold.'
          : 'Visits are below the range target threshold.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (statusInfo['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (statusInfo['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(statusInfo['icon'] as String,
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo['label'] as String,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: statusInfo['color'] as Color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descriptions[status] ?? '',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full Summary Breakdown
  Widget _buildBreakdownCard(
    double collection,
    double pct,
    double incentive,
    double basicSalary,
    double basicEarned,
    double visitPct,
    double totalSalary,
    int visited,
    int target,
    int paidCnt,
    int fbCnt,
    bool hasBasic,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _isSingleDay ? 'Full Summary Breakdown' : 'Range Summary Breakdown ($_numberOfDays days)',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF1A2744)),
              ),
            ],
          ),
       
          const SizedBox(height: 6),
          if (hasBasic) ...[
            const Divider(height: 18),
            _row('Basic Salary Given',
                'Rs ${basicSalary.toStringAsFixed(2)}',
                Icons.account_balance_wallet_rounded,
                AppColors.accentBlueDark),
                
            _row('Your Visit Target Achievement',
                '${visitPct.toStringAsFixed(1)}%',
                Icons.donut_large_rounded, AppColors.accentBlueDark),
            _row('Part 1: Your Basic Salary Earned',
                'Rs ${basicEarned.toStringAsFixed(2)}',
                Icons.check_circle_outline_rounded,
                AppColors.accentBlueDark),
               Text(
                'Basic Salary is calculated from PAID and FEEDBACKED shops.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.red[500]),
              ), 
          ],
          _row('Total Cash Collection',
              'Rs ${collection.toStringAsFixed(2)}',
              Icons.monetization_on_rounded, const Color(0xFF1B5E5C)),
         
          _row('Commission Rate (%)',
              pct > 0 ? '${pct.toStringAsFixed(2)}%' : 'Pending',
              Icons.percent_rounded, AppColors.accentTealDark),
          _row('Part 2: Your Incentive Salary',
              'Rs ${incentive.toStringAsFixed(2)}',
              Icons.trending_up_rounded, AppColors.accentTealDark),
             Text(
                'Commission is calculate from TODAY COLLECTION.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.red[500]),
              ), 
          const Divider(height: 18),
          _row('TOTAL FINAL SALARY',
              'Rs ${totalSalary.toStringAsFixed(2)}',
              Icons.workspace_premium_rounded, Colors.amber.shade700),
          
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey[600])),
          ),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2744),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.payments_outlined,
                  size: 52, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              'No Data for This Period',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2744),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No records found for $_rangeLabel().',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _rangeLabel() {
    if (_isSingleDay) {
      final now = DateTime.now();
      if (_startDate.year == now.year &&
          _startDate.month == now.month &&
          _startDate.day == now.day) {
        return 'Today';
      }
      return _fmt(_startDate);
    }
    return '${_fmt(_startDate)} – ${_fmt(_endDate)}';
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _shortFmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'full':
        return {
          'label': 'Full Day Target',
          'icon': '✅',
          'color': AppColors.successDark
        };
      case 'half':
        return {
          'label': 'Half Day Target',
          'icon': '🌗',
          'color': AppColors.warningDark
        };
      default:
        return {
          'label': 'Below Target',
          'icon': '⚠️',
          'color': AppColors.errorDark
        };
    }
  }
}
