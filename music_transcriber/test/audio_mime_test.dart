import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/utils/audio_mime.dart';

void main() {
  test('audioMimeTypeFor maps common extensions, ignoring case', () {
    expect(audioMimeTypeFor('Song.MP3'), 'audio/mpeg');
    expect(audioMimeTypeFor('take 2.m4a'), 'audio/mp4');
    expect(audioMimeTypeFor('a.b.flac'), 'audio/flac');
  });

  test('audioMimeTypeFor falls back to a generic type', () {
    expect(audioMimeTypeFor('noextension'), 'application/octet-stream');
    expect(audioMimeTypeFor('weird.xyz'), 'application/octet-stream');
  });

  test('extensionForMime ignores codec parameters', () {
    expect(extensionForMime('audio/webm;codecs=opus'), 'webm');
    expect(extensionForMime('audio/ogg; codecs=opus'), 'ogg');
    expect(extensionForMime('audio/mp4'), 'm4a');
    expect(extensionForMime(''), 'webm');
  });
}
