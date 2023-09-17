import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:umbrella/Model/AppStateModel.dart';
import 'package:umbrella/Model/BeaconInfo.dart';
import 'package:umbrella/Model/RangedBeaconData.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:umbrella/Model/permissions.dart';
import 'package:umbrella/widgets.dart';
import 'package:umbrella/UmbrellaBeaconTools/UmbrellaBeacon.dart';
import 'package:wakelock/wakelock.dart';
import 'package:umbrella/UmbrellaBeaconTools/LocalizationAlgorithms.dart';
import '../styles.dart';
import 'plot.dart' as plot;
import 'dart:math';

String beaconStatusMessage;
AppStateModel appStateModel = AppStateModel.instance;

Localization localization = new Localization();

bool selectedDestination;
Offset pressedPlace;
plot.PlotMap painterMap;

Point wtCoordinates = new Point(0, 0);
Point minMaxCoordinates = new Point(0, 0);

Map<String, RangedBeaconData> rangedAnchorBeacons =
    new Map<String, RangedBeaconData>();

class NearbyScreen extends StatefulWidget {
  @override
  NearbyScreenState createState() {
    return NearbyScreenState();
  }
}

class NearbyScreenState extends State<NearbyScreen> {
  PermissionsModel permissionsModel = PermissionsModel();

  UmbrellaBeacon umbrellaBeacon = UmbrellaBeacon.instance;

  BleManager bleManager = BleManager();

  // Scanning
  StreamSubscription beaconSubscription;
  Map<int, Beacon> beacons = new Map();

  // ignore: cancel_subscriptions
  StreamSubscription networkChanges;
  var connectivityResult;

  // State
  StreamSubscription bluetoothChanges;
  BluetoothState blState = BluetoothState.UNKNOWN;
  List<Point> location = [];

  @override
  void initState() {
    super.initState();

    painterMap = plot.PlotMap(handlePointPressed, closeLabel);

    bleManager.createClient();

    // Subscribe to state changes
    bluetoothChanges = bleManager.observeBluetoothState().listen((s) {
      setState(() {
        blState = s;
        debugPrint("Bluetooth State changed");
        if (blState == BluetoothState.POWERED_ON) {
          appStateModel.bluetoothEnabled = true;
          debugPrint("Bluetooth is on");
        } else {
          appStateModel.bluetoothEnabled = false;
        }
      });
    });

    networkChanges = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      setState(() {
        connectivityResult = result;
        if (connectivityResult == ConnectivityResult.wifi ||
            connectivityResult == ConnectivityResult.mobile) {
          appStateModel.wifiEnabled = true;
          debugPrint("Network connected");
        } else {
          appStateModel.isScanning = false;
          appStateModel.wifiEnabled = false;
          stopScan();
        }
      });
    });

    Wakelock.enable();

    appStateModel.checkGPS();
  }

  @override
  void dispose() {
    debugPrint("dispose() called");
    beacons.clear();
    bluetoothChanges?.cancel();
    bluetoothChanges = null;
    beaconSubscription?.cancel();
    beaconSubscription = null;
    super.dispose();
  }

  startScan() {
    print("Scanning now");

    if (bleManager == null || umbrellaBeacon == null) {
      print('BleManager is null!');
    } else {
      appStateModel.isScanning = true;
    }

    beaconSubscription = umbrellaBeacon.scan(bleManager).listen((beacon) {
      setState(() {
        beacons[beacon.hash] = beacon;
      });
    }, onDone: stopScan);
  }

  stopScan() {
    print("Scan stopped");
    beaconSubscription?.cancel();
    beaconSubscription = null;
    setState(() {
      appStateModel.isScanning = false;
    });
  }

  void locations() {
    List<BeaconInfo> anchorBeacons = AppStateModel.instance.getAnchorBeacons();

    if (anchorBeacons.length == 0) {
      return;
    }

    for (var beacon in beacons.values) {
      if (beacon is IBeaconUID) {
        var anchored = anchorBeacons.firstWhere(
            (ab) =>
                ab.beaconUUID == beacon.uuid &&
                ab.major == beacon.major &&
                ab.minor == beacon.minor,
            orElse: () => null);

        if (anchored == null) {
          continue;
        }

        final idd = anchored.beaconUUID +
            anchored.major.toString() +
            anchored.minor.toString();

        final RangedBeaconData rbd = new RangedBeaconData();

        rbd.beaconUUID = idd;
        rbd.x = anchored.x;
        rbd.y = anchored.y;

        rbd.rawRssi = beacon.rawRssi;
        rbd.kfRssi = beacon.kfRssi;

        rbd.rawRssiDistance = beacon.rawRssiLogDistance;
        rbd.kfRssiDistance = beacon.kfRssiLogDistance;
        rangedAnchorBeacons[idd] = rbd;

        localization.addAnchorNode(idd, rangedAnchorBeacons[idd]);

        if (localization.conditionsMet) {
          wtCoordinates = localization.WeightedTrilaterationPosition();
          minMaxCoordinates = localization.MinMaxPosition();
        }
      }
    }

    return;
  }

  void handlePointPressed(Offset point) {
    setState(() {
      pressedPlace = point;
    });
  }

  void handlePlaceSelected(Offset point) {
    setState(() {
      selectedDestination = true;
    });
  }

  void closeLabel() {
    setState(() {
      pressedPlace = null;
      selectedDestination = false;
    });
  }

  buildScanButton() {
    if (appStateModel.isScanning) {
      return new FloatingActionButton(
          child: new Icon(Icons.stop),
          backgroundColor: Colors.redAccent,
          onPressed: () {
            stopScan();
            setState(() {
              appStateModel.isScanning = false;
            });
          });
    } else {
      return new FloatingActionButton(
          child: new Icon(Icons.search),
          backgroundColor: Colors.greenAccent,
          onPressed: () async {
            appStateModel.checkGPS();
            // appStateModel.checkLocationPermission();
            await permissionsModel.getPermission();
            if (appStateModel.wifiEnabled &
                appStateModel.bluetoothEnabled &
                appStateModel.gpsEnabled) {
              startScan();
              setState(() {
                appStateModel.isScanning = true;
              });
            } else if (!appStateModel.gpsAllowed) {
              showGenericDialog(context, "Location Permission Required",
                  "Location is needed to scan a beacon");
            } else {
              showGenericDialog(
                  context,
                  "Wi-Fi, Bluetooth and GPS need to be on",
                  'Please check each of these in order to scan');
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    this.locations();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    bool isFrozen = false;

    return Scaffold(
      appBar: new AppBar(
        backgroundColor: createMaterialColor(Color(0xFFE8E6D9)),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'UD',
              style: TextStyle(color: Colors.black),
            ),
            const Image(image: AssetImage('assets/icons8-umbrella-24.png'))
          ],
        ),
      ),
      floatingActionButton: buildScanButton(),
      body: new Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          (rangedAnchorBeacons.length < 3)
              ? buildInfoTitle(context, "Estableciendo posición")
              : buildInfoTitle(
                  context,
                  "wtPos: " +
                      wtCoordinates.x?.toStringAsFixed(2) +
                      ", " +
                      wtCoordinates.y?.toStringAsFixed(2) +
                      "\n" +
                      "mmPos: " +
                      minMaxCoordinates.x?.toStringAsFixed(2) +
                      ", " +
                      minMaxCoordinates.y?.toStringAsFixed(2)),
          (rangedAnchorBeacons.length == 0)
              ? buildInfoTitle(context, "Estableciendo posición")
              : buildInfoTitle(context, "dis " + localization.getDistances()),
          (connectivityResult == ConnectivityResult.none)
              ? buildAlertTile(context, "Wifi required to send beacon data")
              : Container(),
          (appStateModel.isScanning) ? buildProgressBarTile() : new Container(),
          (blState != BluetoothState.POWERED_ON)
              ? buildAlertTile(context, "Please check that Bluetooth is on")
              : Container(),
          Container(
              child: Center(
                  child: GestureDetector(
                      onTapUp: (details) {
                        if (!isFrozen) {
                          setState(() {
                            isFrozen = true;
                          });
                          Future.delayed(Duration(seconds: 3), () {
                            setState(() {
                              isFrozen = false;
                            });
                          });
                        }
                      },
                      onTapDown: (TapDownDetails details) {
                        painterMap.handlePointPressed(details.localPosition,
                            Size(screenWidth * 0.9, screenHeight * 0.5));
                      },
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: painterMap,
                            foregroundPainter: plot.PlotLocationPainter(
                                [wtCoordinates, minMaxCoordinates, trilaterate],
                                goTo(),
                                isFrozen),
                            size: Size(screenWidth * 0.9, screenHeight * 0.5),
                          ),
                          (pressedPlace != null)
                              ? Positioned(
                                  left: pressedPlace.dx,
                                  top: pressedPlace.dy,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      selectedDestination = true;
                                    },
                                    child: Text('Ir ->'),
                                  ),
                                )
                              : Container(),
                        ],
                      )))),
        ],
      ),
    );
  }

  goTo() {
    if (selectedDestination == true) {
      return pressedPlace;
    }

    return null;
  }

}
