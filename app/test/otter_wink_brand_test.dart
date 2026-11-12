import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beef/theme/app_theme.dart';
import 'package:beef/widgets/beef_wordmark.dart';

void main() {
  for (final compact in [true, false]) {
    testWidgets('Otter Wink wordmark fits a narrow screen (compact=$compact)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(theme: BeefTheme.dark, home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: BeefWordmark(compact: compact)),
      )));
      expect(find.text('Otter Wink'), findsOneWidget);
      expect(find.text('BEEF'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
