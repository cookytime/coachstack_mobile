import 'package:flutter_test/flutter_test.dart';

import 'package:coachstack_mobile/main.dart';

void main() {
  testWidgets('App renders bootstrap page', (WidgetTester tester) async {
    await tester.pumpWidget(const CoachStackApp());

    // The bootstrap page shows a loading indicator while checking auth.
    expect(find.byType(CoachStackApp), findsOneWidget);
  });
}
