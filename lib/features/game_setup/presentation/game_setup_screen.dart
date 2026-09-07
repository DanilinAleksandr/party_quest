import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/constants/journey_length_config.dart';
import '../../../core/theme/steel_palette.dart';
import '../../../core/widgets/line_icons.dart';
import '../../../core/widgets/tactile_press_button.dart';
import 'widgets/journey_length_picker.dart';

/// Ephemeral form state — this screen only builds the player list that gets
/// handed off to the game engine, so a local [State] is enough. It doesn't
/// need to be visible to (or survive outside of) this one screen.
///
/// Deliberately no origin picker here: origins are hidden at the start of
/// the game and only surface through rare in-game events — see `Origin`/
/// `RevealOriginAction`. Every player starts without one, and the roster
/// row says so in as many words.
class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final List<String> _playerNames = [];
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  int? _journeySteps = JourneyLengthConfig.defaultSteps;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _canAddPlayer => _playerNames.length < GameConstants.maxPlayers;

  bool get _canStartGame => _playerNames.length >= GameConstants.minPlayers;

  void _addPlayer() {
    final name = _nameController.text.trim();
    if (name.isEmpty || !_canAddPlayer) return;
    setState(() {
      _playerNames.add(name);
      _nameController.clear();
    });
    _nameFocusNode.requestFocus();
  }

  void _removePlayer(int index) {
    setState(() => _playerNames.removeAt(index));
  }

  void _startGame() {
    Navigator.of(context).pushNamed(
      AppRoutes.game,
      arguments: (
        playerNames: List<String>.of(_playerNames),
        journeySteps: _journeySteps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteelPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ScreenHeader(),
                  const SizedBox(height: 18),
                  _NameEntry(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    enabled: _canAddPlayer,
                    onSubmit: _addPlayer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _canAddPlayer
                        ? 'Игроков: ${_playerNames.length} / '
                              '${GameConstants.maxPlayers}'
                        : 'Достигнут лимит игроков',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color: SteelPalette.textLow.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The list of added players sits directly under the field
                  // that adds them: the journey-length picker used to stand
                  // between the two, so after every name the eye had to jump
                  // over an unrelated control to check the name had landed.
                  if (_playerNames.isNotEmpty) ...[
                    _SideRuleTitle(title: 'В ОТРЯДЕ · ${_playerNames.length}'),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: _playerNames.isEmpty
                        ? Center(
                            child: Text(
                              'Добавьте минимум ${GameConstants.minPlayers} '
                              'игроков, чтобы начать',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: SteelPalette.textLow.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _playerNames.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => _RosterRow(
                              name: _playerNames[index],
                              onRemove: () => _removePlayer(index),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  const _SideRuleTitle(title: 'ДЛИНА ПУТЕШЕСТВИЯ'),
                  const SizedBox(height: 14),
                  JourneyLengthPicker(
                    value: _journeySteps,
                    onChanged: (steps) => setState(() => _journeySteps = steps),
                  ),
                  const SizedBox(height: 18),
                  _StartButton(onPressed: _canStartGame ? _startGame : null),
                  // The empty-state hint in the list disappears as soon as
                  // the first name is added, which left the disabled button
                  // with no stated reason. This says why for as long as it
                  // is disabled.
                  if (!_canStartGame) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Нужно минимум ${GameConstants.minPlayers} игрока',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SteelPalette.textLow.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two faint pools of light instead of a flat fill — the same treatment the
/// title screen and the scene banner use, so this reads as part of the same
/// game rather than as a settings form.
class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.95),
              radius: 1,
              colors: [Color(0x1F9CA3AF), Color(0x009CA3AF)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.85, 0.9),
              radius: 0.9,
              colors: [Color(0x149CA3AF), Color(0x009CA3AF)],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Назад',
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 14, 8),
              child: LineIcon(
                shape: LineIconShape.chevronLeft,
                size: 22,
                color: SteelPalette.textLow,
                strokeWidth: 1.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новая игра',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.26,
                  color: SteelPalette.textHigh,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'СБОР ОТРЯДА',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 2.31,
                  color: SteelPalette.textLow.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A section label with a rule running off to the right — the profile
/// sheet centres its headings between two rules, but there the sections are
/// equals in a document. Here the label starts a list, so the line follows
/// it rather than framing it.
class _SideRuleTitle extends StatelessWidget {
  final String title;

  const _SideRuleTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.53,
            color: SteelPalette.textLow.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SteelPalette.steel.withValues(alpha: 0.35),
                  SteelPalette.steel.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The name field and its add button.
///
/// The placeholder is contextual rather than fixed: "кто ещё идёт" while
/// there is room, "отряд полон" once there is not. It is the shortest way
/// to say the field is closed without printing a rule.
class _NameEntry extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSubmit;

  const _NameEntry({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: SteelPalette.steel.withValues(alpha: 0.05),
              border: Border.all(
                color: SteelPalette.steel.withValues(
                  alpha: enabled ? 0.34 : 0.16,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ИМЯ ИГРОКА',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 1.9,
                    color: SteelPalette.textLow.withValues(alpha: 0.5),
                  ),
                ),
                TextField(
                  key: const Key('player_name_field'),
                  controller: controller,
                  focusNode: focusNode,
                  // The first thing anyone does on this screen is type a
                  // name, so the keyboard is already up when it opens.
                  autofocus: true,
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    color: SteelPalette.textHigh,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: enabled ? 'кто ещё идёт' : 'отряд полон',
                    hintStyle: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      color: SteelPalette.textLow.withValues(alpha: 0.35),
                    ),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Добавить игрока',
          child: GestureDetector(
            onTap: enabled ? onSubmit : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SteelPalette.steel.withValues(
                    alpha: enabled ? 0.34 : 0.16,
                  ),
                ),
                gradient: enabled
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          SteelPalette.steel.withValues(alpha: 0.12),
                          SteelPalette.steel.withValues(alpha: 0.03),
                        ],
                      )
                    : null,
              ),
              child: Icon(
                Icons.add,
                size: 22,
                color: SteelPalette.textLow.withValues(
                  alpha: enabled ? 0.85 : 0.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One name in the squad, shaped like the roster card it will become once
/// the journey starts — same avatar language, same "происхождение скрыто"
/// wording as the game screen's dashed badge, so nothing about a player
/// changes appearance between this screen and the first step.
class _RosterRow extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _RosterRow({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1D21),
        border: Border.all(color: SteelPalette.steel.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SteelPalette.steel.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: SteelPalette.textHigh,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: SteelPalette.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ПРОИСХОЖДЕНИЕ СКРЫТО',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 1.47,
                    color: SteelPalette.textLow.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Удалить игрока',
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: LineIcon(
                  shape: LineIconShape.trash,
                  size: 20,
                  color: SteelPalette.steel,
                  strokeWidth: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The last thing anyone touches before the journey starts, so it gets the
/// menu's press: [TactilePressButton] holds the action back until the
/// press has played through. Unlike "Сделать шаг", which is pressed twenty
/// times a match, this one is pressed once — the weight lands as ceremony
/// rather than as lag.
class _StartButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;

    return TactilePressButton(
      onPressed: onPressed,
      scaleDepth: 0.02,
      builder: (context, press) {
        final dim = (1 - 0.28 * press) * (enabled ? 1.0 : 0.4);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SteelPalette.steel.withValues(alpha: 0.5 * dim),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF22262B), Color(0xFF1A1D21)],
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              // Without this the label — the only non-positioned child —
              // lands in the Stack's top-left corner instead of the middle
              // of the plate.
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.06 * dim),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'НАЧАТЬ ИГРУ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.2,
                      color: SteelPalette.textHigh.withValues(alpha: dim),
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
}
