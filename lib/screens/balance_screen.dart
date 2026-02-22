import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart'
    as printer;
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../services/branch_context.dart';

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
  double? creditLimit;
  bool _isProcessing = false;
  double? shopLatitude;
  double? shopLongitude;
  String branchName = 'Pegas Flex';
  String branchPhone = '';

  List<Map<String, dynamic>> transactions = [];
  final firestore = FirebaseFirestore.instance;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchBranchDetails();
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
    try {
      final branchId = BranchContext().branchId;
      
      // Build shop reference with branch context
      final shopRef = firestore
          .collection('branches')
          .doc(branchId)
          .collection('routes')
          .doc(widget.routeName)
          .collection('shops')
          .doc(widget.shopId);

      // Fetch shop document
      final shopDoc = await shopRef.get();

      if (!shopDoc.exists) {
        debugPrint('Shop not found: ${widget.shopId}');
        return;
      }

      final shopData = shopDoc.data() ?? {};

      // Safely convert amount to double (match CashCollector field name)
      double amount = 0.0;
      final amountValue = shopData['amount'];
      if (amountValue is double) {
        amount = amountValue;
      } else if (amountValue is int) {
        amount = amountValue.toDouble();
      } else if (amountValue is String) {
        amount = double.tryParse(amountValue) ?? 0.0;
      }

      // Safely convert latitude to double
      double latitude = 0.0;
      final latValue = shopData['latitude'];
      if (latValue is double) {
        latitude = latValue;
      } else if (latValue is int) {
        latitude = latValue.toDouble();
      } else if (latValue is String) {
        latitude = double.tryParse(latValue) ?? 0.0;
      }

      // Safely convert longitude to double
      double longitude = 0.0;
      final longValue = shopData['longitude'];
      if (longValue is double) {
        longitude = longValue;
      } else if (longValue is int) {
        longitude = longValue.toDouble();
      } else if (longValue is String) {
        longitude = double.tryParse(longValue) ?? 0.0;
      }

      // Safely convert creditLimit to double
      double creditLimitValue = 50000.0;
      final creditLimitData = shopData['creditLimit'];
      if (creditLimitData is double) {
        creditLimitValue = creditLimitData;
      } else if (creditLimitData is int) {
        creditLimitValue = creditLimitData.toDouble();
      } else if (creditLimitData is String) {
        creditLimitValue = double.tryParse(creditLimitData) ?? 50000.0;
      }

      setState(() {
        balanceAmount = amount;
        creditLimit = creditLimitValue;
        shopLatitude = latitude;
        shopLongitude = longitude;
      });

      // Fetch transactions for this shop (matching CashCollector pattern)
      final txSnapshot = await shopRef
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint('Transaction docs fetched: ${txSnapshot.docs.length}');

      // Filter transactions where type == 'paid' OR type is missing (like CashCollector)
      final txList = txSnapshot.docs.where((doc) {
        final type = doc.data()['type'];
        return type == 'paid' || type == null;
      }).map<Map<String, dynamic>>((doc) {
        final data = doc.data();
        double txAmount = 0.0;
        final txAmountValue = data['amount'];
        if (txAmountValue is double) {
          txAmount = txAmountValue;
        } else if (txAmountValue is int) {
          txAmount = txAmountValue.toDouble();
        } else if (txAmountValue is String) {
          txAmount = double.tryParse(txAmountValue) ?? 0.0;
        }

        return {
          'time': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'amount': txAmount,
          'type': data['type'] ?? 'Cash',
          'store': widget.shopName,
        };
      }).toList();

      setState(() {
        transactions = txList;
      });
    } catch (e) {
      debugPrint('Error fetching balance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading balance: $e'),
          backgroundColor: AppColors.errorDark,
        ),
      );
    }
  }

  Future<void> _fetchBranchDetails() async {
    try {
      final branchId = BranchContext().branchId;
      
      final branchDoc = await firestore
          .collection('branches')
          .doc(branchId)
          .get();

      if (branchDoc.exists) {
        final data = branchDoc.data() ?? {};
        
        setState(() {
          branchName = (branchId != null && branchId.isNotEmpty) 
              ? branchId[0].toUpperCase() + branchId.substring(1) 
              : 'Pegas Flex';
          branchPhone = data['phoneNumber'] ?? '';
        });
        
        debugPrint('📱 Branch details fetched: $branchName, $branchPhone');
      }
    } catch (e) {
      debugPrint('Error fetching branch details: $e');
    }
  }

  // Product ordering - Show order dialog with product selection
  final List<String> products = [
    'Cup Juice',
    'Sweet Bottles',
    'Milk pack',
    'Soft Drinks',
  ];
  List<String> selectedProducts = [];

  void _showOrderDialog() {
    setState(() {
      selectedProducts = []; // Reset selection
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Order Products"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select products to order:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: products.map((product) {
                        final isSelected = selectedProducts.contains(product);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(product),
                          selectedColor: Colors.blueGrey.withOpacity(0.2),
                          showCheckmark: false,
                          onSelected: (val) {
                            setStateDialog(() {
                              if (val) {
                                selectedProducts.add(product);
                              } else {
                                selectedProducts.remove(product);
                              }
                            });
                          },
                          avatar: isSelected
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.blueGrey)
                              : const SizedBox.shrink(),
                          backgroundColor: Colors.grey[200],
                          labelStyle: const TextStyle(color: Colors.black),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (selectedProducts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Please select at least one product")),
                            );
                            return;
                          }

                          setStateDialog(() {
                            _isProcessing = true;
                          });

                          await _placeOrder();

                          setStateDialog(() {
                            _isProcessing = false;
                          });

                          Navigator.pop(context);
                        },
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Order",
                          style: TextStyle(color: Colors.orange),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Place order to Firestore
  Future<void> _changeShopOrder() async {
    final branchId = BranchContext().branchId;
    
    // Build shop reference with branch context
    final shopRef = firestore
        .collection('branches')
        .doc(branchId)
        .collection('routes')
        .doc(widget.routeName)
        .collection('shops')
        .doc(widget.shopId);

    try {
      // Fetch current order number
      final shopDoc = await shopRef.get();
      final data = shopDoc.data() as Map<String, dynamic>?;
      final currentOrderNumber = (data?['orderNumber'])?.toString() ?? '';

      final TextEditingController controller = TextEditingController(
        text: currentOrderNumber.isNotEmpty ? currentOrderNumber : '',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Change Shop Order"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Order Number: ${currentOrderNumber.isNotEmpty ? '#$currentOrderNumber' : 'Not set'}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "New Order Number",
                    hintText: "Enter new order number",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final orderNumber = int.tryParse(controller.text);
                  if (orderNumber == null || orderNumber < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid order number"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    // Update order number in Firestore
                    await shopRef.update({'orderNumber': orderNumber});

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "✅ Order updated to #$orderNumber for ${widget.shopName}"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error updating order: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Update"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching order number: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _placeOrder() async {
    try {
      final branchId = BranchContext().branchId;
      
      // Get current location
      String? currentLatitude;
      String? currentLongitude;

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            currentLatitude = position.latitude.toString();
            currentLongitude = position.longitude.toString();
          }
        }
      } catch (e) {
        // Continue without location if there's an error
        debugPrint("Location error: $e");
      }

      Map<String, dynamic> orderData = {
        "type": "remainingShop",
        "shopName": widget.shopName,
        "shopId": widget.shopId,
        "routeName": widget.routeName,
        "submittedAt": FieldValue.serverTimestamp(),
        "products": selectedProducts,
      };

      // Add location data if available
      if (currentLatitude != null && currentLongitude != null) {
        orderData["location"] = {
          "latitude": currentLatitude,
          "longitude": currentLongitude,
          "timestamp": DateTime.now().toIso8601String(),
        };
      }

      // Save order to branch-isolated collection
      await firestore
          .collection('branches')
          .doc(branchId)
          .collection('orders')
          .add(orderData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentLatitude != null
              ? "✅ Order placed with location for ${widget.shopName}"
              : "✅ Order placed for ${widget.shopName}"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedProducts = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error placing order: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                              reduction > 299 &&
                              reduction <= (balanceAmount ?? 0)) {
                            setStateDialog(() {
                              _isProcessing = true;
                            });

                            final oldBalance = balanceAmount ?? 0;
                            final newBalance = oldBalance - reduction;

                            try {
                              final branchId = BranchContext().branchId;

                              // Update balance in Firestore with comprehensive fields (CashCollector pattern)
                              final updateData = {
                                'amount': newBalance,  // Match CashCollector field name
                                'status': newBalance == 0 ? 'Unpaid' : 'Paid',
                                'paidAmount': reduction,
                                'totalPaid': FieldValue.increment(reduction),
                              };

                              if (newBalance > 0) {
                                updateData['paidAt'] = FieldValue.serverTimestamp();
                              }

                              await firestore
                                  .collection('branches')
                                  .doc(branchId)
                                  .collection('routes')
                                  .doc(widget.routeName)
                                  .collection('shops')
                                  .doc(widget.shopId)
                                  .update(updateData);

                              // Add transaction record in Firestore
                              await firestore
                                  .collection('branches')
                                  .doc(branchId)
                                  .collection('routes')
                                  .doc(widget.routeName)
                                  .collection('shops')
                                  .doc(widget.shopId)
                                  .collection('transactions')
                                  .add({
                                'amount': reduction,
                                'type': 'paid',
                                'timestamp': FieldValue.serverTimestamp(),
                                'description': 'Payment collection',
                              });

                              // Update via callback for parent screen
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
                                  reduction != null && reduction <= 299
                                      ? "Minimum amount is 300"
                                      : "Invalid amount entered",
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
                branchPhone.isNotEmpty ? "$branchName • $branchPhone" : "Branch Details",
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
                _buildReceiptRow("Date", DateTime.now().toString().split('.')[0]),
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
                            Text("Pegas Flex\n$branchName\n$branchPhone"),
                            const Divider(),
                            Text("Shop: $shopName"),
                            Text("Date: ${DateTime.now().toString().split('.')[0]}"),
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

                          try {
                            final branchId = BranchContext().branchId;

                            // Save feedback to Firestore
                            await firestore
                                .collection('branches')
                                .doc(branchId)
                                .collection('feedback')
                                .add({
                              'routeName': widget.routeName,
                              'shopName': widget.shopName,
                              'shopId': widget.shopId,
                              'reason': selectedReason,
                              'note': note,
                              'timestamp': Timestamp.now(),
                              'status': 'open',
                            });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Feedback submitted successfully',
                                    style: GoogleFonts.poppins()),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Error submitting feedback: $e',
                                        style: GoogleFonts.poppins()),
                                backgroundColor: AppColors.errorDark,
                              ),
                            );
                          }
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
            onPressed: _changeShopOrder,
            icon: const Icon(Icons.sort,
                color: AppColors.accentTealDark),
            tooltip: "Change Shop Order",
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentTealDark.withOpacity(0.12),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 8),
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
          // Order Products Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showOrderDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
                  const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'ORDER PRODUCTS',
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
                    creditLimit != null
                        ? '${(creditLimit! / 1000).toStringAsFixed(0)},000 LKR'
                        : 'Loading...',
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
