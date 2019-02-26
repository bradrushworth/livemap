import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'models/controller_state_change.dart';
import 'state/map.dart';
import 'state/markers.dart';

class LiveMapController {
  LiveMapController(
      {@required this.mapController,
      @required this.positionStream,
      this.positionStreamEnabled})
      : assert(mapController != null) {
    positionStreamEnabled = positionStreamEnabled ?? true;
    // init state
    _mapState = LiveMapState(
      mapController: mapController,
      notify: notify,
    );
    _markersState = MarkersState(
      mapController: mapController,
      notify: notify,
    );
    // subscribe to position stream
    mapController.onReady.then((_) {
      // listen to position stream
      _positionStreamSubscription = positionStream.listen((Position position) {
        _positionStreamCallbackAction(position);
      });
      if (!positionStreamEnabled) _positionStreamSubscription.pause();
      // map is ready
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    });
  }

  final MapController mapController;
  MapOptions mapOptions;
  final Stream<Position> positionStream;
  bool positionStreamEnabled;

  LiveMapState _mapState;
  MarkersState _markersState;
  StreamSubscription<Position> _positionStreamSubscription;
  Completer<Null> _readyCompleter = Completer<Null>();

  static StreamController _changeFeedController =
      StreamController<LiveMapControllerStateChange>.broadcast();

  Future<Null> get onReady => _readyCompleter.future;

  get changeFeed => _changeFeedController.stream;
  get zoom => mapController.zoom;
  get center => mapController.center;
  get autoCenter => _mapState.autoCenter;

  get markers => _markersState.markers;
  get namedMarkers => _markersState.namedMarkers;

  //set setAutocenter(bool v) => _mapState.autoCenter = v;

  dispose() {
    _changeFeedController.close();
    _positionStreamSubscription.cancel();
  }

  zoomIn() => _mapState.zoomIn();
  zoomOut() => _mapState.zoomOut();
  centerOnPosition(pos) => _mapState.centerOnPosition(pos);
  toggleAutoCenter() => _mapState.toggleAutoCenter();
  centerOnLiveMarker() => _markersState.centerOnLiveMarker();

  addMarker({@required Marker marker, @required String name}) =>
      _markersState.addMarker(marker: marker, name: name);
  removeMarker({@required String name}) =>
      _markersState.removeMarker(name: name);

  void togglePositionStreamSubscription() {
    positionStreamEnabled = !positionStreamEnabled;
    print("TOGGLE POSITION STREAM TO $positionStreamEnabled");
    if (!positionStreamEnabled) {
      print("=====> LIVE MAP DISABLED");
      _positionStreamSubscription.pause();
    } else {
      print("=====> LIVE MAP ENABLED");
      if (_positionStreamSubscription.isPaused) {
        _positionStreamSubscription.resume();
      }
    }
    LiveMapControllerStateChange cmd = LiveMapControllerStateChange(
        name: "positionStream", value: positionStreamEnabled);
    _changeFeedController.sink.add(cmd);
  }

  void _positionStreamCallbackAction(Position position) {
    print("POSITION UPDATE $position");
    _markersState.updateLiveGeoMarkerFromPosition(position: position);
    if (autoCenter) centerOnPosition(position);
  }

  void notify(String name, dynamic value) {
    LiveMapControllerStateChange cmd = LiveMapControllerStateChange(
      name: name,
      value: value,
    );
    print("STATE MUTATION: $cmd");
    _changeFeedController.sink.add(cmd);
  }
}
