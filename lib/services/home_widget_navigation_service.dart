import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/movie.dart';
import '../models/tv.dart';
import '../screens/common/bookmark_screen.dart';
import '../screens/movie/movie_detail.dart';
import '../screens/tv/tv_detail.dart';
import '../screens/wellness/wellness_screen.dart';
import 'in_app_messaging_service.dart';

class HomeWidgetNavigationService {
  HomeWidgetNavigationService._();

  static StreamSubscription<Uri?>? _subscription;
  static Uri? _pendingUri;
  static String? _lastHandled;

  static Future<void> initialize() async {
    await _subscription?.cancel();
    _subscription = HomeWidget.widgetClicked.listen(_handleUri);
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initialUri != null) _handleUri(initialUri);
  }

  static void onAppReady() {
    final uri = _pendingUri;
    if (uri == null) return;
    _pendingUri = null;
    _open(uri);
  }

  static void _handleUri(Uri? uri) {
    if (uri == null || uri.scheme != 'flixquest') return;
    if (_lastHandled == uri.toString()) return;
    if (InAppMessagingService.navigatorKey.currentState == null) {
      _pendingUri = uri;
      return;
    }
    _open(uri);
  }

  static void _open(Uri uri) {
    final navigator = InAppMessagingService.navigatorKey.currentState;
    if (navigator == null) {
      _pendingUri = uri;
      return;
    }
    _lastHandled = uri.toString();
    switch (uri.host) {
      case 'movie':
        final id = int.tryParse(uri.queryParameters['id'] ?? '');
        if (id == null) return;
        final movie = Movie(
          id: id,
          title: uri.queryParameters['title'] ?? 'Movie',
          posterPath: uri.queryParameters['poster'],
          backdropPath: uri.queryParameters['backdrop'],
          releaseDate: uri.queryParameters['date'],
        );
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => MovieDetailPage(
            movie: movie,
            heroId: 'home-widget-movie-$id',
          ),
        ));
        return;
      case 'tv':
        final id = int.tryParse(uri.queryParameters['id'] ?? '');
        if (id == null) return;
        final show = TV(
          id: id,
          name: uri.queryParameters['name'] ?? 'TV Show',
          posterPath: uri.queryParameters['poster'],
          backdropPath: uri.queryParameters['backdrop'],
          firstAirDate: uri.queryParameters['date'],
        );
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => TVDetailPage(
            tvSeries: show,
            heroId: 'home-widget-tv-$id',
          ),
        ));
        return;
      case 'wellness':
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const WellnessScreen(),
        ));
        return;
      case 'my-list':
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const BookmarkScreen(),
        ));
        return;
    }
  }
}
