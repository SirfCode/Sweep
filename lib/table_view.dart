part of 'main.dart';

extension _TableView on _SweepScreenState {
  String _moveLabel(Move move) => switch (move.kind) {
        MoveKind.capture => textFor('capture'),
        MoveKind.build => textFor('build', {'p0': move.value}),
        MoveKind.raise => textFor('raise_to', {'p0': move.value}),
        MoveKind.discard => textFor('discard'),
      };

  Future<void> _showScores() => _overlay(() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(textFor('scores_deal', {'p0': _game!.dealNumber})),
              content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(child: _scores(stacked: true))),
              actions: [
                TextButton(
                    key: Key('close-scores'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(textFor('back_to_table')))
              ])));
  Widget _gathered(bool affected, Widget child) => _moving == null || !affected
      ? child
      : FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0)
              .chain(CurveTween(curve: Interval(.6, .72)))
              .animate(_motion),
          child: child);
  void _chooseCard(int card, List<Move> moves) {
    if (moves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(textFor('keep_this_card_for_your_house_or'))));
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
                    child: Text(
                        team == 0 ? textFor('you_ari') : textFor('mira_dev'),
                        style: TextStyle(
                            color: team == 0 ? gold : cream, fontSize: 16))),
                Text(textFor('game', {'p0': g.totals[team]}),
                    key: Key('score-game-total-$team'),
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              SizedBox(height: 6),
              Text(textFor('this_deal'),
                  style: TextStyle(
                      color: Colors.white54, fontSize: 11, letterSpacing: 1)),
              SizedBox(height: 3),
              Wrap(spacing: 12, runSpacing: 3, children: [
                Text(textFor('card_pts', {'p0': g.score(team).cardPoints}),
                    key: Key('score-card-points-$team'),
                    style: TextStyle(
                        color: cream,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text(textFor('seeps', {'p0': g.sweeps[team].length}),
                    key: Key('score-sweeps-$team'),
                    style: TextStyle(color: gold, fontSize: 16)),
              ]),
              SizedBox(height: 3),
              Tooltip(
                  message: textFor('seep_bonuses_count_at_the_end_of'),
                  child: Text(
                      textFor('seep_pts', {
                        'p0': g.score(team).earnedSweepPoints,
                        'p1': g.score(team).cardPoints < 20
                            ? textFor('need_card_pts')
                            : textFor('pending')
                      }),
                      key: Key('score-sweep-points-$team'),
                      style: TextStyle(color: Colors.white60, fontSize: 14))),
            ])),
    ];
    return stacked
        ? Column(children: panels)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final panel in panels) Expanded(child: panel)]);
  }

  Widget _liveDealScore(int team) {
    final g = _game!;
    return GestureDetector(
      onTap: _showScores,
      child: Container(
        key: Key('live-deal-score-$team'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Tooltip(
          message: textFor('card_points_seeps_tap_for_scores', {
            'p0': team == 0 ? textFor('your_team') : textFor('opposition'),
            'p1': g.score(team).cardPoints,
            'p2': g.sweeps[team].length
          }),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.style_outlined, color: cream, size: 19),
            SizedBox(width: 5),
            Text('${g.score(team).cardPoints}',
                key: Key('live-points-$team'),
                style: TextStyle(
                    color: cream, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(width: 12),
            Icon(Icons.cleaning_services, color: gold, size: 19),
            SizedBox(width: 5),
            Text('${g.sweeps[team].length}',
                key: Key('live-sweeps-$team'),
                style: TextStyle(
                    color: gold, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
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
        Widget seat(int s) => Tooltip(
            message: textFor('latest_capture', {'p0': playerName(context, s)}),
            child: InkWell(
                key: Key('last-capture-player-$s'),
                onTap: () => _showLastCapture(s),
                child: PlayerSeat(
                    seat: s,
                    count: g.hands[s].length,
                    active: g.turn == s,
                    dealer: g.dealer == s,
                    compact: tight)));
        final side = 46.0;
        final top = 60.0;
        final bottom = 30.0;
        final cardScale = compact
            ? 1.05
            : wide
                ? 1.5
                : 1.25;
        final status = _showingFinalMove
            ? textFor('deal_complete', {'p0': _lastAction})
            : _paused
                ? textFor('paused_take_your_time')
                : _moving != null
                    ? '${playerName(context, g.turn)} · ${_moveLabel(_moving!)}'
                    : g.phase == Phase.opening && g.turn != 0
                        ? textFor('called_s_to_study_the_table', {
                            'p0': playerName(context, g.turn),
                            'p1': g.calledValue,
                            'p2': widget.openingDelay.inSeconds
                          })
                        : (human &&
                                g.phase != Phase.call &&
                                _lastAction != null)
                            ? textFor('your_turn', {'p0': _lastAction})
                            : _lastAction ??
                                (g.phase == Phase.call
                                    ? (g.turn == 0
                                        ? textFor('choose_your_opening_call')
                                        : textFor('is_choosing_a_call', {
                                            'p0': playerName(context, g.turn)
                                          }))
                                    : human
                                        ? (g.phase == Phase.opening
                                            ? textFor(
                                                'opening_call_choose_a_card',
                                                {'p0': g.calledValue})
                                            : textFor(
                                                'your_turn_choose_a_card'))
                                        : textFor('is_thinking', {
                                            'p0': playerName(context, g.turn)
                                          }));
        final sections = <Widget>[
          Expanded(
              child: Center(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 1800),
                      child: FeltSurface(
                          child: Stack(children: [
                        Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Center(child: seat(2))),
                        Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 44,
                            child: Center(child: seat(3))),
                        Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 44,
                            child: Center(child: seat(1))),
                        if (g.calledValue != null)
                          Positioned(
                            top: 6,
                            left: 8,
                            child: Tooltip(
                              message: textFor('called', {
                                'p0': playerName(context, (g.dealer + 1) % 4),
                                'p1': g.calledValue
                              }),
                              child: Container(
                                key: Key('table-call'),
                                width: 40,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: cream,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: gold),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(textFor('call'),
                                        style: TextStyle(
                                            color: ink,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                    Text(rankName(g.calledValue!),
                                        style: TextStyle(
                                            color: ink,
                                            fontFamily: 'Georgia',
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        playerName(context, (g.dealer + 1) % 4),
                                        maxLines: 1,
                                        key: Key('call-player'),
                                        style: TextStyle(
                                            color: ink,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Positioned(top: 32, right: 8, child: _liveDealScore(1)),
                        Positioned(
                            bottom: 4, left: 8, child: _liveDealScore(0)),
                        Positioned(
                            bottom: 4,
                            right: 8,
                            child: Tooltip(
                                message:
                                    textFor('your_latest_capture_tap_to_view'),
                                child: InkWell(
                                    key: Key('last-capture-player-0'),
                                    onTap: () => _showLastCapture(0),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6, horizontal: 4),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(textFor('you'),
                                                  style: TextStyle(
                                                      color: cream,
                                                      fontSize: 11)),
                                              Icon(Icons.style_outlined,
                                                  color: cream, size: 12),
                                              SizedBox(width: 3),
                                              Text('${g.hands[0].length}',
                                                  key: Key('cards-left-0'),
                                                  style: TextStyle(
                                                      color: cream,
                                                      fontSize: 11)),
                                            ]))))),
                        Positioned(
                            top: top,
                            bottom: bottom,
                            left: side,
                            right: side,
                            child: LayoutBuilder(
                                builder: (context, area) =>
                                    SingleChildScrollView(
                                        key: Key('table-cards'),
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
                                                    Wrap(
                                                        alignment: WrapAlignment
                                                            .center,
                                                        spacing: 9,
                                                        runSpacing: 10,
                                                        children: [
                                                          for (final c
                                                              in g.loose)
                                                            AnimatedOpacity(
                                                                duration: Duration(
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
                                                                    TableCard(
                                                                        key: Key(
                                                                            'table-$c'),
                                                                        card: c,
                                                                        scale:
                                                                            cardScale,
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
                        if (_leftoverCards.isNotEmpty)
                          Positioned.fill(
                              child: IgnorePointer(child: _leftoverFlight())),
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
                                              child: Icon(Icons.pause,
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
                                    child: Text(
                                        textFor('call_2', {'p0': value})))),
                        ]))),
          if (_selectedCard != null && _moving == null && !(compact && wide))
            _moveTray(options, true),
          if (_selectedCard != null && _moving == null && compact && wide)
            Row(children: [
              Expanded(child: _hand(hand, legal, tight)),
              SizedBox(width: 230, child: _moveTray(options, true))
            ])
          else
            _hand(hand, legal, tight),
        ];
        return ColoredBox(
            color: Color(0xFF161F1A),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(children: sections)));
      });

  Widget _leftoverFlight() => AnimatedBuilder(
      animation: _motion,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
            final t = _motion.value;
            // Hold the remaining cards in view before gathering them to the winner.
            final travel =
                Curves.easeInOut.transform(((t - .4) / .6).clamp(0.0, 1.0));
            final destination = switch (_leftoverSeat) {
              0 => Offset(.5, .94),
              1 => Offset(.94, .5),
              2 => Offset(.5, .06),
              _ => Offset(.06, .5),
            };
            final position = Offset.lerp(Offset(.5, .5), destination, travel)!;
            final spread =
                (box.maxWidth - 130).clamp(0.0, 260.0) * (1 - travel);
            return Stack(key: Key('leftover-flight'), children: [
              for (var i = 0; i < _leftoverCards.length; i++)
                Positioned(
                  left: (position.dx * (box.maxWidth - 72) +
                          (_leftoverCards.length > 1
                                  ? i / (_leftoverCards.length - 1) - .5
                                  : 0) *
                              spread)
                      .clamp(
                          0.0, (box.maxWidth - 72).clamp(0.0, double.infinity)),
                  top: position.dy *
                      (box.maxHeight - 102).clamp(0.0, double.infinity),
                  child: TableCard(card: _leftoverCards[i]),
                ),
              Align(
                  alignment: Alignment(0, -.8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: ink, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        textFor('leftover_cards_points_no_seep', {
                          'p0': playerName(context, _leftoverSeat),
                          'p1': pointsOf(_leftoverCards)
                        }),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cream)),
                  )),
            ]);
          }));

  Widget _flight(SweepGame game) {
    final move = _moving!;
    final affected = game.position.affectedCards(move);
    final capture = move.kind == MoveKind.capture;
    final sweep = capture &&
        game.plays < 47 &&
        move.selectedLoose.length == game.loose.length &&
        move.houseIndexes.length == game.houses.length;
    final origin = switch (game.turn) {
      0 => Offset(.5, .92),
      1 => Offset(.94, .5),
      2 => Offset(.5, .08),
      _ => Offset(.06, .5),
    };
    return AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => LayoutBuilder(builder: (context, box) {
              final t = _motion.value;
              final flightScale = box.maxHeight < 210 ? 1.1 : 1.7;
              final travel =
                  t < .32 ? Curves.easeOutCubic.transform(t / .32) : 1.0;
              final gather =
                  t <= .65 ? 0.0 : Curves.easeInOut.transform((t - .65) / .35);
              const center = Offset(.5, .5);
              final position = t < .65
                  ? Offset.lerp(origin, center, travel)!
                  : Offset.lerp(
                      center, capture ? origin : Offset(.5, .42), gather)!;
              return Stack(children: [
                Positioned(
                    left: position.dx * (box.maxWidth - 72 * flightScale),
                    top: position.dy * (box.maxHeight - 102 * flightScale),
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
                                  child: TableCard(
                                      card: affected[i], scale: flightScale)),
                          TableCard(
                              card: move.card,
                              scale: flightScale,
                              highlighted: true),
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
                                        style: TextStyle(
                                            color: ink,
                                            fontWeight: FontWeight.bold)))),
                        ]))),
                if (sweep && t > .6)
                  Align(
                      alignment: Alignment(0, -.4),
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
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, color: gold),
                                    SizedBox(width: 8),
                                    Text(textFor('seep'),
                                        key: Key('sweep-celebration'),
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
      key: Key('hand'),
      height: 126,
      child: hand.isEmpty
          ? Center(
              child: Text(
                  _showingFinalMove
                      ? textFor('scores_in_a_moment')
                      : textFor('waiting_for_the_deal'),
                  style: TextStyle(color: Colors.white54, fontSize: 12)))
          : LayoutBuilder(builder: (context, area) {
              const cardWidth = 72.0;
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
                                      (hand.indexOf(card) - (hand.length - 1) / 2)
                                          .abs(),
                              child: Transform.rotate(
                                  angle: (hand.indexOf(card) -
                                          (hand.length - 1) / 2) *
                                      .009,
                                  child: Visibility(
                                      key: Key('hand-visibility-$card'),
                                      visible: !(_game!.turn == 0 &&
                                          _moving?.card == card),
                                      maintainSize: true,
                                      maintainState: true,
                                      maintainAnimation: true,
                                      child: CardFace(
                                          key: Key('hand-$card'),
                                          card: card,
                                          large: true,
                                          highlighted: _selectedCard == card,
                                          onTap: _canPlay &&
                                                  _game!.phase != Phase.call
                                              ? () => _chooseCard(
                                                  card,
                                                  legal
                                                      .where((m) => m.card == card)
                                                      .toList())
                                              : null)))),
                      ])));
            }));

  Widget _moveTray(List<Move> options, bool compact) {
    final g = _game!;
    final move = _preview!;
    return Container(
        key: Key('move-tray'),
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
        decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold.withValues(alpha: .25))),
        child: Row(children: [
          IconButton(
              tooltip: textFor('cancel_selection'),
              onPressed: () => _update(() {
                    _selectedCard = null;
                    _preview = null;
                  }),
              icon: Icon(Icons.close, size: 18)),
          Expanded(
              child: SizedBox(
                  height: compact ? 46 : 79,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: options.length,
                      separatorBuilder: (_, index) => SizedBox(width: 5),
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
                                          style: TextStyle(
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
                                                Center(
                                                    child: Icon(Icons.add,
                                                        size: 20, color: gold)),
                                            ])),
                                    ])));
                      }))),
          SizedBox(width: 6),
          FilledButton(
              key: Key('confirm-move'),
              onPressed: _canPlay ? () => _play(move) : null,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(_moveLabel(move))),
        ]));
  }

  Future<void> _showLastCapture(int seat) => _overlay(() => showDialog<void>(
      context: context,
      builder: (context) {
        final capture = _game!.lastCaptures[seat];
        return AlertDialog(
          title: Text(
              textFor('latest_capture_2', {'p0': playerName(context, seat)})),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: capture == null
                  ? Text(textFor('no_capture_recorded_in_this_deal_yet'))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(
                              textFor('card_points',
                                  {'p0': pointsOf(capture.cards)}),
                              key: Key('last-capture-points'),
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          if (capture.sweepPoints > 0)
                            Text(textFor('seep_bonus_requires_team_card_points',
                                {'p0': capture.sweepPoints})),
                          SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 10, children: [
                            for (final card in capture.cards)
                              CardFace(
                                  key: Key('last-capture-card-$card'),
                                  card: card),
                          ]),
                          SizedBox(height: 12),
                          Text(textFor('turn_includes_the_card_played',
                              {'p0': capture.turn})),
                        ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(textFor('close')))
          ],
        );
      }));

  Future<void> _inspectHouse(House house) => _overlay(() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Row(children: [
                if (house.pakka)
                  Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.lock, color: gold)),
                Text(textFor('house_of', {'p0': house.value}))
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
                    Text(
                        house.owners
                            .map((s) => playerName(context, s))
                            .join(' & '),
                        style: TextStyle(color: gold)),
                    SizedBox(height: 8),
                    Text(house.pakka
                        ? textFor('locked_value_capture_with_a_matching_card')
                        : textFor('capture_with_a_matching_card_or_raise')),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(textFor('close')))
              ])));
}
