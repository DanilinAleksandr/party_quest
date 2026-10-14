import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/stat_chip.dart';
import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../game_engine/models/models.dart';
import 'arm_wrestle.dart';
import 'coin_toss.dart';

/// The moment a gamble is settled, made visible.
///
/// A `chanceCheck` used to resolve in the same silent instant as everything
/// else: the player picked "рискнуть по-крупному" and the dialog closed, with
/// a result plate — or nothing at all — as the only evidence that a coin had
/// been flipped on their behalf. The throw is the most interesting thing
/// that happens on those cards and it was the one thing nobody saw.
///
/// A coin, flipping end over end. The die is still the game's mark for
/// chance in the abstract — the launcher icon, the "Сделать шаг" button —
/// but this screen is not about chance in the abstract: it is one wager with
/// two sides, called or not, and a coin is the object that has exactly two
/// sides. A six-sided die landing on "6 = you won" was always a translation.
///
/// The face is honest: [passed] is the throw the engine will apply, decided
/// before the animation starts, so what lands here is what happens next
/// rather than a decorative spin followed by an unrelated verdict.
///
/// [style] is how the throw looks — the variant the match drew for it (see
/// `GameController.coinStyle`); left null, a fresh one.
///
/// [spinner] forces a throw to come down spinning on its edge, or not; left
/// null, about one in three do. It changes only how the coin gets there.
///
/// [edge] is the rare third way down: the coin comes to rest standing on
/// its milled edge, rocks, and stays there. It favours the thrower
/// whatever was called, so [passed] is true with it.
///
/// The button lives inside the content rather than in the shell's `actions`
/// because it must not exist until the coin has settled: a dialog you can
/// dismiss before it has told you anything is just a delay.
///
/// [sides] and [calledIndex] are the wager's two faces and the one the
/// player called, when the scene offered a call. They change nothing about
/// the throw, but they decide which face the coin comes to rest on and let
/// the settled screen say what was bet against what came up — the whole
/// difference between "платишь" and "платишь, а ставил ты на Короля".
///
/// [challenger] and [opponent] name the two players of a duel, and are
/// absent for a solo risk. See [_Verdict] for why a duel cannot be reported
/// in the second person, and why it names the one who pays.
///
/// [canReroll]: the current player carries the holed die, and a lost throw
/// may be thrown again with it. Completes with true when they chose to.
Future<bool> showChanceCheckDialog({
  required BuildContext context,
  required bool passed,
  bool edge = false,
  bool? spinner,
  CoinStyle? style,
  List<String>? sides,
  int? calledIndex,
  String? challenger,
  String? opponent,
  StatType? stat,
  double? odds,
  bool canReroll = false,
}) async {
  final reroll = await showAppDialog<bool>(
    context: context,
    icon: Icons.toll_outlined,
    title: 'Бросок',
    barrierDismissible: false,
    content: _RollBody(
      passed: passed || edge,
      edge: edge,
      spinner: spinner,
      style: style,
      sides: sides,
      calledIndex: calledIndex,
      challenger: challenger,
      opponent: opponent,
      stat: stat,
      odds: odds,
      canReroll: canReroll,
    ),
    actions: const [],
  );
  return reroll ?? false;
}

/// A gamble that is an arm-wrestling bout, shown as one instead of a coin.
///
/// The odds settled it before the dialog opens; [scenario] only decides how
/// it looks getting there. [challenger] is the near arm, at the bottom —
/// the one who threw down the challenge; [opponent] the far one, a
/// companion or an NPC. [passed] is "the challenger won". Nothing is called
/// and nothing can stand on its edge: two arms have no sides to bet on and
/// no third way down.
Future<void> showArmWrestleDialog({
  required BuildContext context,
  required bool passed,
  required ArmWrestleScenario scenario,
  required String challenger,
  required String opponent,
}) {
  return showAppDialog<void>(
    context: context,
    icon: Icons.fitness_center,
    title: 'Армрестлинг',
    barrierDismissible: false,
    content: ArmWrestleBody(
      passed: passed,
      scenario: scenario,
      challenger: challenger,
      opponent: opponent,
    ),
    actions: const [],
  );
}

/// The inside of [showArmWrestleDialog]. [freezeAt] holds it at one moment
/// instead of playing it — for the contact sheet.
class ArmWrestleBody extends StatefulWidget {
  final bool passed;
  final ArmWrestleScenario scenario;
  final String challenger;
  final String opponent;
  final double? freezeAt;

  const ArmWrestleBody({
    super.key,
    required this.passed,
    required this.scenario,
    required this.challenger,
    required this.opponent,
    this.freezeAt,
  });

  @override
  State<ArmWrestleBody> createState() => _ArmWrestleBodyState();
}

class _ArmWrestleBodyState extends State<ArmWrestleBody>
    with SingleTickerProviderStateMixin {
  final _haptics = ArmWrestleHaptics();

  late final Duration _duration = Duration(
    milliseconds: (widget.scenario.end * 1000).round(),
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.freezeAt == null) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = widget.scenario;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final frozen = widget.freezeAt;
        final t =
            frozen ??
            (_controller.isCompleted
                ? scenario.end
                : _controller.value * _duration.inMilliseconds / 1000);
        if (frozen == null) _haptics.advance(scenario, t);
        final slammed = t >= scenario.hit;
        final over = t >= scenario.end;
        // Bright and underlined for the winner, dimmed for the loser, from
        // the slam on; before it, both the same.
        _NameState stateOf(bool near) => !slammed
            ? _NameState.even
            : near == widget.passed
            ? _NameState.won
            : _NameState.lost;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WhatCounts(
              stat: StatType.strength,
              challenger: widget.challenger,
              opponent: widget.opponent,
            ),
            _BoutName(widget.opponent, state: stateOf(false), near: false),
            ArmWrestleStage(scenario: scenario, nearWins: widget.passed, t: t),
            _BoutName(widget.challenger, state: stateOf(true), near: true),
            const SizedBox(height: 14),
            // Built on the slam, the slot reserved before it — and allowed
            // to grow, so long names push the button down rather than run
            // into it.
            _Verdict(
              settled: slammed,
              passed: widget.passed,
              challenger: widget.challenger,
              opponent: widget.opponent,
              grow: true,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: over
                  ? FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Дальше'),
                    )
                  : const SizedBox(height: 52),
            ),
          ],
        );
      },
    );
  }
}

enum _NameState { even, won, lost }

/// A wrestler's name by their arm: the near one under it, the far one over
/// it. Never declined, two lines at most. From the slam the winner's turns
/// bright and bold with a short bar by it, the loser's fades to half.
class _BoutName extends StatelessWidget {
  final String name;
  final _NameState state;
  final bool near;

  const _BoutName(this.name, {required this.state, required this.near});

  static const _fade = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final won = state == _NameState.won;
    final text = AnimatedDefaultTextStyle(
      duration: _fade,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(
            fontSize: 14,
            height: 1.3,
            fontWeight: won ? FontWeight.w800 : FontWeight.w600,
            color: won
                ? SteelPalette.textHigh
                : SteelPalette.textLow.withValues(alpha: 0.72),
          ),
      child: Text(name, key: Key(near ? 'bout_near' : 'bout_far')),
    );
    final bar = AnimatedOpacity(
      duration: _fade,
      opacity: won ? 1 : 0,
      child: Container(
        key: Key(near ? 'bout_near_bar' : 'bout_far_bar'),
        width: 24,
        height: 2,
        decoration: BoxDecoration(
          color: SteelPalette.steel,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
    return AnimatedOpacity(
      duration: _fade,
      opacity: state == _NameState.lost ? 0.5 : 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, near ? 8 : 0, 12, near ? 0 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: near
              ? [text, const SizedBox(height: 5), bar]
              : [bar, const SizedBox(height: 5), text],
        ),
      ),
    );
  }
}

class _RollBody extends StatefulWidget {
  final bool passed;
  final bool edge;
  final bool? spinner;
  final CoinStyle? style;
  final List<String>? sides;
  final int? calledIndex;
  final String? challenger;
  final String? opponent;
  final StatType? stat;
  final double? odds;
  final bool canReroll;

  const _RollBody({
    required this.passed,
    this.edge = false,
    this.spinner,
    this.style,
    this.sides,
    this.calledIndex,
    this.challenger,
    this.opponent,
    this.stat,
    this.odds,
    this.canReroll = false,
  });

  @override
  State<_RollBody> createState() => _RollBodyState();
}

class _RollBodyState extends State<_RollBody>
    with SingleTickerProviderStateMixin {
  /// How this throw looks: the variant the match drew for it, or a fresh
  /// one. [_RollBody.spinner] can force a spin either way.
  late final CoinMotion _motion = () {
    var style =
        widget.style ?? CoinStyle.of(math.Random().nextInt(CoinStyle.count));
    if (widget.spinner != null) style = style.copyWith(spins: widget.spinner);
    return CoinMotion(style, edge: widget.edge);
  }();

  final _haptics = CoinHaptics();

  late final Duration _duration = Duration(
    milliseconds: (_motion.seconds * 1000).round(),
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Which face the coin is showing once it stops.
  ///
  /// With a call, it is the side that was called if the throw came off and
  /// the other one if it did not — which is exactly what winning a called
  /// bet means, and is what keeps the coin from contradicting the line
  /// underneath it.
  ///
  /// With no call there is no side to be right about, so the coin falls back
  /// to the plain reading of its two faces: the King when the attempt held,
  /// the Jester when it did not.
  bool get _restingFace {
    final called = widget.calledIndex;
    if (called == null) return !widget.passed;
    return widget.passed ? called == 1 : called == 0;
  }

  /// The side the player called, or null when nothing was called.
  String? get _bet {
    final sides = widget.sides;
    final called = widget.calledIndex;
    if (sides == null || called == null || sides.length != 2) return null;
    return sides[called];
  }

  String? get _call {
    final sides = widget.sides;
    final called = widget.calledIndex;
    if (sides == null || called == null || sides.length != 2) return null;
    // Two labelled fields rather than a sentence, for the same reason the
    // duel says "Платит: X": the sides are named by content and carry their
    // own gender, so "она и выпала" is wrong the moment the side is a Шут.
    // A label and a name agree with everything.
    if (widget.edge) return 'Ставка: ${sides[called]}  ·  Выпало: ребро';
    final up = widget.passed ? sides[called] : sides[1 - called];
    return 'Ставка: ${sides[called]}  ·  Выпало: $up';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // The controller is only a clock here — the motion comes from the
        // two simulations, read at the elapsed time in seconds.
        final seconds = _controller.value * _duration.inMilliseconds / 1000;
        final settled = _controller.isCompleted;
        final pose = settled ? _motion.rest : _motion.poseAt(seconds);
        _haptics.advance(_motion, settled ? _motion.seconds : seconds);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WhatCounts(
              stat: widget.stat,
              challenger: widget.challenger,
              opponent: widget.opponent,
            ),
            // The side called, large, for the whole throw — so nobody has
            // to ask afterwards whether it was the King they called.
            if (_bet != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Твоя ставка: $_bet',
                  key: const Key('throw_bet'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: SteelPalette.textHigh,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            CoinTossStage(
              pose: pose,
              peak: _motion.peak,
              // The coin ends on an even half-turn, on the end it started
              // on — so that end carries `_restingFace`, which is the point:
              // the coin is started on whichever side it must finish on.
              face: _restingFace,
              settled: settled,
            ),
            // A debug build says the odds the throw was made at, small,
            // so a playtest can tell a drink made it in. Never in a
            // release: the table should feel strength helps, not count it.
            if (kDebugMode && widget.odds != null)
              _DebugOdds(odds: widget.odds!),
            const SizedBox(height: 4),
            // The verdict is built only once it is true, rather than faded
            // in from a hidden widget: a "Платишь" sitting at zero opacity
            // is still there to be read out by a screen reader, and still
            // there to be found by a test that means to check the table
            // cannot see it yet. The slot keeps its height either way so
            // nothing below it moves when the words arrive.
            _Verdict(
              settled: settled,
              passed: widget.passed,
              edge: widget.edge,
              challenger: widget.challenger,
              opponent: widget.opponent,
            ),
            // What was called against what came up, for a wager that had a
            // side to call. It sits under the verdict rather than replacing
            // it: the verdict is the news, this is the receipt.
            if (_call != null)
              SizedBox(
                height: 26,
                child: settled
                    ? Text(
                        _call!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: SteelPalette.textLow.withValues(alpha: 0.72),
                        ),
                      )
                    : null,
              ),
            const SizedBox(height: 18),
            // The holed die: a lost throw of one's own, once a match, thrown
            // again. Offered only once the coin has settled against you.
            if (settled && widget.canReroll && !widget.passed) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('reroll_with_die'),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  label: const Text('Перебросить костью'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Reserved rather than inserted, so the dialog does not jump a
            // button's height at the exact moment the eye is on the coin.
            SizedBox(
              width: double.infinity,
              child: settled
                  ? FilledButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Дальше'),
                    )
                  : const SizedBox(height: 52),
            ),
          ],
        );
      },
    );
  }
}

class _DebugOdds extends StatelessWidget {
  final double odds;

  const _DebugOdds({required this.odds});

  @override
  Widget build(BuildContext context) => Text(
    'debug · шанс ${(odds * 100).round()}%',
    key: const Key('debug_odds'),
    textAlign: TextAlign.center,
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: SteelPalette.steelDim),
  );
}

/// What the throw measures, over the coin: the stat and its mark, or
/// «Удача» for a pure gamble — and in a duel, the two who measure it. Never
/// a number: the table should feel that strength helps, not work out by
/// how much.
class _WhatCounts extends StatelessWidget {
  final StatType? stat;
  final String? challenger;
  final String? opponent;

  const _WhatCounts({this.stat, this.challenger, this.opponent});

  @override
  Widget build(BuildContext context) {
    final s = stat ?? StatType.luck;
    final duel = challenger != null && opponent != null;
    final text = duel
        // A dash, not «против»: names arrive as typed, in no known case,
        // and «против Миша» reads wrong — the same reason «Платит: X».
        ? '${StatChip.labelFor(s)}: $challenger — $opponent'
        : StatChip.labelFor(s);
    final color = SteelPalette.textLow.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(StatChip.iconFor(s), size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              key: const Key('throw_measures'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who pays, in the words that fit who was playing.
///
/// Names the *loser*, not the winner. This is a drinking game: the winner
/// gets to carry on as they were, and the only person who has to do
/// something about the result is the one who lost. The screen that tells
/// the table what just happened should say who owes, the same way the
/// outcome text does.
///
/// A duel names them, because two named players are in it, the penalty may
/// land on the *other* one, and an impersonal line leaves the table guessing
/// which. A solo risk stays in the second person — there is nobody else in
/// the sentence — and says what it costs rather than what it won.
///
/// A coin on its edge has nobody to name: it is «Ребро», said as plainly
/// as the thing itself.
class _Verdict extends StatelessWidget {
  final bool settled;
  final bool passed;
  final bool edge;
  final String? challenger;
  final String? opponent;

  /// Whether the slot may grow past its height for long names, rather than
  /// hold to it — the bout's, where the names sit right above and a button
  /// right below, and words spilling over them would be worse than a dialog
  /// a line taller.
  final bool grow;

  const _Verdict({
    required this.settled,
    required this.passed,
    this.edge = false,
    this.challenger,
    this.opponent,
    this.grow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenger = this.challenger;
    final opponent = this.opponent;
    final isDuel = challenger != null && opponent != null;

    // `passed` is "the challenger's throw came off", so the one who pays is
    // whichever of the two it was not.
    final headline = edge
        ? 'Ребро'
        : isDuel
        ? 'Платит: ${passed ? opponent : challenger}'
        : (passed ? 'Твоя взяла' : 'Платишь');
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: SteelPalette.textLow.withValues(alpha: 0.72),
    );

    final height = (isDuel ? 62.0 : 34.0) + (edge ? 34 : 0);
    return ConstrainedBox(
      constraints: grow
          ? BoxConstraints(minHeight: height)
          : BoxConstraints.tightFor(height: height),
      child: settled
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDuel)
                    Text(
                      '$challenger и $opponent',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                  Text(
                    // "Платит: X" rather than "платит X" or "X проиграл":
                    // player names are typed by the table and arrive in no
                    // known gender or case, so a past-tense verb would have
                    // to agree with them and get it wrong half the time. A
                    // label and a name in the nominative are right for every
                    // name anyone types — the same rule the outcome text and
                    // the wager receipt follow.
                    //
                    // The solo lines are already gender-free for the same
                    // reason: "Платишь" and "Твоя взяла" are second person
                    // and neither has to know who is playing. "Обошлось" was
                    // retired: said of a +3, it read as "nothing happened".
                    headline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: SteelPalette.textHigh,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (edge)
                    Text(
                      'Монета встала на ребро.',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}
