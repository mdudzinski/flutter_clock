// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import 'bumped_clock.dart';


/// Based on the analog clock from the examples.
class Clock extends StatefulWidget {
  const Clock(this.model);

  final ClockModel model;

  @override
  _ClockState createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  var _now = DateTime.now();
  var _condition;
  bool _is24HoursFormat;
  bool _shouldReload;
  Orientation currentOrientation;
  Timer _timer;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    // Set the initial values.
    _updateTime();
    _updateModel();
  }

  @override
  void didUpdateWidget(Clock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      _condition = widget.model.weatherCondition;
      if (widget.model.is24HourFormat != _is24HoursFormat) {
        _shouldReload = true;
        _is24HoursFormat = widget.model.is24HourFormat;
      }
    });
  }

  void _updateTime() {
    setState(() {
      _now = DateTime.now();
      _shouldReload = false;
      // Update once per second. Make sure to do it at the beginning of each
      // new second, so that the clock is accurate.
      _timer = Timer(
        Duration(seconds: 1) - Duration(milliseconds: _now.millisecond),
        _updateTime,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hms().format(DateTime.now());

    return Semantics.fromProperties(
      properties: SemanticsProperties(
        label: 'BUmped clock with time $time',
        value: time,
      ),
      child: OrientationBuilder(
        builder: (context, orientation) {
           return  Container(
            child: BumpedClock(time: _now, weatherCondition: _condition, is24HourFormat: _is24HoursFormat, shouldReload: _shouldReload,));
      }),
    );
  }
}
