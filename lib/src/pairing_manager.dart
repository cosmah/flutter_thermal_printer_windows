import '../flutter_thermal_printer_windows_platform_interface.dart';
import 'models/bluetooth_printer.dart';
import 'models/connection_result.dart';
import 'models/connection_state.dart';
import 'models/pairing_result.dart';

/// Manages Bluetooth device pairing and connection state for thermal printers.
///
/// Uses the platform implementation (WinRT on Windows) for pairing
/// (DeviceInformationPairing.PairAsync) and connection lifecycle.
class PairingManager {
  PairingManager({FlutterThermalPrinterWindowsPlatform? platform})
    : _platform = platform ?? FlutterThermalPrinterWindowsPlatform.instance;

  final FlutterThermalPrinterWindowsPlatform _platform;

  /// Pairs with [printer]. Returns [PairingResult] with success/failure and
  /// optional updated [BluetoothPrinter] or error.
  Future<PairingResult> pairDevice(BluetoothPrinter printer) {
    return _platform.pairDevice(printer);
  }

  /// Unpairs [printer]. No-op if not paired.
  Future<void> unpairDevice(BluetoothPrinter printer) {
    return _platform.unpairDevice(printer);
  }

  /// Connects to [printer]. Returns [ConnectionResult].
  /// Printer should be paired first.
  Future<ConnectionResult> connectToDevice(BluetoothPrinter printer) {
    return _platform.connectToDevice(printer);
  }

  /// Disconnects from [printer].
  Future<void> disconnectFromDevice(BluetoothPrinter printer) {
    return _platform.disconnectFromDevice(printer);
  }

  /// Stream of connection state updates for [printer].
  /// Emits when the connection state changes.
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) {
    return _platform.watchConnectionState(printer);
  }
}
