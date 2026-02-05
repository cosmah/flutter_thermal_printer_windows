// Property 7: Input Validation Completeness
// For any invalid input data, the package should reject it with a meaningful
// error message rather than processing it incorrectly.
// Validates: Requirements 10.5

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 7: Input Validation Completeness',
    () {
      test('ReceiptSettings invalid paperWidth throws ValidationException', () {
        const settings = ReceiptSettings(paperWidth: 0);
        expect(() => settings.validate(), throwsA(isA<ValidationException>()));
        expect(
          () => settings.validate(),
          throwsA(
            predicate<ValidationException>(
              (e) => e.message.contains('paperWidth'),
            ),
          ),
        );
      });

      test('ReceiptSettings invalid feedLinesAfterCut throws', () {
        const settings = ReceiptSettings(feedLinesAfterCut: -1);
        expect(() => settings.validate(), throwsA(isA<ValidationException>()));
      });

      test('ReceiptItem image without imageData throws', () {
        const item = ReceiptItem(type: ReceiptItemType.image);
        expect(() => item.validate(), throwsA(isA<ValidationException>()));
        expect(
          () => item.validate(),
          throwsA(
            predicate<ValidationException>(
              (e) =>
                  e.message.contains('image') &&
                  e.message.contains('imageData'),
            ),
          ),
        );
      });

      test('ReceiptItem barcode without barcodeData throws', () {
        const item = ReceiptItem(type: ReceiptItemType.barcode);
        expect(() => item.validate(), throwsA(isA<ValidationException>()));
      });

      test('Receipt validate propagates item validation', () {
        final receipt = Receipt(
          items: [
            ReceiptItem(type: ReceiptItemType.text, text: 'OK'),
            ReceiptItem(type: ReceiptItemType.barcode),
          ],
          settings: ReceiptSettings(),
        );
        expect(() => receipt.validate(), throwsA(isA<ValidationException>()));
        expect(
          () => receipt.validate(),
          throwsA(
            predicate<ValidationException>((e) => e.message.contains('Item 1')),
          ),
        );
      });

      test('generateEscPosCommands invalid receipt throws', () {
        final engine = PrintEngine();
        final receipt = Receipt(
          items: [ReceiptItem(type: ReceiptItemType.image)],
          settings: ReceiptSettings(),
        );
        expect(
          () => engine.generateEscPosCommands(receipt),
          throwsA(isA<ValidationException>()),
        );
      });
    },
  );
}
