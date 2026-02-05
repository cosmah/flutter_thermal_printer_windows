// Property 3: Print Job ESC/POS Conversion
// For any valid print job content, the print engine should successfully convert
// it to valid ESC/POS commands and transmit them to the target printer.
// Validates: Requirements 3.1, 3.2

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 3: Print Job ESC/POS Conversion',
    () {
      test(
        'generateEscPosCommands returns non-empty bytes for valid receipt',
        () {
          final engine = PrintEngine();
          final receipt = Receipt(
            items: [
              ReceiptItem(type: ReceiptItemType.text, text: 'Hello'),
              ReceiptItem(type: ReceiptItemType.line),
              ReceiptItem(type: ReceiptItemType.text, text: 'Total: 10.00'),
            ],
            settings: ReceiptSettings(),
          );
          final bytes = engine.generateEscPosCommands(receipt);
          expect(bytes, isNotEmpty);
          expect(bytes[0], 0x1B);
          expect(bytes[1], 0x40);
        },
      );

      test('generateEscPosCommands handles header and footer', () {
        final engine = PrintEngine();
        final receipt = Receipt(
          items: [ReceiptItem(type: ReceiptItemType.text, text: 'Body')],
          header: ReceiptHeader(text: 'Store Name'),
          footer: ReceiptFooter(text: 'Thank you'),
          settings: ReceiptSettings(),
        );
        final bytes = engine.generateEscPosCommands(receipt);
        expect(bytes, isNotEmpty);
      });

      test('generateEscPosCommands handles barcode and QR items', () {
        final engine = PrintEngine();
        final receipt = Receipt(
          items: [
            ReceiptItem(
              type: ReceiptItemType.barcode,
              barcodeData: BarcodeData(data: '123', type: BarcodeType.code128),
            ),
            ReceiptItem(
              type: ReceiptItemType.qrCode,
              barcodeData: BarcodeData(
                data: 'https://x.com',
                type: BarcodeType.qrCode,
              ),
            ),
          ],
          settings: ReceiptSettings(),
        );
        final bytes = engine.generateEscPosCommands(receipt);
        expect(bytes, isNotEmpty);
      });
    },
  );
}
