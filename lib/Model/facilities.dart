import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Floor {
  Floor({
    @required this.active,
    @required this.name,
    @required this.description,
    @required this.vertices,
    @required this.id,
  });

  final bool active;
  final String name;
  final String description;
  final String id;
  final List<dynamic> vertices;

  factory Floor.fromJson(Map<String, dynamic> json, String id) {
    return Floor(
      active: json['active'],
      name: json['name'],
      description: json['description'],
      vertices: json['vertices'],
      id: id,
    );
  }

  Map<String, dynamic> toJson() => {
        'active': active,
        'name': name,
        'description': description,
        'vertices': vertices,
      };
}

class Place {
  Place({
    @required this.description,
    @required this.floorId,
    @required this.id,
    @required this.name,
    @required this.x,
    @required this.y,
  });

  final String description;
  final DocumentReference floorId;
  final String id;
  final String name;
  final num x;
  final num y;

  factory Place.fromJson(Map<String, dynamic> json, String id) {
    return Place(
      description: json['description'],
      floorId: json['floorId'],
      id: id,
      name: json['name'],
      x: json['x'],
      y: json['y'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'floorId': floorId,
        'id': id,
        'x': x,
        'y': y,
      };
}
