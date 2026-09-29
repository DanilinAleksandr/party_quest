import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/steel_palette.dart';
import '../../game/presentation/widgets/coin_toss.dart';
import '../../../game_engine/models/models.dart';

/// A bench for the coin, in debug builds only: throw it to a chosen result
/// in a random variant, again and again, and read which variant it was, so
/// a bad one can be named and found again.
class DebugCoinScreen extends StatefulWidget {
  const DebugCoinScreen({super.key});

  @override
  State<DebugCoinScreen> createState() => _DebugCoinScreenState();
}

class _DebugCoinScreenState extends State<DebugCoinScreen>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();
  final _haptics = CoinHaptics();
  final _number = TextEditingController();
  late final AnimationController _clock = AnimationController(vsync: this);

  CoinThrow _result = CoinThrow.win;
  CoinMotion? _motion;

  @override
  void dispose() {
    _clock.dispose();
    _number.dispose();
    super.dispose();
  }

  void _throw(CoinThrow result, {int? number}) {
    final style = CoinStyle.of(number ?? _random.nextInt(CoinStyle.count));
    final motion = CoinMotion(style, edge: result == CoinThrow.edge);
    setState(() {
      _result = result;
      _motion = motion;
      _number.text = '${style.number}';
    });
    _haptics.reset();
    _clock
      ..duration = Duration(milliseconds: (motion.seconds * 1000).round())
      ..forward(from: 0);
  }

  void _again() {
    final motion = _motion;
    if (motion == null) return;
    _throw(_result, number: motion.style.number);
  }

  void _byNumber() {
    final number = int.tryParse(_number.text.trim());
    if (number == null) return;
    _throw(_result, number: number % CoinStyle.count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: SteelPalette.textLow.withValues(alpha: 0.7),
      height: 1.45,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Монета')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _clock,
                builder: (context, _) {
                  final motion = _motion;
                  if (motion == null) {
                    return const SizedBox(height: CoinTossStage.height);
                  }
                  final settled = _clock.isCompleted;
                  final seconds = settled
                      ? motion.seconds
                      : _clock.value * motion.seconds;
                  _haptics.advance(motion, seconds);
                  final pose = settled ? motion.rest : motion.poseAt(seconds);
                  // King up for a win and for the edge, the Jester for a
                  // loss — as a throw with no call reads its faces.
                  final jester = _result == CoinThrow.lose;
                  return Column(
                    children: [
                      CoinTossStage(
                        pose: pose,
                        peak: motion.peak,
                        face: (math.cos(pose.angle) < 0) != jester,
                        settled: settled,
                      ),
                      SizedBox(
                        height: 32,
                        child: settled
                            ? Text(switch (_result) {
                                CoinThrow.win => 'Король',
                                CoinThrow.lose => 'Шут',
                                CoinThrow.edge => 'Ребро',
                              }, style: theme.textTheme.titleLarge)
                            : null,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (label, result) in const [
                    ('Король', CoinThrow.win),
                    ('Шут', CoinThrow.lose),
                    ('Ребро', CoinThrow.edge),
                  ]) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _throw(result),
                        child: Text(label),
                      ),
                    ),
                    if (result != CoinThrow.edge) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _motion == null ? null : _again,
                child: const Text('Ещё раз'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _number,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Вариант №',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _byNumber(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _byNumber,
                    child: const Text('Бросить этот'),
                  ),
                ],
              ),
              const Spacer(),
              if (_motion case final motion?)
                Text(_describe(motion), style: small),
            ],
          ),
        ),
      ),
    );
  }
}

/// A variant in words, small enough to read off the phone and repeat.
String _describe(CoinMotion motion) {
  final s = motion.style;
  String n(double v, [int digits = 2]) => v.toStringAsFixed(digits);
  final parts = <String>[
    'Вариант ${s.number}',
    'высота ×${n(s.lift)}',
    '${s.halfTurns} полуоборотов',
    'ось ${s.axisTilt >= 0 ? '+' : ''}${n(s.axisTilt)} рад',
    if (motion.spins)
      'волчок ${s.spinDirection > 0 ? '↻' : '↺'} ${n(s.spinTime, 1)} с, '
          'круг ${n(s.rollRadius, 1)}'
    else
      'подскоков ${s.bounces}',
    if (motion.edge) 'почти падает ${s.nearFalls}',
    'всего ${n(motion.seconds, 1)} с',
  ];
  return parts.join(' · ');
}
