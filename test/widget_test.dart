import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart'; // ✅ Needed for GameWidget
import 'package:timo_game_2013/main.dart'; // ✅ Replace with your actual package name

void main() {
  testWidgets('Stop button is visible and tappable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameWidget<MyGame>(
            game: MyGame(),
            overlayBuilderMap: {
              'StopButton': (context, MyGame game) {
                return Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      key: const Key('stop_button'),
                      onPressed: () => game.stopGame(),
                      child: const Text('Stop'),
                    ),
                  ),
                );
              },
              'RestartOverlay': (context, MyGame game) {
                return const SizedBox.shrink();
              },
            },
            initialActiveOverlays: const ['StopButton'],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final stopButton = find.byKey(const Key('stop_button'));

    expect(stopButton, findsOneWidget); // ✅ Should find it
    await tester.tap(stopButton); // ✅ Tap it
    await tester.pump(); // ✅ Let the widget react
  });
}
