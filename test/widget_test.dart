import 'package:flutter_test/flutter_test.dart';

import 'package:nudgee/app/app.dart';

void main() {
  testWidgets('App renders home page with title', (tester) async {
    await tester.pumpWidget(const NudgeeApp());
    await tester.pumpAndSettle();

    expect(find.text('Nudgee'), findsOneWidget);
    expect(find.text('自律 · 记账 · AI 陪伴'), findsOneWidget);
  });
}
