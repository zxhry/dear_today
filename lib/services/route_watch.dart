import 'package:flutter/widgets.dart';

/// Tells widgets when another page opens on top of theirs (or closes again),
/// so the day reel can pause while you're on another page or in the camera.
final routeWatch = RouteObserver<ModalRoute<void>>();
