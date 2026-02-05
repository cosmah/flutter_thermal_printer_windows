import 'dart:convert';
import 'dart:typed_data';

import 'models/enums.dart';

/// Generates ESC/POS command sequences for thermal printers.
///
/// Implements common ESC/POS commands for text formatting, images,
/// barcodes, QR codes, and paper control.
class EscPosGenerator {
  EscPosGenerator();

  // ESC/POS byte constants
  static const int _esc = 0x1B;
  static const int _gs = 0x1D;
  static const int _lf = 0x0A;

  /// Initialize printer (clear buffer, reset modes).
  Uint8List initializePrinter() {
    return Uint8List.fromList([_esc, 0x40]);
  }

  /// Bold (emphasis): [enabled] true = on, false = off.
  Uint8List setBold(bool enabled) {
    return Uint8List.fromList([_esc, 0x45, enabled ? 1 : 0]);
  }

  /// Underline: [enabled] true = 1-dot underline, false = off.
  Uint8List setUnderline(bool enabled) {
    return Uint8List.fromList([_esc, 0x2D, enabled ? 1 : 0]);
  }

  /// Text alignment: left (0), center (1), right (2).
  Uint8List setAlignment(TextAlignment alignment) {
    final n = alignment.index.clamp(0, 2);
    return Uint8List.fromList([_esc, 0x61, n]);
  }

  /// Character size: GS ! n (bits 0-3 height, 4-7 width; 0=1x1, 1=2x2, etc).
  Uint8List setFontSize(FontSize size) {
    int n = 0;
    switch (size) {
      case FontSize.small:
        n = 0;
        break;
      case FontSize.normal:
        n = 0;
        break;
      case FontSize.large:
        n = 0x11; // 2x2
        break;
    }
    return Uint8List.fromList([_gs, 0x21, n]);
  }

  /// Print [text] as UTF-8, followed by line feed.
  Uint8List printText(String text) {
    final bytes = Uint8List.fromList([...utf8.encode(text), _lf]);
    return bytes;
  }

  /// Feed [lines] blank lines.
  Uint8List feedLines(int lines) {
    final n = lines.clamp(0, 255);
    return Uint8List.fromList([_esc, 0x64, n]);
  }

  /// Full cut (GS V 0). No-op if printer does not support cutting.
  Uint8List cutPaper() {
    return Uint8List.fromList([_gs, 0x56, 0]);
  }

  /// Partial cut (GS V 1). Optional.
  Uint8List cutPaperPartial() {
    return Uint8List.fromList([_gs, 0x56, 1]);
  }

  // --- Image: monochrome raster (GS v 0) ---
  /// Print monochrome raster image. [imageData] is 1 bit per pixel (MSB first),
  /// [width] and [height] in pixels. Each row padded to multiple of 8 bits.
  Uint8List printImage(Uint8List imageData, int width, int height) {
    if (width <= 0 || height <= 0) return Uint8List(0);
    return Uint8List.fromList([
      _gs,
      0x76,
      0x30,
      (width >> 0) & 0xFF,
      (width >> 8) & 0xFF,
      (height >> 0) & 0xFF,
      (height >> 8) & 0xFF,
      ...imageData,
    ]);
  }

  /// Convert RGBA or grayscale image bytes to 1bpp (black/white) for thermal.
  /// [pixels] row-major, 1 byte per pixel (use R or luminance); [width], [height].
  /// Threshold: pixel >= [threshold] (0-255) becomes white (0), else black (1).
  static Uint8List imageToMonochrome(
    Uint8List pixels,
    int width,
    int height, {
    int threshold = 128,
  }) {
    final rowBytes = (width + 7) >> 3;
    final out = Uint8List(rowBytes * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        final v = i < pixels.length ? pixels[i] : 0;
        if (v < threshold) {
          final byteIndex = y * rowBytes + (x >> 3);
          out[byteIndex] |= 0x80 >> (x & 7);
        }
      }
    }
    return out;
  }

  // --- Barcode: GS k ---
  /// Print barcode. [data] content, [type] Code128/Code39/EAN13/EAN8.
  /// Code128 (type 73) is most common for alphanumeric.
  Uint8List printBarcode(String data, BarcodeType type) {
    int m = 73; // Code 128 by default
    switch (type) {
      case BarcodeType.code128:
        m = 73;
        break;
      case BarcodeType.code39:
        m = 69;
        break;
      case BarcodeType.ean13:
        m = 67;
        break;
      case BarcodeType.ean8:
        m = 68;
        break;
      case BarcodeType.qrCode:
        return printQrCode(data, 4);
    }
    final bytes = utf8.encode(data);
    if (bytes.length > 255) return Uint8List(0);
    return Uint8List.fromList([
      _gs,
      0x6B, // k
      m,
      bytes.length,
      ...bytes,
    ]);
  }

  /// Print QR code. [data] content, [size] module size (1-16, typically 4-8).
  Uint8List printQrCode(String data, int size) {
    final s = size.clamp(1, 16);
    final bytes = utf8.encode(data);
    // GS ( k - QR code model/store/print
    // Simplified: use GS ( k with model 2, store and print
    final len = bytes.length + 3;
    final pL = len & 0xFF;
    final pH = (len >> 8) & 0xFF;
    return Uint8List.fromList([
      _gs,
      0x28,
      0x6B,
      4,
      0,
      49,
      65,
      50,
      0,
      pL,
      pH,
      ...bytes,
      _gs,
      0x28,
      0x6B,
      3,
      0,
      49,
      67,
      s,
      _gs,
      0x28,
      0x6B,
      3,
      0,
      49,
      81,
      48,
    ]);
  }
}
