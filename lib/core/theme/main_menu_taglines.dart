import 'dart:math';

/// Subtitle lines for the main menu. One is picked per visit to the screen,
/// so the menu says something slightly different every time the app is
/// opened — the first thing the game does is promise variety, and a fixed
/// tagline quietly contradicts that promise.
const List<String> mainMenuTaglines = [
  'Путешествие за столом',
  'Один телефон. Шесть судеб.',
  'Кость брошена — отступать некуда',
  'Сегодня решает удача, а не трезвый расчёт',
  'Помни. Или расскажи заново.',
  'Дорога начинается с первого глотка',
  'Каждый шаг — чужая история',
  'Кто-то здесь узнает себя',
];

/// Takes an optional [random] so a test can pin the line without touching
/// global state.
String randomMainMenuTagline([Random? random]) {
  final rng = random ?? Random();
  return mainMenuTaglines[rng.nextInt(mainMenuTaglines.length)];
}
