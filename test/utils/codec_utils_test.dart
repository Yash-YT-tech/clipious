import 'package:clipious/utils/codec_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('videoCodecLabel', () {
    test('detects AV1 and marks it as software', () {
      expect(videoCodecLabel('av01.0.08M.08', 'video/mp4'), 'AV1 (software)');
    });

    test('detects VP9', () {
      expect(videoCodecLabel('vp09.00.10.08', 'video/webm'), 'VP9');
      expect(videoCodecLabel('vp9', 'video/webm'), 'VP9');
    });

    test('detects H.264', () {
      expect(videoCodecLabel('avc1.640028', 'video/mp4'), 'H.264');
    });

    test('detects HEVC', () {
      expect(videoCodecLabel('hev1.1.6.L93.B0', 'video/mp4'), 'HEVC');
    });

    test('returns empty for unknown or missing codecs', () {
      expect(videoCodecLabel(null, null), '');
      expect(videoCodecLabel('unknown', 'video/mp4'), '');
    });
  });
}
