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
        ? const Color(0xFFB33035)
        : const Color(0xFF172C2B);
    Widget symbol(double size) => SizedBox.square(
        dimension: size, child: CustomPaint(painter: SuitPainter(suit, color)));
    Widget corner() => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(rankName(rank),
              style: TextStyle(
                  color: color,
                  fontFamily: 'Georgia',
                  fontSize: large ? 19 : 15,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          const SizedBox(height: 2),
          symbol(large ? 12 : 9),
        ]);
    final pips = <Offset>[];
    if (rank <= 10) {
      if (rank == 1) {
        pips.add(const Offset(.5, .5));
      } else if (rank <= 3) {
        pips.addAll([const Offset(.5, .16), const Offset(.5, .84)]);
        if (rank == 3) pips.add(const Offset(.5, .5));
      } else {
        final rows = rank >= 8
            ? 4
            : rank >= 6
                ? 3
                : 2;
        for (var i = 0; i < rows; i++) {
          final y = .14 + i * .72 / (rows - 1);
          pips.addAll([Offset(.24, y), Offset(.76, y)]);
        }
        if (rank.isOdd) pips.add(const Offset(.5, .5));
        if (rank == 10) {
          pips.addAll([const Offset(.5, .32), const Offset(.5, .68)]);
        }
      }
    }
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
                              color:
                                  highlighted ? gold : const Color(0xFFD5CFC0),
                              width: highlighted ? 3 : 1),
                          boxShadow: [
                            BoxShadow(
                                color: highlighted
                                    ? gold.withValues(alpha: .35)
                                    : Colors.black38,
                                blurRadius: highlighted ? 12 : 4,
                                offset: const Offset(0, 3))
                          ]),
                      child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Stack(children: [
                            Positioned(top: 0, left: 0, child: corner()),
                            Positioned(
                                bottom: 0,
                                right: 0,
                                child: RotatedBox(
                                    quarterTurns: 2, child: corner())),
                            Positioned.fill(
                                left: large ? 16 : 12,
                                right: large ? 16 : 12,
                                top: 15,
                                bottom: 15,
                                child: rank <= 10
                                    ? LayoutBuilder(
                                        builder: (context, c) =>
                                            Stack(children: [
                                              for (final pip in pips)
                                                Positioned(
                                                    left: pip.dx * c.maxWidth -
                                                        (rank == 1 ? 11 : 5),
                                                    top: pip.dy * c.maxHeight -
                                                        (rank == 1 ? 13 : 6),
                                                    child: Transform.rotate(
                                                        angle: pip.dy > .5
                                                            ? math.pi
                                                            : 0,
                                                        child: symbol(rank == 1
                                                            ? 23
                                                            : 11))),
                                            ]))
                                    : DecoratedBox(
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: color.withValues(
                                                    alpha: .25)),
                                            color: gold.withValues(alpha: .15)),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.workspace_premium,
                                                  color: color,
                                                  size: large ? 24 : 16),
                                              symbol(large ? 20 : 12)
                                            ]))),
                          ])),
                    )))));
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
  Widget build(BuildContext context) => Semantics(
      label:
          '${seatNames[seat]}, ${seat == 2 ? 'partner' : seat == 0 ? 'you' : 'opponent'}, $count cards${active ? ', active player' : ''}',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        active ? gold : seatColors[seat].withValues(alpha: .45),
                    width: 2),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: gold.withValues(alpha: .3), blurRadius: 16)
                      ]
                    : []),
            child: CircleAvatar(
                radius: compact ? 15 : 21,
                backgroundColor: seatColors[seat].withValues(alpha: .18),
                child: Text(seatNames[seat][0],
                    style: TextStyle(
                        color: seatColors[seat],
                        fontFamily: 'Georgia',
                        fontSize: compact ? 17 : 23)))),
        const SizedBox(height: 3),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(seatNames[seat],
                  style: TextStyle(
                      color: active ? gold : cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              if (dealer)
                Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(
                        color: cream, shape: BoxShape.circle),
                    child: const Text('D',
                        style: TextStyle(color: ink, fontSize: 9)))
            ])),
        if (!compact && seat == 2)
          const Text('PARTNER',
              style: TextStyle(
                  color: Colors.white54, fontSize: 8, letterSpacing: 1.5)),
        if (seat != 0 && count > 0)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: SizedBox(
                  width: 52,
                  height: compact ? 15 : 23,
                  child: Stack(children: [
                    for (var i = 0; i < math.min(count, 5); i++)
                      Positioned(
                          left: i * 7,
                          child:
                              CardBack(width: 19, height: compact ? 15 : 23)),
                    Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            color: ink,
                            child: Text('$count',
                                style: const TextStyle(
                                    fontSize: 9, color: cream))))
                  ]))),
      ]));
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
              width: 106,
              height: 108,
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
                      left: 5 + i * 15,
                      top: 8 + i * 3,
                      child:
                          IgnorePointer(child: CardFace(card: house.cards[i]))),
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
          borderRadius: BorderRadius.circular(70),
          gradient: const LinearGradient(
              colors: [Color(0xFF92633F), Color(0xFF372017), Color(0xFF785135)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))
          ]),
      padding: const EdgeInsets.all(9),
      child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(61),
              border: Border.all(color: gold.withValues(alpha: .45)),
              gradient: const RadialGradient(
                  colors: [Color(0xFF286350), Color(0xFF123D32)], radius: .9)),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
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
