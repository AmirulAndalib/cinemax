import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/player_buffering_configuration.dart';

void main() {
  test('old six-minute preference is bounded and refills before reserve runs out', () {
    final configuration = buildPlayerBufferingConfiguration(
      maximumDurationMs: 360000, television: false,
    );
    expect(configuration.maxBufferMs, 180000);
    expect(configuration.minBufferMs, 60000);
    expect(configuration.bufferForPlaybackMs, 1500);
    expect(configuration.bufferForPlaybackAfterRebufferMs, 5000);
  });

  test('TV gives its sample budget to upcoming media', () {
    final configuration = buildPlayerBufferingConfiguration(
      maximumDurationMs: 360000, television: true,
    );
    expect(configuration.maxBufferMs, 60000);
    expect(configuration.minBufferMs, 30000);
    expect(configuration.backBufferDurationMs, 0);
  });

  test('every supported ceiling and corrupt persisted values produce valid native durations', () {
    for (final television in [false, true]) {
      for (final maximum in [-1, 0, 1000, 15000, 30000, 45000, 60000, 120000, 600000]) {
        final configuration = buildPlayerBufferingConfiguration(
          maximumDurationMs: maximum, television: television,
        );
        expect(configuration.maxBufferMs, greaterThanOrEqualTo(configuration.minBufferMs));
        expect(configuration.minBufferMs, greaterThanOrEqualTo(configuration.bufferForPlaybackAfterRebufferMs));
        expect(configuration.minBufferMs, greaterThanOrEqualTo(configuration.bufferForPlaybackMs));
      }
    }
  });
}
