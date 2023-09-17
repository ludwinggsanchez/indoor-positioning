import 'package:flutter/foundation.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:umbrella/UmbrellaBeaconTools/DistanceAlgorithms/AndroidBeaconLibraryModel.dart';
import 'Filters/KalmanFilter.dart';
import 'package:umbrella/UmbrellaBeaconTools/DistanceAlgorithms/LogDistancePathLossModel.dart';
import 'package:umbrella/UmbrellaBeaconTools/UmbrellaBeacon.dart';
import 'package:umbrella/utils.dart';
import 'package:quiver/core.dart';
export 'package:flutter_ble_lib/flutter_ble_lib.dart' show ScanResult;

const IBeaconManufacturerId = 0x004C;

List<Beacon> beaconList = [];

KalmanFilter kf = new KalmanFilter(0.065, 1.4, 0, 0);

// Adapted from: https://github.com/michaellee8/flutter_blue_beacon/blob/master/lib/beacon.dart
abstract class Beacon {
  final int tx;
  final ScanResult scanResult;

  double get rawRssi => scanResult.rssi.toDouble();

  double get kfRssi => kf.getFilteredValue(rawRssi);

  String get name => scanResult.peripheral.name;

  String get id => scanResult.peripheral.identifier;

  int get hash;

  int get txAt1Meter => tx;

  double get rawRssiLogDistance {
    return LogDistancePathLossModel(rawRssi).getCalculatedDistance();
  }

  double get kfRssiLogDistance {
    return LogDistancePathLossModel(kfRssi).getCalculatedDistance();
  }

  double get rawRssiLibraryDistance {
    return AndroidBeaconLibraryModel()
        .getCalculatedDistance(rawRssi, txAt1Meter);
  }

  double get kfRssiLibraryDistance {
    return AndroidBeaconLibraryModel()
        .getCalculatedDistance(kfRssi, txAt1Meter);
  }

  const Beacon({@required this.tx, @required this.scanResult});

  static List<Beacon> fromScanResult(ScanResult scanResult) {
    try {
      IBeaconUID iBeacon = IBeaconUID.fromScanResult(scanResult);
      if (iBeacon != null) {
        beaconList.add(iBeacon);
      }
    } on Exception catch (e) {
      print("ERROR: " + e.toString());
    }

    return beaconList;
  }
}

// Base class of all IBeacons beacons
abstract class IBeacon extends Beacon {
  const IBeacon({@required int tx, @required ScanResult scanResult})
      : super(tx: tx, scanResult: scanResult);

  @override
  int get txAt1Meter => tx - 64;
}

class IBeaconUID extends IBeacon {
  final String uuid;
  final int major;
  final int minor;

  const IBeaconUID(
      {@required this.uuid,
      @required this.major,
      @required this.minor,
      @required int tx,
      @required ScanResult scanResult})
      : super(tx: tx, scanResult: scanResult);

  factory IBeaconUID.fromScanResult(ScanResult scanResult) {
    if (scanResult.advertisementData.manufacturerData == null) {
      return null;
    }
    if (!scanResult.advertisementData.manufacturerData
        .contains(IBeaconManufacturerId)) {
      return null;
    }
    if (scanResult.advertisementData.manufacturerData.length < 23) {
      return null;
    }
    if (scanResult.advertisementData.manufacturerData[2] != 0x02 ||
        scanResult.advertisementData.manufacturerData[3] != 0x15) {
      return null;
    }

    List<int> rawBytes = scanResult.advertisementData.manufacturerData;
    var uuid = byteListToHexString(rawBytes.sublist(4, 20));
    var major = twoByteToInt16(rawBytes[20], rawBytes[21]);
    var minor = twoByteToInt16(rawBytes[22], rawBytes[23]);
    var tx = byteToInt8(rawBytes[24]);
    return IBeaconUID(
      uuid: uuid,
      major: major,
      minor: minor,
      tx: tx,
      scanResult: scanResult,
    );
  }

  int get hash => hashObjects([
        "IBeacon",
        IBeaconManufacturerId,
        this.uuid,
        this.major,
        this.minor,
        this.tx
      ]);
}
