part of '../vietmap_flutter_gl.dart';

class MarkerWidget extends StatefulWidget {
  final Point initialPosition;
  final LatLng coordinate;
  final void Function(MarkerState) addMarkerState;
  final Widget child;
  final double width;
  final double height;
  final Alignment alignment;
  final double angle;
  final Offset? rotateOrigin;
  final double tiltRotate;
  MarkerWidget(
      {required String key,
      required this.coordinate,
      required this.initialPosition,
      required this.addMarkerState,
      required this.child,
      this.angle = 0,
      this.tiltRotate = 0,
      required this.width,
      this.rotateOrigin,
      this.alignment = Alignment.center,
      required this.height})
      : super(key: Key(key));

  @override
  // ignore: no_logic_in_create_state
  State<StatefulWidget> createState() {
    final state = MarkerState(initialPosition, angle);
    addMarkerState(state);
    return state;
  }
}

class MarkerState extends State {
  Point _position;
  double _angle;
  MarkerState(this._position, this._angle);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var ratio = 1.0;

    //web does not support Platform._operatingSystem
    if (!kIsWeb) {
      // iOS returns logical pixel while Android returns screen pixel
      ratio = Platform.isIOS ? 1.0 : MediaQuery.of(context).devicePixelRatio;
    }
    var leftPosition = 0.0;
    var topPosition = 0.0;
    final width = (widget as MarkerWidget).width;
    final height = (widget as MarkerWidget).height;
    if ((widget as MarkerWidget).alignment == Alignment.center) {
      leftPosition = width / 2;
      topPosition = height / 2;
    } else if ((widget as MarkerWidget).alignment == Alignment.bottomCenter) {
      leftPosition = width / 2;
      topPosition = height;
    } else if ((widget as MarkerWidget).alignment == Alignment.topLeft) {
      leftPosition = 0;
      topPosition = 0;
    } else if ((widget as MarkerWidget).alignment == Alignment.topRight) {
      leftPosition = width;
      topPosition = 0;
    } else if ((widget as MarkerWidget).alignment == Alignment.bottomLeft) {
      leftPosition = 0;
      topPosition = height;
    } else if ((widget as MarkerWidget).alignment == Alignment.bottomRight) {
      leftPosition = width;
      topPosition = height;
    } else if ((widget as MarkerWidget).alignment == Alignment.centerLeft) {
      leftPosition = 0;
      topPosition = height / 2;
    } else if ((widget as MarkerWidget).alignment == Alignment.centerRight) {
      leftPosition = width;
      topPosition = height / 2;
    } else if ((widget as MarkerWidget).alignment == Alignment.topCenter) {
      leftPosition = width / 2;
      topPosition = 0;
    }

    return Positioned(
        left: _position.x / ratio - leftPosition,
        top: _position.y / ratio - topPosition,
        child: Transform(
            alignment: (widget as MarkerWidget).alignment,
            origin: (widget as MarkerWidget).rotateOrigin,
            transform: Matrix4.rotationX(
                (widget as MarkerWidget).tiltRotate * pi / 180)
              ..rotateY(0)
              ..rotateZ(_angle),
            child: getChild()));
  }

  void updatePosition(Point<num> point, double angle) {
    if (!mounted) return;
    setState(() {
      _position = point;
      _angle = angle;
    });
  }

  LatLng getCoordinate() {
    return (widget as MarkerWidget).coordinate;
  }

  Widget getChild() {
    return (widget as MarkerWidget).child;
  }
}
