import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_pdf/ui/home_screen.dart';

void main() {
  group('HomeScreen', () {
    Widget buildSubject() {
      return const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      );
    }

    testWidgets('renders two tabs: Recent and Tools', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
    });

    testWidgets('FAB is visible on Recent tab', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('empty state is shown when document list is empty',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No documents yet'), findsOneWidget);
    });

    testWidgets('switching to Tools tab hides FAB', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Tap the Tools tab
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Tools tab shows grouped headers', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
    });
  });
}
