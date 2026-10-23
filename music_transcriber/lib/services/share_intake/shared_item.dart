import '../phone_audio/selected_audio.dart';

/// Something another app shared to this one.
sealed class SharedItem {
  const SharedItem();
}

/// An audio file, already copied into the app's cache (so the clip owns it).
class SharedAudio extends SharedItem {
  final SelectedAudio audio;
  const SharedAudio(this.audio);
}

/// A link found in shared text (a YouTube "Share" sends the title and the link).
class SharedLink extends SharedItem {
  final String url;
  const SharedLink(this.url);
}
