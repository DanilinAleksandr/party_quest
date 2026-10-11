import 'dart:math' as math;

/// One arm-wrestling bout, as a pure function of time — a port, one for one,
/// of the design's `arm-wrestle.js`. What it comes to is never decided here:
/// the odds have already settled who wins, and a script only shows it.
///
/// `u(t)` is where the locked hands are, from −1 to +1: +1 is the loser's
/// hand on the table, −1 the winner's. Between the keys the curve is a
/// monotone cubic Hermite (Fritsch–Carlson, the harmonic mean of the
/// slopes), so it never overshoots a key; into the last key the slope is
/// 2.2 times the secant — the hand goes down to the table speeding up, and
/// that is the slam.
enum ArmWrestleScenario {
  quick(
    'Сразу',
    [(0, 0), (0.32, 0.05), (0.85, 0.48), (1.3, 1)],
    [(0, 0.4), (0.3, 1.2), (1.3, 0.6)],
    (10, 30, 60),
  ),
  long(
    'Долгая борьба',
    [
      (0, 0),
      (0.5, 0.1),
      (1.1, -0.14),
      (1.7, 0.08),
      (2.3, -0.1),
      (2.9, 0.16),
      (3.4, 0.08),
      (3.75, 0.42),
      (4.05, 1),
    ],
    [(0, 0.6), (0.5, 2.4), (3.4, 2.8), (3.8, 1.4), (4.05, 0.8)],
    (35, 20, 8),
  ),
  comeback(
    'Камбэк',
    [
      (0, 0),
      (0.35, -0.08),
      (1.2, -0.58),
      (1.8, -0.84),
      (2.5, -0.9),
      (2.95, -0.72),
      (3.35, -0.12),
      (3.7, 0.55),
      (3.95, 1),
    ],
    [
      (0, 0.6),
      (1.2, 1.6),
      (1.8, 3),
      (2.6, 3.2),
      (3.0, 2),
      (3.6, 1.2),
      (3.95, 0.8),
    ],
    (20, 10, 4),
  ),
  almost(
    'Почти',
    [
      (0, 0),
      (0.45, 0.28),
      (1.0, 0.56),
      (1.55, 0.2),
      (1.95, 0.05),
      (2.35, 0.2),
      (2.75, 0.7),
      (2.95, 1),
    ],
    [(0, 0.6), (0.9, 1.4), (1.6, 2.6), (2.1, 2.8), (2.5, 1.6), (2.95, 0.8)],
    (20, 25, 18),
  ),
  swing(
    'Качели',
    [
      (0, 0),
      (0.6, 0.46),
      (1.3, -0.5),
      (1.95, 0.4),
      (2.55, -0.28),
      (3.05, 0.5),
      (3.35, 1),
    ],
    [(0, 0.6), (0.6, 1.6), (2.5, 1.8), (3.0, 1.2), (3.35, 0.8)],
    (15, 15, 10),
  );

  /// The design's name for it — for the debug screen and the contact sheet.
  final String title;

  /// `(t, u)` — see the class.
  final List<(double, double)> keys;

  /// `(t, degrees)` — how hard the locked arms tremble, linear between.
  final List<(double, double)> tremor;

  /// How often it is drawn, in %, when the two are even, a little apart,
  /// far apart (gap 0, 0.5, 1); linear between.
  final (double, double, double) weights;

  const ArmWrestleScenario(this.title, this.keys, this.tremor, this.weights);

  /// How long the fist stays down after the slam before it is over.
  static const double hold = 0.7;

  /// How far the locked hands go over at the most: 84°.
  static const double pin = 84 * math.pi / 180;

  /// The tremor's main frequency, Hz — a buzz on each of its peaks.
  static const double tremorHz = 9.3;

  /// The slam: when the loser's fist meets the table.
  double get hit => keys.last.$1;

  /// When it is over, and the button may come.
  double get end => hit + hold;

  List<double> get _slopes => _slopeCache[index] ??= _findSlopes();
  static final _slopeCache = <int, List<double>>{};

  List<double> _findSlopes() {
    final k = keys, n = k.length, m = List<double>.filled(n, 0);
    for (var i = 1; i < n - 1; i++) {
      final a = (k[i].$2 - k[i - 1].$2) / (k[i].$1 - k[i - 1].$1);
      final b = (k[i + 1].$2 - k[i].$2) / (k[i + 1].$1 - k[i].$1);
      m[i] = a * b <= 0 ? 0 : 2 / (1 / a + 1 / b);
    }
    m[n - 1] = 2.2 * (k[n - 1].$2 - k[n - 2].$2) / (k[n - 1].$1 - k[n - 2].$1);
    return m;
  }

  /// Where the locked hands are at [t] — see the class. After the slam, a
  /// short bounce off the table.
  double u(double t) {
    if (t >= hit) {
      final s = t - hit;
      return 1 - 0.045 * math.exp(-9 * s) * math.sin(18 * s).abs();
    }
    final k = keys, n = k.length, m = _slopes;
    var i = 0;
    while (i < n - 2 && t >= k[i + 1].$1) {
      i++;
    }
    final (t0, p0) = k[i];
    final (t1, p1) = k[i + 1];
    final h = t1 - t0;
    final x = math.max(0.0, (t - t0) / h), x2 = x * x, x3 = x2 * x;
    return math.max(
      -0.97,
      (2 * x3 - 3 * x2 + 1) * p0 +
          (x3 - 2 * x2 + x) * h * m[i] +
          (-2 * x3 + 3 * x2) * p1 +
          (x3 - x2) * h * m[i + 1],
    );
  }

  /// The tremor's amplitude at [t], in degrees; none after the slam.
  double tremorAt(double t) => t >= hit ? 0 : _lin(tremor, t);

  static double _noise(double t) =>
      0.62 * math.sin(2 * math.pi * tremorHz * t + 1.1) +
      0.38 * math.sin(2 * math.pi * 14.1 * t + 0.4) +
      0.3 * math.sin(2 * math.pi * 2.3 * t);

  /// The angle the locked hands stand at, radians. [nearWins]: positive
  /// goes the near player's way. 0 is upright.
  double theta(bool nearWins, double t) =>
      (nearWins ? 1 : -1) * u(t) * pin +
      tremorAt(t) * math.pi / 180 * _noise(t);

  /// The beats the phone plays: a light knock at the start, a click on each
  /// peak of a tremor of 1.4° or more, a heavy one on the slam.
  List<(double, ArmBeat)> get beats {
    final b = <(double, ArmBeat)>[(0, ArmBeat.start)];
    for (
      var t = (0.25 - 1.1 / (2 * math.pi)) / tremorHz;
      t < hit - 0.05;
      t += 1 / tremorHz
    ) {
      if (t > 0.12 && _lin(tremor, t) >= 1.4) {
        b.add((double.parse(t.toStringAsFixed(3)), ArmBeat.tremble));
      }
    }
    b.add((hit, ArmBeat.slam));
    return b;
  }

  /// A script for a bout [gap] lopsided (0 even, 1 as far apart as the odds
  /// go), by [weights], with [roll] in [0, 1).
  static ArmWrestleScenario pick(double gap, double roll) {
    final g = gap.clamp(0.0, 1.0) * 2;
    final i = math.min(1, g.floor());
    final x = g - i;
    double weight(ArmWrestleScenario s) {
      final w = [s.weights.$1, s.weights.$2, s.weights.$3];
      return w[i] + (w[i + 1] - w[i]) * x;
    }

    var s = roll * values.fold(0.0, (a, v) => a + weight(v));
    for (final v in values) {
      if ((s -= weight(v)) <= 0) return v;
    }
    return values.first;
  }

  static double _lin(List<(double, double)> keys, double t) {
    if (t <= keys.first.$1) return keys.first.$2;
    for (var i = 1; i < keys.length; i++) {
      if (t <= keys[i].$1) {
        final (a, p) = keys[i - 1];
        final (b, q) = keys[i];
        return p + (q - p) * (t - a) / (b - a);
      }
    }
    return keys.last.$2;
  }
}

/// How lopsided a bout at [odds] is, for [ArmWrestleScenario.pick]: the
/// odds run 25–75 %, so 50 % is 0 and either end is 1.
double armWrestleGap(double odds) => ((odds - 0.5).abs() / 0.25).clamp(0, 1);

/// A beat of a bout the phone plays — see [ArmWrestleScenario.beats].
enum ArmBeat { start, tremble, slam }
