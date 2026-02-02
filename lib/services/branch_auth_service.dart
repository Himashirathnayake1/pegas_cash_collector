import 'package:cloud_firestore/cloud_firestore.dart';

class BranchAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verify access code for a specific branch and role
  /// Returns true if code is valid, false otherwise
  Future<bool> verifyAccessCode({
    required String branchId,
    required String role, // 'cashCollector', 'adder', 'store'
    required String accessCode,
  }) async {
    try {
      print('🔍 Verifying access code for branch=$branchId, role=$role');
      
      // Fetch branch document
      final branchDoc = await _firestore
          .collection('branches')
          .doc(branchId)
          .get();

      if (!branchDoc.exists) {
        print('❌ Branch "$branchId" not found in Firestore');
        print('   Available docs: ${(await _firestore.collection("branches").get()).docs.map((d) => d.id).toList()}');
        return false;
      }

      print('✅ Branch document found');

      // Get the access codes map for this branch
      final Map<String, dynamic>? data = branchDoc.data();
      if (data == null) {
        print('❌ Branch data is null');
        return false;
      }

      print('📄 Branch data keys: ${data.keys.toList()}');

      // Access codes are stored in a nested structure like:
      // branches/{branchId}/accessCodes: { cashCollector: "1234", adder: "5678", store: "9012" }
      
      final accessCodesMap = data['accessCodes'] as Map<String, dynamic>?;
      if (accessCodesMap == null) {
        print('❌ No accessCodes found for branch "$branchId"');
        print('   Available fields: ${data.keys.toList()}');
        return false;
      }

      print('📋 AccessCodes map: $accessCodesMap');

      final storedCode = accessCodesMap[role] as String?;
      if (storedCode == null) {
        print('❌ No access code found for role "$role" in branch "$branchId"');
        print('   Available roles: ${accessCodesMap.keys.toList()}');
        return false;
      }

      print('🔐 Comparing codes: input=$accessCode, stored=$storedCode');

      final isValid = storedCode == accessCode;
      if (isValid) {
        print('✅ Access code verified for $branchId / $role');
      } else {
        print('❌ Invalid access code for $branchId / $role (mismatch)');
      }

      return isValid;
    } catch (e) {
      print('❌ Error verifying access code: $e');
      print('   Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Fetch all available branches from Firestore
  Future<List<String>> fetchBranchIds() async {
    try {
      print('📡 Fetching branch IDs from Firestore...');
      
      final snapshot = await _firestore.collection('branches').get();
      final branchIds = snapshot.docs.map((doc) => doc.id).toList();
      
      print('✅ Fetched ${branchIds.length} branches: $branchIds');
      
      if (branchIds.isEmpty) {
        print('⚠️ No branches found! Check your Firestore permissions and data.');
      }
      
      return branchIds;
    } catch (e) {
      print('❌ Error fetching branches: $e');
      print('   Error type: ${e.runtimeType}');
      
      // If Firestore fails, return fallback branches for testing/dev
      print('⚠️ Returning fallback branches for testing');
      return ['kinniya', 'kandy']; // REMOVE THIS in production after Firestore is properly set up
    }
  }

  /// Fetch available roles for a branch (optional helper)
  Future<List<String>> fetchAvailableRoles(String branchId) async {
    try {
      print('📡 Fetching available roles for branch: $branchId');
      
      final branchDoc = await _firestore
          .collection('branches')
          .doc(branchId)
          .get();

      if (!branchDoc.exists) {
        print('❌ Branch "$branchId" not found');
        return [];
      }

      final data = branchDoc.data() as Map<String, dynamic>?;
      final accessCodesMap = data?['accessCodes'] as Map<String, dynamic>?;
      
      if (accessCodesMap == null) {
        print('❌ No accessCodes field in branch "$branchId"');
        return [];
      }

      final roles = accessCodesMap.keys.toList();
      print('✅ Available roles for $branchId: $roles');
      return roles;
    } catch (e) {
      print('❌ Error fetching roles: $e');
      return [];
    }
  }
}
