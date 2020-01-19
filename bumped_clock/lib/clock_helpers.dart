library bumped_clock.helpers;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

/// Total distance traveled by a second or a minute hand, each second or minute,
/// respectively.
final radiansPerTick = radians(360 / 60);

double secondsRadius(Size size) {
  return size.shortestSide * 0.3;
}

int nextSecondOnTheClock(int second) {
  if (second >= 55) {
    return 0;
  }
  return second + (5 - (second % 5));
}

Offset positionOnTheClockCircum(int second, Size size) {
  final length = secondsRadius(size);
  final center = (Offset.zero & size).center;
  final radian = second * radiansPerTick - math.pi / 2.0;
  return center + Offset(math.cos(radian), math.sin(radian)) * length;
}

Future<ui.Image> pixelsToImage(ByteBuffer pixelsBuffer, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      pixelsBuffer.asUint8List(), width, height, ui.PixelFormat.bgra8888,
      (ui.Image img) {
    completer.complete(img);
  });

  return completer.future;
}

int lightRadius(Size size, Orientation screenOrientation) {
  if (screenOrientation == Orientation.portrait) {
    return (size.longestSide / 3.2).floor();
  } else {
    return (size.shortestSide / 3.5).floor();
  }
}
