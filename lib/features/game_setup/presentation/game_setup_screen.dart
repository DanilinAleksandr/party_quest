import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/constants/journey_length_config.dart';
import 'widgets/journey_length_picker.dart';

/// Ephemeral form state — this screen only builds the player list that gets
/// handed off to the game engine, so a local [State] is enough. It doesn't
/// need to be visible to (or survive outside of) this one screen.
///
/// Deliberately no origin picker here: origins are hidden at the start of
/// the game and only surface through rare in-game events — see `Origin`/
/// `RevealOriginAction`. Every player starts "Неизвестный".
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
      appBar: AppBar(title: const Text('Новая игра')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('player_name_field'),
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      // The first thing anyone does on this screen is type a
                      // name, so the keyboard is already up when it opens.
                      autofocus: true,
                      enabled: _canAddPlayer,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Имя игрока',
                        border: const OutlineInputBorder(),
                        helperText: _canAddPlayer
                            ? 'Игроков: ${_playerNames.length} / ${GameConstants.maxPlayers}'
                            : 'Достигнут лимит игроков',
                      ),
                      onSubmitted: (_) => _addPlayer(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _canAddPlayer ? _addPlayer : null,
                    icon: const Icon(Icons.add),
                    tooltip: 'Добавить игрока',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // The list of added players sits directly under the field that
              // adds them: the journey-length picker used to stand between
              // the two, so after every name the eye had to jump over an
              // unrelated control to check the name had landed.
              Expanded(
                child: _playerNames.isEmpty
                    ? const Center(
                        child: Text('Добавьте минимум 2 игроков, чтобы начать'),
                      )
                    : ListView.separated(
                        itemCount: _playerNames.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(_playerNames[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Удалить игрока',
                                onPressed: () => _removePlayer(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Text('Длина путешествия', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              JourneyLengthPicker(
                value: _journeySteps,
                onChanged: (steps) => setState(() => _journeySteps = steps),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canStartGame ? _startGame : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Начать игру'),
                ),
              ),
              // The empty-state hint in the list disappears as soon as the
              // first name is added, which left the disabled button with no
              // stated reason. This says why for as long as it is disabled.
              if (!_canStartGame) ...[
                const SizedBox(height: 6),
                Text(
                  'Нужно минимум ${GameConstants.minPlayers} игрока',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
