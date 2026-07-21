import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtengatenga_ar/core/services/indoor_navigation_service.dart';
import 'package:mtengatenga_ar/features/map/indoor_navigation_screen.dart';

void main() {
  testWidgets('indoor navigation renders and completes manual route', (
    WidgetTester tester,
  ) async {
    final service = IndoorNavigationService();

    await tester.pumpWidget(
      MaterialApp(home: IndoorNavigationScreen(navigationService: service)),
    );

    expect(find.text('Indoor Navigation'), findsOneWidget);
    expect(find.text('Measured Room Map'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.tap(find.text('Preview Route'));
    await tester.pumpAndSettle();

    expect(find.text('Full tour'), findsOneWidget);
    expect(find.text('Start Navigation'), findsOneWidget);

    await tester.tap(find.text('Start Navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Artifact 1'), findsOneWidget);
    expect(find.text('1 of 4 - 4.7 m from current stop'), findsOneWidget);

    await tester.tap(find.text("I'm here"));
    await tester.pumpAndSettle();
    expect(find.text('Artifact 2'), findsOneWidget);

    await tester.tap(find.text("I'm here"));
    await tester.pumpAndSettle();
    expect(find.text('Artifact 3'), findsOneWidget);

    await tester.tap(find.text("I'm here"));
    await tester.pumpAndSettle();
    expect(find.text('Artifact 4'), findsOneWidget);

    await tester.tap(find.text("I'm here"));
    await tester.pumpAndSettle();

    expect(find.text('Tour complete'), findsOneWidget);
    expect(find.text('4 artifacts visited - 17.1 m walked'), findsOneWidget);
  });
}
