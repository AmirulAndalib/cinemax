import 'package:better_player_plus/better_player_plus.dart';

/// Validate old persisted values and keep the refill threshold below the ceiling.
BetterPlayerBufferingConfiguration buildPlayerBufferingConfiguration({
  required int maximumDurationMs,
  required bool television,
}) {
  final maximum = maximumDurationMs.clamp(15000, television ? 60000 : 180000);
  return BetterPlayerBufferingConfiguration(
    minBufferMs:
        (maximum * 0.5).round().clamp(15000, television ? 30000 : 60000),
    maxBufferMs: maximum,
    bufferForPlaybackMs: 1500,
    bufferForPlaybackAfterRebufferMs: 5000,
    backBufferDurationMs: television ? 0 : 15000,
    retainBackBufferFromKeyframe: false,
  );
}
