// Web Audio pitch shifting via @soundtouchjs/audio-worklet.
// Setup (graph wiring) is separated from playback so async worklet loading
// never blocks the play() user-gesture path.

(function () {
  'use strict';

  const MAIN_URL =
    'https://unpkg.com/@soundtouchjs/audio-worklet@1.0.10/dist/index.js';
  const WORKLET_URL =
    'https://unpkg.com/@soundtouchjs/audio-worklet@1.0.10/dist/soundtouch-processor.js';

  let _ctx = null;
  let _currentSemitones = 0;

  // blobUrl -> HTMLAudioElement (our elements, not just_audio's)
  const _elements = new Map();
  // blobUrl -> MediaElementAudioSourceNode (created once per element)
  const _sources = new Map();
  // blobUrl -> SoundTouchNode | null (null = passthrough)
  const _stNodes = new Map();

  // Start loading SoundTouchNode immediately so it's ready by setup() time.
  let _SoundTouchNode = null;
  const _stLoading = import(MAIN_URL)
    .then(m => {
      _SoundTouchNode = m.SoundTouchNode || m.default;
      console.log('[PS] SoundTouchNode loaded: ' + typeof _SoundTouchNode);
    })
    .catch(e => console.warn('[PS] SoundTouch load failed: ' + (e.message || e)));

  function _applyPitch(stNode, semitones) {
    const p = stNode.pitchSemitones;
    if (p !== null && typeof p === 'object' && 'value' in p) {
      p.value = semitones;   // AudioParam API (v1.x)
    } else {
      stNode.pitchSemitones = semitones;  // plain property (legacy)
    }
  }

  window.pitchShifter = {
    // Called as each track loads — creates an <audio> element immediately.
    loadTrack(blobUrl) {
      if (_elements.has(blobUrl)) return;
      const el = document.createElement('audio');
      el.src = blobUrl;
      el.preload = 'auto';
      _elements.set(blobUrl, el);
      console.log('[PS] loadTrack total=' + _elements.size);
    },

    // Called ONCE after all tracks are loaded.
    // Creates AudioContext, waits for SoundTouch, wires Web Audio graph.
    // Does NOT require a user gesture (context starts suspended).
    async setup() {
      if (_ctx) {
        console.log('[PS] setup: already initialised');
        return;
      }

      _ctx = new AudioContext(); // suspended — no gesture needed
      console.log('[PS] AudioContext created, state=' + _ctx.state);

      // Wait for SoundTouchNode with a 5-second deadline before falling back.
      if (!_SoundTouchNode) {
        try {
          await Promise.race([
            _stLoading,
            new Promise((_, rej) =>
              setTimeout(() => rej(new Error('timeout')), 5000)
            ),
          ]);
        } catch (e) {
          console.warn('[PS] ' + e.message + ' — falling back to passthrough');
        }
      }

      // Register the AudioWorklet processor.
      let workletReady = false;
      if (_SoundTouchNode) {
        try {
          if (typeof _SoundTouchNode.register === 'function') {
            await _SoundTouchNode.register(_ctx, WORKLET_URL);
          } else {
            await _ctx.audioWorklet.addModule(WORKLET_URL);
          }
          workletReady = true;
          console.log('[PS] AudioWorklet registered');
        } catch (e) {
          console.warn('[PS] Worklet registration failed: ' + (e.message || e));
        }
      }

      // Wire each audio element into the Web Audio graph.
      for (const [url, el] of _elements) {
        let source;
        try {
          source = _ctx.createMediaElementSource(el);
          _sources.set(url, source);
        } catch (e) {
          console.error('[PS] createMediaElementSource failed: ' + (e.message || e));
          continue;
        }

        if (workletReady && _SoundTouchNode) {
          try {
            const stNode = new _SoundTouchNode(_ctx, { bufferSize: 4096 });
            _applyPitch(stNode, _currentSemitones);
            source.connect(stNode);
            stNode.connect(_ctx.destination);
            _stNodes.set(url, stNode);
            console.log('[PS] Connected with pitch shift');
          } catch (e) {
            console.warn('[PS] SoundTouchNode failed: ' + (e.message || e) + ' — passthrough');
            source.connect(_ctx.destination);
            _stNodes.set(url, null);
          }
        } else {
          source.connect(_ctx.destination);
          _stNodes.set(url, null);
          console.log('[PS] Connected passthrough');
        }
      }
    },

    // Called on user gesture (first thing in play()). Resumes the AudioContext
    // if it is suspended. This is the only async step in the play path.
    async resume() {
      if (_ctx && _ctx.state === 'suspended') {
        await _ctx.resume();
        console.log('[PS] AudioContext resumed');
      }
    },

    async play(blobUrl) {
      const el = _elements.get(blobUrl);
      if (!el) { console.warn('[PS] play: unknown url'); return; }
      try {
        await el.play();
        console.log('[PS] play ok t=' + el.currentTime.toFixed(3));
      } catch (e) {
        console.error('[PS] play failed: ' + (e.message || e));
      }
    },

    pause(blobUrl) {
      const el = _elements.get(blobUrl);
      if (el) el.pause();
    },

    seek(blobUrl, seconds) {
      const el = _elements.get(blobUrl);
      if (el) el.currentTime = seconds;
    },

    setPitchSemitones(semitones) {
      _currentSemitones = semitones;
      for (const stNode of _stNodes.values()) {
        if (stNode) _applyPitch(stNode, semitones);
      }
    },

    reset() {
      for (const el of _elements.values()) { el.pause(); el.src = ''; }
      _elements.clear();
      _sources.clear();
      _stNodes.clear();
      if (_ctx) { _ctx.close().catch(() => {}); _ctx = null; }
      _currentSemitones = 0;
    },
  };
})();
