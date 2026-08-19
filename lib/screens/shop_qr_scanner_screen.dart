import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/branch_context.dart';
import '../utils/app_theme.dart';
import 'balance_screen.dart';

class ShopQrScannerScreen extends StatefulWidget {
  final String? routeId;

  const ShopQrScannerScreen({super.key, this.routeId});

  @override
  State<ShopQrScannerScreen> createState() => _ShopQrScannerScreenState();
}

class _ShopQrScannerScreenState extends State<ShopQrScannerScreen> {
  late final MobileScannerController _scannerController;
  bool _isLookingUp = false;
  String? _lastScannedCode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 500,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _findShopById(String shopId) async {
    final branchId = BranchContext().branchId;
    if (branchId == null || branchId.isEmpty) {
      return null;
    }

    final firestore = FirebaseFirestore.instance;

    if (widget.routeId != null && widget.routeId!.isNotEmpty) {
      final routeRef = firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .doc(widget.routeId);
      final shopDoc = await routeRef.collection('shops').doc(shopId).get();

      if (!shopDoc.exists) return null;

      return {
        'routeId': routeRef.id,
        'routeName': routeRef.id,
        'shopId': shopDoc.id,
        'shopData': shopDoc.data() ?? <String, dynamic>{},
      };
    }

    final routesSnapshot =
        await firestore
            .collection('branches')
            .doc(branchId)
            .collection('routes')
            .get();

    for (final routeDoc in routesSnapshot.docs) {
      final shopDoc =
          await routeDoc.reference.collection('shops').doc(shopId).get();
      if (shopDoc.exists) {
        return {
          'routeId': routeDoc.id,
          'routeName': routeDoc.data()['name'] ?? routeDoc.id,
          'shopId': shopDoc.id,
          'shopData': shopDoc.data() ?? <String, dynamic>{},
        };
      }
    }

    return null;
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorDark : AppColors.successDark,
      ),
    );
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isLookingUp || !mounted) {
      return;
    }

    final code =
        capture.barcodes.isNotEmpty
            ? capture.barcodes.first.rawValue?.trim()
            : null;

    if (code == null || code.isEmpty) {
      _showMessage('Invalid QR code. Please scan a shop QR.', isError: true);
      return;
    }

    final now = DateTime.now();
    if (_lastScannedCode == code &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastScannedCode = code;
    _lastScanAt = now;
    setState(() => _isLookingUp = true);
    await _scannerController.stop();

    try {
      final result = await _findShopById(code);
      if (!mounted) {
        return;
      }

      if (result == null) {
        _showMessage('Shop not found for QR code: $code', isError: true);
        await _scannerController.start();
        return;
      }

      final shopData = result['shopData'] as Map<String, dynamic>;
      final shopName = shopData['name']?.toString() ?? 'Unknown Shop';
      final routeId = result['routeId']?.toString() ?? '';

      if (routeId.isEmpty) {
        _showMessage(
          'Unable to open shop balance. Route not found.',
          isError: true,
        );
        await _scannerController.start();
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => BalanceScreen(
                shopName: shopName,
                routeName: routeId,
                shopId: code,
                onBalanceAdjusted: (shopName, reducedAmount) {},
              ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Error scanning QR code: $e', isError: true);
        await _scannerController.start();
      }
    } finally {
      if (mounted) {
        setState(() => _isLookingUp = false);
      }
    }
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildPermissionError(
    BuildContext context,
    MobileScannerException error,
    Widget? child,
  ) {
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionDenied
                  ? Icons.no_photography_rounded
                  : Icons.error_outline_rounded,
              size: 72,
              color: AppColors.errorDark,
            ),
            const SizedBox(height: 16),
            Text(
              isPermissionDenied
                  ? 'Camera permission required'
                  : 'Scanner unavailable',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPermissionDenied
                  ? 'Allow camera access in system settings to scan shop QR codes.'
                  : 'The QR scanner could not be started. Please try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _scannerController.start();
                    } catch (_) {
                      // Ignore retry failures here; the error builder will remain visible.
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        title: Text(
          'Scan Shop QR',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppColors.lightTextPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleScan,
            errorBuilder: _buildPermissionError,
            placeholderBuilder: (context, child) {
              return Center(
                child: Text(
                  'Starting camera...',
                  style: GoogleFonts.poppins(
                    color: AppColors.lightTextSecondary,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Align the shop QR code inside the frame.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: _buildScannerOverlay(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLookingUp
                        ? 'Looking up shop details...'
                        : 'Scanning for shop ID QR codes',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLookingUp)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
