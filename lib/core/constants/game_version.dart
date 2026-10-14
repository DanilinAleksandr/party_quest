/// The game's version is the number of the pull request that made it: every
/// change lands through one, and a playtester who says «на #71 было так»
/// points at exactly the build they played. Raised in each pull request to
/// that request's own number.
const int kGameVersionPr = 71;

/// How the version reads in the settings.
String get gameVersionLabel => 'Версия игры: #$kGameVersionPr';
