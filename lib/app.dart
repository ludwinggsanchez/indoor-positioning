import 'package:flutter/material.dart';
import 'package:umbrella/View/NearbyScreen.dart';

import 'Model/AppStateModel.dart';

class UmbrellaMain extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Navegación', home: BottomNav());
  }
}

class BottomNav extends StatefulWidget {
  @override
  BottomNavState createState() {
    return BottomNavState();
  }
}

class BottomNavState extends State<BottomNav> {
  @override
  void initState() {
    super.initState();

    AppStateModel appStateModel = AppStateModel.instance;

    appStateModel.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: NearbyScreen(),
    ));
  }
}
