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
  DateTime _selectedDate = DateTime.now();

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

  String get _dateKey =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _salaryStream {
    final branchId = BranchContext().branchId;
    return FirebaseFirestore.instance
        .collection('branches')
        .doc(branchId)
        .collection('cashcollector_salary')
        .doc(_dateKey)
        .snapshots();
  }

  Future<Map<String, dynamic>> _fetchLiveTodayData() async {
    final branchId = BranchContext().branchId;
    if (branchId == null) return {};

    final fs = FirebaseFirestore.instance;
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final dayEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59, 999);

    // 1. Check if separate daily visits document exists in branches/{branchId}/cashcollector_visits/{date}
    final visitsDocRef = fs
        .collection('branches')
        .doc(branchId)
        .collection('cashcollector_visits')
        .doc(_dateKey);

    int finalVisited = 0;
    int paidCount = 0;
    int feedbackCount = 0;
    bool hasValidSavedVisits = false;

    try {
      final visitsSnap = await visitsDocRef.get();
      if (visitsSnap.exists) {
        final vData = visitsSnap.data()!;
        finalVisited = (vData['totalVisited'] ?? vData['shopsVisitedToday'] ?? 0) as int;
        final pList = vData['paidShopIds'] as List?;
        final fList = vData['feedbackShopIds'] as List?;

        paidCount = (vData['paidShopCount'] ?? pList?.length ?? 0) as int;
        feedbackCount = (vData['feedbackShopCount'] ?? fList?.length ?? 0) as int;

        if (finalVisited > 0 && (paidCount > 0 || feedbackCount > 0)) {
          hasValidSavedVisits = true;
        }
      }
    } catch (_) {}

    double summaryTodayPaid = 0.0;
    int targetShops = 0;
    double defaultCommission = 0.0;

    try {
      final summaryDoc = await fs.collection('branches').doc(branchId).collection('admin').doc('summary').get();
      if (summaryDoc.exists) {
        summaryTodayPaid = _asDouble(summaryDoc.data()?['todaytotalPaid']);
      }
    } catch (_) {}

    try {
      final statsDoc = await fs.collection('branches').doc(branchId).collection('admin').doc('stats').get();
      if (statsDoc.exists) {
        final statsData = statsDoc.data() ?? {};
        targetShops = (statsData['cashcollector_target'] ?? 0) as int;
        defaultCommission = _asDouble(statsData['default_commission_percent'] ?? statsData['commission_percent']);
      }
    } catch (_) {}

    double txSum = 0.0;
    final visitedShopIds = <String>{};
    final paidShopIdsSet = <String>{};

    try {
      final routesSnap = await fs.collection('branches').doc(branchId).collection('routes').get();

      for (final routeDoc in routesSnap.docs) {
        final shopsSnap = await routeDoc.reference.collection('shops').get();

        for (final shopDoc in shopsSnap.docs) {
          final shopId = shopDoc.id;

          try {
            final txSnap = await shopDoc.reference.collection('transactions').get();
            for (final txDoc in txSnap.docs) {
              final txData = txDoc.data();
              final type = txData['type']?.toString();
              final tsRaw = txData['timestamp'] ??
                  txData['resetAt'] ??
                  txData['submittedAt'] ??
                  txData['createdAt'] ??
                  txData['date'];
              DateTime? txTime;
              if (tsRaw is Timestamp) {
                txTime = tsRaw.toDate();
              } else if (tsRaw is String) {
                txTime = DateTime.tryParse(tsRaw);
              }

              if (txTime != null &&
                  txTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
                  txTime.isBefore(dayEnd.add(const Duration(seconds: 1)))) {
                if (type == null || type == 'paid' || type == 'partialPaid' || type == 'Cash') {
                  txSum += _asDouble(txData['amount']);
                  paidShopIdsSet.add(shopId);
                  visitedShopIds.add(shopId);
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    final feedbackShopIdsSet = <String>{};
    try {
      final feedbackSnap = await fs
          .collection('branches')
          .doc(branchId)
          .collection('feedback')
          .get();

      for (final fbDoc in feedbackSnap.docs) {
        final fbData = fbDoc.data();
        final tsRaw = fbData['createdAt'] ?? fbData['timestamp'] ?? fbData['time'];
        DateTime? fbTime;
        if (tsRaw is Timestamp) {
          fbTime = tsRaw.toDate();
        } else if (tsRaw is DateTime) {
          fbTime = tsRaw;
        } else if (tsRaw is String) {
          fbTime = DateTime.tryParse(tsRaw);
        }

        if (fbTime != null &&
            fbTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
            fbTime.isBefore(dayEnd.add(const Duration(seconds: 1)))) {
          final shopId =
              (fbData['shopId'] ?? fbData['shopName'] ?? fbData['name'] ?? fbDoc.id)
                  .toString()
                  .trim();
          if (shopId.isNotEmpty) {
            feedbackShopIdsSet.add(shopId);
            visitedShopIds.add(shopId);
          }
        }
      }
    } catch (_) {}

    if (!hasValidSavedVisits) {
      finalVisited = visitedShopIds.length;
      paidCount = paidShopIdsSet.length;
      feedbackCount = feedbackShopIdsSet.length;
    }

    double finalCollection = txSum;
    if (finalCollection == 0 && _isToday && summaryTodayPaid > 0) {
      finalCollection = summaryTodayPaid;
    }

    String status = 'below';
    if (targetShops > 0) {
      if (finalVisited >= targetShops) {
        status = 'full';
      } else if (finalVisited >= (targetShops / 2).ceil()) {
        status = 'half';
      }
    }

    double finalSalary = defaultCommission > 0 ? (finalCollection * defaultCommission / 100.0) : 0.0;

    return {
      'todayCollection': finalCollection,
      'commissionPercent': defaultCommission,
      'finalSalary': finalSalary,
      'shopVisitTarget': targetShops,
      'shopsVisitedToday': finalVisited,
      'paidShopCount': paidCount,
      'feedbackShopCount': feedbackCount,
      'dayStatus': status,
      'isLive': true,
    };
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accentBlue,
            onPrimary: Colors.white,
            surface: AppColors.surfaceCard,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
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
            // ── Header ──────────────────────────────────────────
            _buildHeader(),

            // ── Body ─────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _salaryStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentBlue,
                          ),
                        );
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _fetchLiveTodayData(),
                          builder: (context, liveSnap) {
                            if (liveSnap.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accentBlue,
                                ),
                              );
                            }
                            final liveData = liveSnap.data ?? {};
                            if ((liveData['todayCollection'] ?? 0.0) == 0.0 &&
                                (liveData['shopsVisitedToday'] ?? 0) == 0 &&
                                !_isToday) {
                              return _buildEmptyState();
                            }
                            return _buildContent(liveData, isLiveUnsaved: true);
                          },
                        );
                      }

                      final data = Map<String, dynamic>.from(snapshot.data!.data()!);
                      final paidCnt = (data['paidShopCount'] ?? 0) as int;
                      final fbCnt = (data['feedbackShopCount'] ?? 0) as int;

                      // If paidShopCount/feedbackShopCount are missing/0 in saved salary doc, enrich from cashcollector_visits/{date}
                      if (paidCnt == 0 && fbCnt == 0) {
                        final branchId = BranchContext().branchId;
                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('branches')
                              .doc(branchId)
                              .collection('cashcollector_visits')
                              .doc(_dateKey)
                              .get(),
                          builder: (context, vSnap) {
                            if (vSnap.hasData && vSnap.data!.exists) {
                              final vData = vSnap.data!.data()!;
                              final pList = vData['paidShopIds'] as List?;
                              final fList = vData['feedbackShopIds'] as List?;

                              data['paidShopCount'] =
                                  (vData['paidShopCount'] ?? pList?.length ?? 0);
                              data['feedbackShopCount'] =
                                  (vData['feedbackShopCount'] ?? fList?.length ?? 0);
                              if (data['shopsVisitedToday'] == null || data['shopsVisitedToday'] == 0) {
                                data['shopsVisitedToday'] = (vData['totalVisited'] ?? vData['shopsVisitedToday'] ?? 0);
                              }
                            }
                            return _buildContent(data, isLiveUnsaved: false);
                          },
                        );
                      }

                      return _buildContent(data, isLiveUnsaved: false);
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

  // ────────────────────────────────────────────────────────────
  // Header
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      _isToday ? 'Today\'s Overview' : _formattedDate(_selectedDate),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Date picker button
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _isToday ? 'Today' : _shortDate(_selectedDate),
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
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Content
  // ────────────────────────────────────────────────────────────

  Widget _buildContent(Map<String, dynamic> data, {required bool isLiveUnsaved}) {
    final collection = _asDouble(data['todayCollection']);
    final pct = _asDouble(data['commissionPercent']);
    final salary = _asDouble(data['finalSalary']);
    final target = (data['shopVisitTarget'] ?? 0) as int;
    final visited = (data['shopsVisitedToday'] ?? 0) as int;
    final paidCnt = (data['paidShopCount'] ?? 0) as int;
    final fbCnt = (data['feedbackShopCount'] ?? 0) as int;
    final status = data['dayStatus'] as String? ?? 'below';
    final statusInfo = _statusInfo(status);

    final progress = target > 0 ? (visited / target).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          if (isLiveUnsaved) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pct > 0
                          ? 'Auto-calculated using default branch commission (${pct.toStringAsFixed(1)}%).'
                          : 'Live collection today. Admin can adjust commission % if needed.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Main salary hero card ──────────────────────────
          _buildSalaryHeroCard(salary, collection, pct, statusInfo, isLiveUnsaved),
          const SizedBox(height: 20),

          // ── Shop visits card ───────────────────────────────
          _buildVisitCard(visited, target, progress, statusInfo, paidCnt, fbCnt),
          const SizedBox(height: 20),

          // ── Day status banner ──────────────────────────────
          _buildDayStatusBanner(statusInfo, status),
          const SizedBox(height: 20),

          // ── Breakdown card ─────────────────────────────────
          _buildBreakdownCard(collection, pct, salary, visited, target, paidCnt, fbCnt, isLiveUnsaved),
        ],
      ),
    );
  }

  Widget _buildSalaryHeroCard(double salary, double collection, double pct,
      Map<String, dynamic> statusInfo, bool isLiveUnsaved) {
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
                  color: AppColors.accentTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.accentTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                (isLiveUnsaved && pct == 0) ? 'Today Collection (Live)' : 'Final Salary',
                style: GoogleFonts.poppins(
                  color: AppColors.accentTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            (isLiveUnsaved && pct == 0)
                ? 'Rs ${collection.toStringAsFixed(2)}'
                : 'Rs ${salary.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pct > 0
                ? 'Rs ${collection.toStringAsFixed(2)} × ${pct.toStringAsFixed(2)}%'
                : 'Awaiting admin commission percentage',
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              _miniStatChip('Collection for day', 'Rs ${collection.toStringAsFixed(0)}',
                  AppColors.accentBlue),
              const SizedBox(width: 10),
              _miniStatChip(
                  'Commission',
                  pct > 0 ? '${pct.toStringAsFixed(2)}%' : 'Pending',
                  AppColors.accentPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: color.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(int visited, int target, double progress,
      Map<String, dynamic> statusInfo, int paidCnt, int fbCnt) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: Color(0xFF1B5E5C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Shop Visits',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFF1A2744),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (statusInfo['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (statusInfo['color'] as Color).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '${statusInfo['icon']} ${statusInfo['label']}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusInfo['color'] as Color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$visited',
                style: GoogleFonts.poppins(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: statusInfo['color'] as Color,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  ' / $target shops',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: $paidCnt shops',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successDark,
                  ),
                ),
                Text(
                  'Feedback: $fbCnt shops',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentBlueDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                statusInfo['color'] as Color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            target > 0
                ? '${(progress * 100).toStringAsFixed(0)}% of daily target achieved'
                : 'No target set by admin',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayStatusBanner(
      Map<String, dynamic> statusInfo, String status) {
    final descriptions = {
      'full': 'Excellent work! You\'ve completed your full daily target. 🎉',
      'half': 'You\'ve completed half of your daily target. Keep going!',
      'below': 'Visits are below the required threshold for today.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (statusInfo['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (statusInfo['color'] as Color).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            statusInfo['icon'] as String,
            style: const TextStyle(fontSize: 28),
          ),
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
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(double collection, double pct, double salary,
      int visited, int target, int paidCnt, int fbCnt, bool isLiveUnsaved) {
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
          Text(
            'Summary',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF1A2744),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _breakdownRow(
            'Total Collection',
            'Rs ${collection.toStringAsFixed(2)}',
            Icons.monetization_on_rounded,
            const Color(0xFF1B5E5C),
          ),
          _breakdownRow(
            'Commission Rate',
            pct > 0 ? '${pct.toStringAsFixed(2)}%' : 'Pending',
            Icons.percent_rounded,
            AppColors.accentTeal,
          ),
          _breakdownRow(
            'Final Salary',
            salary > 0 ? 'Rs ${salary.toStringAsFixed(2)}' : 'Pending',
            Icons.account_balance_wallet_rounded,
            AppColors.successDark,
          ),
          const Divider(height: 20),
          _breakdownRow(
            'Shops Visited Total',
            '$visited',
            Icons.check_circle_rounded,
            AppColors.accentBlueDark,
          ),
          _breakdownRow(
            'Paid Shops',
            '$paidCnt',
            Icons.monetization_on_outlined,
            AppColors.successDark,
          ),
          _breakdownRow(
            'Feedback Shops',
            '$fbCnt',
            Icons.rate_review_outlined,
            AppColors.accentBlueDark,
          ),
          _breakdownRow(
            'Daily Target',
            '$target shops',
            Icons.flag_rounded,
            AppColors.warningDark,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2744),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Empty state
  // ────────────────────────────────────────────────────────────

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
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payments_outlined,
                size: 52,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Data for This Day',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2744),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No payment transactions or shop feedback records exist for ${_formattedDate(_selectedDate)}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formattedDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'full':
        return {
          'label': 'Full Day',
          'icon': '✅',
          'color': AppColors.successDark,
        };
      case 'half':
        return {
          'label': 'Half Day',
          'icon': '🌗',
          'color': AppColors.warningDark,
        };
      default:
        return {
          'label': 'Below Target',
          'icon': '⚠️',
          'color': AppColors.errorDark,
        };
    }
  }
}
