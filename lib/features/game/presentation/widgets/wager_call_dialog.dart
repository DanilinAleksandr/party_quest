import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/widgets/app_dialog_shell.dart';

/// Asks the player to call it before the throw — "Король или Шут?".
///
/// The two sides are the coin's own faces — the King for order, the Jester
/// for chance — so each button carries the mark the coin will land on.
///
/// Only for the gambles a person in the scene actually offered. A ledge does
/// not let you pick a side, and pretending it does would make every risk in
/// the game feel like the same minigame. The odds are untouched either way:
/// calling a side changes who you are gambling *against*, not what the throw
/// is worth.
///
/// Returns the index of the side the player called, or null if the dialog
/// was somehow dismissed — which the caller treats as no call at all rather
/// than as a silent default, since a wager nobody answered should not
/// quietly resolve as though they had.
Future<int?> showWagerCallDialog({
  required BuildContext context,
  required List<String> sides,
}) {
  return showAppDialog<int>(
    context: context,
    icon: Icons.front_hand_outlined,
    title: 'Твоя ставка',
    barrierDismissible: false,
    content: const SizedBox(
      width: double.infinity,
      child: Text('Назови сторону, прежде чем бросят.'),
    ),
    actions: [
      for (var i = 0; i < sides.length; i++)
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(i),
          // The mark the coin will land on, beside the name of it — so the
          // player recognises the face when it comes up rather than reading
          // the receipt to find out what they were looking at.
          icon: SvgPicture.asset(
            i == 0
                ? 'assets/icons/coin/coin_king.svg'
                : 'assets/icons/coin/coin_jester.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
          label: Text(sides[i]),
        ),
    ],
  );
}
