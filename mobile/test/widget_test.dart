import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Smart Helpdesk workspace renders ticket inbox', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1600));
    await tester.pumpWidget(const SmartHelpdeskApp(enableNetwork: false));

    expect(find.text('Omnichannel Customer Support'), findsOneWidget);
    expect(find.text('UNIFIED INBOX'), findsOneWidget);
    expect(find.textContaining('#102'), findsWidgets);
    expect(find.text('1. Live Customer Support'), findsOneWidget);
  });

  testWidgets('phone layout uses compact navigation and opens a ticket', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const SmartHelpdeskApp(enableNetwork: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Smart Helpdesk'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('UNIFIED INBOX'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('#102').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Customer'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Reports'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Support Performance'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Manage'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('System Management'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add knowledge'));
    await tester.pumpAndSettle();
    expect(find.text('Upload Knowledge Document'), findsOneWidget);
    expect(find.text('Choose Document'), findsOneWidget);
    expect(find.textContaining('Maximum size: 10 MB'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('agent phone view contains only the support workspace', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'smart_helpdesk_demo_role': 'agent',
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const SmartHelpdeskApp(enableNetwork: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Manage'), findsNothing);
    expect(find.textContaining('Support Performance'), findsNothing);
    expect(find.text('System Management'), findsNothing);
    expect(find.text('UNIFIED INBOX'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agent desktop header hides reports and administration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'smart_helpdesk_demo_role': 'agent',
    });
    await tester.binding.setSurfaceSize(const Size(3000, 1600));
    await tester.pumpWidget(const SmartHelpdeskApp(enableNetwork: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1. Live Customer Support'), findsOneWidget);
    expect(find.text('2. Reports & Revenue'), findsNothing);
    expect(find.text('3. Management & AI Knowledge'), findsNothing);
    expect(find.text('UNIFIED INBOX'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolved conversations expose a confirmed delete action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1600));
    await tester.pumpWidget(const SmartHelpdeskApp(enableNetwork: false));

    await tester.tap(find.text('Resolved (1)'));
    await tester.pump();
    await tester.tap(find.textContaining('Nam Le (Web Store)').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Delete Chat'), findsOneWidget);
    await tester.tap(find.text('Delete Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Delete resolved conversation?'), findsOneWidget);
    expect(
      find.textContaining('permanently removes ticket #101'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete resolved conversation?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
