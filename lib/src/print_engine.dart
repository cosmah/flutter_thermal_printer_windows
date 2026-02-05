import 'dart:typed_data';

import '../flutter_thermal_printer_windows_platform_interface.dart';
import 'esc_pos_generator.dart';
import 'models/bluetooth_printer.dart';
import 'models/enums.dart';
import 'models/receipt.dart';

/// A print job: either a [Receipt] (converted to ESC/POS) or raw [Uint8List].
class PrintJob {
  const PrintJob.receipt(this.receipt) : rawBytes = null;
  const PrintJob.raw(this.rawBytes) : receipt = null;

  final Receipt? receipt;
  final Uint8List? rawBytes;

  bool get isReceipt => receipt != null;
  bool get isRaw => rawBytes != null;
}

/// Converts print jobs to ESC/POS and sends them to printers via the platform.
///
/// Jobs to the same printer are queued and executed sequentially.
class PrintEngine {
  PrintEngine({
    FlutterThermalPrinterWindowsPlatform? platform,
    EscPosGenerator? escPosGenerator,
  }) : _platform = platform ?? FlutterThermalPrinterWindowsPlatform.instance,
       _generator = escPosGenerator ?? EscPosGenerator();

  final FlutterThermalPrinterWindowsPlatform _platform;
  final EscPosGenerator _generator;

  final Map<String, Future<void>> _printerQueues = {};

  /// Converts [receipt] to ESC/POS command bytes.
  /// Throws [ValidationException] if [receipt] is invalid.
  Uint8List generateEscPosCommands(Receipt receipt) {
    receipt.validate();
    final out = <int>[];
    out.addAll(_generator.initializePrinter());
    out.addAll(_generator.setAlignment(receipt.settings.defaultAlignment));

    if (receipt.header != null) {
      if (receipt.header!.text != null && receipt.header!.text!.isNotEmpty) {
        out.addAll(_generator.setAlignment(TextAlignment.center));
        out.addAll(_generator.printText(receipt.header!.text!));
        out.addAll(_generator.setAlignment(receipt.settings.defaultAlignment));
      }
      if (receipt.header!.imageData != null &&
          receipt.header!.imageData!.isNotEmpty) {
        final w = receipt.settings.paperWidth * 8;
        final h = (receipt.header!.imageData!.length * 8 / w).ceil().clamp(
          1,
          0xFFFF,
        );
        out.addAll(_generator.printImage(receipt.header!.imageData!, w, h));
      }
    }

    for (final item in receipt.items) {
      final style = item.style;
      if (style != null) {
        out.addAll(_generator.setBold(style.bold));
        out.addAll(_generator.setUnderline(style.underline));
        out.addAll(_generator.setFontSize(style.fontSize));
        out.addAll(_generator.setAlignment(style.alignment));
      }
      switch (item.type) {
        case ReceiptItemType.text:
          if (item.text != null && item.text!.isNotEmpty) {
            out.addAll(_generator.printText(item.text!));
          }
          break;
        case ReceiptItemType.image:
          if (item.imageData != null && item.imageData!.isNotEmpty) {
            final w = receipt.settings.paperWidth * 8;
            final h = (item.imageData!.length * 8 / w).ceil().clamp(1, 0xFFFF);
            out.addAll(_generator.printImage(item.imageData!, w, h));
          }
          break;
        case ReceiptItemType.barcode:
          if (item.barcodeData != null) {
            out.addAll(
              _generator.printBarcode(
                item.barcodeData!.data,
                item.barcodeData!.type,
              ),
            );
          }
          break;
        case ReceiptItemType.qrCode:
          if (item.barcodeData != null) {
            final size = item.barcodeData!.width ?? 4;
            out.addAll(_generator.printQrCode(item.barcodeData!.data, size));
          }
          break;
        case ReceiptItemType.line:
          out.addAll(_generator.feedLines(1));
          break;
        case ReceiptItemType.spacer:
          out.addAll(_generator.feedLines(2));
          break;
      }
    }

    if (receipt.footer != null &&
        receipt.footer!.text != null &&
        receipt.footer!.text!.isNotEmpty) {
      out.addAll(_generator.setAlignment(TextAlignment.center));
      out.addAll(_generator.printText(receipt.footer!.text!));
      out.addAll(_generator.setAlignment(receipt.settings.defaultAlignment));
    }

    out.addAll(_generator.feedLines(receipt.settings.feedLinesAfterCut));
    if (receipt.settings.autoCut) {
      out.addAll(_generator.cutPaper());
    }
    return Uint8List.fromList(out);
  }

  /// Sends [job] to [printer]. Queued per printer; runs sequentially.
  Future<void> sendPrintJob(BluetoothPrinter printer, PrintJob job) {
    return _enqueue(printer.id, () async {
      Uint8List bytes;
      if (job.receipt != null) {
        bytes = generateEscPosCommands(job.receipt!);
      } else if (job.rawBytes != null && job.rawBytes!.isNotEmpty) {
        bytes = job.rawBytes!;
      } else {
        return;
      }
      await _platform.sendRawCommands(printer, bytes);
    });
  }

  /// Sends raw [commands] to [printer] (queued like [sendPrintJob]).
  Future<void> sendRawCommands(BluetoothPrinter printer, Uint8List commands) {
    return sendPrintJob(printer, PrintJob.raw(commands));
  }

  Future<void> _enqueue(String printerId, Future<void> Function() work) async {
    final previous = _printerQueues[printerId] ?? Future.value();
    final next = previous.then((_) => work());
    _printerQueues[printerId] = next;
    await next;
    if (_printerQueues[printerId] == next) {
      _printerQueues.remove(printerId);
    }
  }
}
