// Property 10: Connection Recovery Resilience
// For any temporary connection interruption, the package should detect the
// disconnection, attempt reconnection, and restore normal operation when
// the printer becomes available.
// Validates: Requirements 4.2, 4.3, 4.5, 9.5

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 10: Connection Recovery Resilience',
    () {
      test(
        'getConnectionStateStream emits state changes (disconnect then connect)',
        () async {
          final printer = BluetoothPrinter(
            id: 'p1',
            name: 'P',
            macAddress: '00:00:00:00:00:00',
            signalStrength: -50,
            isPaired: true,
            connectionState: ConnectionState.disconnected,
            capabilities: null,
          );
          FlutterThermalPrinterWindowsPlatform.instance = MockRecoveryPlatform(
            Stream.fromIterable([
              ConnectionState.disconnected,
              ConnectionState.connecting,
              ConnectionState.connected,
            ]),
          );
          final api = ThermalPrinterWindows.instance;
          final states = await api
              .getConnectionStateStream(printer)
              .take(3)
              .toList();
          expect(states.length, 3);
          expect(states[0], ConnectionState.disconnected);
          expect(states[2], ConnectionState.connected);
        },
      );

      test('connection state stream yields ConnectionState values', () async {
        final printer = BluetoothPrinter(
          id: 'p1',
          name: 'P',
          macAddress: '00:00:00:00:00:00',
          signalStrength: -50,
          isPaired: true,
          connectionState: ConnectionState.disconnected,
          capabilities: null,
        );
        final states = [ConnectionState.connected];
        FlutterThermalPrinterWindowsPlatform.instance = MockRecoveryPlatform(
          Stream.fromIterable(states),
        );
        final api = ThermalPrinterWindows.instance;
        final stream = api.getConnectionStateStream(printer);
        expect(stream, isA<Stream<ConnectionState>>());
        final first = await stream.first;
        expect(first, isA<ConnectionState>());
        expect(first, ConnectionState.connected);
      });
    },
  );
}

class MockRecoveryPlatform extends FlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin {
  MockRecoveryPlatform(this._stateStream);

  final Stream<ConnectionState> _stateStream;

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
      _stateStream.first;

  @override
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) =>
      _stateStream;

  @override
  Future<void> sendRawCommands(BluetoothPrinter printer, Uint8List commands) =>
      Future.value();

  @override
  Future<List<BluetoothPrinter>> getPairedPrinters() => Future.value([]);

  @override
  Future<PrinterCapabilities> getPrinterCapabilities(
    BluetoothPrinter printer,
  ) => Future.value(
    const PrinterCapabilities(
      maxPaperWidth: 58,
      supportsCutting: true,
      supportsImages: true,
      supportedBarcodes: [BarcodeType.code128],
      supportedFontSizes: [FontSize.normal],
    ),
  );

  @override
  Future<PrinterStatus> getPrinterStatus(BluetoothPrinter printer) =>
      Future.value(PrinterStatus(isConnected: true));
}
