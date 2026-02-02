# Branch-Based Authentication Setup Guide

## Firestore Structure (Required)

Your new Firebase project MUST have this exact structure:

```
Collection: branches
├── Document: kinniya
│   └── Field: accessCodes (Map)
│       ├── adder: "5678"
│       ├── cashCollector: "1234"
│       └── store: "9100"
│
└── Document: kandy
    └── Field: accessCodes (Map)
        ├── adder: "6789"
        ├── cashCollector: "2345"
        └── store: "0123"
```

## How to Set Up in Firebase Console

1. Go to **Firestore Database**
2. Click **+ Start collection**
3. Create collection named: `branches`
4. Add first document with ID: `kinniya`
5. In that document, add a field:
   - Field name: `accessCodes`
   - Type: **Map**
6. Inside the map, add three string fields:
   - `adder` = `"5678"`
   - `cashCollector` = `"1234"`
   - `store` = `"9100"`
7. Repeat steps 4-6 for another document with ID: `kandy` (with different codes)

## Login Flow

1. **Branch Selection Dropdown** — Loads branch IDs from `branches` collection
2. **Role Selection Dropdown** — Shows [Cash Collector, Adder, Store Keeper]
3. **Access Code Field** — 4-digit code
4. **Submit** — Verifies code against `branches/{branchId}/accessCodes/{role}`

## Testing

### Test Case 1: Kinniya Branch - Cash Collector
- **Branch**: kinniya
- **Role**: Cash Collector
- **Code**: 1234
- **Expected**: ✅ Login successful

### Test Case 2: Kinniya Branch - Adder
- **Branch**: kinniya
- **Role**: Adder
- **Code**: 5678
- **Expected**: ✅ Login successful

### Test Case 3: Wrong Code
- **Branch**: kinniya
- **Role**: Cash Collector
- **Code**: 9999
- **Expected**: ❌ Wrong Code dialog

## Debugging

If branches dropdown shows "Loading" indefinitely:

1. **Check Firestore Rules** — Ensure reads are allowed:
   ```
   match /branches/{document=**} {
     allow read: if true;
   }
   ```

2. **Check Firebase Initialization** — Verify firebase_options.dart has correct project credentials

3. **Check Logs** — Look for error messages in Flutter console (watch `flutter logs`)

4. **Fallback Mode** — BranchAuthService returns fallback branches ['kinniya', 'kandy'] if Firestore fails (for testing). This will disappear once Firestore is set up.

## After Login

Once user logs in successfully:
- `BranchContext().branchId` is set to selected branch (e.g., "kinniya")
- `BranchContext().role` is set to selected role (e.g., "cashCollector")
- All subsequent Firestore queries are scoped to that branch using `BranchFirestore()` helper
- Data is isolated per branch — no mixing between kinniya and kandy

## Code Integration Example

In home_screen.dart (or any screen after login):

```dart
import 'package:pegas_cashcollector/services/branch_firestore.dart';

// Fetch all shops for current branch
final bf = BranchFirestore();
final shops = await bf.allShops();

// Fetch orders for current branch
final orders = await bf.ordersCollection().get();

// Update stats for current branch
await bf.statsRef().set({'someField': value}, SetOptions(merge: true));
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Branches dropdown stuck on "Loading" | Firebase read permission denied | Update Firestore rules to allow reads |
| "Wrong Code" dialog after valid code | Code mismatch (spaces, quotes, case) | Ensure codes in Firestore are exact strings without extra spaces |
| Branch not appearing in dropdown | Document ID doesn't exist | Create the document in Firestore with exact ID (lowercase) |
| `BranchContext` returns null | Login not completed | Ensure user logs in successfully before navigating to home |
