// Lock-screen / notification / media-key integration (Media Session API).
// Real implementation on web; a no-op elsewhere.
export 'media_session_stub.dart'
    if (dart.library.js_interop) 'media_session_web.dart';
