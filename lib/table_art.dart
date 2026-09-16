import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game/engine.dart';

const gold = Color(0xFFE8C889);
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
        path.moveTo(50, 3);
        path.cubicTo(30, 30, -10, 58, 18, 76);
        path.cubicTo(30, 84, 43, 72, 50, 65);
        path.cubicTo(57, 72, 70, 84, 82, 76);
        path.cubicTo(110, 58, 70, 30, 50, 3);
        path.close();
        path.moveTo(50, 55);
        path.quadraticBezierTo(48, 85, 32, 97);
        path.lineTo(68, 97);
        path.quadraticBezierTo(52, 85, 50, 55);
      default:
        canvas.drawCircle(const Offset(50, 26), 23, p);
        canvas.drawCircle(const Offset(27, 58), 23, p);
        canvas.drawCircle(const Offset(73, 58), 23, p);
        path.moveTo(50, 45);
        path.quadraticBezierTo(48, 84, 30, 97);
        path.lineTo(70, 97);
        path.quadraticBezierTo(52, 84, 50, 45);
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
      label: '${cardName(card)}, ${cardOf(card).points} card points',
      button: onTap != null,
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
                  width: highlighted ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: highlighted
                        ? gold.withValues(alpha: .4)
                        : Colors.black38,
                    blurRadius: highlighted ? 12 : 4,
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
                          symbol(large ? 14 : 11),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      left: large ? 19 : 15,
                      top: large ? 24 : 19,
                      child: Center(
                        child: rank <= 10
                            ? symbol(large ? 36 : 26)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium,
                                      color: const Color(0xFF94702E),
                                      size: large ? 19 : 13),
                                  symbol(large ? 25 : 18),
                                  Text(
                                    '$rank',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: large ? 14 : 11,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
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
    final description =
        '${seatNames[seat]}${seat == 2 ? ', partner' : ', opponent'}, $count cards${dealer ? ', dealer' : ''}${active ? ', active player' : ''}';
    return Semantics(
        label: description,
        child: Tooltip(
            message: description,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: seat == 2 ? 88 : 44,
                height: seat == 2 ? 30 : 64,
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
                child: Text(seatNames[seat],
                    style: TextStyle(
                        fontSize: 12,
                        color: active ? ink : cream,
                        fontWeight: FontWeight.w600)))));
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
          '${house.pakka ? 'Pakka' : 'House'} ${house.value}, ${house.owners.map((s) => seatNames[s]).join(', ')}',
      button: true,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
              width: 134,
              height: 139,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: highlighted ? gold : Colors.transparent, width: 2),
                  color: highlighted
                      ? gold.withValues(alpha: .1)
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
                                child: Text(seatNames[owner][0],
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
