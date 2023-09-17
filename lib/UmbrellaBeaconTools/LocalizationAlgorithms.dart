import 'dart:math';
import 'package:ml_linalg/linalg.dart';
import 'package:umbrella/Model/RangedBeaconData.dart';

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

  // ignore: non_constant_identifier_names
  Point WeightedTrilaterationPosition() {
    double a = (-2 * rbd1.x) + (2 * rbd2.x);
    double b = (-2 * rbd1.y) + (2 * rbd2.y);
    double c = pow(rbd1.kfRssiDistance, 2) -
        pow(rbd2.kfRssiDistance, 2) -
        pow(rbd1.x, 2) +
        pow(rbd2.x, 2) -
        pow(rbd1.y, 2) +
        pow(rbd2.y, 2);
    double d = (-2 * rbd2.x) + (2 * rbd3.x);
    double e = (-2 * rbd2.y) + (2 * rbd3.y);
    double f = pow(rbd2.kfRssiDistance, 2) -
        pow(rbd3.kfRssiDistance, 2) -
        pow(rbd2.x, 2) +
        pow(rbd3.x, 2) -
        pow(rbd2.y, 2) +
        pow(rbd3.y, 2);

    double x = (c * e - f * b);
    x = x / (e * a - b * d);

    double y = (c * d - a * f);
    y = y / (b * d - a * e);

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
}
