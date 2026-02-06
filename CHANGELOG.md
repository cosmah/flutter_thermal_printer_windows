## 0.0.1

* Initial release.
* Bluetooth printer discovery (scan, SPP filter).
* Pairing and connection management (pair, unpair, connect, disconnect).
* Connection state stream and diagnostics (getPrinterCapabilities, getPrinterStatus, getPairedPrinters).
* ESC/POS command generation (text, alignment, bold, underline, font size, image, barcode, QR, feed, cut).
* PrintEngine: receipt-to-ESC/POS conversion, job queue per printer, sendRawCommands.
* ThermalPrinterWindows main API (singleton): scanForPrinters, pairPrinter, unpairPrinter, getPairedPrinters, connect (optional printSampleOnSuccess), printConnectionSuccessSample, disconnect, getConnectionStateStream, printText, printReceipt, printRawBytes, getPrinterCapabilities, getPrinterStatus).
* Data models: BluetoothPrinter, Receipt, ReceiptItem, ReceiptSettings, PrinterCapabilities, PrinterStatus, PairingResult, ConnectionResult.
* Validation: Receipt and ReceiptSettings validation with ValidationException.
* Error hierarchy: ThermalPrinterException and subclasses with errorCode, cause, context; fromCode() mapping.
* Windows plugin: method channel and C++/WinRT Bluetooth implementation (MTA worker thread, SPP discovery, pairing, StreamSocket connection, raw byte send).
* Local status tracking (isPaired, connectionState) for Windows where native pairing status is unreliable.
* PlatformException → ThermalPrinterException mapping with user-friendly error messages.
* Production-oriented logging (errors only in release; verbose logs in debug builds).
