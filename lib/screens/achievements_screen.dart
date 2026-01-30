import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int get totalPaidShopsInPeriod {
    return allData.fold<int>(0, (sum, row) => sum + (row['paidShops'] as int));
  }

  DateTime? _startDate;
  DateTime? _endDate;

  final int totalShops = 50;
  final int paidShops = 40;

  final List<Map<String, dynamic>> allData = [
    {
      'date': '2026-01-20',
      'target': 20000,
      'collection': 18000,
      'paidShops': 8,
      'status': true,
    },
    {
      'date': '2026-01-21',
      'target': 25000,
      'collection': 25000,
      'paidShops': 10,
      'status': true,
    },
    {
      'date': '2026-01-22',
      'target': 30000,
      'collection': 22000,
      'paidShops': 12,
      'status': false,
    },
    {
      'date': '2026-01-23',
      'target': 25000,
      'collection': 20000,
      'paidShops': 10,
      'status': false,
    },
  ];

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

  int get totalPaidShopsInRange {
    return filteredData.fold<int>(
        0, (sum, row) => sum + (row['paidShops'] as int));
  }

  int get achievedDaysCount {
    return allData.where((row) => row['status'] == true).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: Container(
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                            'Paid Shops',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$totalPaidShopsInRange',
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
                      icon: const Icon(Icons.date_range_rounded, size: 18),
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
                      icon: const Icon(Icons.clear_rounded, color: Colors.red),
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
                                      fontSize:
                                          constraints.maxWidth < 400 ? 13 : 16,
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
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.green.shade100),
                                    columnSpacing:
                                        constraints.maxWidth < 400 ? 16 : 24,
                                    dataRowHeight:
                                        constraints.maxWidth < 400 ? 32 : 40,
                                    columns: const [
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Target')),
                                      DataColumn(label: Text('Collection')),
                                      DataColumn(label: Text('Paid Shops')),
                                      DataColumn(label: Text('Status')),
                                    ],
                                    rows: filteredData.map((row) {
                                      return DataRow(cells: [
                                        DataCell(Text(row['date'],
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.green.shade900,
                                                fontSize:
                                                    constraints.maxWidth < 400
                                                        ? 12
                                                        : 14))),
                                        DataCell(Text(row['target'].toString(),
                                            style: GoogleFonts.poppins(
                                                color: Colors.green.shade800,
                                                fontSize:
                                                    constraints.maxWidth < 400
                                                        ? 12
                                                        : 14))),
                                        DataCell(Text(
                                            row['collection'].toString(),
                                            style: GoogleFonts.poppins(
                                                color: Colors.green.shade800,
                                                fontSize:
                                                    constraints.maxWidth < 400
                                                        ? 12
                                                        : 14))),
                                        DataCell(Text(
                                            row['paidShops'].toString(),
                                            style: GoogleFonts.poppins(
                                                color: Colors.green.shade800,
                                                fontSize:
                                                    constraints.maxWidth < 400
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
                                              size: constraints.maxWidth < 400
                                                  ? 16
                                                  : 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                                row['status']
                                                    ? 'Achieved'
                                                    : 'Not Achieved',
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w500,
                                                    color: row['status']
                                                        ? Colors.green.shade700
                                                        : Colors.red,
                                                    fontSize:
                                                        constraints.maxWidth <
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
