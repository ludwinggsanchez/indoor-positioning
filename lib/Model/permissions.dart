import 'dart:io';

import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;

class PermissionsModel {
  loc.Location location = loc.Location();
  BleManager bleManager = BleManager();

  Future<bool> getPermission() async {
    if (Platform.isAndroid) {
      await Permission.location.request();
      if (await Permission.location.isGranted) {
        await Permission.bluetooth.request();
        if (await Permission.bluetooth.isGranted) {
          await Permission.bluetoothConnect.request();
          if (await Permission.bluetoothConnect.isGranted) {
            await Permission.bluetoothScan.request();
            if (await Permission.bluetoothScan.isDenied ||
                await Permission.bluetoothScan.isRestricted ||
                await Permission.bluetoothScan.isPermanentlyDenied) {
              getPermission();
              // openAppSettings();
              return false;
            } else if (await Permission.bluetoothScan.isGranted) {
              await Permission.storage.request();
              if (await Permission.storage.isGranted) {
                return true;
              } else if (await Permission.storage.isDenied ||
                  await Permission.storage.isRestricted ||
                  await Permission.storage.isPermanentlyDenied) {
                getPermission();
              }
            }
          } else if (await Permission.bluetoothConnect.isDenied ||
              await Permission.bluetoothConnect.isPermanentlyDenied ||
              await Permission.bluetoothConnect.isRestricted) {
            getPermission();
            // openAppSettings();
            return false;
          }

          return false;
        } else if (await Permission.bluetooth.isDenied ||
            await Permission.bluetooth.isRestricted ||
            await Permission.bluetooth.isPermanentlyDenied) {
          getPermission();
          // openAppSettings();
          return false;
        }

        return false;
      } else if (await Permission.location.isDenied ||
          await Permission.location.isRestricted ||
          await Permission.location.isPermanentlyDenied) {
        getPermission();
        // openAppSettings();

        return false;
      }
      return false;
    } else if (Platform.isIOS) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> customEnableBT(BuildContext context) async {
    String dialogTitle = "Bluetooth Permission";
    bool displayDialogContent = true;
    String dialogContent =
        "This app requires enabling bluetooth to connect to device.";
    String cancelBtnText = "Nope";
    String acceptBtnText = "Sure";
    double dialogRadius = 10.0;
    bool barrierDismissible = false; //

    await BluetoothEnable.customBluetoothRequest(
            context,
            dialogTitle,
            displayDialogContent,
            dialogContent,
            cancelBtnText,
            acceptBtnText,
            dialogRadius,
            barrierDismissible)
        .then((result) {
      if (result == "true") {
        return true;
      } else {
        return false;
      }
    });
    return false;
  }

  Future<bool> check() async {
    bool permissionGranted = await getPermission();
    bool serviceEnabled = await location.serviceEnabled();

    BluetoothState checkBlueTooth = await bleManager.bluetoothState();
    var t = checkBlueTooth.name;
    print('permissions file: $t');
    if (permissionGranted && serviceEnabled) {
      return true;
    } else {
      if (await location.requestService() &&
          // await customEnableBT(context) &&
          await getPermission()) {
      } else {
        return false;
      }
      return false;
    }
  }
}
