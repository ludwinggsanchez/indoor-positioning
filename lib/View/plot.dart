import 'dart:math';
import 'package:flutter/material.dart';
import 'package:umbrella/Model/BeaconInfo.dart';

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

List<Point_> pointsPlaces() {
  List<Place> places = AppStateModel.instance.getPlaces();
  final List<Point_> pointPlaces = [];

  for (var place in places) {
    pointPlaces.add(Point_(place.x, place.y, Colors.red, place.name));
  }

  return pointPlaces;
}

List<Point_> pointsBeacons() {
  List<BeaconInfo> beacons = AppStateModel.instance.getAnchorBeacons();
  final List<Point_> pointBeacons = [];

  for (var beacon in beacons) {
    pointBeacons.add(Point_(beacon.x, beacon.y, Colors.blue, ''));
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

  final proportion = propX > propY ? propY : propX;

  final Map<String, double> transformation = {
    'proportion': proportion,
    'offsetX': propX > propY ? (size.width - (diffX * proportion)) / 2 : 0,
    'offsetY': propX > propY ? 0 : (size.height - (diffY * proportion)) / 2,
  };

  return transformation;
}

Offset getPointTransformed(Point_ point, Map<String, double> transformation) {
  return point.offset * transformation['proportion'] +
      Offset(transformation['offsetX'], transformation['offsetY']);
}

class PlotMap extends CustomPainter {
  final Function(Offset) onPointPressed;
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
        ..color = Color(0xf0f0f0f0)
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

        canvas.drawCircle(getPointTransformed(point, transformation), 8, paint);
      }

      for (final point in pointsBeacons()) {
        final paint = Paint()
          ..color = point.color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

        canvas.drawCircle(getPointTransformed(point, transformation), 8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  void handlePointPressed(Offset localPosition, Size size) {
    final transformation = getTransform(size, getVerticesX(), getVerticesY());

    for (final point in pointsPlaces()) {
      final point_ = getPointTransformed(point, transformation);
      if ((localPosition - point_).distance <= 20.0) {
        onPointPressed(point_);
        return;
      }
    }

    onOutsidePressed();
  }
}

class PlotLocationPainter extends CustomPainter {
  List<Point> points = [];
  final Offset selected;
  final bool isFrozen;

  PlotLocationPainter(this.points, this.selected, this.isFrozen);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill
      ..strokeWidth = 20.0
      ..strokeCap = StrokeCap.round;

    if (!isFrozen && this.points.length > 0) {
      final verticesX = getVerticesX();
      final verticesY = getVerticesY();
      final transformation = getTransform(size, verticesX, verticesY);

      if (transformation != null) {
        for (var point in this.points) {
          canvas.drawPoints(
              ui.PointMode.points,
              [
                Offset(
                    point.x * transformation['proportion'] +
                        transformation['offsetX'],
                    point.y * transformation['proportion'] +
                        transformation['offsetY'])
              ],
              paint);
        }
      }

      if (this.selected != null) {
        // Draw line to destination
        final Paint linePaint = Paint()
          ..color = Colors.blue
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.0;

        final destination = Offset(
            this.points[0].x * transformation['proportion'] +
                transformation['offsetX'],
            this.points[0].y * transformation['proportion'] +
                transformation['offsetY']);

        double cornerX = destination.dx;
        double cornerY = this.selected.dy;
        final Offset cornerPoint = Offset(cornerX, cornerY);

        canvas.drawLine(this.selected, cornerPoint, linePaint);
        canvas.drawLine(cornerPoint, destination, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class Point_ {
  final Offset offset;
  final Color color;
  final String nombre;

  Point_(double x, double y, this.color, this.nombre) : offset = Offset(x, y);
}
