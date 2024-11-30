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

bool destinationSelected;
plot.PointPlace pressedPlace;
plot.PointPlace destination;
plot.PlotMap painterMap;

bool settings = false;

Point wtCoordinates = new Point(0.01, 0.01);
Point minMaxCoordinates = new Point(0.01, 0.01);
Point trilaterateCoordinates = new Point(0.01, 0.01);

final distance = StreamController<double>();

Map<String, RangedBeaconData> rangedAnchorBeacons =
    new Map<String, RangedBeaconData>();

class NearbyScreen extends StatefulWidget {
  @override
  NearbyScreenState createState() {
    return NearbyScreenState();
  }
}

class NearbyScreenState extends State<NearbyScreen> {
  double _sliderPar1 = 3.5;
  double _sliderRssiRef1 = -68;
  double _sliderPar2 = 2.3;
  double _sliderRssiRef2 = -68;
  double _sliderPar3 = 2.0;
  double _sliderRssiRef3 = -70;

  double _sliderRef1 = -80;
  double _sliderRef2 = -92;
  double _sliderDistanceRef = 4;
  bool raw = false;
  bool log = true;
  Timer _timer;

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
        debugPrint('Bluetooth State changed');
        if (blState == BluetoothState.POWERED_ON) {
          appStateModel.bluetoothEnabled = true;
          debugPrint('Bluetooth is on');
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
          debugPrint('Network connected');
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
    debugPrint('dispose() called');
    beacons.clear();
    bluetoothChanges?.cancel();
    bluetoothChanges = null;
    beaconSubscription?.cancel();
    beaconSubscription = null;
    super.dispose();
  }

  startScan() {
    print('Scanning now');

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
    print('Scan stopped');
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
        if (raw == true) {
          rbd.kfRssi = beacon.rawRssi;
        } else {
          rbd.kfRssi = beacon.kfRssi;
        }

        rbd.rawRssiDistance = beacon.getLogDistance_(
            false,
            log,
            _sliderRef1,
            _sliderRef2,
            _sliderPar1,
            _sliderRssiRef1,
            _sliderPar2,
            _sliderRssiRef2,
            _sliderPar3,
            _sliderRssiRef3);
        rbd.kfRssiDistance = beacon.getLogDistance_(
            true,
            log,
            _sliderRef1,
            _sliderRef2,
            _sliderPar1,
            _sliderRssiRef1,
            _sliderPar2,
            _sliderRssiRef2,
            _sliderPar3,
            _sliderRssiRef3);
        // rbd.rawRssiDistance =
        //     beacon.rawRssiLogDistance_(_sliderPar, _sliderRssiRef);
        // rbd.kfRssiDistance =
        //     beacon.kfRssiLogDistance_(_sliderPar, _sliderRssiReF);
        rangedAnchorBeacons[idd] = rbd;

        localization.addAnchorNode(idd, rangedAnchorBeacons[idd]);

        if (localization.conditionsMet) {
          wtCoordinates = localization.WeightedTrilaterationPosition();
          minMaxCoordinates = localization.MinMaxPosition();
          // wtCoordinates = Point(14.1, 15.7);
          // minMaxCoordinates = Point(11.2, 10.9);
          // trilaterateCoordinates = localization.trilaterationMethod();
          // trilaterate = localization.nonLinear();
        }
      }
    }

    return;
  }

  void handlePointPressed(plot.PointPlace point) {
    setState(() {
      pressedPlace = point;
    });
  }

  void closeLabel() {
    setState(() {
      pressedPlace = null;
    });
  }

  checkPermissions() async {
    if (!appStateModel.isScanning) {
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
        showGenericDialog(context, 'Location Permission Required',
            'Location is needed to scan a beacon');
      } else {
        showGenericDialog(context, 'Wi-Fi, Bluetooth and GPS need to be on',
            'Please check each of these in order to scan');
      }
    }
  }

  buildConfigButton() {
    if (settings == false) {
      return new FloatingActionButton(
          child: new Icon(Icons.settings),
          backgroundColor: Colors.redAccent,
          onPressed: () {
            setState(() {
              settings = true;
            });
          });
    } else {
      return new FloatingActionButton(
          child: new Icon(Icons.settings),
          backgroundColor: Colors.grey,
          onPressed: () {
            settings = false;
          });
    }
  }

  stopButton() {
    if (appStateModel.isScanning == false ||
        destinationSelected == false ||
        destination == null) {
      return Container();
    }

    return new FloatingActionButton(
        child: new Icon(Icons.stop),
        backgroundColor: Colors.redAccent,
        onPressed: () {
          destination = null;
          destinationSelected = false;
          _timer?.cancel();
        });
  }

  @override
  Widget build(BuildContext context) {
    this.locations();
    this.checkPermissions();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final Size size = Size(screenWidth * 0.9, screenHeight * 0.7);

    bool isFrozen = false;
    plot.PlotLocationPainter locationPainter = plot.PlotLocationPainter(
        [minMaxCoordinates, wtCoordinates], goTo(), isFrozen);

    locationPainter.distance.stream.listen((num measured) {
      if (measured < _sliderDistanceRef && destination != null) {
        if (_timer == null || _timer?.isActive == false) {
          // print('Timer started!');
          _timer = Timer(Duration(seconds: 4), () {
            // print('Timer executed!');
            _showPopUp(context, destination.nombre);
            destination = null;
            destinationSelected = false;
          });
        }
      } else {
        // print('Timer cancelled!');
        _timer?.cancel();
      }
    });

    return Scaffold(
      appBar: new AppBar(
        backgroundColor: createMaterialColor(Color(0xFFE8E6D9)),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Mapa UDistrital',
              style: TextStyle(color: Colors.black),
            ),
            // const Image(image: AssetImage('assets/icons8-umbrella-24.png'))
          ],
        ),
      ),
      floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            buildConfigButton(),
            stopButton(),
          ]),
      body: new Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          connectivityResult == ConnectivityResult.none
              ? buildAlertTile(context, 'Wifi required to send beacon data')
              : Container(),
          blState != BluetoothState.POWERED_ON
              ? buildAlertTile(context, 'Please check that Bluetooth is on')
              : Container(),
          settings == true
              ? Row(children: [
                  Slider(
                    value: _sliderPar1,
                    onChanged: _handleSliderValueChanged1,
                    min: 0,
                    max: 6,
                    divisions: 41,
                  ),
                  Text('n1: $_sliderPar1')
                ])
              : Container(),
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderRssiRef1,
                      onChanged: _handleSliderRssi1,
                      divisions: 31,
                      min: -80,
                      max: -50,
                    ),
                    Text('RssiRef1: $_sliderRssiRef1')
                  ],
                )
              : Container(),
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderPar2,
                      onChanged: _handleSliderValueChanged2,
                      min: 0,
                      max: 6,
                      divisions: 41,
                    ),
                    Text('n2: $_sliderPar2')
                  ],
                )
              : Container(),
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderRssiRef2,
                      onChanged: _handleSliderRssi2,
                      divisions: 31,
                      min: -80,
                      max: -50,
                    ),
                    Text('RssiRef2: $_sliderRssiRef2')
                  ],
                )
              : Container(),
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderPar3,
                      onChanged: _handleSliderValueChanged3,
                      min: 0,
                      max: 6,
                      divisions: 41,
                    ),
                    Text('n3: $_sliderPar3')
                  ],
                )
              : Container(),
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderRssiRef3,
                      onChanged: _handleSliderRssi3,
                      divisions: 31,
                      min: -80,
                      max: -50,
                    ),
                    Text('RssiRef3: $_sliderRssiRef3')
                  ],
                )
              : Container(),
//
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderRef1,
                      onChanged: _handleSliderRef1,
                      min: -100,
                      max: -60,
                      divisions: 41,
                    ),
                    Text('lim1: $_sliderRef1')
                  ],
                )
              : Container(),
          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderRef2,
                      onChanged: _handleSliderRef2,
                      divisions: 31,
                      min: -100,
                      max: -60,
                    ),
                    Text('lim2: $_sliderRef2')
                  ],
                )
              : Container(),

          settings == true
              ? Row(
                  children: [
                    Slider(
                      value: _sliderDistanceRef,
                      onChanged: _handleSliderDisRef,
                      min: 1,
                      max: 6,
                    ),
                    Text('Value: $_sliderDistanceRef')
                  ],
                )
              : Container(),
//
          settings == true
              ? Row(children: [
                  Text('Raw'),
                  Checkbox(
                    value: raw,
                    onChanged: (bool newValue) {
                      setState(() {
                        raw = newValue;
                      });
                    },
                  )
                ])
              : Container(),
          settings == true
              ? Row(children: [
                  Text('Log'),
                  Checkbox(
                    value: log,
                    onChanged: (bool newValue) {
                      setState(() {
                        log = newValue;
                      });
                    },
                  )
                ])
              : Container(),
          settings == true
              ? (rangedAnchorBeacons.length < 3
                  ? buildInfoTitle(context, 'Estableciendo posición')
                  : buildInfoTitle(
                      context,
                      positionLog('wt', wtCoordinates) +
                          positionLog('mm', minMaxCoordinates)))
              : Container(),
          settings == true
              ? rangedAnchorBeacons.length == 0
                  ? buildInfoTitle(context, 'Estableciendo posición')
                  : buildInfoTitle(
                      context, 'distancias: \n' + localization.getDistances())
              : Container(),
          settings == false &&
                  appStateModel.isScanning == true &&
                  destinationSelected == true
              ? buildProgressBarTile()
              : Container(),
          settings == false
              ? destinationSelected == true && destination != null
                  ? buildInfoTitle(
                      context, 'En camino a: ' + destination.nombre)
                  : buildInfoTitle(
                      context, 'Seleccione un lugar para ver detalles')
              : Container(),
          settings == false
              ? Container(
                  child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      child: GestureDetector(
                          onTapUp: (details) {
                            if (!isFrozen) {
                              setState(() {
                                isFrozen = true;
                              });
                              Future.delayed(Duration(seconds: 1), () {
                                setState(() {
                                  isFrozen = false;
                                });
                              });
                            }
                          },
                          onTapDown: (TapDownDetails details) {
                            painterMap.handlePointPressed(
                                details.localPosition, size);
                          },
                          child: Stack(
                            children: [
                              CustomPaint(
                                painter: painterMap,
                                foregroundPainter: locationPainter,
                                size: size,
                              ),
                              pressedPlace != null
                                  ? Positioned(
                                      left: pressedPlace.offset?.dx,
                                      top: pressedPlace.offset?.dy,
                                      child: LabelButtonWidget(),
                                    )
                                  : Container(),
                            ],
                          ))))
              : Container(),
        ],
      ),
    );
  }

  goTo() {
    if (destinationSelected == true && destination != null) {
      return destination.offset;
    }

    return null;
  }

  void _handleSliderValueChanged1(double value) {
    setState(() {
      _sliderPar1 = value;
    });
  }

  void _handleSliderRssi1(double value) {
    setState(() {
      _sliderRssiRef1 = value;
    });
  }

  void _handleSliderValueChanged2(double value) {
    setState(() {
      _sliderPar2 = value;
    });
  }

  void _handleSliderRssi2(double value) {
    setState(() {
      _sliderRssiRef2 = value;
    });
  }

  void _handleSliderValueChanged3(double value) {
    setState(() {
      _sliderPar3 = value;
    });
  }

  void _handleSliderRssi3(double value) {
    setState(() {
      _sliderRssiRef3 = value;
    });
  }

  void _handleSliderRef1(double value) {
    setState(() {
      _sliderRef1 = value;
    });
  }

  void _handleSliderRef2(double value) {
    setState(() {
      _sliderRef2 = value;
    });
  }

  void _handleSliderDisRef(double value) {
    setState(() {
      _sliderDistanceRef = value;
    });
  }
}

class LabelButtonWidget extends StatefulWidget {
  @override
  _LabelButtonWidgetState createState() => _LabelButtonWidgetState();
}

class _LabelButtonWidgetState extends State<LabelButtonWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          pressedPlace != null
              ? pressedPlace.nombre
              : destination != null
                  ? destination.nombre
                  : '',
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              destination = pressedPlace;
              destinationSelected = true;
              pressedPlace = null;
            });
          },
          child: Text('Ir'),
        ),
      ],
    );
  }
}

Future<void> _showPopUp(BuildContext context, String destino) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Recorrido finalizado'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Ha llegado a ' + destino),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Continuar'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

String positionLog(String method, Point point) {
  return method +
      ': ' +
      point.x.toStringAsFixed(2) +
      ', ' +
      point.y.toStringAsFixed(2) +
      '\n';
}
