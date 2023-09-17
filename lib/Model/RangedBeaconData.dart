class RangedBeaconData {
  double rawRssi;
  double rawRssiDistance;
  double kfRssi;
  double kfRssiDistance;
  double x;
  double y;

  String phoneMake;
  String beaconUUID;
  int txAt1Meter;

  Map<String, dynamic> toJson() => {
        'phoneMake': phoneMake,
        'beaconUUID': beaconUUID,
        'txAt1Meter': txAt1Meter,
        'rawRssi': rawRssi,
        'rawRssiDist': rawRssiDistance,
        'kfRssi': kfRssi,
        'kfRssiDist': kfRssiDistance,
      };
}
