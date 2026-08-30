import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_ai/main.dart';

void main() {
  testWidgets('App boots to the Campaign Hub home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp(initialLocation: '/home')));
    await tester.pumpAndSettle();

    expect(find.text('ARCANE DARK'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('App boots to onboarding when routed there', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp(initialLocation: '/onboarding')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dungeon Master'), findsWidgets);
  });
}
