import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/game/engine.dart';
import 'package:sweep/table_art.dart';

void main() {
  for (final counts in [(4, 0), (12, 0), (0, 6), (12, 5), (40, 0)]) {
    for (final size in [const Size(240, 220), const Size(286, 430)]) {
      testWidgets('table fits $counts in $size and remains tappable',
          (tester) async {
        var taps = 0;
        final items = <Widget>[
          for (var i = 0; i < counts.$1; i++)
            TableCard(
                key: ValueKey('loose-$i'),
                card: i,
                scale: 1.25,
                onTap: () => taps++),
        ];
        final houses = <Widget>[
          for (var i = 0; i < counts.$2; i++)
            HouseStack(
                key: ValueKey('house-$i'),
                house: House(10, [
                  [9]
                ], [
                  0
                ]),
                highlighted: false,
                onTap: () => taps++),
        ];
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: FittedTable(
                key: const Key('board'),
                looseCount: counts.$1,
                houseCount: counts.$2,
                cardWidth: 90,
                cardHeight: 127.5,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Wrap(spacing: 9, runSpacing: 10, children: items),
                  if (houses.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child:
                            Wrap(spacing: 10, runSpacing: 8, children: houses)),
                ])),
          ),
        ))));
        final board = tester.getRect(find.byKey(const Key('board')));
        for (final item in [...items, ...houses]) {
          final finder = find.byKey(item.key!);
          final rect = tester.getRect(finder);
          expect(board.inflate(.01).contains(rect.topLeft), isTrue);
          expect(board.inflate(.01).contains(rect.bottomRight), isTrue);
          await tester.tap(finder);
        }
        expect(taps, items.length + houses.length);
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
