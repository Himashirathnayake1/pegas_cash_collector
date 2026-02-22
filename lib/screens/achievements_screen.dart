import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pegas_cashcollector/utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/branch_context.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> allData = [];
  double dailyTarget = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievementsData();
  }

  Future<void> _loadAchievementsData() async {
    try {
      setState(() => isLoading = true);
      
      final branchId = BranchContext().branchId;
      print('📊 Loading achievements for branch: $branchId');

      final firestore = FirebaseFirestore.instance;

      // Fetch daily target
      final targetDoc = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('stats')
          .get();

      if (targetDoc.exists) {
        final targetVal = targetDoc.data()?['cashcollector_target'];
        setState(() {
          dailyTarget = (targetVal is num) ? targetVal.toDouble() : 0.0;
        });
        print('✅ Daily target: Rs. $dailyTarget');
      }

      // Fetch today's total paid from summary
      final summaryDoc = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('admin')
          .doc('summary')
          .get();

      double todayTotalPaid = 0.0;
      if (summaryDoc.exists) {
        final todayVal = summaryDoc.data()?['todaytotalPaid'];
        todayTotalPaid = (todayVal is num) ? todayVal.toDouble() : 0.0;
        print('📈 Today total paid: Rs. $todayTotalPaid');
      }

      // Fetch all routes and their daily collections
      final routesSnapshot = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .get();

      final achievementsList = <Map<String, dynamic>>[];
      final dailyCollections = <String, double>{};

      // For each route, sum up daily collections
      for (var routeDoc in routesSnapshot.docs) {
        final routeName = routeDoc.id;
        
        final shopsSnapshot = await firestore
            .collection('branches')
            .doc(branchId)
            .collection('routes')
            .doc(routeName)
            .collection('shops')
            .get();

        // For each shop, get transactions
        for (var shopDoc in shopsSnapshot.docs) {
          final transactionsSnapshot = await firestore
              .collection('branches')
              .doc(branchId)
              .collection('routes')
              .doc(routeName)
              .collection('shops')
              .doc(shopDoc.id)
              .collection('transactions')
              .get();

          // Group transactions by date
          for (var txnDoc in transactionsSnapshot.docs) {
            final data = txnDoc.data();
            final amount = data['amount'];
            final timestamp = data['timestamp'] as Timestamp?;

            if (amount != null && timestamp != null) {
              final amountVal = (amount is num) ? amount.toDouble() : 0.0;
              final dateString = timestamp.toDate().toString().substring(0, 10);

              dailyCollections[dateString] =
                  (dailyCollections[dateString] ?? 0.0) + amountVal;
            }
          }
        }
      }

      // Convert to list and determine status
      final today = DateTime.now();
      final todayString = today.toString().substring(0, 10);

      for (var dateStr in dailyCollections.keys) {
        final date = DateTime.parse(dateStr);
        var collection = dailyCollections[dateStr] ?? 0.0;
        
        // For today, use the fetched todaytotalPaid value
        if (dateStr == todayString) {
          collection = todayTotalPaid;
          print('🔄 Using todaytotalPaid for today: Rs. $collection');
        }

        final isAchieved = collection >= dailyTarget;

        achievementsList.add({
          'date': dateStr,
          'target': dailyTarget,
          'collection': collection,
          'paidShops': 0,
          'status': isAchieved,
          'dateObj': date,
        });
      }

      // Also add today if it doesn't have transactions yet
      if (!dailyCollections.containsKey(todayString)) {
        final isAchieved = todayTotalPaid >= dailyTarget;
        achievementsList.add({
          'date': todayString,
          'target': dailyTarget,
          'collection': todayTotalPaid,
          'paidShops': 0,
          'status': isAchieved,
          'dateObj': today,
        });
        print('➕ Added today\'s record: Rs. $todayTotalPaid vs target Rs. $dailyTarget');
      }

      // Sort by date descending
      achievementsList.sort((a, b) => (b['dateObj'] as DateTime).compareTo(a['dateObj'] as DateTime));

      setState(() {
        allData = achievementsList;
        isLoading = false;
      });
      print('✅ Loaded ${achievementsList.length} achievement days');
    } catch (e) {
      print('❌ Error loading achievements: $e');
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredData {
    if (_startDate == null || _endDate == null) return allData;
    return allData.where((row) {
      final rowDate = DateTime.parse(row['date']);
      return rowDate.isAtSameMomentAs(_startDate!) ||
          rowDate.isAtSameMomentAs(_endDate!) ||
          (rowDate.isAfter(_startDate!) && rowDate.isBefore(_endDate!));
    }).toList();
  }

  int get achievedDaysCountInRange {
    return filteredData.where((row) => row['status'] == true).length;
  }

  int get achievedDaysCount {
    return allData.where((row) => row['status'] == true).length;
  }

  @override
  Widget build(BuildContext context) {
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
              'Achievements',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentTeal,
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Achieved Days Summary Section
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: Icon(Icons.emoji_events_rounded,
                                      color: Colors.green.shade700, size: 24),
                                  radius: 18,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$achievedDaysCountInRange Days Target Achieved',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Out of ${filteredData.length} days',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade50,
                                  child: Icon(Icons.verified_rounded,
                                      color: Colors.green.shade700, size: 20),
                                  radius: 14,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Daily Target',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Rs.${dailyTarget.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Date Range Filter
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                            ),
                            icon:
                                const Icon(Icons.date_range_rounded, size: 18),
                            label: Text(
                              (_startDate == null || _endDate == null)
                                  ? 'Select Range'
                                  : '${_startDate!.toIso8601String().substring(0, 10)} - ${_endDate!.toIso8601String().substring(0, 10)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              final pickedStart = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2025, 1, 1),
                                lastDate: DateTime(2026, 12, 31),
                              );
                              if (pickedStart != null) {
                                final pickedEnd = await showDatePicker(
                                  context: context,
                                  initialDate: pickedStart,
                                  firstDate: pickedStart,
                                  lastDate: DateTime(2026, 12, 31),
                                );
                                if (pickedEnd != null) {
                                  setState(() {
                                    _startDate = pickedStart;
                                    _endDate = pickedEnd;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        if (_startDate != null || _endDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Table Section
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: filteredData.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No data for selected range.',
                                        style: GoogleFonts.poppins(
                                            fontSize: constraints.maxWidth < 400
                                                ? 13
                                                : 16,
                                            color: Colors.grey),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth,
                                        ),
                                        child: DataTable(
                                          headingRowColor:
                                              MaterialStateProperty.all(
                                                  Colors.green.shade100),
                                          columnSpacing:
                                              constraints.maxWidth < 400
                                                  ? 16
                                                  : 24,
                                          dataRowHeight:
                                              constraints.maxWidth < 400
                                                  ? 32
                                                  : 40,
                                          columns: const [
                                            DataColumn(label: Text('Date')),
                                            DataColumn(label: Text('Target')),
                                            DataColumn(
                                                label: Text('Collection')),
                                            DataColumn(label: Text('Status')),
                                          ],
                                          rows: filteredData.map((row) {
                                            return DataRow(cells: [
                                              DataCell(Text(row['date'],
                                                  style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors
                                                          .green.shade900,
                                                      fontSize: constraints
                                                              .maxWidth <
                                                          400
                                                          ? 12
                                                          : 14))),
                                              DataCell(Text(
                                                  'Rs.${(row['target'] as double).toStringAsFixed(0)}',
                                                  style: GoogleFonts.poppins(
                                                      color: Colors
                                                          .green.shade800,
                                                      fontSize: constraints
                                                              .maxWidth <
                                                          400
                                                          ? 12
                                                          : 14))),
                                              DataCell(Text(
                                                  'Rs.${(row['collection'] as double).toStringAsFixed(0)}',
                                                  style: GoogleFonts.poppins(
                                                      color: Colors
                                                          .green.shade800,
                                                      fontSize: constraints
                                                              .maxWidth <
                                                          400
                                                          ? 12
                                                          : 14))),
                                              DataCell(Row(
                                                children: [
                                                  Icon(
                                                    row['status']
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    color: row['status']
                                                        ? Colors.green
                                                        : Colors.red,
                                                    size: constraints.maxWidth <
                                                            400
                                                        ? 16
                                                        : 20,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                      row['status']
                                                          ? 'Achieved'
                                                          : 'Not Achieved',
                                                      style: GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: row['status']
                                                              ? Colors
                                                                  .green.shade700
                                                              : Colors.red,
                                                          fontSize: constraints
                                                                  .maxWidth <
                                                              400
                                                              ? 12
                                                              : 14)),
                                                ],
                                              )),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                ),],
                ),),),);}}
                  

                          