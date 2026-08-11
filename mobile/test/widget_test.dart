import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_helpdesk_mobile/main.dart';

void main() {
  testWidgets('logs in as employee and shows support navigation',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());

    expect(find.text('Smart Helpdesk'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('Assigned'), findsWidgets);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('mobile login does not expose manual role selection',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());

    expect(find.text('super_admin'), findsNothing);
    expect(find.text('agent'), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('assigned ticket list shows an empty state without backend data',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('No assigned tickets right now.'), findsOneWidget);
  });

  testWidgets('online offline toggle updates shell state', (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('urgent screen shows an empty state without notifications',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Urgent'));
    await tester.pumpAndSettle();

    expect(find.text('No urgent tickets right now.'), findsOneWidget);
  });
}
