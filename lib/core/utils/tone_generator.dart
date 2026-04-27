// lib/core/utils/tone_generator.dart
import 'dart:math';
import 'dart:typed_data';

/// Generates procedural WAV alarm tones without needing audio files.
class ToneGenerator {
  /// Generate a critical alarm WAV (urgent alternating tones).
  static Uint8List criticalAlarm() {
    return _generateTone(
      frequencies: [880, 1100],
      durationMs: 3000,
      sampleRate: 22050,
      alternateEveryMs: 250,
    );
  }

  /// Generate a warning alarm WAV (gentler beeping).
  static Uint8List warningAlarm() {
    return _generateTone(
      frequencies: [660],
      durationMs: 2000,
      sampleRate: 22050,
      alternateEveryMs: 500,
      silentMs: 250,
    );
  }

  static Uint8List _generateTone({
    required List<int> frequencies,
    required int durationMs,
    required int sampleRate,
    int alternateEveryMs = 500,
    int silentMs = 0,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    final samplesPerAlternate = (sampleRate * alternateEveryMs / 1000).round();
    final silentSamples = (sampleRate * silentMs / 1000).round();

    int freqIdx = 0;
    for (int i = 0; i < numSamples; i++) {
      // Alternate frequency
      if (samplesPerAlternate > 0 && i > 0 && i % samplesPerAlternate == 0) {
        freqIdx = (freqIdx + 1) % frequencies.length;
      }

      // Silent gap
      if (silentMs > 0) {
        final posInCycle = i % (samplesPerAlternate + silentSamples);
        if (posInCycle >= samplesPerAlternate) {
          samples[i] = 0;
          continue;
        }
      }

      final freq = frequencies[freqIdx];
      final t = i / sampleRate;
      final value = (sin(2 * pi * freq * t) * 16000).round().clamp(-32768, 32767);
      samples[i] = value;
    }

    return _wavFromSamples(samples, sampleRate);
  }

  static Uint8List _wavFromSamples(Int16List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57);  // W
    buffer.setUint8(9, 0x41);  // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little);           // chunk size
    buffer.setUint16(20, 1, Endian.little);            // PCM
    buffer.setUint16(22, 1, Endian.little);            // mono
    buffer.setUint32(24, sampleRate, Endian.little);   // sample rate
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little);            // block align
    buffer.setUint16(34, 16, Endian.little);           // bits per sample

    // data chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
