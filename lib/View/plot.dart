import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:umbrella/Model/BeaconInfo.dart';
import 'package:umbrella/View/NearbyScreen.dart';

import '../Model/AppStateModel.dart';
import '../Model/facilities.dart';
import 'dart:ui' as ui;

List<double> getVerticesX() {
  List<Floor> floors = AppStateModel.instance.getFloors();
  final List<double> verticesX = [];

  for (var floor in floors) {
    for (var vertex in floor.vertices) {
      verticesX.add(vertex['x'] as double);
    }
  }

  return verticesX;
}

List<double> getVerticesY() {
  List<Floor> floors = AppStateModel.instance.getFloors();
  final List<double> verticesY = [];

  for (var floor in floors) {
    for (var vertex in floor.vertices) {
      verticesY.add(vertex['y'] as double);
    }
  }

  return verticesY;
}

List<PointPlace> pointsPlaces() {
  List<Place> places = AppStateModel.instance.getPlaces();
  final List<PointPlace> pointPlaces = [];

  for (var place in places) {
    pointPlaces.add(PointPlace(place.x, place.y, Colors.red, place.name));
  }

  return pointPlaces;
}

List<PointPlace> pointsBeacons() {
  List<BeaconInfo> beacons = AppStateModel.instance.getAnchorBeacons();
  final List<PointPlace> pointBeacons = [];

  for (var beacon in beacons) {
    pointBeacons.add(PointPlace(beacon.x, beacon.y, Colors.blue, ''));
  }

  return pointBeacons;
}

Map<String, double> getTransform(
    Size size, List<double> verticesX, List<double> verticesY) {
  if (verticesX.length == 0 || verticesY.length == 0) {
    return null;
  }

  final double diffX = verticesX.reduce(max) - verticesX.reduce(min);
  final double diffY = verticesY.reduce(max) - verticesY.reduce(min);
  final propX = size.width / diffX;
  final propY = size.height / diffY;

  final proportion = propX < propY ? propX : propY;

  final Map<String, double> transformation = {
    'proportion': proportion,
    'offsetX': propX > propY ? (size.width - (diffX * proportion)) / 2 : 0,
    'offsetY': propX > propY ? 0 : (size.height - (diffY * proportion)) / 2,
  };

  return transformation;
}

Offset getCoordinatesToPixels(
    PointPlace point, Map<String, double> transformation) {
  return point.offset * transformation['proportion'] +
      Offset(transformation['offsetX'], transformation['offsetY']);
}

Offset getPixelsToCoordinates(
    PointPlace point, Map<String, double> transformation) {
  return (point.offset -
          Offset(transformation['offsetX'], transformation['offsetY'])) /
      transformation['proportion'];
}

class PlotMap extends CustomPainter {
  final Function(PointPlace) onPointPressed;
  final Function() onOutsidePressed;

  PlotMap(this.onPointPressed, this.onOutsidePressed);

  Path createPath(Map<String, double> transform) {
    var path = Path();
    final verticesX = getVerticesX();
    final verticesY = getVerticesY();

    for (int i = 1; i <= verticesX.length; i++) {
      final x =
          verticesX[i - 1] * transform['proportion'] + transform['offsetX'];
      final y =
          verticesY[i - 1] * transform['proportion'] + transform['offsetY'];

      if (i == 1) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final transformation = getTransform(size, getVerticesX(), getVerticesY());
    if (transformation != null) {
      Paint paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.fill
        ..strokeWidth = 8.0;

      Path path = createPath(transformation);
      path.close();
      canvas.drawPath(path, paint);

      for (final point in pointsPlaces()) {
        final paint = Paint()
          ..color = point.color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;

        canvas.drawCircle(
            getCoordinatesToPixels(point, transformation), 8, paint);
      }

      for (final point in pointsBeacons()) {
        final paint = Paint()
          ..color = point.color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

        canvas.drawCircle(
            getCoordinatesToPixels(point, transformation), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  void handlePointPressed(Offset localPosition, Size size) {
    final transformation = getTransform(size, getVerticesX(), getVerticesY());

    for (final point in pointsPlaces()) {
      final point_ = getCoordinatesToPixels(point, transformation);
      if ((localPosition - point_).distance <= 20.0) {
        onPointPressed(
            PointPlace(point_.dx, point_.dy, point.color, point.nombre));
        return;
      }
    }

    onOutsidePressed();
  }
}

class PlotLocationPainter extends CustomPainter {
  List<Point> points = [];
  final Offset destination;
  final bool isFrozen;
  final distance = StreamController<double>();

  PlotLocationPainter(this.points, this.destination, this.isFrozen);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 20.0
      ..strokeCap = StrokeCap.round;
    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    if (!isFrozen && this.points.length > 0) {
      final verticesX = getVerticesX();
      final verticesY = getVerticesY();
      final transformation = getTransform(size, verticesX, verticesY);

      if (transformation != null) {
        for (int i = 0; i < points.length; i++) {
          paint.color = colors[i];
          canvas.drawPoints(
              ui.PointMode.points,
              [
                getCoordinatesToPixels(
                    PointPlace(points[i].x, points[i].y, Colors.white, ''),
                    transformation)
              ],
              paint);
        }
      }

      if (this.destination != null) {
        // Draw line to destination
        final destinationAbs = getPixelsToCoordinates(
            PointPlace(
                this.destination.dx, this.destination.dy, Colors.white, ''),
            transformation);

        final double measured =
            (destinationAbs - Offset(this.points[0].x, this.points[0].y))
                .distance;
        distance.sink.add(measured);

        final originPixels = getCoordinatesToPixels(
            PointPlace(this.points[0].x, this.points[0].y, Colors.white, ''),
            transformation);

        double cornerX = originPixels.dx;
        double cornerY = this.destination.dy;
        final Offset cornerPoint = Offset(cornerX, cornerY);

        canvas.drawLine(originPixels, cornerPoint, linePaint);
        canvas.drawLine(cornerPoint, this.destination, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class PointPlace {
  final Offset offset;
  final Color color;
  final String nombre;

  PointPlace(double x, double y, this.color, this.nombre)
      : offset = Offset(x, y);
}

var colors = [Colors.cyan, Colors.amber, Colors.green];
