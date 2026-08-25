import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WellnessPlaybackTracker', () {
    test('counts active playback and excludes pauses', () {
      final tracker = WellnessPlaybackTracker(
        id: 'session',
        createdAt: DateTime.utc(2026, 8, 20, 18),
      );
      tracker.play(DateTime.utc(2026, 8, 20, 18));
      tracker.pause(DateTime.utc(2026, 8, 20, 18, 10));
      tracker.play(DateTime.utc(2026, 8, 20, 18, 30));
      tracker.pause(DateTime.utc(2026, 8, 20, 18, 35));

      expect(tracker.watchedMs(), const Duration(minutes: 15).inMilliseconds);
      expect(tracker.snapshot(), hasLength(2));
    });
  });

  group('WellnessInsights', () {
    final period = WellnessPeriod(
      startUtc: DateTime.utc(2026, 8, 17),
      endUtc: DateTime.utc(2026, 8, 24),
    );

    test('unions simultaneous playback for the headline total', () {
      final first = _session(
        id: 'one',
        contentId: '1',
        title: 'First',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );
      final second = _session(
        id: 'two',
        contentId: '2',
        title: 'Second',
        start: DateTime.utc(2026, 8, 20, 18, 30),
        end: DateTime.utc(2026, 8, 20, 19, 30),
      );

      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[first, second],
        period: period,
      );

      expect(insights.sumPlaybackMs, const Duration(hours: 2).inMilliseconds);
      expect(
        insights.totalWatchedMs,
        const Duration(minutes: 90).inMilliseconds,
      );
    });

    test('adds repeated playback of the same title to the headline total', () {
      final first = _session(
        id: 'rewatch-1',
        contentId: 'same-title',
        title: 'Arrival',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );
      final second = _session(
        id: 'rewatch-2',
        contentId: 'same-title',
        title: 'Arrival',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );

      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[first, second],
        period: period,
      );

      expect(
        insights.totalWatchedMs,
        const Duration(hours: 2).inMilliseconds,
      );
    });

    test('tracks unique completions, series, and rewatches separately', () {
      final sessions = <WellnessViewingSession>[
        _session(
          id: 'movie-1',
          contentId: '10',
          title: 'Arrival',
          start: DateTime.utc(2026, 8, 18, 18),
          end: DateTime.utc(2026, 8, 18, 20),
          completed: true,
        ),
        _session(
          id: 'movie-2',
          contentId: '10',
          title: 'Arrival',
          start: DateTime.utc(2026, 8, 19, 18),
          end: DateTime.utc(2026, 8, 19, 20),
          completed: true,
        ),
        _session(
          id: 'episode-1',
          contentId: 'episode-1',
          seriesId: 'show-1',
          title: 'Severance',
          start: DateTime.utc(2026, 8, 20, 18),
          end: DateTime.utc(2026, 8, 20, 19),
          mediaType: WellnessMediaType.episode,
          completed: true,
        ),
      ];

      final insights = WellnessInsights.fromSessions(sessions, period: period);

      expect(insights.completedMovies, 1);
      expect(insights.completedEpisodes, 1);
      expect(insights.uniqueSeries, 1);
      expect(insights.rewatches, 1);
    });

    test('groups nearby titles into one viewing session', () {
      final sessions = <WellnessViewingSession>[
        _session(
          id: 'episode-1',
          contentId: 'episode-1',
          title: 'Show',
          start: DateTime.utc(2026, 8, 20, 18),
          end: DateTime.utc(2026, 8, 20, 18, 30),
          mediaType: WellnessMediaType.episode,
        ),
        _session(
          id: 'episode-2',
          contentId: 'episode-2',
          title: 'Show',
          start: DateTime.utc(2026, 8, 20, 18, 45),
          end: DateTime.utc(2026, 8, 20, 19, 15),
          mediaType: WellnessMediaType.episode,
        ),
        _session(
          id: 'movie',
          contentId: 'movie',
          title: 'Later',
          start: DateTime.utc(2026, 8, 20, 21),
          end: DateTime.utc(2026, 8, 20, 22),
        ),
      ];

      final insights = WellnessInsights.fromSessions(sessions, period: period);

      expect(insights.sessionCount, 2);
      expect(
        insights.longestSessionMs,
        const Duration(hours: 1).inMilliseconds,
      );
    });

    test('ignores playback shorter than thirty seconds', () {
      final tiny = _session(
        id: 'tiny',
        contentId: '1',
        title: 'Preview',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 18, 0, 29),
      );

      final insights = WellnessInsights.fromSessions(<WellnessViewingSession>[
        tiny,
      ], period: period);

      expect(insights.isEmpty, isTrue);
    });

    test('splits active time across local midnight', () {
      final session = _session(
        id: 'midnight',
        contentId: '1',
        title: 'Late movie',
        start: DateTime.utc(2026, 8, 20, 20, 30),
        end: DateTime.utc(2026, 8, 20, 21, 30),
        timezoneOffsetMinutes: 180,
      );

      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[session],
        period: period,
      );

      expect(
        insights.dailyWatchedMs[DateTime(2026, 8, 20)],
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(
        insights.dailyWatchedMs[DateTime(2026, 8, 21)],
        const Duration(minutes: 30).inMilliseconds,
      );
    });
  });
}

WellnessViewingSession _session({
  required String id,
  required String contentId,
  required String title,
  required DateTime start,
  required DateTime end,
  String? seriesId,
  WellnessMediaType mediaType = WellnessMediaType.movie,
  bool completed = false,
  int timezoneOffsetMinutes = 0,
}) {
  final watchedMs = end.difference(start).inMilliseconds;
  return WellnessViewingSession(
    id: id,
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: mediaType,
    source: WellnessPlaybackSource.streaming,
    contentId: contentId,
    seriesId: seriesId,
    title: title,
    startedAtUtc: start,
    endedAtUtc: end,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    watchedMs: watchedMs,
    durationMs: watchedMs,
    progressEndMs: watchedMs,
    completed: completed,
    segments: <WellnessPlaybackSegment>[
      WellnessPlaybackSegment(startedAtUtc: start, endedAtUtc: end),
    ],
    updatedAtUtc: end,
  );
}
