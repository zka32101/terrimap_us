import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('天候の重ね画像: 8種類がそろい、どれも縦長 768x1344 の PNG（盤面と同じ向き）', () {
    for (final t in ['hurricane', 'tornado', 'blizzard', 'heatwave', 'wildfire', 'flood', 'earthquake', 'storm']) {
      final f = File('assets/art/weather/$t.png');
      expect(f.existsSync(), true, reason: t);
      final b = f.readAsBytesSync();
      expect(b.sublist(1, 4), [0x50, 0x4E, 0x47], reason: '$t PNG');
      final d = ByteData.sublistView(Uint8List.fromList(b.sublist(16, 24)));
      expect((d.getUint32(0), d.getUint32(4)), (768, 1344), reason: t);
    }
  });
}
