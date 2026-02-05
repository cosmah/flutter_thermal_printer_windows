// Property 4: Connection State Accuracy
// For any paired printer, the reported connection status should accurately
// reflect the actual Bluetooth connection state at all times.
// Validates: Requirements 4.1, 4.4

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 4: Connection State Accuracy',
    () {
      test('reported connection state matches platform state', () async {
        const iterations = 100;
        for (var i = 0; i < iterations; i++) {
          final printer = BluetoothPrinter(
            id: 'id-$i',
            name: 'Printer-$i',
            macAddress: '11:22:33:44:55:66',
            signalStrength: -50,
            isPaired: true,
            connectionState: ConnectionState.disconnected,
            capabilities: null,
          );
          final state =
              ConnectionState.values[i % ConnectionState.values.length];
          final mock = MockConnectionStatePlatform(state);
          final manager = PairingManager(platform: mock);
          final reported = await mock.getConnectionState(printer);
          expect(reported, state);
          final fromStream = await manager.watchConnectionState(printer).first;
          expect(fromStream, state);
        }
      });
    },
  );
}

class MockConnectionStatePlatform extends FlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin {
  MockConnectionStatePlatform(this._state);

  final ConnectionState _state;

  @override
  Future<String?> getPlatformVersion() => Future.value('Windows');

  @override
  Future<List<BluetoothPrinter>> scanForPrinters({Duration? timeout}) =>
      Future.value([]);

  @override
  Future<PairingResult> pairDevice(BluetoothPrinter printer) => Future.value(
    PairingResult(isPaired: true, printer: printer.copyWith(isPaired: true)),
  );

  @override
  Future<void> unpairDevice(BluetoothPrinter printer) => Future.value();

  @override
  Future<ConnectionResult> connectToDevice(BluetoothPrinter printer) =>
      Future.value(
        ConnectionResult(isConnected: _state == ConnectionState.connected),
      );

  @override
  Future<void> disconnectFromDevice(BluetoothPrinter printer) => Future.value();

  @override
  Future<ConnectionState> getConnectionState(BluetoothPrinter printer) =>
      Future.value(_state);

  @override
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) =>
      Stream.value(_state);
}
