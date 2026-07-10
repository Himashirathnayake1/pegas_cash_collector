import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/branch_context.dart';
import '../utils/app_theme.dart';

class SalesRepTransferHistoryScreen extends StatelessWidget {
  const SalesRepTransferHistoryScreen({super.key});

  String _formatAmount(num amount) => 'Rs ${amount.toStringAsFixed(2)}';

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[date.month - 1];
    final day = date.day;
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month $day, $year at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final branchId = BranchContext().branchId;
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Rep Transfer History'),
        backgroundColor: const Color(0xFF1B5E5C),
        foregroundColor: Colors.white,
      ),
      body:
          branchId == null
              ? const Center(child: Text('No branch selected'))
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    firestore
                        .collection('branches')
                        .doc(branchId)
                        .collection('admin')
                        .doc('stats')
                        .collection('sales_rep_transfers')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No sales rep transfers yet',
                        style: GoogleFonts.poppins(color: AppColors.textMuted),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final amount = (data['amount'] ?? 0.0) as num;
                      final previousBalance =
                          (data['previousBalance'] ?? 0.0) as num;
                      final newBalance = (data['newBalance'] ?? 0.0) as num;
                      final note = (data['note'] ?? '') as String;
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatAmount(amount),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(createdAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Previous balance: ${_formatAmount(previousBalance)}',
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              Text(
                                'New balance: ${_formatAmount(newBalance)}',
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Note: $note',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
