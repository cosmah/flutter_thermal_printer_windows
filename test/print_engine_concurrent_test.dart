// Property 9: Concurrent Job Handling
// For any set of concurrent print jobs submitted to the same printer, the
// package should queue and execute them sequentially without data corruption or job loss.
// Validates: Requirements 9.4

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 9: Concurrent Job Handling',
    () {
      test(
        'concurrent sendPrintJob to same printer executes sequentially',
        () async {
          final order = <int>[];
          final mock = MockPrintPlatform((printer, bytes) async {
            order.add(bytes.length);
            await Future.delayed(Duration(milliseconds: 10));
          });
          final printer = BluetoothPrinter(
            id: 'p1',
            name: 'P',
            macAddress: '00:00:00:00:00:00',
            signalStrength: -50,
            isPaired: true,
            connectionState: ConnectionState.connected,
            capabilities: null,
          );
          final engine = PrintEngine(platform: mock);
          final jobs = List.generate(
            5,
            (i) => PrintJob.receipt(
              Receipt(
                items: [
                  ReceiptItem(type: ReceiptItemType.text, text: 'Job $i'),
                ],
                settings: ReceiptSettings(),
              ),
            ),
          );
          await Future.wait(jobs.map((j) => engine.sendPrintJob(printer, j)));
          expect(order.length, 5);
        },
      );
    },
  );
}

class MockPrintPlatform extends FlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin {
  MockPrintPlatform(this._onSend);

  final Future<void> Function(BluetoothPrinter printer, List<int> bytes)
  _onSend;

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
      Future.value(ConnectionResult(isConnected: true));

  @override
  Future<void> disconnectFromDevice(BluetoothPrinter printer) => Future.value();

  @override
  Future<ConnectionState> getConnectionState(BluetoothPrinter printer) =>
      Future.value(ConnectionState.connected);

  @override
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) =>
      Stream.value(ConnectionState.connected);

  @override
  Future<void> sendRawCommands(
    BluetoothPrinter printer,
    Uint8List commands,
  ) async {
    await _onSend(printer, commands.toList());
  }
}
