# flutter_thermal_printer_windows

Flutter plugin for Bluetooth thermal printer support on **Windows**. Provides discovery, pairing, connection, and ESC/POS printing for POS and receipt applications.

## Requirements

- **Flutter** 3.16+ (stable)
- **Dart** 3.2+
- **Windows** 10 (1809+) or Windows 11
- **Bluetooth** adapter (built-in or USB)
- **Windows SDK** 10.0.19041.0+ for native build

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_thermal_printer_windows: ^0.0.1
```

Then run `flutter pub get`.

## Usage

### Main API (ThermalPrinterWindows)

Use the singleton for all operations:

```dart
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

final api = ThermalPrinterWindows.instance;

// Scan for printers (30s default)
final printers = await api.scanForPrinters(timeout: Duration(seconds: 30));

// Pair and connect
await api.pairPrinter(printers.first);
await api.connect(printers.first);

// Optional: print a "connection successful" sample after connect
await api.connect(printers.first, printSampleOnSuccess: true);
// Or call explicitly anytime after connecting:
await api.printConnectionSuccessSample(printers.first);

// Print plain text
await api.printText(printers.first, 'Hello\nWorld\n');

// Print a structured receipt
final receipt = Receipt(
  header: ReceiptHeader(text: 'My Store\n123 Main St'),
  items: [
    ReceiptItem(type: ReceiptItemType.text, text: 'Item A     \$10.00'),
    ReceiptItem(type: ReceiptItemType.text, text: 'Item B     \$5.50'),
    ReceiptItem(type: ReceiptItemType.line),
    ReceiptItem(type: ReceiptItemType.text, text: 'Total      \$15.50', style: TextStyle(bold: true)),
  ],
  footer: ReceiptFooter(text: 'Thank you!'),
  settings: ReceiptSettings(paperWidth: 58, autoCut: true),
);
await api.printReceipt(printers.first, receipt);

// Raw ESC/POS bytes
await api.printRawBytes(printers.first, myEscPosBytes);

// Diagnostics
final paired = await api.getPairedPrinters();
final caps = await api.getPrinterCapabilities(printers.first);
final status = await api.getPrinterStatus(printers.first);

// Connection state stream
api.getConnectionStateStream(printers.first).listen((state) {
  print('Connection: $state');
});
```

### Lower-level components

- **PrinterScanner** – `scanForThermalPrinters(timeout)`, `startContinuousScanning()`
- **PairingManager** – `pairDevice`, `unpairDevice`, `connectToDevice`, `disconnectFromDevice`, `watchConnectionState`
- **PrintEngine** – `generateEscPosCommands(Receipt)`, `sendPrintJob`, `sendRawCommands`
- **EscPosGenerator** – build ESC/POS bytes (init, bold, alignment, text, image, barcode, QR, feed, cut)

### Error handling

Operations throw `ThermalPrinterException` (or subclasses) on failure:

- `BluetoothNotAvailableException` – Bluetooth off or unavailable
- `DeviceNotPairedException` – Device not paired
- `ConnectionFailedException` – Connect/timeout/refused
- `PrintJobFailedException` – Send/print failed
- `ValidationException` – Invalid receipt or input

Use try/catch or `.catchError`. Exceptions include `message`, optional `errorCode`, and optional `cause`/`context`.

```dart
try {
  await api.pairPrinter(printer);
} on ConnectionFailedException catch (e) {
  print('Failed: ${e.message} (${e.errorCode})');
}
```

## Example

The Usage section above shows the main API. To run a demo:

1. Create a new Flutter project: `flutter create my_pos_app`
2. Add this plugin to `pubspec.yaml` and run `flutter pub get`
3. Add the usage code above to your app (e.g. a button that calls `scanForPrinters`, then `pairPrinter` and `connect`)
4. Run: `flutter run -d windows`

## Troubleshooting

### No printers found when scanning

- Ensure Bluetooth is **on** and the printer is **on** and in range.
- Windows may need the device in **pairing mode** (see printer manual).
- Some printers only appear after being paired once via Windows Settings → Bluetooth.
- The plugin filters by SPP (Serial Port Profile) UUID; if your printer uses a different profile, it may not appear.

### Pairing fails or times out

- Put the printer in pairing mode and retry.
- Remove the device from Windows Settings → Bluetooth and try again.
- Restart the Bluetooth adapter or the app.

### Print job does nothing

- Confirm the printer is **connected** (not only paired): call `api.connect(printer)` before printing.
- Check paper and power; some printers report status via `getPrinterStatus`.
- Try `printText` with a short string to verify the link; then try receipt/raw.

### Build errors on Windows

- Install **Visual Studio** with “Desktop development with C++” and the **Windows 10 SDK**.
- Run `flutter doctor -v` and fix any Windows toolchain issues.
- Clean and rebuild: `flutter clean && flutter pub get && flutter run -d windows`.

## FAQ

**Q: Does this work on Android or iOS?**  
A: No. This package is Windows-only. Use a different plugin for mobile.

**Q: Which printers are supported?**  
A: Any Bluetooth thermal printer that supports ESC/POS over SPP (Serial Port Profile). Most receipt printers do.

**Q: Can I use USB thermal printers?**  
A: Not with this plugin. It uses Windows Bluetooth APIs only.

**Q: How do I add a logo or image to a receipt?**  
A: Use `ReceiptHeader(imageData: myMonochromeBytes)` or `ReceiptItem(type: ReceiptItemType.image, imageData: ...)`. Image data should be 1 bpp; see `EscPosGenerator.imageToMonochrome`.

## License

See the LICENSE file.
