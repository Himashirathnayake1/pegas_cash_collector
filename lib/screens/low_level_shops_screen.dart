import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class LowLevelShopsScreen extends StatefulWidget {
  const LowLevelShopsScreen({Key? key}) : super(key: key);

  @override
  State<LowLevelShopsScreen> createState() => _LowLevelShopsScreenState();
}

class _LowLevelShopsScreenState extends State<LowLevelShopsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool showUnpaid = true;

  final List<Map<String, dynamic>> allShops = [
    {
      'id': 1,
      'name': 'Shop A',
      'address': '123 Main St',
      'phone': '9876543210',
      'status': 'Unpaid',
      'amount': 1200,
      'paidAmount': 0,
      'paidAt': null,
      'latitude': 12.9716,
      'longitude': 77.5946,
    },
    {
      'id': 2,
      'name': 'Shop B',
      'address': '456 Market Rd',
      'phone': '9123456780',
      'status': 'Paid',
      'amount': 0,
      'paidAmount': 1200,
      'paidAt': DateTime.now().subtract(const Duration(hours: 2)),
      'latitude': 12.2958,
      'longitude': 76.6394,
    },
    {
      'id': 3,
      'name': 'Shop C',
      'address': '789 Central Ave',
      'phone': '9988776655',
      'status': 'Unpaid',
      'amount': 800,
      'paidAmount': 0,
      'paidAt': null,
      'latitude': 11.0168,
      'longitude': 76.9558,
    },
  ];

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final filteredShops = allShops.where((shop) {
      final matchStatus =
          showUnpaid ? shop['status'] == 'Unpaid' : shop['status'] == 'Paid';
      final matchSearch = shop['name']
          .toString()
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Level Shops'),
        backgroundColor: Colors.green.shade700,
      ),
      body: Column(
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
          Expanded(
            child: filteredShops.isEmpty
                ? _buildEmptyState()
                : _buildShopsList(filteredShops),
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
            child: _buildFilterTab(
              'Unpaid',
              showUnpaid,
              () => setState(() => showUnpaid = true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterTab(
              'Paid',
              !showUnpaid,
              () => setState(() => showUnpaid = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
      String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentTeal : AppColors.lightBackground,
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
      child: Text(
        showUnpaid ? 'All shops are paid!' : 'No paid shops yet',
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildShopsList(List<Map<String, dynamic>> shops) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        return _buildShopCard(shops[index], index);
      },
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop, int index) {
    final bool isPaid = shop['status'] == 'Paid';
    final DateTime? paidAt = shop['paidAt'];

    int remainingSeconds = 0;
    if (isPaid && paidAt != null) {
      remainingSeconds =
          43200 - DateTime.now().difference(paidAt).inSeconds;
      if (remainingSeconds < 0) remainingSeconds = 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop['name'],
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
                ),
              ],
            ),
          ),
          if (isPaid && remainingSeconds > 0)
            Text(
              formatDuration(Duration(seconds: remainingSeconds)),
              style: GoogleFonts.spaceMono(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}