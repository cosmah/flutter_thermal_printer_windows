// Property 5: Format Support Completeness
// For any supported content type (text with formatting, images, barcodes),
// the print engine should generate appropriate ESC/POS commands without errors.
// Validates: Requirements 3.5, 5.1, 5.2, 5.3, 5.4, 5.5

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 5: Format Support Completeness',
    () {
      late EscPosGenerator generator;

      setUp(() {
        generator = EscPosGenerator();
      });

      test('initializePrinter returns non-empty ESC/POS bytes', () {
        final cmd = generator.initializePrinter();
        expect(cmd, isNotEmpty);
        expect(cmd[0], 0x1B);
        expect(cmd[1], 0x40);
      });

      test('setBold returns valid bytes', () {
        expect(generator.setBold(true), isNotEmpty);
        expect(generator.setBold(false), isNotEmpty);
      });

      test('setUnderline returns valid bytes', () {
        expect(generator.setUnderline(true), isNotEmpty);
        expect(generator.setUnderline(false), isNotEmpty);
      });

      test('setAlignment returns valid bytes for all alignments', () {
        for (final a in TextAlignment.values) {
          final cmd = generator.setAlignment(a);
          expect(cmd, isNotEmpty);
          expect(cmd[0], 0x1B);
          expect(cmd[1], 0x61);
          expect(cmd[2], lessThanOrEqualTo(2));
        }
      });

      test('setFontSize returns valid bytes for all sizes', () {
        for (final s in FontSize.values) {
          final cmd = generator.setFontSize(s);
          expect(cmd, isNotEmpty);
        }
      });

      test('printText returns bytes ending with LF', () {
        final cmd = generator.printText('Hello');
        expect(cmd, isNotEmpty);
        expect(cmd.last, 0x0A);
      });

      test('printText handles empty and unicode', () {
        expect(generator.printText(''), isNotEmpty);
        expect(generator.printText(' café 日本 '), isNotEmpty);
      });

      test('feedLines and cutPaper return non-empty bytes', () {
        expect(generator.feedLines(1), isNotEmpty);
        expect(generator.feedLines(5), isNotEmpty);
        expect(generator.cutPaper(), isNotEmpty);
        expect(generator.cutPaperPartial(), isNotEmpty);
      });

      test('printImage returns valid header + data for 1bpp image', () {
        final rowBytes = (8 + 7) >> 3;
        final data = Uint8List(rowBytes * 8);
        final cmd = generator.printImage(data, 8, 8);
        expect(cmd.length, greaterThanOrEqualTo(7 + data.length));
        expect(cmd[0], 0x1D);
        expect(cmd[1], 0x76);
      });

      test('printBarcode returns non-empty bytes for Code128 and Code39', () {
        expect(
          generator.printBarcode('ABC123', BarcodeType.code128),
          isNotEmpty,
        );
        expect(generator.printBarcode('ABC', BarcodeType.code39), isNotEmpty);
        expect(
          generator.printBarcode('1234567890123', BarcodeType.ean13),
          isNotEmpty,
        );
        expect(
          generator.printBarcode('12345678', BarcodeType.ean8),
          isNotEmpty,
        );
      });

      test('printQrCode returns non-empty bytes', () {
        expect(generator.printQrCode('https://example.com', 4), isNotEmpty);
        expect(generator.printQrCode('', 1), isNotEmpty);
      });

      test('imageToMonochrome produces 1bpp bitmap', () {
        final pixels = Uint8List.fromList(List.filled(16 * 16, 0));
        for (var i = 0; i < 64; i++) {
          pixels[i] = 255;
        }
        final mono = EscPosGenerator.imageToMonochrome(pixels, 16, 16);
        final expectedBytes = ((16 + 7) >> 3) * 16;
        expect(mono.length, expectedBytes);
      });
    },
  );
}
