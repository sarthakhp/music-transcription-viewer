# Local patch: just_audio 0.9.46

Vendored from pub.dev because `audioTimePitchAlgorithm` is hardcoded and not
exposed via the Dart API.

**Change:** `darwin/just_audio/Sources/just_audio/UriAudioSource.m` —
`AVAudioTimePitchAlgorithmTimeDomain` → `AVAudioTimePitchAlgorithmSpectral`.
TimeDomain is tuned for voice and sounds choppy on music when speed != 1.0;
Spectral is the high-quality algorithm meant for music.

To upgrade: copy a newer just_audio release into this directory and reapply
the one-line change above.
