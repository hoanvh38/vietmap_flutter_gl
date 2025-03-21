part of '../vietmap_flutter_gl.dart';

class PolylineAnimation {
  List<turf.Position> _coordinates = [];
  late turf.Feature<turf.LineString> _lineStringFeature;

  double _totalDistance = 0;

  PolylineAnimation(List<LatLng> listLatLng) {
    final lineStringFeature = makeLineString(listLatLng);
    _coordinates = lineStringFeature.geometry?.coordinates ?? [];
    _lineStringFeature = lineStringFeature;

    for (var i = 1; i < _coordinates.length; i++) {
      _totalDistance += turf.distance(get(i - 1), get(i));
    }
  }

  turf.Feature<turf.Point> coordinateFromStart(double distance) {
    final pointAlong = turf.along(_lineStringFeature, distance);
    pointAlong.properties = {
      'distance': distance,
      'nearestIndex': findNearestFloorIndex(distance)
    };
    pointAlong.properties?['distance'] = distance;
    pointAlong.properties?['nearestIndex'] = findNearestFloorIndex(distance);
    return pointAlong;
  }

  int findNearestFloorIndex(double currentDistance) {
    var runningDistance = 0.0;

    for (var i = 1; i < _coordinates.length; i++) {
      runningDistance += turf.distance(get(i - 1), get(i));

      if (runningDistance >= currentDistance) {
        return i - 1;
      }
    }
    return -1;
  }

  turf.Feature<turf.LineString> makeLineString(List<LatLng> latLng) {
    final listPoint =
        latLng.map((e) => turf.Position(e.longitude, e.latitude)).toList();
    return turf.Feature<turf.LineString>(
        id: listPoint.hashCode.toString(),
        geometry: turf.LineString(coordinates: listPoint));
  }

  turf.Point get(index) {
    return turf.Point(
        coordinates:
            turf.Position(_coordinates[index].first, _coordinates[index].last));
  }

  get totalDistance {
    return _totalDistance;
  }
}

class RouteSimulator {
  late PolylineAnimation _polyline;
  double _currentDistance = 0;
  late double _speed;
  Function(LatLng?, int?, double?)? _listener;
  Function(LatLng?, int?, double?, LatLng?)? _v2Listener;
  late AnimationController _animationController;
  Timer? timer;
  late Duration duration;
  Function(LatLng)? _onLocationChange;
  LatLng? previousLatLng;

  /// vsync from `TickerProviderStateMixin` class, used to init
  /// AnimationController
  RouteSimulator(List<LatLng> listLatLng, TickerProvider vsync,
      {double speed = 0.001,
      bool repeat = false,
      this.duration = const Duration(seconds: 10),
      Function(LatLng)? onLocationChange,
      double upperBound = 2.2,
      AnimationBehavior animationBehavior = AnimationBehavior.normal}) {
    _polyline = PolylineAnimation(listLatLng);
    _currentDistance = 0;
    _speed = speed;
    _onLocationChange = onLocationChange;
    _animationController = AnimationController(
        upperBound: upperBound,
        vsync: vsync,
        duration: duration,
        animationBehavior: animationBehavior)
      ..forward()
      ..addListener(() {
        if (_animationController.isCompleted && repeat) {
          _animationController.repeat();
        }
      });
  }

  get getAnimationController => _animationController;

  /// this function is deprecated and will be removed in the future,
  /// use `addV2Listener` instead
  @Deprecated('use addV2Listener instead')
  void addListener(void Function(LatLng?, int?, double?)? listener) {
    _listener = listener;
  }

  /// this function return current `LatLng` and a value that present if the
  /// animation is completed (1 time).
  /// Function(LatLng? currentLatLng, int? nearestIndex, double? distance)
  void addV2Listener(void Function(LatLng?, int?, double?, LatLng?)? listener) {
    _v2Listener = listener;
  }

  void start() {
    tick();
  }

  void reset() {
    _currentDistance = 0;
    start();
  }

  void stop() {
    _animationController.stop();
  }

  void tick() {
    _animationController.forward();

    _animationController.addListener(() {
      _currentDistance += _speed;
      // interpolate between previous to current distance

      final currentPosition =
          _polyline.coordinateFromStart(_animationController.value);
      final currentLatLng = LatLng(
          currentPosition.geometry?.coordinates.lat.toDouble() ?? 0,
          currentPosition.geometry?.coordinates.lng.toDouble() ?? 0);

      _onLocationChange?.call(currentLatLng);
      emit(currentPosition);
      previousLatLng = currentLatLng;
      if (_currentDistance > _polyline.totalDistance) {
        reset();
        return;
      }
    });
  }

  void emit(
    turf.Feature<turf.Point>? pointFeature,
  ) {
    if (_listener != null) {
      if (pointFeature?.geometry != null) {
        _listener!(
            LatLng(pointFeature!.geometry!.coordinates.lat.toDouble(),
                pointFeature.geometry!.coordinates.lng.toDouble()),
            pointFeature.properties?['nearestIndex'],
            pointFeature.properties?['distance']);
      }
    }

    if (_v2Listener != null) {
      if (pointFeature?.geometry != null) {
        _v2Listener!(
            LatLng(pointFeature!.geometry!.coordinates.lat.toDouble(),
                pointFeature.geometry!.coordinates.lng.toDouble()),
            pointFeature.properties?['nearestIndex'],
            pointFeature.properties?['distance'],
            previousLatLng);
      }
    }
  }
}
