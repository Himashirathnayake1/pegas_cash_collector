import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

class CollectorStockListPage extends StatefulWidget {
  const CollectorStockListPage({super.key});

  @override
  State<CollectorStockListPage> createState() => _CollectorStockListPageState();
}

class _CollectorStockListPageState extends State<CollectorStockListPage>
    with TickerProviderStateMixin {
  final firestore = FirebaseFirestore.instance;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  List<DocumentSnapshot> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fetchProducts();
  }

  /// Fetch all products from Firestore
  Future<void> _fetchProducts() async {
    try {
      setState(() => isLoading = true);
      print('🔄 Fetching products from Firestore...');
      
      final branchId = BranchContext().branchId;
      if (branchId == null) {
        print('❌ No branch ID available');
        setState(() => isLoading = false);
        return;
      }
      
      print('📂 Branch ID: $branchId');
      
      final snapshot = await firestore
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .get();
      
      print('✅ Fetched ${snapshot.docs.length} products');
      
      setState(() {
        products = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching products: $e');
      setState(() => isLoading = false);
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
      body: Container(
        color: AppColors.lightBackground,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: isLoading
                      ? _buildLoadingState()
                      : products.isEmpty
                          ? _buildEmptyState()
                          : _buildStockList(products),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accentTealDark,
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
                  'Stock Items',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  '${products.length} items available',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentTealDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppColors.accentTealDark, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightTextMuted.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.lightTextMuted, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'No stocks found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList(List<DocumentSnapshot> productList) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: productList.length,
      itemBuilder: (context, index) {
        final productDoc = productList[index];
        return _buildStockCard(productDoc, index);
      },
    );
  }

  Widget _buildStockCard(DocumentSnapshot productDoc, int index) {
    final productData = productDoc.data() as Map<String, dynamic>;
    
    final name = productData['name'] ?? 'Unknown';
    final imageUrl = productData['imageUrl'] ?? '';
    final originalPrice = productData['originalPrice'] ?? 0;
    final normalShopsPrice = productData['normalShopsPrice'] ?? 0;
    final stock = productData['stock'] ?? 0;
    final isAvailable = (stock as num) > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAvailable
                ? AppColors.lightCardBorder
                : AppColors.errorDark.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: isAvailable
                  ? Colors.black.withOpacity(0.05)
                  : AppColors.errorDark.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentTealDark,
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPriceRow('Original', originalPrice, AppColors.lightTextMuted),
                  _buildPriceRow('Store Price', normalShopsPrice, AppColors.accentTealDark),
                  _buildStockRow('Stock', stock),
                ],
              ),
            ),

            // Availability Badge
            Column(
              children: [
                if (isAvailable)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successDark.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.successDark, size: 22),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.errorDark.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Out',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorDark,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, dynamic price, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.lightTextMuted,
            ),
          ),
          Text(
            'Rs.${price ?? 'N/A'}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockRow(String label, dynamic quantity) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.lightTextMuted,
            ),
          ),
          Text(
            '${quantity ?? 0}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accentBlueDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.image_not_supported_rounded,
          color: AppColors.lightTextMuted, size: 28),
    );
  }
}
