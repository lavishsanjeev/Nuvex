import 'dart:io';
import 'dart:typed_data';

/// Extracts (width, height) from raw JPEG bytes by inspecting SOF markers in O(1) time.
///
/// Returns null if not a valid JPEG or SOF marker is missing.
({int width, int height})? getJpegDimensions(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return null;
  }
  int i = 2;
  while (i < bytes.length - 8) {
    if (bytes[i] == 0xFF) {
      final marker = bytes[i + 1];
      // SOF0 (Baseline), SOF1 (Extended), SOF2 (Progressive)
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        final height = (bytes[i + 5] << 8) | bytes[i + 6];
        final width = (bytes[i + 7] << 8) | bytes[i + 8];
        return (width: width, height: height);
      }
      if (marker == 0xD9 || marker == 0xDA) {
        // EOI or SOS marker
        break;
      }
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      i += 2 + len;
    } else {
      i++;
    }
  }
  return null;
}

/// Extracts (width, height) from raw PNG bytes by inspecting the IHDR chunk in O(1) time.
///
/// Returns null if not a valid PNG or IHDR chunk is missing.
({int width, int height})? getPngDimensions(Uint8List bytes) {
  if (bytes.length < 24) {
    return null;
  }
  // Check PNG signature: 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'
  if (bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47 ||
      bytes[4] != 0x0D ||
      bytes[5] != 0x0A ||
      bytes[6] != 0x1A ||
      bytes[7] != 0x0A) {
    return null;
  }
  // Check IHDR chunk type: 'I', 'H', 'D', 'R'
  if (bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }
  final width =
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final height =
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  if (width <= 0 || height <= 0) return null;
  return (width: width, height: height);
}

/// Inspects leading bytes to extract image dimensions (width, height) without decoding pixels.
///
/// Supports JPEG and PNG headers in O(1) time.
({int width, int height})? getImageDimensions(Uint8List bytes) {
  final jpg = getJpegDimensions(bytes);
  if (jpg != null) return jpg;
  final png = getPngDimensions(bytes);
  if (png != null) return png;
  return null;
}

/// Validates whether a cached thumbnail file is a genuine high-quality thumbnail.
///
/// Ensures:
/// 1. File exists and is > 1500 bytes (stripped thumbnails are ~700 bytes).
/// 2. Header decodes to actual dimensions with width >= 120 and height >= 120
///    (stripped thumbnails are 40x40; real Telegram 'm' thumbnails are ~320x320).
bool isValidHqThumbnail(File file) {
  try {
    if (!file.existsSync() || file.lengthSync() < 1500) {
      return false;
    }
    final bytes = file.readAsBytesSync();
    final dims = getJpegDimensions(bytes);
    if (dims == null) return false;
    return dims.width >= 120 && dims.height >= 120;
  } catch (_) {
    return false;
  }
}
