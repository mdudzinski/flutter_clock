import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:analog_clock/bumped_image.dart';
import 'package:flutter/material.dart';

import 'clock_helpers.dart';

class Clock extends StatefulWidget {
  const Clock({@required this.time}) : assert(time != null);
  final DateTime time;
  @override
  State<StatefulWidget> createState() {
    return ClockState();
  }
}

class ClockState extends State<Clock> with TickerProviderStateMixin {
  GlobalKey _key =
      GlobalKey(); // Needed to determine the available size for the clock face generation
  Size _size;
  Orientation _currentOrientation;
  ImageBumpMapper _imageBumpMapper;
  int _lightRadius;
  AnimationController _lightMovementController;
  Animation<Offset> _lightOffset;
  DateTime _currentHourAndMin;

  @override
  Widget build(BuildContext context) {
    _resetIfOrientationChanged(context);

    return Center(
        key: _key,
        child: SizedBox.expand(
            child: FutureBuilder<ui.Image>(
          future: _process(_getSize()),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return CustomPaint(
                painter: _ImagePainter(image: snapshot.data),
              );
            } else {
              return Container(
                  decoration: BoxDecoration(color: Colors.black),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ));
            }
          },
        )));
  }

  // if the orientation of the device has changed, we need to reset data in order to generate a new clock face according to the new size available
  void _resetIfOrientationChanged(BuildContext context) {
    var actualOrientation = MediaQuery.of(context).orientation;
    if (_currentOrientation == null) {
      _currentOrientation = actualOrientation;
    }

    if (_currentOrientation != actualOrientation) {
      _reset(actualOrientation);
    }
  }

  void _reset(Orientation actualOrientation) {
    _key = GlobalKey();
    _imageBumpMapper = null;
    _size = null;
    _currentOrientation = actualOrientation;
    _lightRadius = null;
  }

  Size _getSize() {
    if (_key.currentContext == null) {
      // may be null at the very beginning, just return Size.zero and keep checking till it returns a value
      return Size.zero;
    }
    if (_size == null) {
      final RenderBox renderBox = _key.currentContext.findRenderObject();
      _size = renderBox.size;
    }
    return _size;
  }

  Future<ui.Image> _process(Size size) async {
    if (_hasHourOrMinuteChanged()) {
      _imageBumpMapper =
          null; // force generation of a new clock face with updated hour and minute
    }
    if (_imageBumpMapper == null) {
      final ui.Image face = await _generateClockFace(size);
      final ByteData facePixels =
          await face.toByteData(format: ui.ImageByteFormat.rawRgba);

      _imageBumpMapper = ImageBumpMapper(facePixels, face);
      _imageBumpMapper.init();
    }

    if (_lightRadius == null) {
      _lightRadius = lightRadius(size, _currentOrientation);
    }

    _animateLight();
    final position = _lightOffset.value;
    _imageBumpMapper.update(
        position.dx.toInt(), position.dy.toInt(), _lightRadius);

    return pixelsToImage(_imageBumpMapper.getPixelsBuffer(), size.width.toInt(),
        size.height.toInt());
  }

  Future<ui.Image> _generateClockFace(ui.Size size) async {
    final pictureRecorder = new ui.PictureRecorder();
    final canvas = new Canvas(pictureRecorder);

    _ClockFaceGeneratorPainter(time: widget.time).paint(canvas, size);
    _currentHourAndMin = widget.time;
    final ui.Image face = await pictureRecorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor());
    return face;
  }

  bool _hasHourOrMinuteChanged() =>
      _currentHourAndMin != null &&
      (_currentHourAndMin.hour != widget.time.hour ||
          _currentHourAndMin.minute != widget.time.minute);

  void _animateLight() {
    final center = (Offset.zero & _getSize()).center;
    if (_lightMovementController == null) {
      final endOffset =
          positionForDigit(nextDigit(widget.time.second), _getSize());
      _setupController(nextDigit(widget.time.second) -
          widget.time
              .second); // ensure the time is accurate by checking how many seconds left for the light to get to the next digit on the clock
      _setupTween((Offset.zero & _getSize()).center, endOffset);
      _lightMovementController.forward();
      _lightMovementController.addListener(() => setState(() {}));
    } else if (_lightMovementController.status != AnimationStatus.forward) {
      // it may happen that the first animation hasn't started at this point (it has status dismissed) so we can't check only for status completed here
      _setupController(5);
      final startOffset = _lightOffset.value;
      final endOffset =
          positionForDigit(nextDigit(widget.time.second), _getSize());

      _lightOffset = TweenSequence(<TweenSequenceItem<Offset>>[
        TweenSequenceItem<Offset>(
            tween: Tween<Offset>(begin: startOffset, end: center)
                .chain(CurveTween(curve: Curves.elasticInOut)),
            weight: 50.0),
        TweenSequenceItem<Offset>(
            tween: Tween<Offset>(begin: center, end: endOffset)
                .chain(CurveTween(curve: Curves.elasticInOut)),
            weight: 50.0),
      ]).animate(_lightMovementController);
      _lightMovementController.forward();
      _lightMovementController.addListener(() {
        setState(() {});
      });
    }
  }

  void _setupController(int duration) {
    _lightMovementController =
        AnimationController(vsync: this, duration: Duration(seconds: duration));
  }

  void _setupTween(Offset begin, Offset end) {
    _lightOffset = Tween<Offset>(begin: begin, end: end).animate(
        CurvedAnimation(
            parent: _lightMovementController,
            curve: Interval(0.0, 1.0, curve: Curves.elasticInOut)));
  }
}

// Responsible for drawing intentionally blurred clock face, depending on the available size.
class _ClockFaceGeneratorPainter extends CustomPainter {
  static const secondsDisplay = {
    0: '12',
    5: '5',
    10: '10',
    15: '15',
    20: '20',
    25: '25',
    30: '30',
    35: '35',
    40: '40',
    45: '45',
    50: '50',
    55: '55'
  };

  const _ClockFaceGeneratorPainter({this.time}) : assert(time != null);
  final DateTime time;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSeconds(canvas, size);
    _drawHourAndMinute(canvas, size);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }

  void _drawSeconds(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final secondsFontSize = _secondsFontSize(size);
    final length = secondsRadius(size);
    secondsDisplay.forEach((second, display) {
      final radian = second * radiansPerTick - math.pi / 2.0;
      final position =
          center + Offset(math.cos(radian), math.sin(radian)) * length;

      final ui.TextStyle style = ui.TextStyle(
          fontSize: secondsFontSize,
          foreground: Paint()
            ..color = Colors.grey
            ..maskFilter = MaskFilter.blur(BlurStyle.inner, 6));
      final ui.ParagraphBuilder paragraphBuilder =
          ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
            ..pushStyle(style)
            ..addText(display);
      final secondPosition =
          _calculateSecondOffset(position, second, secondsFontSize);
      canvas.drawParagraph(
          paragraphBuilder.build()
            ..layout(ui.ParagraphConstraints(
                width: _calculateSecondParagraphWidth(second, secondsFontSize))),
          secondPosition);
    });
  }

  void _drawHourAndMinute(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final hourAndMinFontSize = _hourAndMinFontSize(size);
    final ui.TextStyle style = ui.TextStyle(
        fontSize: hourAndMinFontSize,
        foreground: Paint()
          ..color = Colors.grey
          ..maskFilter = MaskFilter.blur(BlurStyle.inner, 4.5));
    final ui.ParagraphBuilder paragraphBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.left))
          ..pushStyle(style)
          ..addText(_hourAndMinToDisplay(time));
    canvas.drawParagraph(
        paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: size.width)),
        _calculateHourAndMinOffset(center, hourAndMinFontSize));
  }

  double _calculateSecondParagraphWidth(int second, double secondsFontSize) {
    if (second == 5) {
      return secondsFontSize;
    } else {
      return 2 * secondsFontSize;
    }
  }

  ui.Offset _calculateHourAndMinOffset(
          ui.Offset center, double hourAndMinFontSize) =>
      center - Offset(hourAndMinFontSize * 1.5, hourAndMinFontSize / 2);
  double _secondsFontSize(Size size) => size.shortestSide * 0.8 / 12.5;

  double _hourAndMinFontSize(Size size) => size.shortestSide * 0.1;

  String _hourAndMinToDisplay(DateTime time) =>
      "${time.hour} : ${time.minute > 9 ? time.minute : "0${time.minute}"}";

  ui.Offset _calculateSecondOffset(
      ui.Offset position, int second, double secondsFontSize) {
    if (second == 5) {
      return position - Offset(secondsFontSize / 2, secondsFontSize);
    } else {
      return position - Offset(secondsFontSize, secondsFontSize);
    }
  }
}

class _ImagePainter extends CustomPainter {
  ui.Image image;

  _ImagePainter({this.image});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}