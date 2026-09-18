import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/audio/sfx_manager.dart';

void main() {
  test('every SFX variant is a short non-silent unclipped PCM WAV', () {
    for (final filename in sfxCatalog.values.expand((spec) => spec.files)) {
      final bytes = File('assets/audio/sfx/$filename').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF',
          reason: filename);
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(20, Endian.little), 1); // PCM
      expect(data.getUint16(22, Endian.little), 1); // mono
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.getUint16(34, Endian.little), 16);
      var offset = 12;
      var samples = 0;
      var peak = 0;
      while (offset + 8 <= bytes.length) {
        final size = data.getUint32(offset + 4, Endian.little);
        if (String.fromCharCodes(bytes.sublist(offset, offset + 4)) == 'data') {
          samples = size ~/ 2;
          for (var i = offset + 8; i < offset + 8 + size; i += 2) {
            final value = data.getInt16(i, Endian.little).abs();
            if (value > peak) peak = value;
          }
        }
        offset += 8 + size + size % 2;
      }
      expect(samples / 44100, inInclusiveRange(.025, 1.0), reason: filename);
      expect(peak, inInclusiveRange(500, 30000), reason: filename);
    }
  });
}
