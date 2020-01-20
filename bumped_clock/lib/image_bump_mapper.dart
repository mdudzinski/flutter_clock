import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'package:flutter/painting.dart';

enum LightColor { violet, coldblue, iceblue, orange, teal, grey, yellow }

class ImageBumpMapper {
  final ByteData _bytes; // assumes rgba format
  final int _width;
  final int _height;
  final List<List<Vector2>> _normals;

  Int32List _pixels;

  ImageBumpMapper(this._bytes, image)
      : _width = image.width,
        _height = image.height,
        // initialize the normals map with placeholders
        _normals = List.generate(image.height,
            (_) => List.generate(image.width, (_) => Vector2(0, 0)));

  void init() {
    final List<List<int>> pixelsHeightMap =
        List.generate(_height, (_) => List(_width));

    for (var i = 0; i < _height; i++) {
      for (var j = 0; j < _width; j++) {
        var color = getColorAt(j, i);
        pixelsHeightMap[i][j] = color.value & 0xff;
      }
    }

    for (var i = 0; i < _height; i++) {
      for (var j = 0; j < _width; j++) {
        if (i == 0 || i == _height - 1 || j == 0 || j == _width - 1) {
          continue;
        }

        final newX =
            (pixelsHeightMap[i][j - 1] - pixelsHeightMap[i][j + 1]).toDouble();
        final newY =
            (pixelsHeightMap[i - 1][j] - pixelsHeightMap[i + 1][j]).toDouble();

        _normals[i][j] = Vector2(newX, newY);
      }
    }

    _pixels = Int32List(_width * _height);
  }

  void update(int lightX, int lightY, int lightRadius, LightColor lightColor) {
    for (var i = 0; i < _height; i++) {
      for (var j = 0; j < _width; j++) {
        final normalVector = _normals[i][j];
        final lightVector =
            Vector2((lightX - j).toDouble(), (lightY - i).toDouble());

        final int light = _calculateLightFactor(normalVector, lightVector);
        final int shade = _calculateShadeFactor(lightVector, lightRadius);

        final color = getColorAt(j, i);
        final _Pixel pixel =
            _Pixel(r: color.red, g: color.green, b: color.blue);

        pixel.applyLight(light);
        pixel.applyShade(shade);
        pixel.applyColors(lightColor);

        final int index = i * _width + j;
        _pixels[index] = pixel.toColor().value;
      }
    }
  }

  int _calculateLightFactor(final Vector2 normal, final Vector2 light) {
    double dotProduct = normal.dot(light);
    final softness = pow(2, 13);
    final double ratio = (dotProduct + softness / 2) / softness;
    return (ratio * 255).floor();
  }

  int _calculateShadeFactor(final Vector2 lightVector, final int lightRadius) {
    final double distanceFromOrigin = lightVector.distanceTo(Vector2(0, 0));
    final double ratio = (distanceFromOrigin / lightRadius);
    return (ratio * 255).floor();
  }

  ByteBuffer getPixelsBuffer() {
    return _pixels.buffer;
  }

  Color getColorAt(int x, int y) {
    var byteOffset = (x + y * _width) * 4;
    var argb = _bytes.getUint32(byteOffset);
    return Color(argb);
  }
}

// Simple rgb wrapper for passing around light & shade calculation results
// The Color class cannot be easily used because it does byte shifts on update where we want to limit individual color
// values to 0 - 255 after light and shade is applied.
class _Pixel {
  _Pixel({this.r, this.g, this.b});
  int r;
  int g;
  int b;

  void applyLight(int light) {
    r += light;
    g += light;
    b += light;
  }

  void applyShade(int shade) {
    r -= shade;
    g -= shade;
    b -= shade;
  }

  void applyColors(LightColor color) {
    if (color == null) {
      return;
    }
    double redFactor = 1.0;
    double blueFactor = 1.0;
    double greenFactor = 1.0;
    switch (color) {
      case LightColor.violet:
        blueFactor = 1.4;
        break;
      case LightColor.coldblue:
        blueFactor = 1.9;
        greenFactor = 1.2;
        redFactor = 0.7;
        break;
      case LightColor.iceblue:
        blueFactor = 2.0;
        greenFactor = 1.4;
        redFactor = 0.5;
        break;
      case LightColor.orange:
        redFactor = 1.8;
        greenFactor = 1.15;
        blueFactor = 0.5;
        break;
      case LightColor.grey:
        redFactor = 0.55;
        greenFactor = 0.55;
        blueFactor = 0.55;
        break;
      case LightColor.teal:
        redFactor = 0.35;
        greenFactor = 0.55;
        blueFactor = 0.55;
        break;
      case LightColor.yellow:
        redFactor = 1.1;
        greenFactor = 1.05;
        blueFactor = 0.0;
        break;
    }

    r = (r * redFactor).floor();
    b = (b * blueFactor).floor();
    g = (g * greenFactor).floor();
  }

  Color toColor() {
    if (r < 0) r = 0;
    if (r > 255) r = 255;
    if (g < 0) g = 0;
    if (g > 255) g = 255;
    if (b < 0) b = 0;
    if (b > 255) b = 255;
    return Color.fromARGB(255, r, g, b);
  }
}
