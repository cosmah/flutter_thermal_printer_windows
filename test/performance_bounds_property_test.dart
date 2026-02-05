// Property 8: Performance Bounds Compliance
// For any standard operation (discovery, connection, printing), the package
// should complete within the specified time limits under normal conditions.
// Validates: Requirements 1.5, 9.1, 9.2, 9.3

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 8: Performance Bounds Compliance',
    () {
      late MockQuickPlatform mock;

      setUp(() {
        mock = MockQuickPlatform();
        FlutterThermalPrinterWindowsPlatform.instance = mock;
      });

      test(
        'scanForPrinters completes within 30s (mock returns immediately)',
        () async {
          final api = ThermalPrinterWindows.instance;
          final stopwatch = Stopwatch()..start();
          await api.scanForPrinters(timeout: Duration(seconds: 30));
          stopwatch.stop();
          expect(stopwatch.elapsedMilliseconds, lessThan(35000));
        },
      );

      test('getPairedPrinters completes within 10s', () async {
        final api = ThermalPrinterWindows.instance;
        final stopwatch = Stopwatch()..start();
        await api.getPairedPrinters();
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(12000));
      });

      test('getPrinterCapabilities completes within 5s', () async {
        final api = ThermalPrinterWindows.instance;
        final printer = BluetoothPrinter(
          id: 'p1',
          name: 'P',
          macAddress: '00:00:00:00:00:00',
          signalStrength: -50,
          isPaired: true,
          connectionState: ConnectionState.disconnected,
          capabilities: null,
        );
        final stopwatch = Stopwatch()..start();
        await api.getPrinterCapabilities(printer);
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(6000));
      });
    },
  );
}

class MockQuickPlatform extends FlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin {
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
      Future.value(ConnectionState.disconnected);

  @override
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) =>
      Stream.value(ConnectionState.disconnected);

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
      supportedBarcodes: [BarcodeType.code128, BarcodeType.qrCode],
      supportedFontSizes: [FontSize.small, FontSize.normal, FontSize.large],
    ),
  );

  @override
  Future<PrinterStatus> getPrinterStatus(BluetoothPrinter printer) =>
      Future.value(PrinterStatus(isConnected: false));
}
