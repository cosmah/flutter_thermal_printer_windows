import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin
    implements FlutterThermalPrinterWindowsPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  List<BluetoothPrinter>? scanResult;

  @override
  Future<List<BluetoothPrinter>> scanForPrinters({Duration? timeout}) =>
      Future.value(scanResult ?? []);

  PairingResult? pairResult;
  @override
  Future<PairingResult> pairDevice(BluetoothPrinter printer) => Future.value(
    pairResult ??
        PairingResult(
          isPaired: true,
          printer: printer.copyWith(isPaired: true),
        ),
  );

  @override
  Future<void> unpairDevice(BluetoothPrinter printer) => Future.value();

  ConnectionResult? connectResult;
  @override
  Future<ConnectionResult> connectToDevice(BluetoothPrinter printer) =>
      Future.value(connectResult ?? ConnectionResult(isConnected: true));

  @override
  Future<void> disconnectFromDevice(BluetoothPrinter printer) => Future.value();

  ConnectionState? connectionState;
  @override
  Future<ConnectionState> getConnectionState(BluetoothPrinter printer) =>
      Future.value(connectionState ?? ConnectionState.disconnected);

  Stream<ConnectionState>? connectionStateStream;
  @override
  Stream<ConnectionState> watchConnectionState(BluetoothPrinter printer) =>
      connectionStateStream ?? Stream.value(ConnectionState.disconnected);

  @override
  Future<void> sendRawCommands(BluetoothPrinter printer, Uint8List commands) =>
      Future.value();

  @override
  Future<List<BluetoothPrinter>> getPairedPrinters() =>
      Future.value(scanResult ?? []);

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
      Future.value(
        PrinterStatus(
          isConnected: connectionState == ConnectionState.connected,
        ),
      );
}

void main() {
  final FlutterThermalPrinterWindowsPlatform initialPlatform =
      FlutterThermalPrinterWindowsPlatform.instance;

  test(
    '$MethodChannelFlutterThermalPrinterWindows is the default instance',
    () {
      expect(
        initialPlatform,
        isInstanceOf<MethodChannelFlutterThermalPrinterWindows>(),
      );
    },
  );

  test('getPlatformVersion', () async {
    final plugin = FlutterThermalPrinterWindows();
    final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
    FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
    expect(await plugin.getPlatformVersion(), '42');
  });

  group('ThermalPrinterWindows', () {
    test('instance returns singleton', () {
      final a = ThermalPrinterWindows.instance;
      final b = ThermalPrinterWindows.instance;
      expect(identical(a, b), isTrue);
    });
    test('scanForPrinters returns list from platform', () async {
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      final printers = [
        BluetoothPrinter(
          id: 'p1',
          name: 'P',
          macAddress: '00:00:00:00:00:00',
          signalStrength: -50,
          isPaired: false,
          connectionState: ConnectionState.disconnected,
          capabilities: null,
        ),
      ];
      fakePlatform.scanResult = printers;
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final api = ThermalPrinterWindows.instance;
      final list = await api.scanForPrinters(timeout: Duration(seconds: 1));
      expect(list.length, 1);
      expect(list[0].name, 'P');
    });
    test('getPairedPrinters returns list from platform', () async {
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      fakePlatform.scanResult = [];
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final api = ThermalPrinterWindows.instance;
      final list = await api.getPairedPrinters();
      expect(list, isEmpty);
    });
  });

  group('PairingManager', () {
    test('pairingManager returns PairingManager instance', () {
      final plugin = FlutterThermalPrinterWindows();
      expect(plugin.pairingManager, isA<PairingManager>());
    });

    test('pairDevice returns result from platform', () async {
      final printer = BluetoothPrinter(
        id: 'p1',
        name: 'Printer',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        signalStrength: -50,
        isPaired: false,
        connectionState: ConnectionState.disconnected,
        capabilities: null,
      );
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final manager = PairingManager(platform: fakePlatform);
      final result = await manager.pairDevice(printer);
      expect(result.isPaired, isTrue);
      expect(result.printer?.isPaired, isTrue);
    });

    test('unpairDevice completes', () async {
      final printer = BluetoothPrinter(
        id: 'p1',
        name: 'Printer',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        signalStrength: -50,
        isPaired: true,
        connectionState: ConnectionState.disconnected,
        capabilities: null,
      );
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final manager = PairingManager(platform: fakePlatform);
      await manager.unpairDevice(printer);
    });

    test('connectToDevice returns result from platform', () async {
      final printer = BluetoothPrinter(
        id: 'p1',
        name: 'Printer',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        signalStrength: -50,
        isPaired: true,
        connectionState: ConnectionState.disconnected,
        capabilities: null,
      );
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      fakePlatform.connectResult = ConnectionResult(isConnected: true);
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final manager = PairingManager(platform: fakePlatform);
      final result = await manager.connectToDevice(printer);
      expect(result.isConnected, isTrue);
    });

    test('watchConnectionState emits state from platform', () async {
      final printer = BluetoothPrinter(
        id: 'p1',
        name: 'Printer',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        signalStrength: -50,
        isPaired: true,
        connectionState: ConnectionState.disconnected,
        capabilities: null,
      );
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      fakePlatform.connectionStateStream = Stream.fromIterable([
        ConnectionState.connecting,
        ConnectionState.connected,
      ]);
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final manager = PairingManager(platform: fakePlatform);
      final states = await manager
          .watchConnectionState(printer)
          .take(2)
          .toList();
      expect(states, [ConnectionState.connecting, ConnectionState.connected]);
    });
  });

  group('PrinterScanner', () {
    test('scanner returns scanner instance', () {
      final plugin = FlutterThermalPrinterWindows();
      expect(plugin.scanner, isA<PrinterScanner>());
    });

    test(
      'scanForThermalPrinters returns empty list when platform returns empty',
      () async {
        final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
        fakePlatform.scanResult = [];
        FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
        final scanner = PrinterScanner(platform: fakePlatform);
        final result = await scanner.scanForThermalPrinters(
          Duration(seconds: 5),
        );
        expect(result, isEmpty);
      },
    );

    test('scanForThermalPrinters returns printers from platform', () async {
      final printers = [
        BluetoothPrinter(
          id: 'id1',
          name: 'Printer One',
          macAddress: 'AA:BB:CC:DD:EE:FF',
          signalStrength: -50,
          isPaired: false,
          connectionState: ConnectionState.disconnected,
          capabilities: null,
        ),
      ];
      final fakePlatform = MockFlutterThermalPrinterWindowsPlatform();
      fakePlatform.scanResult = printers;
      FlutterThermalPrinterWindowsPlatform.instance = fakePlatform;
      final scanner = PrinterScanner(platform: fakePlatform);
      final result = await scanner.scanForThermalPrinters(Duration(seconds: 5));
      expect(result.length, 1);
      expect(result[0].name, 'Printer One');
      expect(result[0].macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(result[0].signalStrength, -50);
    });
  });
}
