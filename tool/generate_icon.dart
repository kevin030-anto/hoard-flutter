// One-off generator for the FinFlow app icon. Run with:
//   dart run tool/generate_icon.dart
// Produces assets/icon/finflow_icon.png (1024x1024), then run
// `dart run flutter_launcher_icons` to install it across platforms.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

void main() {
  const size = 1024;
  final img = Image(width: size, height: size, numChannels: 4);

  // Indigo -> blue diagonal gradient background.
  final c1 = ColorRgb8(0x7B, 0x6C, 0xF6);
  final c2 = ColorRgb8(0x5B, 0x7B, 0xFF);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      img.setPixelRgba(
        x,
        y,
        _lerp(c1.r, c2.r, t),
        _lerp(c1.g, c2.g, t),
        _lerp(c1.b, c2.b, t),
        255,
      );
    }
  }

  // Rounded-square mask (transparent corners).
  const radius = 230;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (_outsideRoundedRect(x, y, size, radius)) {
        img.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }

  // White "flow" wave: an upward sine-ish ribbon ending in an arrow.
  final white = ColorRgb8(255, 255, 255);
  final pts = <math.Point<double>>[];
  for (var i = 0; i <= 100; i++) {
    final p = i / 100;
    final x = 230 + p * 560;
    final y = 640 - p * 300 + math.sin(p * math.pi * 2) * 70;
    pts.add(math.Point(x, y));
  }
  for (var i = 0; i < pts.length - 1; i++) {
    drawLine(img,
        x1: pts[i].x.round(),
        y1: pts[i].y.round(),
        x2: pts[i + 1].x.round(),
        y2: pts[i + 1].y.round(),
        color: white,
        thickness: 46,
        antialias: true);
  }
  // Arrow head at the end.
  final tip = pts.last;
  drawLine(img,
      x1: tip.x.round(),
      y1: tip.y.round(),
      x2: (tip.x - 90).round(),
      y2: (tip.y + 20).round(),
      color: white,
      thickness: 46,
      antialias: true);
  drawLine(img,
      x1: tip.x.round(),
      y1: tip.y.round(),
      x2: (tip.x - 30).round(),
      y2: (tip.y + 110).round(),
      color: white,
      thickness: 46,
      antialias: true);

  final dir = Directory('assets/icon')..createSync(recursive: true);
  File('${dir.path}/finflow_icon.png').writeAsBytesSync(encodePng(img));
  stdout.writeln('Wrote assets/icon/finflow_icon.png');
}

int _lerp(num a, num b, double t) => (a + (b - a) * t).round().clamp(0, 255);

bool _outsideRoundedRect(int x, int y, int size, int r) {
  final cx = x < r
      ? r
      : (x > size - r ? size - r : x);
  final cy = y < r
      ? r
      : (y > size - r ? size - r : y);
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy > r * r;
}
