import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Smart Helpdesk workspace renders ticket inbox', (tester) async {
    await tester.pumpWidget(const SmartHelpdeskApp());

    expect(find.text('Smart Helpdesk Staff'), findsOneWidget);
    expect(find.text('Hop thu CSKH'), findsOneWidget);
    expect(find.textContaining('#102'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
  });
}
