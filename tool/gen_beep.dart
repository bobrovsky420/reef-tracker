// Generates assets/sounds/timer_beep.wav — the double beep played when a
// Hanna measurement timer runs out. Checked-in asset; rerun only if the tone
// design changes:
//
//   dart run tool/gen_beep.dart
//
// Two 160 ms sine bursts at 1568 Hz (G6 — piercing enough to cut through a
// running skimmer, not shrill) separated by 120 ms of silence, with 8 ms
// linear fade-in/out ramps on each burst so the edges don't click.
// 44.1 kHz / 16-bit / mono PCM.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const freq = 1568.0;
  const beepMs = 160, gapMs = 120, rampMs = 8;
  const amplitude = 0.55;

  final beepSamples = sampleRate * beepMs ~/ 1000;
  final gapSamples = sampleRate * gapMs ~/ 1000;
  final rampSamples = sampleRate * rampMs ~/ 1000;

  final samples = <int>[];
  for (var burst = 0; burst < 2; burst++) {
    for (var i = 0; i < beepSamples; i++) {
      var envelope = 1.0;
      if (i < rampSamples) envelope = i / rampSamples;
      final tail = beepSamples - 1 - i;
      if (tail < rampSamples) envelope = math.min(envelope, tail / rampSamples);
      final v = amplitude *
          envelope *
          math.sin(2 * math.pi * freq * i / sampleRate);
      samples.add((v * 32767).round());
    }
    if (burst == 0) samples.addAll(List.filled(gapSamples, 0));
  }

  final dataSize = samples.length * 2;
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16); // PCM chunk size
  u16(1); // PCM format
  u16(1); // mono
  u32(sampleRate);
  u32(sampleRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits per sample
  str('data');
  u32(dataSize);
  for (final s in samples) {
    u16(s & 0xFFFF);
  }

  final out = File('assets/sounds/timer_beep.wav');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(b.toBytes());
  stdout.writeln('wrote ${out.path} (${b.length} bytes)');
}
