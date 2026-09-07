import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/journey_length_config.dart';
import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/line_icons.dart';

/// A walkable trail + synced numeric field for picking the journey's step
/// target freely, rather than from a handful of fixed presets. Dragging the
/// trail updates the number; typing a number moves the trail. The very end
/// of the scale — one position past [JourneyLengthConfig.maxFiniteSteps] —
/// means "infinite" ([value] null), so infinite reads as a natural
/// continuation of the walk rather than a separate toggle.
///
/// The trail is the same row of notches the game screen uses for progress,
/// which is the point: what you set here is literally the thing you will
/// watch fill up. A Material `Slider` said "adjust a parameter"; this says
/// "choose how far you are going".
class JourneyLengthPicker extends StatefulWidget {
  /// Null means infinite (no step target).
  final int? value;
  final ValueChanged<int?> onChanged;

  const JourneyLengthPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<JourneyLengthPicker> createState() => _JourneyLengthPickerState();
}

class _JourneyLengthPickerState extends State<JourneyLengthPicker> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayText(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      // Typing over "∞" should just replace it, not append to it.
      if (_focusNode.hasFocus && _controller.text == '∞') {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant JourneyLengthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final expected = _displayText(widget.value);
    // Only overwrite the field when it doesn't already show this value —
    // otherwise every keystroke's own onChanged->setState round-trip would
    // reset the cursor to the end of the field.
    if (_controller.text != expected) {
      _controller.text = expected;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _displayText(int? value) => value == null ? '∞' : '$value';

  void _onTextChanged(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null) return;
    widget.onChanged(
      parsed.clamp(
        JourneyLengthConfig.minSteps,
        JourneyLengthConfig.maxFiniteSteps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInfinite = widget.value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 84,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: SteelPalette.steel.withValues(alpha: 0.05),
                border: Border.all(
                  color: SteelPalette.steel.withValues(alpha: 0.34),
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: SteelPalette.textHigh,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isInfinite ? 'путешествие без конца' : 'шагов до конца пути',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: SteelPalette.textLow.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _JourneyTrailPicker(value: widget.value, onChanged: widget.onChanged),
        const _JourneyScaleMarkers(),
        if (!isInfinite &&
            widget.value! >= JourneyLengthConfig.longJourneyWarningThreshold)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _LongJourneyWarning(),
          ),
      ],
    );
  }
}

/// The scale, walked rather than dragged by a handle.
///
/// One shared mapping does all the work in both directions: a fraction of
/// the widget's width is a position on the same 10..201 scale the numeric
/// field writes to, and the last position is infinity. That is exactly what
/// the `Slider` computed internally — replacing it changes how the value is
/// picked, not what the values are.
class _JourneyTrailPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  static const double _minSegmentWidth = 6;
  static const double _gap = 3;
  static const double _height = 10;
  static const double _milestoneHeight = 16;

  /// Every seventh notch stands taller — something to count by, so a long
  /// scale still reads as a distance rather than as texture.
  static const int _milestoneEvery = 7;

  /// The slot the ∞ glyph occupies at the far right of the scale.
  static const double _infinityWidth = 34;
  static const double _infinityGlyphSize = 26;

  const _JourneyTrailPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInfinite = value == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final trackWidth = math.max(1.0, width - _infinityWidth);
        final fits = ((trackWidth + _gap) / (_minSegmentWidth + _gap)).floor();
        final segments = math.max(1, fits);

        void report(Offset local) {
          final fraction = (local.dx / width).clamp(0.0, 1.0);
          final position =
              JourneyLengthConfig.minSteps +
              fraction *
                  (JourneyLengthConfig.sliderMaxPosition -
                      JourneyLengthConfig.minSteps);
          final rounded = position.round();
          if (rounded >= JourneyLengthConfig.sliderMaxPosition) {
            onChanged(null);
          } else {
            onChanged(
              rounded.clamp(
                JourneyLengthConfig.minSteps,
                JourneyLengthConfig.maxFiniteSteps,
              ),
            );
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => report(details.localPosition),
          onHorizontalDragUpdate: (details) => report(details.localPosition),
          child: SizedBox(
            // Tall enough for the ∞ glyph, not for the notches: they are
            // bottom-aligned, so the extra height is headroom above them
            // rather than a taller trail.
            height: _infinityGlyphSize,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: trackWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < segments; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: _Notch(
                            state: _stateOf(i, segments),
                            tall: i % _milestoneEvery == 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: _infinityWidth,
                  child: Text(
                    '∞',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: _infinityGlyphSize,
                      height: 1,
                      color: SteelPalette.textLow.withValues(
                        alpha: isInfinite ? 0.7 : 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Which side of the chosen value a notch falls on. The notch containing
  /// the value itself is the bright one — the same "you are standing here"
  /// mark the game screen's trail uses for the last step walked.
  _NotchState _stateOf(int index, int segments) {
    if (value == null) return _NotchState.walked;
    final span =
        JourneyLengthConfig.sliderMaxPosition - JourneyLengthConfig.minSteps;
    final start = JourneyLengthConfig.minSteps + span * index / segments;
    final end = JourneyLengthConfig.minSteps + span * (index + 1) / segments;
    if (value! >= end) return _NotchState.walked;
    if (value! >= start) return _NotchState.current;
    return _NotchState.ahead;
  }
}

enum _NotchState { walked, current, ahead }

class _Notch extends StatelessWidget {
  final _NotchState state;
  final bool tall;

  const _Notch({required this.state, required this.tall});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _NotchState.walked => SteelPalette.steel.withValues(alpha: 0.52),
      _NotchState.current => SteelPalette.steel.withValues(alpha: 0.95),
      _NotchState.ahead => SteelPalette.textLow.withValues(alpha: 0.11),
    };
    return Container(
      height: tall
          ? _JourneyTrailPicker._milestoneHeight
          : _JourneyTrailPicker._height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// The long-journey caution. Not a scolding — 120 steps is a legitimate
/// choice, it just wants the table to know what it is agreeing to.
class _LongJourneyWarning extends StatelessWidget {
  static const Color _warning = Color(0xFFC98A4B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _warning.withValues(alpha: 0.08),
        border: Border.all(color: _warning.withValues(alpha: 0.33)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: LineIcon(
              shape: LineIconShape.warning,
              size: 17,
              color: _warning,
              strokeWidth: 1.3,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Очень длинное путешествие. Рекомендуется для опытных игроков '
              'или длительных игровых сессий.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: SteelPalette.textLow.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rough scale labels under the trail — orientation for a first-time
/// player, not hard limits. Positioned by the same linear fraction the
/// trail itself uses, so they line up with where that step count actually
/// sits (they cluster toward the left, since the scale runs 10–200 but the
/// markers are 10/20/40/80 — an honest reflection of the track, not a
/// layout bug).
class _JourneyScaleMarkers extends StatelessWidget {
  const _JourneyScaleMarkers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10.5,
      color: SteelPalette.textLow.withValues(alpha: 0.5),
    );
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          for (final step in JourneyLengthConfig.scaleMarkers)
            Align(
              alignment: Alignment(_fractionToX(step), 0),
              child: Text('$step', style: style),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('∞', style: style),
          ),
        ],
      ),
    );
  }

  double _fractionToX(int step) {
    final fraction =
        (step - JourneyLengthConfig.minSteps) /
        (JourneyLengthConfig.sliderMaxPosition - JourneyLengthConfig.minSteps);
    return (fraction * 2) - 1;
  }
}
