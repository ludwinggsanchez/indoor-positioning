import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../utils.dart';
import 'BeaconInfo.dart';
import 'facilities.dart';

class AppStateModel extends foundation.ChangeNotifier {
  // Singleton
  AppStateModel._();

  static AppStateModel _instance = new AppStateModel._();

  static AppStateModel get instance => _instance;

  bool wifiEnabled = false;
  bool bluetoothEnabled = false;
  bool gpsEnabled = false;
  bool gpsAllowed = false;

  PermissionStatus locationPermissionStatus = PermissionStatus.denied;
  FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;

  String beaconStatusMessage;
  bool isScanning = false;

  Uuid uuid = new Uuid();

  String id = "";

  String phoneMake = "";

  List<BeaconInfo> anchorBeacons = [];
  List<Floor> floors = [];
  List<Place> places = [];

  CollectionReference anchorPath =
      FirebaseFirestore.instance.collection('AnchorNodes');

  CollectionReference rangedPath =
      FirebaseFirestore.instance.collection('RangedNodes');

  CollectionReference wtPath =
      FirebaseFirestore.instance.collection('WeightedTri');

  CollectionReference minmaxPath =
      FirebaseFirestore.instance.collection('MinMax');

  CollectionReference floorPath =
      FirebaseFirestore.instance.collection('Floor');

  CollectionReference placesPath =
      FirebaseFirestore.instance.collection('Places');
  Stream<QuerySnapshot> beaconSnapshots;
  Stream<QuerySnapshot> floorSnapshots;
  Stream<QuerySnapshot> placesSnapshots;

  // ignore: cancel_subscriptions
  StreamSubscription beaconStream;
  // ignore: cancel_subscriptions
  StreamSubscription floorStream;
  // ignore: cancel_subscriptions
  StreamSubscription placesStream;

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  void init() async {
    debugPrint("init() called");

    FirebaseFirestore.instance.settings;
    // FirebaseFirestore.instance.settings(persistenceEnabled: false);

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    phoneMake = androidInfo.model.toString();
    print('Running on $phoneMake');

    id = uuid.v1().toString();
    id = id.replaceAll(RegExp('-'), '');

    if (Platform.isAndroid) {
      // For Android, the user's uuid has to be 20 chars long to conform
      // with Eddystones NamespaceId length
      // Also has to be without hyphens
      id = id.substring(0, 20);

      if (id.length == 20) {
        debugPrint("Android users ID is the correct format");
      } else {
        debugPrint('user ID was of an incorrect format');
        debugPrint(id);
      }
    }
    streamAnchorBeacons();
    streamFloors();
    streamPlaces();
  }

  void streamAnchorBeacons() {
    beaconSnapshots =
        FirebaseFirestore.instance.collection(anchorPath.path).snapshots();

    beaconStream = beaconSnapshots.listen((s) {
      anchorBeacons = [];
      for (var document in s.docs) {
        anchorBeacons = List.from(anchorBeacons);
        anchorBeacons.add(BeaconInfo.fromJson(document.data()));
      }
      debugPrint("REGISTERED BEACONS: " + anchorBeacons.length.toString());
    });
  }

  void streamFloors() {
    floorSnapshots =
        FirebaseFirestore.instance.collection(floorPath.path).snapshots();

    floorStream = floorSnapshots.listen((s) {
      floors = [];
      for (var document in s.docs) {
        floors = List.from(floors);
        Floor floor = Floor.fromJson(document.data(), document.id);
        if (floor.active == true) {
          floors.add(floor);
        }
      }
      debugPrint("REGISTERED FLOORS: " + floors.length.toString());
    });
  }

  void streamPlaces() {
    placesSnapshots =
        FirebaseFirestore.instance.collection(placesPath.path).snapshots();

    placesStream = placesSnapshots.listen((s) {
      places = [];
      for (var document in s.docs) {
        places = List.from(places);
        places.add(Place.fromJson(document.data(), document.id));
      }
      debugPrint("REGISTERED PLACES: " + places.length.toString());
    });
  }

  addWTXY(var coordinates) async {
    // print("Data sent to Firestore: $coordinates");
    // await wtPath.add(coordinates);
  }

  addMinMaxXY(var coordinates) async {
    // await minmaxPath.add(coordinates);
  }

  List<BeaconInfo> getAnchorBeacons() {
    return anchorBeacons;
  }

  List<Floor> getFloors() {
    return floors;
  }

  List<Place> getPlaces() {
    return places;
  }

  checkGPS() async {
    if (!(await Geolocator.isLocationServiceEnabled())) {
      print("GPS disabled");
      gpsEnabled = false;
    } else {
      print("GPS enabled");
      gpsEnabled = true;
    }
  }

  // Adapted from: https://dev.to/ahmedcharef/flutter-wait-user-enable-gps-permission-location-4po2#:~:text=Flutter%20Permission%20handler%20Plugin&text=Check%20if%20a%20permission%20is,permission%20status%20of%20location%20service.
  // Future<bool> requestPermission(Permissions permission) async {
  //   PermissionHandler _permissionHandler = PermissionHandler();
  //   PermissionStatus p = PermissionStatus
  //   var result = await _permissionHandler.requestPermissions([permission]);
  //   if (result[permission] == PermissionStatus.granted) {
  //     return true;
  //   }
  //   return false;
  // }

  // // Adapted from: https://dev.to/ahmedcharef/flutter-wait-user-enable-gps-permission-location-4po2#:~:text=Flutter%20Permission%20handler%20Plugin&text=Check%20if%20a%20permission%20is,permission%20status%20of%20location%20service.
  // Future<bool> requestLocationPermission({Function onPermissionDenied}) async {
  //   var granted = await requestPermission(PermissionGroup.location);
  //   if (granted != true) {
  //     gpsAllowed = false;
  //     requestLocationPermission();
  //   } else {
  //     gpsAllowed = true;
  //   }
  //   debugPrint('requestLocationPermission $granted');
  //   return granted;
  // }

  // Future<void> checkLocationPermission() async {
  //   gpsAllowed = await requestPermission(PermissionGroup.location);
  // }
}
