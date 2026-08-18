// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:pegas_cashcollector/screens/home_screen.dart';
import 'package:pegas_cashcollector/screens/route_balance_in_hand_screen.dart';

void main() {
  test('route password matches trimmed values', () {
    expect(routePasswordMatches('abc123', 'abc123'), isTrue);
    expect(routePasswordMatches('abc123', ' abc123 '), isTrue);
    expect(routePasswordMatches('abc123', 'abc124'), isFalse);
  });

  test('blank route password bypasses the gate', () {
    expect(routePasswordMatches('', 'anything'), isTrue);
    expect(routePasswordMatches(null, 'anything'), isTrue);
  });

  test('route balance totals sum all shop totals for a route', () {
    final total = calculateRouteBalanceFromShops([
      {'totalPaid': 250.0},
      {'totalPaid': '100'},
      {'totalPaid': 50},
    ]);

    expect(total, 400.0);
  });
}
