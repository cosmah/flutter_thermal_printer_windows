import 'dart:typed_data';

import '../flutter_thermal_printer_windows_platform_interface.dart';
import 'models/receipt.dart';
import 'models/bluetooth_printer.dart';
import 'models/connection_state.dart';
import 'models/enums.dart';
import 'models/exceptions.dart';
import 'models/printer_capabilities.dart';
import 'models/printer_status.dart';
import 'pairing_manager.dart';
import 'print_engine.dart';
import 'printer_scanner.dart';

/// Main API for thermal printing on Windows.
///
/// Singleton entry point: [ThermalPrinterWindows.instance].
/// All operations use async/await and throw [ThermalPrinterException]
/// (or subclasses) on failure.
class ThermalPrinterWindows {
  ThermalPrinterWindows._();

  static final ThermalPrinterWindows _instance = ThermalPrinterWindows._();

  /// Singleton instance.
  static ThermalPrinterWindows get instance => _instance;

  FlutterThermalPrinterWindowsPlatform get _platform =>
      FlutterThermalPrinterWindowsPlatform.instance;

  PrinterScanner get _scanner => PrinterScanner(platform: _platform);
  PairingManager get _pairingManager => PairingManager(platform: _platform);
  PrintEngine get _printEngine => PrintEngine(platform: _platform);

  /// Default scan timeout (30 seconds per requirements).
  static const Duration defaultScanTimeout = Duration(seconds: 30);

  /// Default connect timeout (10 seconds per requirements).
  static const Duration defaultConnectTimeout = Duration(seconds: 10);

  /// Scans for Bluetooth thermal printers within [timeout].
  Future<List<BluetoothPrinter>> scanForPrinters({
    Duration timeout = defaultScanTimeout,
  }) => _scanner.scanForThermalPrinters(timeout);

  /// Pairs with [printer]. Throws on failure.
  Future<void> pairPrinter(BluetoothPrinter printer) async {
    final result = await _pairingManager.pairDevice(printer);
    if (!result.isPaired && result.error != null) throw result.error!;
    if (!result.isPaired) {
      throw ConnectionFailedException('Pairing failed');
    }
  }

  /// Unpairs [printer].
  Future<void> unpairPrinter(BluetoothPrinter printer) =>
      _pairingManager.unpairDevice(printer);

  /// Returns paired printers.
  Future<List<BluetoothPrinter>> getPairedPrinters() =>
      _platform.getPairedPrinters();

  /// Connects to [printer]. Throws on failure.
  ///
  /// If [printSampleOnSuccess] is true, a short "connection successful"
  /// sample receipt is sent to the printer after a successful connect.
  Future<void> connect(
    BluetoothPrinter printer, {
    bool printSampleOnSuccess = false,
  }) async {
    final result = await _pairingManager.connectToDevice(printer);
    if (!result.isConnected && result.error != null) throw result.error!;
    if (!result.isConnected) {
      throw ConnectionFailedException('Connection failed');
    }
    if (printSampleOnSuccess) {
      await printConnectionSuccessSample(printer);
    }
  }

  /// Prints a short sample receipt to [printer] to confirm connection.
  ///
  /// Use after a successful [connect] to verify the link. The sample
  /// includes "Connection successful", the printer name, and the current
  /// date/time.
  Future<void> printConnectionSuccessSample(BluetoothPrinter printer) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final receipt = Receipt(
      header: ReceiptHeader(
        text: 'Connection successful\n${printer.name.isNotEmpty ? printer.name : printer.macAddress}\n$dateStr',
      ),
      items: [
        ReceiptItem(type: ReceiptItemType.line),
        ReceiptItem(
          type: ReceiptItemType.text,
          text: 'Thermal printer ready.',
          style: const TextStyle(bold: true),
        ),
      ],
      settings: ReceiptSettings(paperWidth: 58, autoCut: true),
    );
    return _printEngine.sendPrintJob(printer, PrintJob.receipt(receipt));
  }

  /// Disconnects from [printer].
  Future<void> disconnect(BluetoothPrinter printer) =>
      _pairingManager.disconnectFromDevice(printer);

  /// Stream of connection state for [printer].
  Stream<ConnectionState> getConnectionStateStream(BluetoothPrinter printer) =>
      _pairingManager.watchConnectionState(printer);

  /// Prints [text] as plain text to [printer].
  Future<void> printText(BluetoothPrinter printer, String text) {
    final receipt = Receipt(
      items: [ReceiptItem(type: ReceiptItemType.text, text: text)],
      settings: ReceiptSettings(),
    );
    return _printEngine.sendPrintJob(printer, PrintJob.receipt(receipt));
  }

  /// Prints [receipt] to [printer].
  Future<void> printReceipt(BluetoothPrinter printer, Receipt receipt) =>
      _printEngine.sendPrintJob(printer, PrintJob.receipt(receipt));

  /// Sends raw [data] to [printer].
  Future<void> printRawBytes(BluetoothPrinter printer, Uint8List data) =>
      _printEngine.sendRawCommands(printer, data);

  /// Returns capabilities for [printer].
  Future<PrinterCapabilities> getPrinterCapabilities(
    BluetoothPrinter printer,
  ) => _platform.getPrinterCapabilities(printer);

  /// Returns current status for [printer].
  Future<PrinterStatus> getPrinterStatus(BluetoothPrinter printer) =>
      _platform.getPrinterStatus(printer);
}
