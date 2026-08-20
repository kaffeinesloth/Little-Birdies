import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Smart Helpdesk workspace renders ticket inbox', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1600));
    await tester.pumpWidget(const SmartHelpdeskApp());

    expect(find.text('Hệ Thống Quản Trị CSKH Đa Kênh'), findsOneWidget);
    expect(find.text('HỘP THƯ HỢP NHẤT'), findsOneWidget);
    expect(find.textContaining('#102'), findsWidgets);
    expect(find.text('1. Live Chat & CSKH'), findsOneWidget);
  });
}
