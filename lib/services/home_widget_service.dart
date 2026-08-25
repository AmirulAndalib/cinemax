import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

import '../api/endpoints.dart';
import '../constants/api_constants.dart';
import '../functions/network.dart';
import '../models/app_colors.dart';
import '../models/movie.dart';
import '../models/tv.dart';
import '../models/wellness.dart';
import '../models/wellness_insights.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/bookmark_provider.dart';
import '../provider/settings_provider.dart';
import '../provider/wellness_provider.dart';

class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  static const _providers = <String>[
    'dev.beamlak.flixquest_v2.widgets.MovieOfDayWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.TvShowOfDayWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.WellnessWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.ContinueWatchingWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.MyListWidgetProvider',
  ];
  DateTime? _lastNetworkRefresh;
  String? _lastThemeSignature;

  Future<void> refreshAll({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    required WellnessProvider wellness,
    required BookmarkProvider bookmarks,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await refreshLocal(
        wellness: wellness,
        bookmarks: bookmarks,
        settings: settings,
        dependencies: dependencies,
      );

      final lastRefresh = _lastNetworkRefresh;
      if (lastRefresh != null &&
          DateTime.now().difference(lastRefresh) < const Duration(hours: 6)) {
        return;
      }
      _lastNetworkRefresh = DateTime.now();

      final results = await Future.wait<Object?>([
        _refreshMovieSchedule(settings, dependencies),
        _refreshTvSchedule(settings, dependencies),
      ].map((future) => future.catchError((Object error, StackTrace stack) {
            debugPrint('[HomeWidget] Daily content refresh failed: $error');
            return null;
          })));

      if (results.any((result) => result != null)) {
        await _updateWidgets();
      }
    } catch (error, stack) {
      debugPrint('[HomeWidget] Refresh failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> refreshLocal({
    required WellnessProvider wellness,
    required BookmarkProvider bookmarks,
    SettingsProvider? settings,
    AppDependencyProvider? dependencies,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _refreshLocal(
        wellness: wellness,
        bookmarks: bookmarks,
        settings: settings,
        dependencies: dependencies,
      );
    } catch (error, stack) {
      debugPrint('[HomeWidget] Local refresh failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _refreshLocal({
    required WellnessProvider wellness,
    required BookmarkProvider bookmarks,
    SettingsProvider? settings,
    AppDependencyProvider? dependencies,
  }) async {
    final week = WellnessInsights.fromSessions(
      wellness.sessions,
      period: WellnessPeriod.forRange(WellnessRange.week, DateTime.now()),
    );
    if (settings != null) {
      await _saveTheme(
        settings: settings,
        dependencies: dependencies,
      );
    }
    await Future.wait([
      HomeWidget.saveWidgetData<String>(
        'wellness_title',
        week.isEmpty ? 'Your week is ready' : _duration(week.totalWatchedMs),
      ),
      HomeWidget.saveWidgetData<String>(
        'wellness_subtitle',
        week.isEmpty
            ? 'Watch something to begin your private insights'
            : '${week.completedTitles} completed  |  ${week.activeDays} active days',
      ),
      HomeWidget.saveWidgetData<String>(
        'wellness_meta',
        week.topGenres.isEmpty
            ? 'Viewing Insights'
            : 'Top genre: ${week.topGenres.first.label}',
      ),
      HomeWidget.saveWidgetData<String>(
        'wellness_deep_link',
        'flixquest://wellness',
      ),
      HomeWidget.saveWidgetData<int>(
        'wellness_progress',
        week.isEmpty ? 0 : ((week.activeDays / 7) * 100).round().clamp(0, 100),
      ),
    ]);

    final latest = wellness.sessions
        .where((session) =>
            !session.isDeleted &&
            session.qualifies &&
            session.mediaType != WellnessMediaType.live)
        .firstOrNull;
    final continueImage = await _savePoster(
      key: 'continue_poster',
      posterPath: latest?.posterPath,
    );
    await Future.wait([
      HomeWidget.saveWidgetData<String>(
        'continue_title',
        latest?.title ?? 'Nothing in progress',
      ),
      HomeWidget.saveWidgetData<String>(
        'continue_subtitle',
        latest == null
            ? 'Your latest movie or episode will appear here'
            : _sessionSubtitle(latest),
      ),
      HomeWidget.saveWidgetData<String>(
        'continue_meta',
        latest == null
            ? 'Continue watching'
            : '${(latest.progress * 100).round()}% watched',
      ),
      HomeWidget.saveWidgetData<int>(
        'continue_progress',
        latest == null ? 0 : (latest.progress * 100).round(),
      ),
      HomeWidget.saveWidgetData<String>(
        'continue_image',
        continueImage,
      ),
      HomeWidget.saveWidgetData<String>(
        'continue_deep_link',
        _sessionDeepLink(latest),
      ),
    ]);

    final savedCount = bookmarks.movies.length + bookmarks.tvShows.length;
    final savedMovie = bookmarks.movies.firstOrNull;
    final savedTv = bookmarks.tvShows.firstOrNull;
    final savedTitle = savedMovie?.title ?? savedTv?.name;
    final savedPoster = savedMovie?.posterPath ?? savedTv?.posterPath;
    final myListImage = await _savePoster(
      key: 'my_list_poster',
      posterPath: savedPoster,
    );
    await Future.wait([
      HomeWidget.saveWidgetData<String>(
        'my_list_title',
        savedCount == 0 ? 'Your list is empty' : '$savedCount saved titles',
      ),
      HomeWidget.saveWidgetData<String>(
        'my_list_subtitle',
        '${bookmarks.movies.length} movies  |  ${bookmarks.tvShows.length} TV shows',
      ),
      HomeWidget.saveWidgetData<String>(
        'my_list_meta',
        savedTitle == null ? 'Build your watchlist' : 'Up next: $savedTitle',
      ),
      HomeWidget.saveWidgetData<String>('my_list_image', myListImage),
      HomeWidget.saveWidgetData<String>(
        'my_list_deep_link',
        'flixquest://my-list',
      ),
    ]);

    await _updateWidgets();
  }

  Future<void> _saveTheme({
    required SettingsProvider settings,
    AppDependencyProvider? dependencies,
  }) async {
    final isDark = settings.appTheme != 'light';
    final palette = AppColorsList().appColors(
      isDark,
      customColor: settings.customAppColor > 0 ? settings.customAppColor : null,
    );
    final selected = palette.firstWhere(
      (color) => color.index == settings.appColorIndex,
      orElse: () => palette.first,
    );
    final scheme = selected.cs;
    final occasional = dependencies?.activeOccasionalTheme;
    final primary = occasional?.primaryColor ?? scheme.primary;
    final background = occasional?.backgroundFor(
          isDark ? Brightness.dark : Brightness.light,
        ) ??
        (dependencies?.activeAmbientColor ?? scheme.surface);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black;
    await Future.wait([
      HomeWidget.saveWidgetData<int>(
        'theme_background',
        background.toARGB32(),
      ),
      HomeWidget.saveWidgetData<int>(
          'theme_surface',
          Color.alphaBlend(primary.withValues(alpha: .12), background)
              .toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_primary', primary.toARGB32()),
      HomeWidget.saveWidgetData<int>(
        'theme_foreground',
        foreground.toARGB32(),
      ),
      HomeWidget.saveWidgetData<int>(
        'theme_muted',
        foreground.withValues(alpha: .66).toARGB32(),
      ),
      HomeWidget.saveWidgetData<int>(
        'theme_eyebrow',
        primary.toARGB32(),
      ),
    ]);
  }

  Future<void> syncResolvedTheme(ThemeData theme) async {
    if (!Platform.isAndroid) return;
    try {
      await _syncResolvedTheme(theme);
    } catch (error, stack) {
      debugPrint('[HomeWidget] Theme sync failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _syncResolvedTheme(ThemeData theme) async {
    final surface = theme.scaffoldBackgroundColor;
    final softSurface = theme.cardTheme.color ?? theme.colorScheme.surface;
    final primary = theme.colorScheme.primary;
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final signature = <int>[
      surface.toARGB32(),
      softSurface.toARGB32(),
      primary.toARGB32(),
      foreground.toARGB32(),
      muted.toARGB32(),
    ].join(':');
    if (_lastThemeSignature == signature) return;
    _lastThemeSignature = signature;
    await Future.wait([
      HomeWidget.saveWidgetData<int>('theme_background', surface.toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_surface', softSurface.toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_primary', primary.toARGB32()),
      HomeWidget.saveWidgetData<int>(
        'theme_foreground',
        foreground.toARGB32(),
      ),
      HomeWidget.saveWidgetData<int>('theme_muted', muted.toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_eyebrow', primary.toARGB32()),
    ]);
    await _updateWidgets();
  }

  Future<Object?> _refreshMovieSchedule(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) async {
    final movies = await fetchMovies(
      Endpoints.trendingMoviesUrl(settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    final valid = movies
        .where((movie) =>
            movie.id != null &&
            movie.title?.trim().isNotEmpty == true &&
            movie.adult != true)
        .toList(growable: false);
    if (valid.isEmpty) return null;
    await _saveMovieSchedule(valid);
    return true;
  }

  Future<Object?> _refreshTvSchedule(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) async {
    final shows = await fetchTV(
      Endpoints.trendingTVUrl(settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    final valid = shows
        .where((show) =>
            show.id != null &&
            show.name?.trim().isNotEmpty == true &&
            show.adult != true)
        .toList(growable: false);
    if (valid.isEmpty) return null;
    await _saveTvSchedule(valid);
    return true;
  }

  Future<void> _saveMovieSchedule(List<Movie> movies) async {
    final startDay = _epochDay(DateTime.now());
    final items = <Map<String, Object?>>[];
    for (var offset = 0; offset < 7; offset++) {
      final movie = movies[(startDay + offset) % movies.length];
      final image = await _savePoster(
        key: 'movie_daily_$offset',
        posterPath: movie.posterPath,
      );
      items.add(<String, Object?>{
        'title': movie.title,
        'subtitle': _year(movie.releaseDate, fallback: 'Trending movie'),
        'meta': _rating(movie.voteAverage),
        'image': image,
        'deepLink': Uri(
          scheme: 'flixquest',
          host: 'movie',
          queryParameters: <String, String>{
            'id': movie.id.toString(),
            'title': movie.title!,
            if (movie.posterPath != null) 'poster': movie.posterPath!,
            if (movie.backdropPath != null) 'backdrop': movie.backdropPath!,
            if (movie.releaseDate != null) 'date': movie.releaseDate!,
          },
        ).toString(),
      });
    }
    await HomeWidget.saveWidgetData<String>(
      'movie_daily_schedule',
      jsonEncode(<String, Object?>{'startDay': startDay, 'items': items}),
    );
  }

  Future<void> _saveTvSchedule(List<TV> shows) async {
    final startDay = _epochDay(DateTime.now());
    final items = <Map<String, Object?>>[];
    for (var offset = 0; offset < 7; offset++) {
      final show = shows[(startDay + offset) % shows.length];
      final image = await _savePoster(
        key: 'tv_daily_$offset',
        posterPath: show.posterPath,
      );
      items.add(<String, Object?>{
        'title': show.name,
        'subtitle': _year(show.firstAirDate, fallback: 'Trending TV show'),
        'meta': _rating(show.voteAverage),
        'image': image,
        'deepLink': Uri(
          scheme: 'flixquest',
          host: 'tv',
          queryParameters: <String, String>{
            'id': show.id.toString(),
            'name': show.name!,
            if (show.posterPath != null) 'poster': show.posterPath!,
            if (show.backdropPath != null) 'backdrop': show.backdropPath!,
            if (show.firstAirDate != null) 'date': show.firstAirDate!,
          },
        ).toString(),
      });
    }
    await HomeWidget.saveWidgetData<String>(
      'tv_daily_schedule',
      jsonEncode(<String, Object?>{'startDay': startDay, 'items': items}),
    );
  }

  Future<String?> _savePoster({
    required String key,
    required String? posterPath,
  }) async {
    if (posterPath == null || posterPath.isEmpty) return null;
    final sourceKey = '${key}_source';
    final previousSource = await HomeWidget.getWidgetData<String>(sourceKey);
    final previousFile = await HomeWidget.getWidgetData<String>(key);
    if (previousSource == posterPath && previousFile != null) {
      return previousFile;
    }
    try {
      final response = await http
          .get(Uri.parse('${TMDB_BASE_IMAGE_URL}w342$posterPath'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final saved =
          await HomeWidget.saveFile(key, response.bodyBytes, extension: 'jpg');
      await HomeWidget.saveWidgetData<String>(sourceKey, posterPath);
      return saved;
    } catch (error) {
      debugPrint('[HomeWidget] Poster download failed: $error');
      return HomeWidget.getWidgetData<String>(key);
    }
  }

  Future<void> _updateWidgets() async {
    await Future.wait(
      _providers.map(
        (provider) => HomeWidget.updateWidget(
          qualifiedAndroidName: provider,
        ).catchError((Object error) {
          debugPrint('[HomeWidget] Could not update $provider: $error');
          return false;
        }),
      ),
    );
  }

  static int _epochDay(DateTime date) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    return utcDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  static String _duration(int milliseconds) {
    final minutes = Duration(milliseconds: milliseconds).inMinutes;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '${remainder}m watched';
    if (remainder == 0) return '${hours}h watched';
    return '${hours}h ${remainder}m watched';
  }

  static String _rating(num? rating) => rating == null
      ? 'Picked for today'
      : '${rating.toStringAsFixed(1)} / 10  |  Picked for today';

  static String _year(String? date, {required String fallback}) {
    final parsed = date == null ? null : DateTime.tryParse(date);
    return parsed == null ? fallback : parsed.year.toString();
  }

  static String _sessionSubtitle(WellnessViewingSession session) {
    if (session.mediaType == WellnessMediaType.episode) {
      final season = session.seasonNumber;
      final episode = session.episodeNumber;
      if (season != null && episode != null) return 'S$season E$episode';
      if (session.subtitle?.trim().isNotEmpty == true) return session.subtitle!;
    }
    return session.viewingStatus;
  }

  static String _sessionDeepLink(WellnessViewingSession? session) {
    if (session == null) return 'flixquest://wellness';
    if (session.mediaType == WellnessMediaType.movie) {
      return Uri(
        scheme: 'flixquest',
        host: 'movie',
        queryParameters: <String, String>{
          'id': session.contentId,
          'title': session.title,
          if (session.posterPath != null) 'poster': session.posterPath!,
          if (session.backdropPath != null) 'backdrop': session.backdropPath!,
        },
      ).toString();
    }
    final seriesId = session.seriesId;
    if (seriesId == null) return 'flixquest://wellness';
    return Uri(
      scheme: 'flixquest',
      host: 'tv',
      queryParameters: <String, String>{
        'id': seriesId,
        'name': session.title,
        if (session.posterPath != null) 'poster': session.posterPath!,
        if (session.backdropPath != null) 'backdrop': session.backdropPath!,
      },
    ).toString();
  }
}
