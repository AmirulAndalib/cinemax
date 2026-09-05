import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'deep_link_dispatcher.dart';
import 'deep_link_routes.dart';
import 'home_widget_deep_link.dart';

/// Opens what a home screen widget was tapped on.
///
/// The link only names its target — the record behind it is fetched by the route this pushes, so a
/// detail page opened from the home screen is the same page as one opened from inside the app rather
/// than a stub of it. Waiting for a navigator and ignoring a tap reported twice are [DeepLinkDispatcher]'s
/// job, because they are the same problem for every kind of link.
class HomeWidgetNavigationService {
  HomeWidgetNavigationService._();

  static StreamSubscription<Uri?>? _subscription;

  static Future<void> initialize() async {
    await _subscription?.cancel();
    _subscription = HomeWidget.widgetClicked.listen(_handleUri);
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initialUri != null) _handleUri(initialUri);
  }

  static void _handleUri(Uri? uri) {
    if (uri == null) return;
    final target = HomeWidgetDeepLink.parse(uri);
    if (target == null) return;
    final route = _route(target);
    if (route == null) return;
    DeepLinkDispatcher.submit(
      key: uri.toString(),
      open: (navigator) => navigator.push(route),
    );
  }

  /// The home link is the app itself, so it has arrived already and there is nothing to push.
  static Route<void>? _route(HomeWidgetTarget target) => switch (target) {
        HomeWidgetMovieTarget() => DeepLinkRoutes.movie(
            id: target.id,
            title: target.title,
            artworkPath: target.backdropPath ?? target.posterPath,
          ),
        HomeWidgetTvTarget() => DeepLinkRoutes.tv(
            id: target.id,
            name: target.name,
            artworkPath: target.backdropPath ?? target.posterPath,
          ),
        HomeWidgetEpisodeTarget() => DeepLinkRoutes.episode(
            seriesId: target.seriesId,
            seasonNumber: target.seasonNumber,
            episodeNumber: target.episodeNumber,
            seriesName: target.seriesName,
            posterPath: target.posterPath,
            artworkPath: target.stillPath ?? target.posterPath,
          ),
        HomeWidgetWellnessTarget() => DeepLinkRoutes.wellness(),
        HomeWidgetMyListTarget() => DeepLinkRoutes.myList(),
        HomeWidgetHomeTarget() => null,
      };
}
