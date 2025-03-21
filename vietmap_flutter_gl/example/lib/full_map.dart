import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'page.dart';

class FullMapPage extends ExamplePage {
  const FullMapPage({super.key})
      : super(const Icon(Icons.map), 'Full screen map');

  @override
  Widget build(BuildContext context) {
    return const FullMap();
  }
}

class FullMap extends StatefulWidget {
  const FullMap({super.key});

  @override
  State createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
  VietmapController? mapController;
  var isLight = true;

  _onMapCreated(VietmapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  _onStyleLoadedCallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Style loaded :)"),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        VietmapGL(
          myLocationEnabled: true,
          logoEnabled: false,
          myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
          trackCameraPosition: true,
          // For mobile
          styleString:
              'https://maps.vietmap.vn/api/maps/light/styles.json?apikey=YOUR_API_KEY_HERE',
          // For web:
          // styleString: 'https://maps.vietmap.vn/mt/tm/style.json?apikey=YOUR_API_KEY_HERE',
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
          onStyleLoadedCallback: _onStyleLoadedCallback,
        ),
        if (mapController != null)
          MarkerLayer(markers: [
            Marker(
                child: const Icon(Icons.abc),
                latLng: const LatLng(10.762622, 106.213233)),
          ], mapController: mapController!),
        if (mapController != null)
          UserLocationLayer(mapController: mapController!),
      ],
    ));
  }
}
