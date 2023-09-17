import 'package:flutter/foundation.dart';

class BeaconInfo {
  BeaconInfo({
    @required this.phoneMake,
    @required this.beaconUUID,
    @required this.txPower,
    @required this.minor,
    @required this.major,
    @required this.standardBroadcasting,
    this.x,
    this.y,
  });

  final String phoneMake;
  final String beaconUUID;
  final String txPower;
  final String standardBroadcasting;
  final int minor;
  final int major;
  final x;
  final y;

  factory BeaconInfo.fromJson(Map<String, dynamic> json) {
    return BeaconInfo(
        phoneMake: json['phoneMake'],
        beaconUUID: json['beaconUUID'],
        txPower: json['txPower'],
        standardBroadcasting: json['standardBroadcasting'],
        minor: json['minor'],
        major: json['major'],
        x: json['xCoordinate'],
        y: json['yCoordinate']);
  }

  Map<String, dynamic> toJson() => {
        'phoneMake': phoneMake,
        'beaconUUID': beaconUUID,
        'txPower': txPower,
        'standardBroadcasting': standardBroadcasting,
        'xCoordinate': x,
        'yCoordinate': y
      };
}
