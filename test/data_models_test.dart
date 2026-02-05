import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

void main() {
  group('ReceiptSettings', () {
    test('valid default does not throw', () {
      const s = ReceiptSettings();
      expect(() => s.validate(), returnsNormally);
    });
    test('paperWidth 1 is valid', () {
      const s = ReceiptSettings(paperWidth: 1);
      expect(() => s.validate(), returnsNormally);
    });
    test('paperWidth 256 is valid', () {
      const s = ReceiptSettings(paperWidth: 256);
      expect(() => s.validate(), returnsNormally);
    });
    test('paperWidth 257 throws', () {
      const s = ReceiptSettings(paperWidth: 257);
      expect(() => s.validate(), throwsA(isA<ValidationException>()));
    });
    test('feedLinesAfterCut 0 is valid', () {
      const s = ReceiptSettings(feedLinesAfterCut: 0);
      expect(() => s.validate(), returnsNormally);
    });
    test('feedLinesAfterCut 256 throws', () {
      const s = ReceiptSettings(feedLinesAfterCut: 256);
      expect(() => s.validate(), throwsA(isA<ValidationException>()));
    });
  });

  group('ReceiptItem', () {
    test('text item with text is valid', () {
      const item = ReceiptItem(type: ReceiptItemType.text, text: 'x');
      expect(() => item.validate(), returnsNormally);
    });
    test('barcode item with barcodeData is valid', () {
      const item = ReceiptItem(
        type: ReceiptItemType.barcode,
        barcodeData: BarcodeData(data: '123', type: BarcodeType.code128),
      );
      expect(() => item.validate(), returnsNormally);
    });
    test('qrCode item with barcodeData is valid', () {
      const item = ReceiptItem(
        type: ReceiptItemType.qrCode,
        barcodeData: BarcodeData(data: 'url', type: BarcodeType.qrCode),
      );
      expect(() => item.validate(), returnsNormally);
    });
    test('image item with imageData is valid', () {
      final item = ReceiptItem(
        type: ReceiptItemType.image,
        imageData: Uint8List.fromList([0, 1]),
      );
      expect(() => item.validate(), returnsNormally);
    });
    test('line and spacer do not throw', () {
      expect(
        () => ReceiptItem(type: ReceiptItemType.line).validate(),
        returnsNormally,
      );
      expect(
        () => ReceiptItem(type: ReceiptItemType.spacer).validate(),
        returnsNormally,
      );
    });
    test('barcodeData empty data throws', () {
      const item = ReceiptItem(
        type: ReceiptItemType.barcode,
        barcodeData: BarcodeData(data: '', type: BarcodeType.code128),
      );
      expect(() => item.validate(), throwsA(isA<ValidationException>()));
    });
  });

  group('Receipt', () {
    test('empty items valid receipt does not throw', () {
      final receipt = Receipt(items: [], settings: ReceiptSettings());
      expect(() => receipt.validate(), returnsNormally);
    });
    test('invalid settings in receipt throws', () {
      final receipt = Receipt(
        items: [],
        settings: ReceiptSettings(paperWidth: 0),
      );
      expect(() => receipt.validate(), throwsA(isA<ValidationException>()));
    });
  });

  group('PrinterCapabilities', () {
    test('maxPaperWidth 0 is allowed by model', () {
      const c = PrinterCapabilities(
        maxPaperWidth: 0,
        supportsCutting: false,
        supportsImages: false,
        supportedBarcodes: [],
        supportedFontSizes: [],
      );
      expect(c.maxPaperWidth, 0);
    });
  });
}
