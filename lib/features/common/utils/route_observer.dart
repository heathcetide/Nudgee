import 'package:flutter/widgets.dart';

/// Shared route observer for app pages.
///
/// Subscribe in `didChangeDependencies` and unsubscribe in `dispose`
/// to receive `didPopNext` callbacks that refresh user info from
/// local storage.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
