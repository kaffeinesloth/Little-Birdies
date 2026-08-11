import 'package:flutter_test/flutter_test.dart';

import 'package:smart_helpdesk_web/main.dart';

void main() {
  testWidgets('signs in and shows the Flutter admin inbox', (tester) async {
    await tester.pumpWidget(const SmartHelpdeskWebApp());

    expect(find.text('Flutter web admin console'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Unified Inbox'), findsOneWidget);
    expect(find.text('Linh Tran'), findsOneWidget);
  });
}
