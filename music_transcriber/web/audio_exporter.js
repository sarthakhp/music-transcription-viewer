/*
 * Offline (non real-time) audio export: decode -> pitch/tempo shift via the
 * same SoundTouch worklet used for live playback -> encode to MP3.
 *
 * Runs through an OfflineAudioContext rather than capturing live playback,
 * so it doesn't have to idle-wait between audio blocks. In practice this is
 * only modestly faster than real-time (roughly 1.5-2x) since the SoundTouch
 * worklet's own DSP cost, not idle time, dominates — not the "instant"
 * export a bigger speedup would allow, but still meaningfully better than
 * real-time capture.
 */
import { SoundTouchNode } from './SoundTouchNode.js';

const MPEG_FRAME_SAMPLES = 1152;
const MP3_BITRATE_KBPS = 128;
// Safety margin for the worklet's internal processing latency, so the tail
// of the track isn't cut off. Results in a little trailing silence instead.
const TAIL_PADDING_SECONDS = 1.0;
// Rendering is only modestly faster than real-time (the SoundTouch worklet's
// DSP cost dominates), so it's worth reporting progress rather than looking
// frozen. Checkpoints reserve the last 10% of progress for encoding.
const RENDER_PROGRESS_CHECKPOINTS = 20;

async function decodeToAudioBuffer(arrayBuffer) {
  const tempCtx = new AudioContext();
  try {
    return await tempCtx.decodeAudioData(arrayBuffer);
  } finally {
    await tempCtx.close();
  }
}

function floatTo16BitPCM(floatSamples) {
  const out = new Int16Array(floatSamples.length);
  for (let i = 0; i < floatSamples.length; i++) {
    const s = Math.max(-1, Math.min(1, floatSamples[i]));
    out[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
  }
  return out;
}

function encodeMp3(leftFloat, rightFloat, sampleRate) {
  const encoder = new lamejs.Mp3Encoder(2, sampleRate, MP3_BITRATE_KBPS);
  const left = floatTo16BitPCM(leftFloat);
  const right = floatTo16BitPCM(rightFloat);
  const chunks = [];
  let totalLength = 0;

  for (let i = 0; i < left.length; i += MPEG_FRAME_SAMPLES) {
    const leftChunk = left.subarray(i, i + MPEG_FRAME_SAMPLES);
    const rightChunk = right.subarray(i, i + MPEG_FRAME_SAMPLES);
    const encoded = encoder.encodeBuffer(leftChunk, rightChunk);
    if (encoded.length > 0) {
      chunks.push(encoded);
      totalLength += encoded.length;
    }
  }
  const flushed = encoder.flush();
  if (flushed.length > 0) {
    chunks.push(flushed);
    totalLength += flushed.length;
  }

  const result = new Uint8Array(totalLength);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.length;
  }
  return result;
}

/**
 * @param {ArrayBuffer} arrayBuffer - raw bytes of the source audio file.
 * @param {number} semitones - pitch shift, independent of speed.
 * @param {number} speed - tempo multiplier (1.0 = original speed).
 * @param {(fraction: number) => void} [onProgress] - called with 0..1.
 * @returns {Promise<Uint8Array>} encoded MP3 bytes.
 */
export async function exportMp3(arrayBuffer, semitones, speed, onProgress) {
  const decoded = await decodeToAudioBuffer(arrayBuffer);
  const sampleRate = decoded.sampleRate;
  const outputSeconds = decoded.duration / speed + TAIL_PADDING_SECONDS;
  const outputLength = Math.ceil(outputSeconds * sampleRate);

  const offlineCtx = new OfflineAudioContext(2, outputLength, sampleRate);
  await SoundTouchNode.register(offlineCtx, 'soundtouch-processor.js');

  const source = offlineCtx.createBufferSource();
  source.buffer = decoded;

  // AudioBufferSourceNode has no browser-level pitch-preserving playback
  // rate (unlike the HTMLAudioElement used for live playback), so SoundTouch
  // itself drives both tempo (speed) and pitch here.
  const stNode = new SoundTouchNode(offlineCtx);
  stNode.tempo.value = speed;
  stNode.pitchSemitones.value = semitones;

  source.connect(stNode);
  stNode.connect(offlineCtx.destination);
  source.start(0);

  if (onProgress) {
    const totalSeconds = outputLength / sampleRate;
    for (let i = 1; i < RENDER_PROGRESS_CHECKPOINTS; i++) {
      const checkpointTime = (totalSeconds * i) / RENDER_PROGRESS_CHECKPOINTS;
      offlineCtx.suspend(checkpointTime).then(() => {
        onProgress((i / RENDER_PROGRESS_CHECKPOINTS) * 0.9);
        offlineCtx.resume();
      });
    }
  }

  const rendered = await offlineCtx.startRendering();
  onProgress?.(0.9);

  const left = rendered.getChannelData(0);
  const right = rendered.numberOfChannels > 1 ? rendered.getChannelData(1) : left;

  const mp3 = encodeMp3(left, right, sampleRate);
  onProgress?.(1.0);
  return mp3;
}
