import 'dart:async';

import '../flutter_thermal_printer_windows_platform_interface.dart';
import 'models/bluetooth_printer.dart';

/// Handles Bluetooth device discovery for thermal printers.
///
/// Uses the platform implementation (WinRT on Windows) to discover
/// devices that expose the Serial Port Profile (SPP) and match
/// thermal printer criteria.
class PrinterScanner {
  PrinterScanner({FlutterThermalPrinterWindowsPlatform? platform})
    : _platform = platform ?? FlutterThermalPrinterWindowsPlatform.instance;

  final FlutterThermalPrinterWindowsPlatform _platform;

  /// Default scan timeout when none is specified (30 seconds per requirements).
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Scans for Bluetooth thermal printers within [timeout].
  ///
  /// Returns a list of [BluetoothPrinter] with id, name, MAC address,
  /// and signal strength. Returns an empty list if no printers are found
  /// or if the scan times out.
  Future<List<BluetoothPrinter>> scanForThermalPrinters([
    Duration timeout = defaultTimeout,
  ]) async {
    return _platform.scanForPrinters(timeout: timeout);
  }

  /// Starts continuous scanning, emitting printers as they are discovered.
  ///
  /// Call [stopScanning] to cancel. The platform may not support
  /// continuous scanning; in that case this falls back to a single
  /// [scanForThermalPrinters] call.
  Stream<BluetoothPrinter> startContinuousScanning() async* {
    final list = await scanForThermalPrinters(defaultTimeout);
    for (final p in list) {
      yield p;
    }
  }

  /// Stops an in-progress scan (no-op if platform does not support cancellation).
  void stopScanning() {
    // Platform-specific cancellation can be added when supported.
  }
}
