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

  double getCalculatedDistance_(
      double pathLossExponent_, double referenceRssi_) {
    // rssi = -85;
    double rssiDiff = rssi - referenceRssi_ - flatFadingMitigation;
    double i = pow(10, -(rssiDiff / (10 * pathLossExponent_)));
    double distance = referenceDistance * i;
    return distance;
  }

  double getddd(double pathLossExponent_, double referenceRssi_, bool linear) {
    // rssi = -85;
    if (linear == false) {
      double rssiDiff = rssi - referenceRssi_ - flatFadingMitigation;
      double i = pow(10, -(rssiDiff / (10 * pathLossExponent_)));
      double distance = referenceDistance * i;
      return distance;
    } else {
      return pathLossExponent_ * rssi + referenceRssi_;
    }
  }
}

double calculateDistance(double rssi, double transmitPower,
    double referencePathLoss, double pathLossExponent) {
  double distance = pow(10,
      ((transmitPower - rssi + referencePathLoss) / (10 * pathLossExponent)));
  return distance;
}

void main() {
  double receivedRSSI = -70; // Received RSSI in dBm
  double transmitPower = 2.5; // Transmit power in dBm
  double referencePathLoss = 66.5; // Reference path loss in dB
  double pathLossExponent = 3.0; // Path loss exponent

  double calculatedDistance = calculateDistance(
      receivedRSSI, transmitPower, referencePathLoss, pathLossExponent);

  print('Calculated Distance: $calculatedDistance meters');
}


// Calculating the distance from Received Signal Strength Indicator (RSSI) is often challenging due to various factors like path loss, interference, and signal variations. However, you can make an approximate distance estimation using the path loss model and some calibration data.

// Here's a simple example of how you might estimate distance from RSSI using a basic path loss model in Python:

// python
// Copy code
// import math

// def calculate_distance(rssi, tx_power, n, ref_distance):
//     # Calculate path loss based on RSSI and other parameters
//     path_loss = tx_power - rssi

//     # Calculate estimated distance using path loss and path loss exponent
//     estimated_distance = ref_distance * math.pow(10, path_loss / (10 * n))

//     return estimated_distance

// # RSSI value received from the device (example: -70 dBm)
// rssi = -70

// # Transmit power of the device (example: 20 dBm)
// tx_power = 20

// # Path loss exponent for the environment (example: 3.0)
// n = 3.0

// # Reference distance for calibration (example: 1 meter)
// ref_distance = 1

// # Calculate estimated distance
// estimated_distance = calculate_distance(rssi, tx_power, n, ref_distance)
// print(f"Estimated Distance: {estimated_distance:.2f} meters")
