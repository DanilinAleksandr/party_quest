import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import 'rarity_frame.dart';

/// Identifies the dialog's content container in the widget tree — since
/// [showAppDialog] doesn't build an `AlertDialog`, tests that need to find
/// "is a dialog open" (rather than a specific button/text inside it) look
/// for this key instead of a type.
const Key appDialogContentKey = Key('app_dialog_content');

/// Replaces raw `AlertDialog` everywhere a card/adventure/choice needs to
/// interrupt the table — consistent dark surface, an accent-colored icon
/// header, and a fade+scale entrance (via `showGeneralDialog`'s
/// `transitionBuilder`, no extra package) instead of the platform's
/// instant default dialog pop-in.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required IconData icon,
  required String title,
  required Widget content,
  required List<Widget> actions,
  Color? accentColor,
  Rarity? rarity,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AppDialogContent(
        icon: icon,
        title: title,
        content: content,
        actions: actions,
        accentColor: accentColor,
        rarity: rarity,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: curved.value.clamp(0, 1),
        child: Transform.scale(
          scale: 0.92 + 0.08 * curved.value,
          child: child,
        ),
      );
    },
  );
}

class _AppDialogContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color? accentColor;
  final Rarity? rarity;

  const _AppDialogContent({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.accentColor,
    this.rarity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;
    final borderRadius = BorderRadius.circular(20);

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 44px rather than 60: the icon repeats information the accent
        // color and the title already carry, and on a phone every pixel it
        // takes pushes the scene text further down a dialog the table reads
        // twenty-odd times a match.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        content,
        const SizedBox(height: 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions) ...[
              SizedBox(width: double.infinity, child: action),
              if (action != actions.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ],
    );

    // With a rarity, the frame's glow shape scales with the tier (see
    // AppColors.glowFor) while staying tinted with this dialog's own accent
    // color — a common event stays nearly bare, a legendary one pulses.
    // Without one (adventure/participant dialogs), fall back to the simple
    // flat-alpha border this shell always had.
    final decoratedContent = rarity != null
        ? RarityFrame(
            rarity: rarity!,
            color: color,
            borderRadius: borderRadius,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: inner,
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: inner,
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          // The whole card scrolls as one unit when it doesn't fit —
          // `SingleChildScrollView` shrink-wraps under loose constraints, so
          // an ordinary dialog is still exactly as tall as its content and
          // still centered; only an overlong one starts scrolling. Without
          // this, a wordy adventure node with five choices (or a player with
          // a large system font scale) silently clips its bottom buttons,
          // which in this game means an unreachable choice.
          child: SingleChildScrollView(
            child: Material(
              key: appDialogContentKey,
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: borderRadius,
              elevation: 8,
              child: decoratedContent,
            ),
          ),
        ),
      ),
    );
  }
}
