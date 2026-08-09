import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_helpdesk_mobile/main.dart';

void main() {
  testWidgets('logs in as super_admin and shows dashboard navigation',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());

    expect(find.text('Smart Helpdesk'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('agent role does not show dashboard navigation', (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());

    await tester.tap(find.text('agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('ticket list renders source, status, summary, and timestamp',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('Linh Tran'), findsOneWidget);
    expect(find.text('Refund request after delayed delivery'), findsOneWidget);
    expect(find.text('Web'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.textContaining('min ago'), findsWidgets);
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

  testWidgets('ticket detail can reply, resolve, and reopen', (tester) async {
    await tester.pumpWidget(const SmartHelpdeskMobileApp());
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Linh Tran'));
    await tester.pumpAndSettle();

    expect(find.text('I want a refund because my delivery is late.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'I am checking this now.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('I am checking this now.'), findsOneWidget);

    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Reopen'), findsOneWidget);

    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    expect(find.text('Resolve'), findsOneWidget);
  });
}
