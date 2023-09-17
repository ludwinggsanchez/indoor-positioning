// Related: https://iasj.net/iasj?func=fulltext&aId=123828

import 'dart:core';
import 'dart:math';

class LogDistancePathLossModel {
  // Rssi is the rssi measured from nearby beacon
  LogDistancePathLossModel(double rssiMeasured) {
    rssi = rssiMeasured;
  }

  // RSSI
  double rssi;
  // Rssd0, rssi measured at chosen reference distance d0
  double referenceRssi = -64;
  //d0
  double referenceDistance = 1.0;
  // For line of sight in building
  // n
  double pathLossExponent = 3.0;
  // Set to zero, as no large obstacle, used to mitigate for flat fading
  // Sigma
  double flatFadingMitigation = 0;

  double getCalculatedDistance() {
    double rssiDiff = rssi - referenceRssi - flatFadingMitigation;
    double i = pow(10, -(rssiDiff / (10 * pathLossExponent)));
    double distance = referenceDistance * i;

    return distance;
  }
}
