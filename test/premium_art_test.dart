import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_game_maker/premium_art.dart';

void main() {
  testWidgets('premium adventure hero renders title and create action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdventureHero(projectCount: 3, onCreate: () => tapped = true),
      ),
    ));

    expect(find.text('سلام، قهرمان کوچولو!'), findsOneWidget);
    expect(find.text('۳ بازی ساخته‌شده'), findsNothing); // Count remains numeric and localized by the platform font.
    expect(find.text('3 بازی ساخته‌شده'), findsOneWidget);
    await tester.tap(find.text('ساخت اولین بازی'));
    expect(tapped, isTrue);
  });
}
