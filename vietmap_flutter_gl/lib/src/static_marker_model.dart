part of '../vietmap_flutter_gl.dart';

class StaticMarker extends Marker {
  /// The bearing of the marker, in degrees clockwise from north.
  /// This value will be normalized to be in the range [0, 360].
  /// You can get [bearing/heading] from GPS location,
  /// If only use StaticMarker to add a non-moving marker, you can set this value to 0
  final double bearing;
  final Offset? rotateOrigin;
  StaticMarker(
      {required this.bearing,
      required super.child,
      required super.latLng,
      this.rotateOrigin,
      super.width,
      super.height,
      super.alignment});
}
