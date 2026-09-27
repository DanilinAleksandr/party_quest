import 'dart:math' as math;
import 'dart:ui';

/// Parses an SVG path `d` string into a [Path].
///
/// The scene strip is ported from an SVG prototype whose shape makers build
/// their outlines as `d` strings; parsing them keeps the port line-for-line
/// with its source, so a shape here can be checked against the prototype by
/// eye. Covers what those makers use: M L H V Q C A Z, absolute and
/// relative. It runs once per item, when the item appears — never per frame.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = _tokenize(d);
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;

  double next() => double.parse(tokens[i++]);
  bool hasNumber() => i < tokens.length && !_isCommand(tokens[i]);

  while (i < tokens.length) {
    if (_isCommand(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.moveTo(x, y);
        startX = x;
        startY = y;
        // Further pairs after a move are implicit lines.
        cmd = rel ? 'l' : 'L';
      case 'L':
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
      case 'H':
        final nx = next();
        x = rel ? x + nx : nx;
        path.lineTo(x, y);
      case 'V':
        final ny = next();
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
      case 'Q':
        var cx = next(), cy = next(), ex = next(), ey = next();
        if (rel) {
          cx += x;
          cy += y;
          ex += x;
          ey += y;
        }
        path.quadraticBezierTo(cx, cy, ex, ey);
        x = ex;
        y = ey;
      case 'C':
        var c1x = next(), c1y = next(), c2x = next(), c2y = next();
        var ex = next(), ey = next();
        if (rel) {
          c1x += x;
          c1y += y;
          c2x += x;
          c2y += y;
          ex += x;
          ey += y;
        }
        path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
        x = ex;
        y = ey;
      case 'A':
        final rx = next(), ry = next(), rot = next();
        final large = next() != 0, sweep = next() != 0;
        var ex = next(), ey = next();
        if (rel) {
          ex += x;
          ey += y;
        }
        path.arcToPoint(
          Offset(ex, ey),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        x = ex;
        y = ey;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Unsupported path command "$cmd" in "$d"');
    }
    // A command letter with nothing after it (Z) must not loop forever.
    if (cmd.toUpperCase() == 'Z' && hasNumber()) cmd = 'L';
  }
  return path;
}

bool _isCommand(String t) => t.length == 1 && 'MLHVQCAZmlhvqcaz'.contains(t);

final _token = RegExp(r'[MLHVQCAZmlhvqcaz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?');

List<String> _tokenize(String d) => [
  for (final m in _token.allMatches(d)) m.group(0)!,
];

/// Degrees to radians, for the few makers that rotate a group.
double radians(double degrees) => degrees * math.pi / 180;
