// Property 2: Pairing Round Trip Consistency
// For any discovered thermal printer, pairing followed by unpairing should return
// the system to its original state with no persistent pairing information.
// Validates: Requirements 2.1, 2.2, 2.5

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 2: Pairing Round Trip Consistency',
    () {
      test(
        'pair then unpair returns to original state (no persistent pairing)',
        () async {
          const iterations = 100;
          for (var i = 0; i < iterations; i++) {
            final printer = _makePrinter(i, isPaired: false);
            final mock = MockPairingPlatform();
            final manager = PairingManager(platform: mock);
            final pairedResult = await manager.pairDevice(printer);
            expect(pairedResult.isPaired, isTrue);
            await manager.unpairDevice(pairedResult.printer ?? printer);
            final stateAfterUnpair = await mock.getConnectionState(printer);
            expect(stateAfterUnpair, ConnectionState.disconnected);
          }
        },
      );
    },
  );
}

BluetoothPrinter _makePrinter(int seed, {required bool isPaired}) {
  return BluetoothPrinter(
    id: 'id-$seed',
    name: 'Printer-$seed',
    macAddress: '11:22:33:44:55:66',
    signalStrength: -60 + (seed % 40),
    isPaired: isPaired,
    connectionState: ConnectionState.disconnected,
    capabilities: null,
  );
}

class MockPairingPlatform extends FlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin {
  bool _paired = false;

  @override
  Future<String?> getPlatformVersion() => Future.value('Windows');

  @override
  Future<List<BluetoothPrinter>> scanForPrinters({Duration? timeout}) =>
      Future.value([]);

  @override
  Future<PairingResult> pairDevice(BluetoothPrinter printer) {
    _paired = true;
    return Future.value(
      PairingResult(
        isPaired: true,
        printer: printer.copyWith(isPaired: true),
        error: null,
      ),
    );
  }

  @override
  Future<void> unpairDevice(BluetoothPrinter printer) {
    _paired = false;
    return Future.value();
  }

  @override
  Future<ConnectionResult> connectToDevice(BluetoothPrinter printer) =>
      Future.value(ConnectionResult(isConnected: _paired));

  @override
  Future<void> disconnectFromDevice(BluetoothPrinter printer) => Future.value();

  @override
  Future<ConnectionState> getConnectionState(BluetoothPrinter printer) =>
      Future.value(
        _paired ? ConnectionState.connected : ConnectionState.disconnected,
      );

  @override
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) =>
      Stream.value(
        _paired ? ConnectionState.connected : ConnectionState.disconnected,
      );
}
