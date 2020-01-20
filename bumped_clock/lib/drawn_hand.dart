// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'hand.dart';

/// A clock hand that is drawn with [CustomPainter]
///
/// The hand's length scales based on the clock's size.
/// This hand is used to build the second and minute hands, and demonstrates
/// building a custom hand.
class DrawnHand extends Hand {
  /// Create a const clock [Hand].
  ///
  /// All of the parameters are required and must not be null.
  const DrawnHand({
    @required Color color,
    @required this.thickness,
    @required double size,
    @required double angleRadians,
  })  : assert(color != null),
        assert(thickness != null),
        assert(size != null),
        assert(angleRadians != null),
        super(
          color: color,
          size: size,
          angleRadians: angleRadians,
        );

  /// How thick the hand should be drawn, in logical pixels.
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _HandPainter(
            handSize: size,
            lineWidth: thickness,
            angleRadians: angleRadians,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// [CustomPainter] that draws a clock hand.
class _HandPainter extends CustomPainter {
  _HandPainter({
    @required this.handSize,
    @required this.lineWidth,
    @required this.angleRadians,
    @required this.color,
  })  : assert(handSize != null),
        assert(lineWidth != null),
        assert(angleRadians != null),
        assert(color != null),
        assert(handSize >= 0.0),
        assert(handSize <= 1.0);

  double handSize;
  double lineWidth;
  double angleRadians;
  Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    // We want to start at the top, not at the x-axis, so add pi/2.
    final angle = angleRadians - math.pi / 2.0;
    final length = size.shortestSide * 0.5 * handSize;
    final position = center + Offset(math.cos(angle), math.sin(angle)) * length;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.square
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 1.5);
    final width = size.width.toInt();
    final height = size.height.toInt();
    Float32List pixels = Float32List(width * height);
    List<Offset> points = List(width * height);
    List<Color> colors = List(width * height);
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        int index = y * width + x;
        //pixels[index] = generatePixel(x, y, size);
        points[index] = Offset(x.toDouble(), y.toDouble());
        colors[index] = generatePixel(x, y, size);
      }
    }
    final pointsPaint = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 1;
    canvas.drawPoints(PointMode.points, points, pointsPaint);
    canvas.drawLine(center, position, linePaint);
  }

  @override
  bool shouldRepaint(_HandPainter oldDelegate) {
    return oldDelegate.handSize != handSize ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.angleRadians != angleRadians ||
        oldDelegate.color != color;
  }

  Color generatePixel(int x, int y, Size size) {
    return Color.fromRGBO(x, 0, y, 1.0);
  }
}
