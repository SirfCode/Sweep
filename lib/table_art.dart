import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game/engine.dart';
import 'l10n/strings.dart';

const gold = Color(0xFFF0D294);
const ink = Color(0xFF102D27);
const felt = Color(0xFF194C40);
const cream = Color(0xFFF7F0DE);
const seatColors = [
  gold,
  Color(0xFFE6A18B),
  Color(0xFF9CD5C0),
  Color(0xFFAEBDE9)
];

/// Drawn suits keep cards crisp and avoid platform-dependent emoji glyphs.
class SuitPainter extends CustomPainter {
  final int suit;
  final Color color;
  const SuitPainter(this.suit, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final p = Paint()..color = color;
    final path = Path();
    switch (suit) {
      case 1:
        path.moveTo(50, 3);
        path.lineTo(90, 50);
        path.lineTo(50, 97);
        path.lineTo(10, 50);
        path.close();
      case 2:
        path.moveTo(50, 93);
        path.cubicTo(-20, 45, 8, -15, 50, 25);
        path.cubicTo(92, -15, 120, 45, 50, 93);
        path.close();
      case 3:
        // A narrow spear silhouette contrasts with the club's round lobes.
        path.moveTo(50, 1);
        path.cubicTo(43, 23, 15, 44, 15, 60);
        path.cubicTo(15, 78, 38, 81, 50, 65);
        path.cubicTo(62, 81, 85, 78, 85, 60);
        path.cubicTo(85, 44, 57, 23, 50, 1);
        path.close();
        path.moveTo(46, 64);
        path.quadraticBezierTo(46, 86, 38, 98);
        path.lineTo(62, 98);
        path.quadraticBezierTo(54, 86, 54, 64);
        path.close();
      default:
        // Deep open notches preserve three distinct circles at corner size.
        canvas.drawCircle(const Offset(50, 23), 20, p);
        canvas.drawCircle(const Offset(23, 58), 21, p);
        canvas.drawCircle(const Offset(77, 58), 21, p);
        canvas.drawCircle(const Offset(50, 53), 12, p);
        path.moveTo(44, 57);
        path.quadraticBezierTo(44, 83, 29, 94);
        path.lineTo(71, 94);
        path.quadraticBezierTo(56, 83, 56, 57);
        path.close();
    }
    canvas.drawPath(path, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

class CardFace extends StatelessWidget {
  final int card;
  final bool large, highlighted;
  final VoidCallback? onTap;
  const CardFace(
      {super.key,
      required this.card,
      this.large = false,
      this.highlighted = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final suit = card ~/ 13;
    final rank = rankOf(card);
    final color = suit == 1 || suit == 2
        ? const Color(0xFFAD2035)
        : const Color(0xFF18221F);
    Widget symbol(double size) => SizedBox.square(
        dimension: size, child: CustomPaint(painter: SuitPainter(suit, color)));
    return Semantics(
      label: tr(context, 'card_points_2',
          {'p0': cardName(card), 'p1': cardOf(card).points}),
      button: onTap != null,
      selected: highlighted,
      child: Tooltip(
        message: cardName(card),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: large ? 72 : 54,
              height: large ? 102 : 78,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF3),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: highlighted ? gold : const Color(0xFF77796D),
                  width: highlighted ? 4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: highlighted
                        ? gold.withValues(alpha: .65)
                        : Colors.black38,
                    blurRadius: highlighted ? 16 : 4,
                    spreadRadius: highlighted ? 2 : 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rankName(rank),
                            style: TextStyle(
                              color: color,
                              fontFamily: 'Georgia',
                              fontSize: large ? 23 : 18,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          symbol(large ? 16 : 12),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      left: large ? 19 : 15,
                      top: large ? 24 : 19,
                      child: Center(
                        child: rank > 1 && rank <= 10
                            ? symbol(large ? 36 : 26)
                            : SizedBox(
                                width: large ? 39 : 28,
                                height: large ? 64 : 46,
                                child: CustomPaint(
                                    painter: RoyalPainter(rank, suit, color)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact vector engravings remain sharp when table cards are enlarged.
class RoyalPainter extends CustomPainter {
  final int rank, suit;
  final Color color;
  const RoyalPainter(this.rank, this.suit, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 60, size.height / 96);
    final gilt = Paint()..color = const Color(0xFF94702E);
    final dark = Paint()..color = color;
    final paper = Paint()..color = cream;
    final line = Paint()
      ..color = const Color(0xFF94702E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    void shape(List<Offset> points, Paint paint) {
      canvas.drawPath(Path()..addPolygon(points, true), paint);
    }

    void suitAt(double x, double y, double extent) {
      canvas.save();
      canvas.translate(x, y);
      SuitPainter(suit, color).paint(canvas, Size.square(extent));
      canvas.restore();
    }

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 2, 56, 92), const Radius.circular(24)),
        line);
    if (rank == 1) {
      for (final side in [-1, 1]) {
        for (var i = 0; i < 6; i++) {
          final y = 28.0 + i * 8;
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(30.0 + side * (21 - (i - 3).abs()), y),
                  width: 5,
                  height: 9),
              gilt);
        }
      }
      suitAt(12, 27, 36);
      shape(
          const [Offset(30, 8), Offset(34, 14), Offset(30, 20), Offset(26, 14)],
          gilt);
      canvas.drawLine(const Offset(22, 79), const Offset(38, 79), line);
      canvas.drawCircle(const Offset(30, 85), 2, gilt);
    } else {
      // Mantle, contrasting lapels and engraved gold seams.
      shape(const [
        Offset(7, 78),
        Offset(13, 58),
        Offset(25, 52),
        Offset(36, 52),
        Offset(49, 61),
        Offset(54, 78)
      ], dark);
      shape(const [
        Offset(17, 58),
        Offset(30, 77),
        Offset(42, 58),
        Offset(34, 55),
        Offset(27, 55)
      ], gilt);
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(
            Offset(12.0 + i * 3, 65), Offset(10.0 + i * 3, 76), line);
        canvas.drawLine(
            Offset(42.0 + i * 3, 65), Offset(44.0 + i * 3, 76), line);
      }
      canvas.drawOval(const Rect.fromLTWH(15, 22, 31, 39), dark);
      canvas.drawOval(const Rect.fromLTWH(22, 26, 20, 29), paper);
      canvas.drawLine(const Offset(25, 36), const Offset(30, 36), line);
      canvas.drawLine(const Offset(35, 36), const Offset(39, 36), line);
      canvas.drawPath(
          Path()
            ..moveTo(33, 37)
            ..lineTo(31, 43)
            ..lineTo(35, 43),
          line);
      canvas.drawLine(const Offset(29, 48), const Offset(36, 48), line);
      if (rank == 13) {
        shape(const [
          Offset(22, 45),
          Offset(30, 50),
          Offset(41, 44),
          Offset(38, 57),
          Offset(31, 64),
          Offset(24, 57)
        ], dark);
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
              Offset(27.0 + i * 4, 52), Offset(30.0 + i * 2, 59), line);
        }
      }
      if (rank == 11) {
        canvas.drawOval(const Rect.fromLTWH(12, 19, 35, 10), dark);
        shape(const [
          Offset(18, 24),
          Offset(20, 14),
          Offset(35, 12),
          Offset(42, 24)
        ], dark);
        canvas.drawOval(const Rect.fromLTWH(39, 3, 7, 20), gilt);
        canvas.drawLine(const Offset(40, 23), const Offset(44, 5), line);
      } else {
        shape(const [
          Offset(19, 26),
          Offset(16, 12),
          Offset(25, 18),
          Offset(31, 7),
          Offset(37, 18),
          Offset(46, 12),
          Offset(42, 26)
        ], gilt);
        canvas.drawCircle(const Offset(31, 20), 2.5, dark);
        if (rank == 12) {
          canvas.drawCircle(const Offset(20, 44), 2.5, gilt);
          canvas.drawCircle(const Offset(43, 44), 2.5, gilt);
        }
      }
      suitAt(5, 80, 11);
      final label = TextPainter(
          text: TextSpan(
              text: '$rank',
              style: TextStyle(
                  color: color,
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr)
        ..layout();
      label.paint(canvas, Offset(32 - label.width / 2, 79));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RoyalPainter oldDelegate) =>
      oldDelegate.rank != rank ||
      oldDelegate.suit != suit ||
      oldDelegate.color != color;
}

class CardBack extends StatelessWidget {
  final double width, height;
  const CardBack({super.key, this.width = 54, this.height = 78});
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 3, offset: Offset(0, 2))
          ]),
      child: CustomPaint(
          painter: const BackPainter(),
          child: const Center(
              child: Icon(Icons.diamond_outlined, color: gold, size: 15))));
}

class BackPainter extends CustomPainter {
  const BackPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF762F32));
    final p = Paint()
      ..color = gold.withValues(alpha: .22)
      ..strokeWidth = .7;
    for (double x = -size.height; x < size.width + size.height; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), p);
    }
    canvas.drawRect(
        const Offset(2, 2) &
            Size(math.max(0, size.width - 4), math.max(0, size.height - 4)),
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6);
  }

  @override
  bool shouldRepaint(BackPainter oldDelegate) => false;
}

/// Keep every loose card and house visible, preserving their tap targets.
class FittedTable extends StatelessWidget {
  final int looseCount, houseCount;
  final double cardWidth, cardHeight;
  final Widget child;
  const FittedTable(
      {super.key,
      required this.looseCount,
      required this.houseCount,
      required this.cardWidth,
      required this.cardHeight,
      required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(builder: (context, bounds) {
          if (bounds.maxWidth <= 0 || bounds.maxHeight <= 0) {
            return const SizedBox.shrink();
          }
          double groupHeight(int count, double width, double height, double gap,
              double rowGap, double availableWidth) {
            if (count == 0) return 0;
            final columns =
                math.max(1, ((availableWidth + gap) / (width + gap)).floor());
            final rows = (count / columns).ceil();
            return rows * height + (rows - 1) * rowGap;
          }

          bool fits(double scale) {
            final width = bounds.maxWidth / scale;
            final height =
                groupHeight(looseCount, cardWidth, cardHeight, 9, 10, width) +
                    groupHeight(houseCount, 134, 139, 10, 8, width) +
                    (houseCount > 0 ? 10 : 0);
            return height * scale <= bounds.maxHeight &&
                (looseCount == 0 || cardWidth * scale <= bounds.maxWidth) &&
                (houseCount == 0 || 134 * scale <= bounds.maxWidth);
          }

          var low = 0.0;
          var high = 1.0;
          for (var i = 0; i < 32; i++) {
            final mid = (low + high) / 2;
            if (fits(mid)) {
              low = mid;
            } else {
              high = mid;
            }
          }
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: bounds.maxWidth / low, child: child),
          );
        }),
      );
}

class PlayerSeat extends StatelessWidget {
  final int seat, count;
  final bool active, dealer, compact;
  const PlayerSeat(
      {super.key,
      required this.seat,
      required this.count,
      required this.active,
      required this.dealer,
      this.compact = false});
  @override
  Widget build(BuildContext context) {
    final description = tr(context, 'cards', {
      'p0': playerName(context, seat),
      'p1': seat == 2 ? tr(context, 'partner') : tr(context, 'opponent'),
      'p2': count,
      'p3': dealer ? tr(context, 'dealer') : '',
      'p4': active ? tr(context, 'active_player') : ''
    });
    return Semantics(
        label: description,
        child: Tooltip(
            message: description,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: seat == 2 ? 88 : 32,
                height: seat == 2 ? 42 : 80,
                decoration: BoxDecoration(
                    color: active ? gold : ink,
                    border: Border.all(
                        color: active
                            ? gold
                            : seatColors[seat].withValues(alpha: .6)),
                    borderRadius: seat == 2
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(44))
                        : seat == 3
                            ? const BorderRadius.horizontal(
                                right: Radius.circular(40))
                            : const BorderRadius.horizontal(
                                left: Radius.circular(40)),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: gold.withValues(alpha: .35),
                                blurRadius: 12)
                          ]
                        : []),
                alignment: Alignment.center,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RotatedBox(
                        quarterTurns: seat == 2
                            ? 0
                            : seat == 3
                                ? 1
                                : 3,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(playerName(context, seat),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: active ? ink : cream,
                                  fontWeight: FontWeight.w600)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.style_outlined,
                                size: 10, color: active ? ink : cream),
                            const SizedBox(width: 2),
                            Text('$count',
                                key: Key('cards-left-$seat'),
                                style: TextStyle(
                                    fontSize: 10,
                                    height: 1,
                                    color: active ? ink : cream)),
                          ]),
                        ]))))));
  }
}

/// Size the whole card together, keeping the existing face artwork unchanged.
class TableCard extends StatelessWidget {
  final int card;
  final double scale;
  final bool highlighted;
  final VoidCallback? onTap;
  const TableCard(
      {super.key,
      required this.card,
      this.scale = 1.3,
      this.highlighted = false,
      this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 72 * scale,
      height: 102 * scale,
      child: FittedBox(
          child: CardFace(
              card: card,
              large: true,
              highlighted: highlighted,
              onTap: onTap)));
}

class HouseStack extends StatelessWidget {
  final House house;
  final bool highlighted;
  final VoidCallback onTap;
  const HouseStack(
      {super.key,
      required this.house,
      required this.highlighted,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      label:
          '${house.pakka ? tr(context, 'pakka') : tr(context, 'house')} ${house.value}, ${house.owners.map((s) => playerName(context, s)).join(', ')}',
      button: true,
      selected: highlighted,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
              width: 134,
              height: 139,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: highlighted ? gold : Colors.transparent, width: 4),
                  boxShadow: highlighted
                      ? [
                          BoxShadow(
                              color: gold.withValues(alpha: .35),
                              blurRadius: 14)
                        ]
                      : [],
                  color: highlighted
                      ? gold.withValues(alpha: .22)
                      : Colors.transparent),
              child: Stack(children: [
                for (var i = 0; i < math.min(3, house.cards.length); i++)
                  Positioned(
                      left: 5 + i * 19,
                      top: 8 + i * 3,
                      child: IgnorePointer(
                          child: CardFace(card: house.cards[i], large: true))),
                Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (house.pakka)
                            const Icon(Icons.lock, size: 12, color: ink),
                          Text('${house.value}',
                              style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19))
                        ]))),
                Positioned(
                    bottom: 0,
                    left: 10,
                    child: Row(children: [
                      for (final owner in house.owners)
                        Container(
                            margin: const EdgeInsets.only(right: 3),
                            width: 19,
                            height: 19,
                            decoration: BoxDecoration(
                                color: seatColors[owner],
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text(playerName(context, owner)[0],
                                    style: const TextStyle(
                                        color: ink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold))))
                    ])),
              ]))));
}

class FeltSurface extends StatelessWidget {
  final Widget child;
  const FeltSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [Color(0xFF92633F), Color(0xFF372017), Color(0xFF785135)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))
          ]),
      padding: const EdgeInsets.all(3),
      child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: gold.withValues(alpha: .45)),
              gradient: const RadialGradient(
                  colors: [Color(0xFF286350), Color(0xFF123D32)], radius: .9)),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: const FeltGrain(), child: child))));
}

class FeltGrain extends CustomPainter {
  const FeltGrain();
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(4);
    final p = Paint()..color = Colors.white.withValues(alpha: .035);
    for (var i = 0; i < 2400; i++) {
      canvas.drawCircle(
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height),
          .6,
          p);
    }
  }

  @override
  bool shouldRepaint(FeltGrain oldDelegate) => false;
}
