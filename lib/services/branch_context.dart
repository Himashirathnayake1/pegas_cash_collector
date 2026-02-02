import 'package:flutter/material.dart';

/// Global provider for branch and role context
/// Stores selected branch and role for the entire app session
class BranchContext {
  static final BranchContext _instance = BranchContext._internal();

  factory BranchContext() {
    return _instance;
  }

  BranchContext._internal();

  String? _branchId;
  String? _role;

  String? get branchId => _branchId;
  String? get role => _role;

  bool get isAuthenticated => _branchId != null && _role != null;

  /// Set branch and role after successful authentication
  void setBranchAndRole(String branchId, String role) {
    _branchId = branchId;
    _role = role;
    print('✅ BranchContext set: branch=$branchId, role=$role');
  }

  /// Clear branch and role on logout
  void clear() {
    _branchId = null;
    _role = null;
    print('✅ BranchContext cleared');
  }

  @override
  String toString() => 'BranchContext(branch: $_branchId, role: $_role)';
}

/// Optional: Use a ChangeNotifier for reactive updates
class BranchContextProvider extends ChangeNotifier {
  String? _branchId;
  String? _role;

  String? get branchId => _branchId;
  String? get role => _role;

  bool get isAuthenticated => _branchId != null && _role != null;

  void setBranchAndRole(String branchId, String role) {
    _branchId = branchId;
    _role = role;
    print('✅ BranchContextProvider updated: branch=$branchId, role=$role');
    notifyListeners();
  }

  void clear() {
    _branchId = null;
    _role = null;
    print('✅ BranchContextProvider cleared');
    notifyListeners();
  }
}
