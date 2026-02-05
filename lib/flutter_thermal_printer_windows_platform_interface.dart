import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_thermal_printer_windows_method_channel.dart';
import 'src/models/bluetooth_printer.dart';
import 'src/models/connection_result.dart';
import 'src/models/connection_state.dart';
import 'src/models/pairing_result.dart';
import 'src/models/printer_capabilities.dart';
import 'src/models/printer_status.dart';

abstract class FlutterThermalPrinterWindowsPlatform extends PlatformInterface {
  /// Constructs a FlutterThermalPrinterWindowsPlatform.
  FlutterThermalPrinterWindowsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterThermalPrinterWindowsPlatform _instance =
      MethodChannelFlutterThermalPrinterWindows();

  /// The default instance of [FlutterThermalPrinterWindowsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterThermalPrinterWindows].
  static FlutterThermalPrinterWindowsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterThermalPrinterWindowsPlatform] when
  /// they register themselves.
  static set instance(FlutterThermalPrinterWindowsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Scans for Bluetooth thermal printers within the given [timeout].
  Future<List<BluetoothPrinter>> scanForPrinters({Duration? timeout}) {
    throw UnimplementedError('scanForPrinters() has not been implemented.');
  }

  /// Pairs with the given [printer]. Returns [PairingResult].
  Future<PairingResult> pairDevice(BluetoothPrinter printer) {
    throw UnimplementedError('pairDevice() has not been implemented.');
  }

  /// Unpairs the given [printer].
  Future<void> unpairDevice(BluetoothPrinter printer) {
    throw UnimplementedError('unpairDevice() has not been implemented.');
  }

  /// Connects to the given [printer]. Returns [ConnectionResult].
  Future<ConnectionResult> connectToDevice(BluetoothPrinter printer) {
    throw UnimplementedError('connectToDevice() has not been implemented.');
  }

  /// Disconnects from the given [printer].
  Future<void> disconnectFromDevice(BluetoothPrinter printer) {
    throw UnimplementedError(
      'disconnectFromDevice() has not been implemented.',
    );
  }

  /// Returns the current connection state for [printer].
  Future<ConnectionState> getConnectionState(BluetoothPrinter printer) {
    throw UnimplementedError('getConnectionState() has not been implemented.');
  }

  /// Returns a stream of connection state updates for [printer].
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) {
    throw UnimplementedError(
      'watchConnectionState() has not been implemented.',
    );
  }

  /// Sends raw ESC/POS [commands] to [printer] over Bluetooth.
  Future<void> sendRawCommands(BluetoothPrinter printer, Uint8List commands) {
    throw UnimplementedError('sendRawCommands() has not been implemented.');
  }

  /// Returns paired Bluetooth printers.
  Future<List<BluetoothPrinter>> getPairedPrinters() {
    throw UnimplementedError('getPairedPrinters() has not been implemented.');
  }

  /// Returns capabilities for [printer] (paper width, cutting, images, barcodes).
  Future<PrinterCapabilities> getPrinterCapabilities(BluetoothPrinter printer) {
    throw UnimplementedError(
      'getPrinterCapabilities() has not been implemented.',
    );
  }

  /// Returns current status for [printer] (connected, paper, error).
  Future<PrinterStatus> getPrinterStatus(BluetoothPrinter printer) {
    throw UnimplementedError('getPrinterStatus() has not been implemented.');
  }
}
