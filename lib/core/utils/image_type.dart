import 'dart:typed_data';

/// Works out the image type from the file's first bytes (never trusts the file name).
/// Only JPEG, PNG and WebP are accepted; anything else returns null.
({String mime, String ext})? sniffImageType(Uint8List b) {
  if (b.length > 12 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return (mime: 'image/png', ext: 'png');
  }
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return (mime: 'image/jpeg', ext: 'jpg');
  }
  if (b.length > 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return (mime: 'image/webp', ext: 'webp');
  }
  return null;
}
