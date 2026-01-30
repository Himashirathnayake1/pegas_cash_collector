import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart'
    as printer;
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mock_data_service.dart';
import '../utils/app_theme.dart';

class BalanceScreen extends StatefulWidget {
  final String shopName;
  final String routeName;
  final String shopId;
  final Function(String shopName, double reducedAmount) onBalanceAdjusted;

  const BalanceScreen({
    super.key,
    required this.shopName,
    required this.routeName,
    required this.shopId,
    required this.onBalanceAdjusted,
  });

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen>
    with TickerProviderStateMixin {
  printer.ReceiptController? _receiptController;

  double? balanceAmount;
  bool _isProcessing = false;
  double? shopLatitude;
  double? shopLongitude;

  List<Map<String, dynamic>> transactions = [];
  final mockService = MockDataService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
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

  Future<void> _fetchBalance() async {
    await Future.delayed(const Duration(milliseconds: 200));

    final shops = mockService.getShopsForRoute(widget.routeName);
    final shop = shops.firstWhere((s) => s.id == widget.shopId,
        orElse: () => shops.first);

    setState(() {
      balanceAmount = shop.amount;
      shopLatitude = shop.latitude;
      shopLongitude = shop.longitude;
    });

    final txList =
        shop.transactions.where((tx) => tx.type != 'Credit').map((tx) {
      return {
        'time': tx.timestamp,
        'amount': tx.amount,
        'type': tx.type,
        'store': widget.shopName,
      };
    }).toList();

    setState(() {
      transactions = txList.reversed.toList();
    });
  }

  void _showAdjustDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentTealDark.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: AppColors.accentTealDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Adjust Balance",
                    style: GoogleFonts.poppins(
                      color: AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accentTealDark.withOpacity(0.08),
                            AppColors.accentBlueDark.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accentTealDark.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentTealDark.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: GoogleFonts.poppins(
                            color: AppColors.lightTextPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: "Enter amount",
                            hintStyle: GoogleFonts.poppins(
                              color: AppColors.lightTextMuted.withOpacity(0.6),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.currency_rupee_rounded,
                                color:
                                    AppColors.accentTealDark.withOpacity(0.7),
                                size: 24,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(
                        color: AppColors.lightTextSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          final input = controller.text;
                          final double? reduction = double.tryParse(input);

                          if (reduction != null &&
                              reduction > 0 &&
                              reduction <= (balanceAmount ?? 0)) {
                            setStateDialog(() {
                              _isProcessing = true;
                            });

                            final oldBalance = balanceAmount ?? 0;
                            final newBalance = oldBalance - reduction;

                            try {
                              // Update via callback (which updates mockService)
                              widget.onBalanceAdjusted(
                                  widget.shopName, reduction);

                              setState(() {
                                balanceAmount = newBalance;
                                _isProcessing = false;
                              });

                              await _fetchBalance();

                              Navigator.pop(context);

                              _showReceiptDialog(
                                shopName: widget.shopName,
                                oldBalance: oldBalance,
                                reducedAmount: reduction,
                                newBalance: newBalance,
                              );
                            } catch (e) {
                              setState(() {
                                _isProcessing = false;
                              });
                              setStateDialog(() {
                                _isProcessing = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error reducing balance: $e"),
                                  backgroundColor: AppColors.errorDark,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Invalid amount entered",
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: AppColors.errorDark,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTealDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Confirm",
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptDialog({
    required String shopName,
    required double oldBalance,
    required double reducedAmount,
    required double newBalance,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.lightSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successDark.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.successDark, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                "Pegas Flex",
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentTealDark,
                ),
              ),
              Text(
                "Kinniya 02 • 0755354023",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReceiptRow("Shop", shopName),
                Divider(color: AppColors.lightCardBorder),
                _buildReceiptRow("Old Balance",
                    "LKR ${oldBalance % 1 == 0 ? oldBalance.toInt() : oldBalance} "),
                _buildReceiptRow("Deducted",
                    "- LKR ${reducedAmount % 1 == 0 ? reducedAmount.toInt() : reducedAmount}",
                    isDeduction: true),
                Divider(color: AppColors.lightCardBorder),
                _buildReceiptRow("New Balance",
                    "LKR ${newBalance % 1 == 0 ? newBalance.toInt() : newBalance}",
                    isTotal: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(color: AppColors.lightTextSecondary),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_rounded, size: 18),
              label: Text("Print",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlueDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final device =
                    await printer.FlutterBluetoothPrinter.selectDevice(context);
                if (device == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("No printer selected",
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.warningDark,
                    ),
                  );
                  return;
                }

                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: AppColors.lightSurface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Text(
                        "Receipt Preview",
                        style: GoogleFonts.poppins(
                          color: AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: printer.Receipt(
                        builder: (context) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Pegas Flex\nKinniya 02\n0755354023"),
                            const Divider(),
                            Text("Shop: $shopName"),
                            const SizedBox(height: 10),
                            Text(
                                "Old Balance: LKR ${oldBalance % 1 == 0 ? oldBalance.toInt() : oldBalance}"),
                            const SizedBox(height: 8),
                            Text(
                                "Deducted: LKR ${reducedAmount % 1 == 0 ? reducedAmount.toInt() : reducedAmount}"),
                            const SizedBox(height: 8),
                            Text(
                                "New Balance: LKR ${newBalance % 1 == 0 ? newBalance.toInt() : newBalance}"),
                          ],
                        ),
                        onInitialized: (controller) {
                          _receiptController = controller;
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("Exit",
                              style: GoogleFonts.poppins(
                                  color: AppColors.lightTextSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_receiptController != null) {
                              await _receiptController!
                                  .print(address: device.address);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Receipt sent to printer",
                                      style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.successDark,
                                ),
                              );
                            }
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentTealDark,
                            foregroundColor: Colors.white,
                          ),
                          child: Text("Print",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    );
                  },
                );

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value,
      {bool isDeduction = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isDeduction
                  ? AppColors.errorDark
                  : isTotal
                      ? AppColors.successDark
                      : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void _showFeedbackDialog() {
    String? selectedReason;
    String note = '';
    bool isLocationVerified = false;
    bool isCheckingLocation = false;
    double? currentDistance;
    String? locationError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningDark.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warningDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Feedback",
                    style: GoogleFonts.poppins(
                      color: AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Location Verification Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLocationVerified
                            ? AppColors.success.withOpacity(0.1)
                            : locationError != null
                                ? AppColors.errorDark.withOpacity(0.1)
                                : AppColors.accentTealDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLocationVerified
                              ? AppColors.success.withOpacity(0.3)
                              : locationError != null
                                  ? AppColors.errorDark.withOpacity(0.3)
                                  : AppColors.accentTealDark.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isLocationVerified
                                      ? AppColors.success.withOpacity(0.15)
                                      : locationError != null
                                          ? AppColors.errorDark
                                              .withOpacity(0.15)
                                          : AppColors.accentTealDark
                                              .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isLocationVerified
                                      ? Icons.check_circle_rounded
                                      : locationError != null
                                          ? Icons.error_rounded
                                          : Icons.my_location_rounded,
                                  color: isLocationVerified
                                      ? AppColors.success
                                      : locationError != null
                                          ? AppColors.errorDark
                                          : AppColors.accentTealDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location Verification',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      isLocationVerified
                                          ? 'You are within 10m of shop'
                                          : locationError ??
                                              'Verify you are at shop location',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isLocationVerified
                                            ? AppColors.success
                                            : locationError != null
                                                ? AppColors.errorDark
                                                : AppColors.lightTextMuted,
                                      ),
                                    ),
                                    if (currentDistance != null &&
                                        !isLocationVerified)
                                      Text(
                                        'Distance: ${currentDistance!.toStringAsFixed(1)}m',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: AppColors.errorDark,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!isLocationVerified)
                                SizedBox(
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: isCheckingLocation
                                        ? null
                                        : () async {
                                            setDialogState(() {
                                              isCheckingLocation = true;
                                              locationError = null;
                                            });

                                            // Show loading for 2 seconds
                                            await Future.delayed(
                                                const Duration(seconds: 2));

                                            final position =
                                                await _getCurrentLocation();

                                            if (position == null) {
                                              setDialogState(() {
                                                isCheckingLocation = false;
                                                locationError =
                                                    'Unable to get location';
                                              });
                                              return;
                                            }

                                            if (shopLatitude == null ||
                                                shopLongitude == null) {
                                              setDialogState(() {
                                                isCheckingLocation = false;
                                                locationError =
                                                    'Shop location not available';
                                              });
                                              return;
                                            }

                                            final distance = _calculateDistance(
                                              position.latitude,
                                              position.longitude,
                                              shopLatitude!,
                                              shopLongitude!,
                                            );

                                            setDialogState(() {
                                              isCheckingLocation = false;
                                              currentDistance = distance;
                                              if (distance <= 10) {
                                                isLocationVerified = true;
                                                locationError = null;
                                              } else {
                                                locationError =
                                                    'Too long from shop';
                                              }
                                            });
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentTealDark,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: isCheckingLocation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Verify',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: isLocationVerified ? 1.0 : 0.5,
                      child: IgnorePointer(
                        ignoring: !isLocationVerified,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.lightCardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Reason',
                                labelStyle: GoogleFonts.poppins(
                                    color: AppColors.lightTextMuted),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              dropdownColor: AppColors.lightSurface,
                              style: GoogleFonts.poppins(
                                  color: AppColors.lightTextPrimary),
                              value: selectedReason,
                              items: [
                                'Shop Closed 🏪',
                                'Owner Not Available 🙅‍♂️',
                                'No business today 📉',
                                'Owner refused to pay 💰',
                                'Other ✏️'
                              ]
                                  .map((reason) => DropdownMenuItem(
                                        value: reason,
                                        child: Text(reason),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedReason = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: isLocationVerified ? 1.0 : 0.5,
                      child: IgnorePointer(
                        ignoring: !isLocationVerified,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.lightCardBorder),
                          ),
                          child: TextField(
                            style: GoogleFonts.poppins(
                                color: AppColors.lightTextPrimary),
                            decoration: InputDecoration(
                              labelText: 'Note (optional)',
                              labelStyle: GoogleFonts.poppins(
                                  color: AppColors.lightTextMuted),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 3,
                            onChanged: (value) => note = value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.warningDark.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.warningDark, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "You must be within 10m of shop to submit feedback.",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.warningDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          color: AppColors.lightTextSecondary)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocationVerified
                        ? AppColors.warningDark
                        : AppColors.lightTextMuted,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLocationVerified
                      ? () async {
                          if (selectedReason == null ||
                              selectedReason!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please select a reason',
                                    style: GoogleFonts.poppins()),
                                backgroundColor: AppColors.errorDark,
                              ),
                            );
                            return;
                          }

                          mockService.addFeedback(
                              widget.routeName,
                              widget.shopName,
                              widget.shopId,
                              selectedReason!,
                              note);

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Feedback submitted successfully',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Please verify your location first (must be within 10m of shop)',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: AppColors.errorDark,
                            ),
                          );
                        },
                  child: Text('Submit',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildBalanceCard(),
                        const SizedBox(height: 24),
                        _buildTransactionList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shopName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Balance Details',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchBalance,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.accentTealDark),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentTealDark.withOpacity(0.12),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.errorDark.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.errorDark.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorDark.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.errorDark, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'Credit Balance',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          balanceAmount == null
              ? const CircularProgressIndicator(
                  color: AppColors.accentTealDark, strokeWidth: 2)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      balanceAmount! % 1 == 0
                          ? balanceAmount!.toInt().toString()
                          : balanceAmount.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: AppColors.errorDark,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        ' LKR',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 8),
          Text(
            'Click adjust button to reduce collected amount',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.lightTextMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showAdjustDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTealDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'ADJUST BALANCE',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Feedback Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _showFeedbackDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warningDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: AppColors.warningDark.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'FEEDBACK',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
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

  Widget _buildTransactionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaction History',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lightTextPrimary,
              ),
            ),
            // Credit Limit Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warningDark.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Credit Limit: ',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '50,000 LKR',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warningDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightCardBorder),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      color: AppColors.lightTextMuted, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.poppins(color: AppColors.lightTextMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final tx = entry.value;
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightCardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.successDark.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.payments_rounded,
                          color: AppColors.successDark, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx['store'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tx['time'] != null
                                ? (tx['time'] as DateTime)
                                    .toString()
                                    .substring(0, 16)
                                : 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'LKR ${tx['amount']}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentTealDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }
}
