import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatelessWidget {
  final GeoPoint location;

  const MapScreen({Key? key, required this.location}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialPosition = CameraPosition(
      target: LatLng(location.latitude, location.longitude),
      zoom: 14.0,
    );

    final Set<Marker> markers = {
      Marker(
        markerId: MarkerId('client_location'),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(title: 'Position du client'),
      )
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Localisation du client'),
      ),
      body: GoogleMap(
        initialCameraPosition: initialPosition,
        markers: markers,
      ),
    );
  }
}