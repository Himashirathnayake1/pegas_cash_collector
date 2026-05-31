import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  late Connectivity _connectivity;
  bool _isConnected = true;

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal() {
    _connectivity = Connectivity();
    _initializeConnectivity();
  }

  void _initializeConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isConnected = result != ConnectivityResult.none;
      debugPrint(
        '📶 Network status changed: ${_isConnected ? 'Connected' : 'Disconnected'}',
      );
    });
  }

  // Check current connection status
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  // Get current cached connection status
  bool get currentStatus => _isConnected;

  // Show network error dialog
  static Future<void> showNetworkErrorDialog(
    BuildContext context, {
    String message =
        'Network connection lost. Please check your internet connection and try again.',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Network Error'),
              ],
            ),
            content: Text(message, style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Validate network connection before critical operation
  static Future<bool> validateNetworkBefore(BuildContext context) async {
    final isConnected = await NetworkService().isConnected();

    if (!isConnected) {
      await showNetworkErrorDialog(
        context,
        message:
            'No internet connection. Cannot place order. Please check your connection and try again.',
      );
      return false;
    }

    return true;
  }

  // Monitor network during operation
  static Future<bool> validateNetworkDuring(BuildContext context) async {
    final isConnected = await NetworkService().isConnected();

    if (!isConnected) {
      await showNetworkErrorDialog(
        context,
        message:
            'Network connection lost during order processing. Please check your connection and try again.',
      );
      return false;
    }

    return true;
  }
}
