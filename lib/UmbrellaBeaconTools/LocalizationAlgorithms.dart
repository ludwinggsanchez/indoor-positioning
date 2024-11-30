import 'dart:math';
import 'package:ml_linalg/linalg.dart';
import 'package:umbrella/Model/RangedBeaconData.dart';
import 'package:matrix2d/matrix2d.dart';

// https://www.researchgate.net/publication/296700326_Problem_Investigation_of_Min-max_Method_for_RSSI_Based_Indoor_Localization
class Localization {
  RangedBeaconData rbd1;
  RangedBeaconData rbd2;
  RangedBeaconData rbd3;

  bool conditionsMet = false;

  // Node which have been assigned absolute postions to the distance from it calculated by the receiver
  Map<String, RangedBeaconData> distanceToRangedNodes =
      new Map<String, RangedBeaconData>();

  addAnchorNode(String rbdID, RangedBeaconData rbdDistance) {
    String associatedKeyForLargestVal;
    distanceToRangedNodes[rbdID] = rbdDistance;

    if (distanceToRangedNodes.length >= 3) {
      conditionsMet = true;
      // If list is know greater than 3, remove the node with the largest distance value
      if (distanceToRangedNodes.length > 3) {
        print("Attempting to provide weighting...");
        double largestValue = 0;
        distanceToRangedNodes.forEach((k, v) {
          if (v.kfRssiDistance > largestValue) {
            largestValue = v.kfRssiDistance;
            associatedKeyForLargestVal = k;
            print(
                "Largest value: $largestValue, Associated key: $associatedKeyForLargestVal");
          }
        });
        distanceToRangedNodes.remove(associatedKeyForLargestVal);
        if (distanceToRangedNodes.length == 3) {
          print("Set of beacons correctly weighted");
        }
      }

      rbd1 = distanceToRangedNodes.values.elementAt(0);
      rbd2 = distanceToRangedNodes.values.elementAt(1);
      rbd3 = distanceToRangedNodes.values.elementAt(2);
    } else {
      conditionsMet = false;
    }
  }

  Point Trilaterate() {
    final p1 = rbd1;
    final p2 = rbd2;
    final p3 = rbd3;

    final CE = p3.x - p1.x;
    final CF = p3.y - p1.y;
    final EA = p2.x - p1.x;
    final BD = p2.y - p1.y;
    final CD = (pow(p1.kfRssiDistance, 2) -
            pow(p3.kfRssiDistance, 2) -
            pow(p1.x, 2) -
            pow(p1.y, 2) +
            pow(p3.x, 2) +
            pow(p3.y, 2)) /
        2.0;
    final AF = (pow(p1.kfRssiDistance, 2) -
            pow(p2.kfRssiDistance, 2) -
            pow(p1.x, 2) -
            pow(p1.y, 2) +
            pow(p2.x, 2) +
            pow(p2.y, 2)) /
        2.0;

    final F = (CD * EA - AF * CE) / (BD * EA - AF * CF);
    final x = (CE - CF * F) / EA;
    final y = (CD - BD * F) / EA;

    return Point(x, y);
  }

  // ignore: non_constant_identifier_names
  Point WeightedTrilaterationPosition() {
    double a = 2 * (rbd2.x - rbd1.x);
    double b = 2 * (rbd2.y - rbd1.y);
    double c = pow(rbd1.kfRssiDistance, 2) -
        pow(rbd2.kfRssiDistance, 2) -
        pow(rbd1.x, 2) +
        pow(rbd2.x, 2) -
        pow(rbd1.y, 2) +
        pow(rbd2.y, 2);
    double d = 2 * (rbd3.x - rbd2.x);
    double e = 2 * (rbd3.y - rbd2.y);
    double f = pow(rbd2.kfRssiDistance, 2) -
        pow(rbd3.kfRssiDistance, 2) -
        pow(rbd2.x, 2) +
        pow(rbd3.x, 2) -
        pow(rbd2.y, 2) +
        pow(rbd3.y, 2);

    double x = ((c * e) - (f * b)) / ((e * a) - (b * d));

    double y = ((c * d) - (a * f)) / ((b * d) - (a * e));

    final coordinates = Point(x, y);

    // print("Weighted x coordinate: " + x.toString());

    // print("Weighted y coordinate: " + y.toString());

    return coordinates;
  }

  // ignore: non_constant_identifier_names
  Point MinMaxPosition() {
    var xMin = Matrix.row([
      rbd1.x - rbd1.kfRssiDistance,
      rbd2.x - rbd2.kfRssiDistance,
      rbd3.x - rbd3.kfRssiDistance,
    ]).max();
    var xMax = Matrix.row([
      rbd1.x + rbd1.kfRssiDistance,
      rbd2.x + rbd2.kfRssiDistance,
      rbd3.x + rbd3.kfRssiDistance,
    ]).min();

    var yMin = Matrix.row([
      rbd1.y - rbd1.kfRssiDistance,
      rbd2.y - rbd2.kfRssiDistance,
      rbd3.y - rbd3.kfRssiDistance,
    ]).max();
    var yMax = Matrix.row([
      rbd1.y + rbd1.kfRssiDistance,
      rbd2.y + rbd2.kfRssiDistance,
      rbd3.y + rbd3.kfRssiDistance,
    ]).min();

    var x = (xMin + xMax) / 2;
    var y = (yMin + yMax) / 2;

    final coordinates = Point(x, y);

    // print("MinMax x coordinate: " + x.toString());

    // print("MinMax y coordinate: " + y.toString());

    return coordinates;
  }

  String getDistances() {
    if (rbd1 == null && rbd2 == null && rbd3 == null) {
      return '';
    }
    final distances = "p1: " +
        rbd1.x.toStringAsFixed(2) +
        ", " +
        rbd1.y.toStringAsFixed(2) +
        " rkf1: " +
        rbd1.kfRssiDistance.toStringAsFixed(2) +
        " kf1: " +
        rbd1.kfRssi.toStringAsFixed(2) +
        "\nrraw1: " +
        rbd1.rawRssiDistance.toStringAsFixed(2) +
        " raw1: " +
        rbd1.rawRssi.toStringAsFixed(2) +
        "\np2: " +
        rbd2.x.toStringAsFixed(2) +
        ", " +
        rbd2.y.toStringAsFixed(2) +
        " rkf2: " +
        rbd2.kfRssiDistance.toStringAsFixed(2) +
        " kf2: " +
        rbd2.kfRssi.toStringAsFixed(2) +
        "\nrraw2: " +
        rbd2.rawRssiDistance.toStringAsFixed(2) +
        " raw2: " +
        rbd2.rawRssi.toStringAsFixed(2) +
        "\np3: " +
        rbd3.x.toStringAsFixed(2) +
        ", " +
        rbd3.y.toStringAsFixed(2) +
        " rkf3: " +
        rbd3.kfRssiDistance.toStringAsFixed(2) +
        " kf3: " +
        rbd3.kfRssi.toStringAsFixed(2) +
        "\nrraw3: " +
        rbd3.rawRssiDistance.toStringAsFixed(2) +
        " raw3: " +
        rbd3.rawRssi.toStringAsFixed(2);
    return distances;
  }

  Point trilaterationMethod() {
    var matrixA = [];
    var matrixB = [];
    const Matrix2d m2d = Matrix2d();
    final anchorList = [rbd1, rbd2, rbd3];
    double maxDistance =
        max(rbd1.kfRssiDistance, max(rbd2.kfRssiDistance, rbd3.kfRssiDistance));

    for (int idx = 1; idx <= anchorList.length - 1; idx++) {
      // value A
      matrixA.add([
        anchorList[idx].x - anchorList[0].x,
        anchorList[idx].y - anchorList[0].y
      ]);
      // value b
      matrixB.add([
        ((pow(anchorList[idx].x, 2) +
                    pow(anchorList[idx].y, 2) -
                    pow(
                        anchorList[idx].kfRssiDistance > maxDistance
                            ? maxDistance
                            : anchorList[idx].kfRssiDistance,
                        2)) -
                (pow(anchorList[0].x, 2) +
                    pow(anchorList[0].y, 2) -
                    pow(
                        anchorList[0].kfRssiDistance > maxDistance
                            ? maxDistance
                            : anchorList[0].kfRssiDistance,
                        2))) /
            2
      ]);
    }
    var matrixATranspose = transposeDouble(matrixA);
    var matrixInverse = dim2InverseMatrix(m2d.dot(matrixATranspose, matrixA));
    var matrixDot = m2d.dot(matrixInverse, matrixATranspose);
    var position = m2d.dot(matrixDot, matrixB);

    return Point(position[0][0], position[1][0]);
  }

  Point3D trilaterate(RangedBeaconData p1_, p2_, p3_, bool returnMiddle) {
    // based on: https://en.wikipedia.org/wiki/Trilateration

    // some additional local functions declared here for
    // scalar and vector operations

    final p1 = Point3D(p1_.x, p1_.y, p1_.z);
    final p2 = Point3D(p2_.x, p2_.y, p2_.z);
    final p3 = Point3D(p3_.x, p3_.y, p3_.z);

    double sqr(a) {
      return a * a;
    }

    double norm(Point3D a) {
      return sqrt(sqr(a.x) + sqr(a.y) + sqr(a.z));
    }

    double dot(Point3D a, Point3D b) {
      return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    Point3D vectorSubtract(Point3D a, Point3D b) {
      return Point3D(a.x - b.x, a.y - b.y, a.z - b.z);
    }

    Point3D vectorAdd(Point3D a, Point3D b) {
      return Point3D(a.x + b.x, a.y + b.y, a.z + b.z);
    }

    Point3D vectorDivide(Point3D a, double b) {
      return Point3D(a.x / b, a.y / b, a.z / b);
    }

    Point3D vectorMultiply(Point3D a, double b) {
      return Point3D(a.x * b, a.y * b, a.z * b);
    }

    Point3D vectorCross(a, b) {
      return Point3D(
          a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
    }

    var ex, ey, ez, i, j, d, a, x, y, z, b, p4a, p4b;

    ex = vectorDivide(vectorSubtract(p2, p1), norm(vectorSubtract(p2, p1)));

    i = dot(ex, vectorSubtract(p3, p1));
    a = vectorSubtract(vectorSubtract(p3, p1), vectorMultiply(ex, i));
    ey = vectorDivide(a, norm(a));
    ez = vectorCross(ex, ey);
    d = norm(vectorSubtract(p2, p1));
    j = dot(ey, vectorSubtract(p3, p1));

    x = (sqr(p1_.kfRssiDistance) - sqr(p2_.kfRssiDistance) + sqr(d)) / (2 * d);
    y = (sqr(p1_.kfRssiDistance) - sqr(p3_.kfRssiDistance) + sqr(i) + sqr(j)) /
            (2 * j) -
        (i / j) * x;

    b = sqr(p1_.kfRssiDistance) - sqr(x) - sqr(y);

    // floating point math flaw in IEEE 754 standard
    // see https://github.com/gheja/trilateration.js/issues/2
    if ((b).abs() < 0.0000000001) {
      b = 0;
    }

    z = sqrt(b);

    a = vectorAdd(p1, vectorAdd(vectorMultiply(ex, x), vectorMultiply(ey, y)));
    p4a = vectorAdd(a, vectorMultiply(ez, z));
    p4b = vectorSubtract(a, vectorMultiply(ez, z));

    if (z == 0 || returnMiddle) {
      return a;
    } else {
      return Point3D(0, 0, 0); //[p4a, p4b];
    }
  }
}

class Point3D extends Point {
  num z;

  Point3D(num x, num y, this.z) : super(x, y);
  @override
  String toString() {
    return x.toStringAsFixed(2) +
        ", " +
        y.toStringAsFixed(2) +
        ", " +
        z.toStringAsFixed(2);
  }
}

// matrix transpose
List transposeDouble(List list) {
  var shape = list.shape;
  var temp = List.filled(shape[1], 0.0)
      .map((e) => List.filled(shape[0], 0.0))
      .toList();
  for (var i = 0; i < shape[1]; i++) {
    for (var j = 0; j < shape[0]; j++) {
      temp[i][j] = list[j][i];
    }
  }
  return temp;
}

// inverse matrix
List dim2InverseMatrix(List list) {
  var shape = list.shape;
  var temp = List.filled(shape[1], 0.0)
      .map((e) => List.filled(shape[0], 0.0))
      .toList();
  var determinant = list[0][0] * list[1][1] - list[1][0] * list[0][1];
  temp[0][0] = list[1][1] / determinant;
  temp[0][1] = -list[0][1] / determinant;
  temp[1][0] = -list[1][0] / determinant;
  temp[1][1] = list[0][0] / determinant;

  return temp;
}
