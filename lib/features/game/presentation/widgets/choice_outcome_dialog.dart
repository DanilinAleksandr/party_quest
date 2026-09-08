import 'package:flutter/material.dart';

import '../../../../core/widgets/app_dialog_shell.dart';

/// The outcome step as a caller sees it: one extra screen for the options
/// that have something to say, and not so much as a frame of delay for the
/// ones that do not.
///
/// The null case is the common one — most of the choices in the content
/// carry no [outcome] yet — so it has to cost nothing, which is why the
/// guard lives here rather than in a conditional at every call site.
Future<void> tellChoiceOutcome(BuildContext context, String? outcome) async {
  if (outcome == null) return;
  await showChoiceOutcomeDialog(context: context, outcome: outcome);
}

/// The same beat for a gamble, told as part of the scene rather than as a
/// notice from the app.
///
/// A wager's aftermath is not a generic "Последствие" — it is the second
/// half of *this* card. It keeps the card's own title, and its text is
/// introduced by "В результате:", so the screen reads as the story
/// continuing rather than as the system reporting. The plain dialog above
/// stays exactly as it was for every ordinary choice, where there is no
/// scene to continue and a neutral heading is the honest one.
Future<void> tellGambleOutcome(
  BuildContext context,
  String? outcome, {
  required String cardTitle,
}) async {
  if (outcome == null) return;
  await showAppDialog<void>(
    context: context,
    icon: Icons.subdirectory_arrow_right_rounded,
    title: cardTitle,
    barrierDismissible: false,
    content: _GambleOutcomeBody(outcome: outcome),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Понятно'),
      ),
    ],
  );
}

class _GambleOutcomeBody extends StatelessWidget {
  final String outcome;

  const _GambleOutcomeBody({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'В РЕЗУЛЬТАТЕ',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.52,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            outcome,
            textAlign: TextAlign.start,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// The beat between picking an option and the table finding out what it cost.
///
/// Until this existed, a choice with no visible effect — and most of them
/// have none — closed its dialog and left nothing behind: the player learned
/// what happened only if they later opened their profile and noticed a new
/// stat. This says it out loud, in the words the content author wrote.
///
/// Deliberately plainer than the card dialog it follows: no rarity frame, no
/// participant banner, and the theme's own neutral accent rather than a card
/// type's colour. A consequence is neither good nor bad news by itself, and
/// this screen appears immediately after a far louder one — matching that
/// one's weight would read as a second event rather than as its echo.
///
/// Only shown when the chosen option actually carries an [outcome]; see
/// `CardChoice.outcome` for why that is the exception rather than the rule,
/// and [tellChoiceOutcome] for the guard that skips this step entirely.
Future<void> showChoiceOutcomeDialog({
  required BuildContext context,
  required String outcome,
}) {
  return showAppDialog<void>(
    context: context,
    // "And then this": the one glyph in the set that means consequence
    // rather than category, which is the whole content of this dialog.
    icon: Icons.subdirectory_arrow_right_rounded,
    title: 'Последствие',
    barrierDismissible: false,
    content: SizedBox(
      // Left-aligned and full width for the same reason the card's scene
      // text is: this is body copy that wraps, and centred wrapped lines
      // each start at a different x.
      width: double.infinity,
      child: Text(
        outcome,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Понятно'),
      ),
    ],
  );
}
