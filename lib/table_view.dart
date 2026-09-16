part of 'main.dart';

String _moveLabel(Move move) => switch (move.kind) {
      MoveKind.capture => 'Capture',
      MoveKind.build => 'Build ${move.value}',
      MoveKind.raise => 'Raise to ${move.value}',
      MoveKind.discard => 'Discard',
    };

extension _TableView on _SweepScreenState {
  Widget _gathered(bool affected, Widget child) => _moving == null || !affected
      ? child
      : FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0)
              .chain(CurveTween(curve: const Interval(.6, .72)))
              .animate(_motion),
          child: child);
  void _chooseCard(int card, List<Move> moves) {
    if (moves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Keep this card for your house, or choose a card that follows the opening call.')));
      return;
    }
    _update(() {
      _selectedCard = _selectedCard == card ? null : card;
      _preview = _selectedCard == null ? null : moves.first;
    });
  }

  void _target(bool Function(Move) matches) {
    if (!_canPlay || _selectedCard == null) return;
    final options = _game!.position
        .legalMoves()
        .where((m) => m.card == _selectedCard && matches(m))
        .toList();
    if (options.isEmpty) return;
    final current = options.indexWhere((m) => m.key == _preview?.key);
    _update(() => _preview = options[(current + 1) % options.length]);
  }

  Widget _scores({bool stacked = false}) {
    final g = _game!;
    final panels = <Widget>[
      for (var team = 0; team < 2; team++)
        Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(8)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(team == 0 ? 'You & Ari' : 'Mira & Dev',
                        style: TextStyle(
                            color: team == 0 ? gold : cream, fontSize: 12))),
                Text('Game ${g.totals[team]}',
                    key: Key('score-game-total-$team'),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
              const SizedBox(height: 6),
              const Text('THIS DEAL',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 9, letterSpacing: 1)),
              const SizedBox(height: 3),
              Wrap(spacing: 12, runSpacing: 3, children: [
                Text('${g.score(team).cardPoints} card pts',
                    key: Key('score-card-points-$team'),
                    style: const TextStyle(
                        color: cream,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                Text('${g.sweeps[team].length} sweeps',
                    key: Key('score-sweeps-$team'),
                    style: const TextStyle(color: gold, fontSize: 12)),
              ]),
              const SizedBox(height: 3),
              Tooltip(
                  message:
                      'Sweep bonuses count at the end of the deal only if your team collects at least 20 card points.',
                  child: Text(
                      '+${g.score(team).earnedSweepPoints} sweep pts${g.score(team).cardPoints < 20 ? ' (need 20 card pts)' : ' (pending)'}',
                      key: Key('score-sweep-points-$team'),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10))),
            ])),
    ];
    return stacked
        ? Column(children: panels)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final panel in panels) Expanded(child: panel)]);
  }

  Widget _table() => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 480;
        final tight = constraints.maxHeight < 650;
        final wide = constraints.maxWidth > 650;
        final g = _game!;
        final human = _canPlay;
        final legal = human ? g.position.legalMoves() : <Move>[];
        final options = legal.where((m) => m.card == _selectedCard).toList();
        final current = _moving ?? _preview;
        final selected = current?.selectedLoose ?? <int>{};
        final selectedHouses = {
          ...?current?.houseIndexes,
          if (current?.raisedIndex != null) current!.raisedIndex!
        };
        final available = options.expand((m) => m.selectedLoose).toSet();
        final availableHouses = {
          for (final m in options) ...[
            ...m.houseIndexes,
            if (m.raisedIndex != null) m.raisedIndex!
          ]
        };
        final hand = g.hands[0].toList()
          ..sort((a, b) {
            final rank = rankOf(a).compareTo(rankOf(b));
            return rank == 0 ? a.compareTo(b) : rank;
          });
        Widget seat(int s) => PlayerSeat(
            seat: s,
            count: g.hands[s].length,
            active: g.turn == s,
            dealer: g.dealer == s,
            compact: tight);
        final side = wide ? 90.0 : 58.0;
        final top = tight ? 74.0 : 124.0;
        final bottom = tight ? 55.0 : 69.0;
        final status = _paused
            ? 'Paused — take your time'
            : _moving != null
                ? '${seatNames[g.turn]} · ${_moveLabel(_moving!)}'
                : g.phase == Phase.opening && g.turn != 0
                    ? '${seatNames[g.turn]} called ${g.calledValue} · ${widget.openingDelay.inSeconds}s to study the table'
                    : (human && g.phase != Phase.call && _lastAction != null)
                        ? 'Your turn · $_lastAction'
                        : _lastAction ??
                            (g.phase == Phase.call
                                ? (g.turn == 0
                                    ? 'Choose your opening call'
                                    : '${seatNames[g.turn]} is choosing a call')
                                : human
                                    ? (g.phase == Phase.opening
                                        ? 'Opening call: ${g.calledValue} · Choose a card'
                                        : 'Your turn · Choose a card')
                                    : '${seatNames[g.turn]} is thinking…');
        final sections = <Widget>[
          if (!compact || !wide)
            Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: _scores())),
          Expanded(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: FeltSurface(
                          child: Stack(children: [
                        Positioned(
                            top: compact ? 2 : 10,
                            left: 0,
                            right: 0,
                            child: Center(child: seat(2))),
                        Positioned(
                            left: wide ? 14 : 2,
                            top: 0,
                            bottom: 0,
                            width: side - 5,
                            child: Center(child: seat(3))),
                        Positioned(
                            right: wide ? 14 : 2,
                            top: 0,
                            bottom: 0,
                            width: side - 5,
                            child: Center(child: seat(1))),
                        Positioned(
                            bottom: 5,
                            left: 0,
                            right: 0,
                            child: Center(child: seat(0))),
                        Positioned(
                            top: top,
                            bottom: bottom,
                            left: side,
                            right: side,
                            child: LayoutBuilder(
                                builder: (context, area) =>
                                    SingleChildScrollView(
                                        key: const Key('table-cards'),
                                        padding: const EdgeInsets.all(6),
                                        child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                                minHeight: (area.maxHeight - 12)
                                                    .clamp(0, double.infinity)),
                                            child: Center(
                                                child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                  if (g.phase == Phase.call)
                                                    Wrap(
                                                        alignment: WrapAlignment
                                                            .center,
                                                        spacing: 7,
                                                        runSpacing: 7,
                                                        children: List.generate(
                                                            4,
                                                            (i) => CardBack(
                                                                key: Key(
                                                                    'hidden-$i'))))
                                                  else ...[
                                                    if (g.loose.isEmpty &&
                                                        g.houses.isEmpty)
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(12),
                                                          child:
                                                              Column(children: [
                                                            Icon(
                                                                Icons
                                                                    .auto_awesome,
                                                                size: 30,
                                                                color: gold
                                                                    .withValues(
                                                                        alpha:
                                                                            .45)),
                                                            const SizedBox(
                                                                height: 8),
                                                            const Text(
                                                                'A clear table',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white38,
                                                                    fontFamily:
                                                                        'Georgia'))
                                                          ])),
                                                    Wrap(
                                                        alignment: WrapAlignment
                                                            .center,
                                                        spacing: 9,
                                                        runSpacing: 10,
                                                        children: [
                                                          for (final c
                                                              in g.loose)
                                                            AnimatedOpacity(
                                                                duration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            180),
                                                                opacity: _selectedCard !=
                                                                            null &&
                                                                        !available
                                                                            .contains(
                                                                                c)
                                                                    ? .4
                                                                    : 1,
                                                                child: _gathered(
                                                                    selected
                                                                        .contains(
                                                                            c),
                                                                    CardFace(
                                                                        key: Key(
                                                                            'table-$c'),
                                                                        card: c,
                                                                        large: wide &&
                                                                            !compact,
                                                                        highlighted:
                                                                            selected.contains(
                                                                                c),
                                                                        onTap: human && available.contains(c)
                                                                            ? () =>
                                                                                _target((m) => m.selectedLoose.contains(c))
                                                                            : null))),
                                                        ]),
                                                    if (g.houses.isNotEmpty)
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 10),
                                                          child: Wrap(
                                                              alignment:
                                                                  WrapAlignment
                                                                      .center,
                                                              spacing: 10,
                                                              runSpacing: 8,
                                                              children: [
                                                                for (var i = 0;
                                                                    i <
                                                                        g.houses
                                                                            .length;
                                                                    i++)
                                                                  _gathered(
                                                                      selectedHouses
                                                                          .contains(
                                                                              i),
                                                                      HouseStack(
                                                                          key: Key(
                                                                              'house-$i'),
                                                                          house: g.houses[
                                                                              i],
                                                                          highlighted: selectedHouses.contains(
                                                                              i),
                                                                          onTap: human && availableHouses.contains(i)
                                                                              ? () => _target((m) => m.houseIndexes.contains(i) || m.raisedIndex == i)
                                                                              : () => _inspectHouse(g.houses[i]))),
                                                              ])),
                                                  ],
                                                ])))))),
                        if (_moving != null)
                          Positioned.fill(
                              child: IgnorePointer(child: _flight(g))),
                        if (_paused)
                          Positioned.fill(
                              child: IgnorePointer(
                                  child: ColoredBox(
                                      color: Colors.black26,
                                      child: Center(
                                          child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                  color: ink,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24)),
                                              child: const Icon(Icons.pause,
                                                  color: gold, size: 32)))))),
                      ]))))),
          SizedBox(
              height: compact ? 24 : 34,
              child: Center(
                  child: Text(status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _paused ? Colors.white60 : gold,
                          fontSize: 12)))),
          if (g.phase == Phase.call && human)
            SizedBox(
                height: 48,
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final value in g.position.calls)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FilledButton(
                                    key: Key('call-$value'),
                                    onPressed: () => _act(() {
                                          g.call(value);
                                          _lastAction = null;
                                        }),
                                    child: Text('Call $value'))),
                        ]))),
          if (_selectedCard != null && _moving == null)
            _moveTray(options, tight),
          _hand(hand, legal, tight),
        ];
        return ColoredBox(
            color: const Color(0xFF161F1A),
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    wide ? 16 : 6, compact ? 0 : 8, wide ? 16 : 6, 0),
                child: compact && wide
                    ? Row(children: [
                        sections.first,
                        const SizedBox(width: 8),
                        SizedBox(
                            width: 260,
                            child: SingleChildScrollView(
                                child: Column(children: [
                              _scores(),
                              ...sections.skip(1)
                            ])))
                      ])
                    : Column(children: sections)));
      });

  Widget _flight(SweepGame game) {
    final move = _moving!;
    final affected = game.position.affectedCards(move);
    final capture = move.kind == MoveKind.capture;
    final sweep = capture &&
        move.selectedLoose.length == game.loose.length &&
        move.houseIndexes.length == game.houses.length;
    final origin = switch (game.turn) {
      0 => const Offset(.5, .92),
      1 => const Offset(.94, .5),
      2 => const Offset(.5, .08),
      _ => const Offset(.06, .5),
    };
    return AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => LayoutBuilder(builder: (context, box) {
              final t = _motion.value;
              final travel =
                  t < .32 ? Curves.easeOutCubic.transform(t / .32) : 1.0;
              final gather =
                  t <= .65 ? 0.0 : Curves.easeInOut.transform((t - .65) / .35);
              const center = Offset(.5, .5);
              final position = t < .65
                  ? Offset.lerp(origin, center, travel)!
                  : Offset.lerp(center,
                      capture ? origin : const Offset(.5, .42), gather)!;
              return Stack(children: [
                Positioned(
                    left: position.dx * (box.maxWidth - 72),
                    top: position.dy * (box.maxHeight - 102),
                    child: Transform.scale(
                        scale: 1 - gather * .25,
                        child: Stack(clipBehavior: Clip.none, children: [
                          if (t > .6)
                            for (var i = 0;
                                i < affected.length.clamp(0, 3);
                                i++)
                              Positioned(
                                  left: -(3 - i) * 12,
                                  top: -(3 - i) * 4,
                                  child:
                                      CardFace(card: affected[i], large: true)),
                          CardFace(
                              card: move.card, large: true, highlighted: true),
                          if (!capture &&
                              move.kind != MoveKind.discard &&
                              t > .65)
                            Positioned(
                                right: -10,
                                top: -10,
                                child: CircleAvatar(
                                    radius: 17,
                                    backgroundColor: gold,
                                    child: Text('${move.value}',
                                        style: const TextStyle(
                                            color: ink,
                                            fontWeight: FontWeight.bold)))),
                        ]))),
                if (sweep && t > .6)
                  Align(
                      alignment: const Alignment(0, -.4),
                      child: Transform.scale(
                          scale: .8 + gather * .2,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                  color: ink,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: gold),
                                  boxShadow: [
                                    BoxShadow(
                                        color: gold.withValues(alpha: .4),
                                        blurRadius: 28)
                                  ]),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, color: gold),
                                    SizedBox(width: 8),
                                    Text('SWEEP',
                                        style: TextStyle(
                                            color: gold,
                                            fontFamily: 'Georgia',
                                            letterSpacing: 3,
                                            fontSize: 20))
                                  ])))),
              ]);
            }));
  }

  Widget _hand(List<int> hand, List<Move> legal, bool tight) => SizedBox(
      key: const Key('hand'),
      height: tight ? 96 : 128,
      child: hand.isEmpty
          ? const Center(
              child: Text('Waiting for the deal',
                  style: TextStyle(color: Colors.white54, fontSize: 12)))
          : LayoutBuilder(builder: (context, area) {
              final cardWidth = tight ? 54.0 : 72.0;
              final width =
                  math.min(area.maxWidth - 24, hand.length * (cardWidth + 8));
              final step = hand.length == 1
                  ? 0.0
                  : (width - cardWidth) / (hand.length - 1);
              return Center(
                  child: SizedBox(
                      width: width,
                      child: Stack(clipBehavior: Clip.none, children: [
                        for (final card in hand)
                          Positioned(
                              left: hand.indexOf(card) * step,
                              top: _selectedCard == card
                                  ? 0
                                  : 10 +
                                      (hand.indexOf(card) -
                                              (hand.length - 1) / 2)
                                          .abs(),
                              child: Transform.rotate(
                                  angle: (hand.indexOf(card) -
                                          (hand.length - 1) / 2) *
                                      .009,
                                  child: CardFace(
                                      key: Key('hand-$card'),
                                      card: card,
                                      large: !tight,
                                      highlighted: _selectedCard == card,
                                      onTap: _canPlay &&
                                              _game!.phase != Phase.call
                                          ? () => _chooseCard(
                                              card,
                                              legal
                                                  .where((m) => m.card == card)
                                                  .toList())
                                          : null))),
                      ])));
            }));

  Widget _moveTray(List<Move> options, bool compact) {
    final g = _game!;
    final move = _preview!;
    return Container(
        key: const Key('move-tray'),
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
        decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold.withValues(alpha: .25))),
        child: Row(children: [
          IconButton(
              tooltip: 'Cancel selection',
              onPressed: () => _update(() {
                    _selectedCard = null;
                    _preview = null;
                  }),
              icon: const Icon(Icons.close, size: 18)),
          Expanded(
              child: SizedBox(
                  height: compact ? 46 : 79,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: options.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 5),
                      itemBuilder: (context, index) {
                        final m = options[index];
                        final cards = g.position.affectedCards(m);
                        return InkWell(
                            key: Key('move-$index'),
                            onTap: () => _update(() => _preview = m),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: move.key == m.key
                                        ? gold.withValues(alpha: .16)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: move.key == m.key
                                            ? gold
                                            : Colors.white12)),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_moveLabel(m),
                                          style: const TextStyle(
                                              color: cream, fontSize: 11)),
                                      if (!compact)
                                        SizedBox(
                                            height: 48,
                                            width:
                                                (cards.length.clamp(1, 6) * 15 +
                                                        22)
                                                    .toDouble(),
                                            child: Stack(children: [
                                              for (var i = 0;
                                                  i < cards.length.clamp(0, 6);
                                                  i++)
                                                Positioned(
                                                    left: i * 15,
                                                    top: 3,
                                                    child: Transform.scale(
                                                        scale: .55,
                                                        alignment:
                                                            Alignment.topLeft,
                                                        child: IgnorePointer(
                                                            child: CardFace(
                                                                card: cards[
                                                                    i])))),
                                              if (cards.isEmpty)
                                                const Center(
                                                    child: Icon(Icons.add,
                                                        size: 20, color: gold)),
                                            ])),
                                    ])));
                      }))),
          const SizedBox(width: 6),
          FilledButton(
              key: const Key('confirm-move'),
              onPressed: _canPlay ? () => _play(move) : null,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(_moveLabel(move))),
        ]));
  }

  Future<void> _inspectHouse(House house) => _overlay(() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Row(children: [
                if (house.pakka)
                  const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.lock, color: gold)),
                Text('House of ${house.value}')
              ]),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    for (final group in house.groups)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Wrap(spacing: 5, runSpacing: 5, children: [
                            for (final c in group) CardFace(card: c)
                          ])),
                    Text(house.owners.map((s) => seatNames[s]).join(' & '),
                        style: const TextStyle(color: gold)),
                    const SizedBox(height: 8),
                    Text(house.pakka
                        ? 'Locked value. Capture with a matching card.'
                        : 'Capture with a matching card, or raise its value.'),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ])));
}
