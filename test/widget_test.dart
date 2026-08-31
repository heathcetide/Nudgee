import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nudgee/app/app.dart';

void main() {
  testWidgets('App renders splash page', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await tester.pumpWidget(
      const ProviderScope(
        child: NudgeeApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Nudgee'), findsOneWidget);
  });
}
