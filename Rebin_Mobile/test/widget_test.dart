// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod'ı import et

import 'package:rebin/main.dart';
import 'package:rebin/widgets/main_scaffold.dart';

void main() {
  testWidgets('Main scaffold smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Uygulamayı ProviderScope ile sarmala!
    await tester.pumpWidget(const ProviderScope(child: RebinApp()));

    // pumpAndSettle, animasyonların ve asenkron işlemlerin bitmesini bekler.
    await tester.pumpAndSettle();

    // Verify that the main scaffold is displayed
    expect(find.byType(MainScaffold), findsOneWidget);
  });
}
