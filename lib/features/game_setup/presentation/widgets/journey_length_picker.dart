import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/journey_length_config.dart';

/// A slider + synced numeric field for picking the journey's step target
/// freely, rather than from a handful of fixed presets. Dragging the slider
/// updates the number; typing a number moves the slider. Reaching the very
/// end of the slider — one position past [JourneyLengthConfig.maxFiniteSteps]
/// — means "infinite" ([value] null), so infinite reads as a natural
/// continuation of the scale rather than a separate toggle; the ∞ button
/// next to the field is a direct shortcut to that same end position.
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

  double get _sliderValue {
    final value = widget.value;
    if (value == null) return JourneyLengthConfig.sliderMaxPosition.toDouble();
    return value
        .clamp(JourneyLengthConfig.minSteps, JourneyLengthConfig.maxFiniteSteps)
        .toDouble();
  }

  void _onSliderChanged(double raw) {
    final rounded = raw.round();
    if (rounded >= JourneyLengthConfig.sliderMaxPosition) {
      widget.onChanged(null);
    } else {
      widget.onChanged(
        rounded.clamp(
          JourneyLengthConfig.minSteps,
          JourneyLengthConfig.maxFiniteSteps,
        ),
      );
    }
  }

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
            Expanded(
              child: Slider(
                value: _sliderValue,
                min: JourneyLengthConfig.minSteps.toDouble(),
                max: JourneyLengthConfig.sliderMaxPosition.toDouble(),
                divisions:
                    JourneyLengthConfig.sliderMaxPosition -
                    JourneyLengthConfig.minSteps,
                label: isInfinite ? '∞' : '${widget.value}',
                onChanged: _onSliderChanged,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Бесконечное путешествие',
              onPressed: () => widget.onChanged(null),
              icon: Icon(
                Icons.all_inclusive,
                color: isInfinite ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
        const _JourneyScaleMarkers(),
        if (!isInfinite &&
            widget.value! >= JourneyLengthConfig.longJourneyWarningThreshold)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠️ Очень длинное путешествие. Рекомендуется для опытных '
              'игроков или длительных игровых сессий.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Rough scale labels under the slider — orientation for a first-time
/// player, not hard limits. Positioned by the same linear fraction the
/// slider itself uses, so they roughly line up with where that step count
/// actually sits on the track (they cluster toward the left, since the
/// scale runs 10–200 but the markers themselves are 10/20/40/80 — that's
/// an honest reflection of the track, not a layout bug).
class _JourneyScaleMarkers extends StatelessWidget {
  const _JourneyScaleMarkers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 18,
      child: Stack(
        children: [
          for (final step in JourneyLengthConfig.scaleMarkers)
            Align(
              alignment: Alignment(_fractionToX(step), 0),
              child: Text('$step', style: theme.textTheme.labelSmall),
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
