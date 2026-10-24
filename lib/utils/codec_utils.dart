/// Returns a short, human-readable label for a video codec.
///
/// Invidious exposes several codecs for the same resolution. On older Android
/// devices AV1 is typically decoded in software, which is much slower than the
/// hardware H.264/VP9 decoders. Showing the codec lets the user choose a
/// smooth track, and flags AV1 as software-decoded.
String videoCodecLabel(String? codecs, String? mimeType) {
  final codec = (codecs ?? '').toLowerCase();
  final mime = (mimeType ?? '').toLowerCase();

  if (codec.contains('av01') || mime.contains('av01')) {
    return 'AV1 (software)';
  }
  if (codec.contains('vp09') || codec.contains('vp9') || mime.contains('vp9')) {
    return 'VP9';
  }
  if (codec.contains('avc1') ||
      codec.contains('h264') ||
      mime.contains('avc')) {
    return 'H.264';
  }
  if (codec.contains('hev1') ||
      codec.contains('hvc1') ||
      codec.contains('hevc')) {
    return 'HEVC';
  }
  return '';
}
