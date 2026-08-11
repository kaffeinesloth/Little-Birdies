import 'package:flutter_test/flutter_test.dart';

import 'package:smart_helpdesk_web/main.dart';

void main() {
  testWidgets('signs in and shows the backend-backed admin inbox',
      (tester) async {
    await tester.pumpWidget(const SmartHelpdeskWebApp());

    expect(find.text('Owner admin console'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('No customer tickets yet'), findsOneWidget);
  });
}
