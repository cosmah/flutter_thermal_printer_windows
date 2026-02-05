import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterThermalPrinterWindows();
  const MethodChannel channel = MethodChannel(
    'flutter_thermal_printer_windows',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPlatformVersion') return '42';
          if (methodCall.method == 'scanForPrinters') return <Object?>[];
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('scanForPrinters returns empty list from channel', () async {
    final result = await platform.scanForPrinters(
      timeout: Duration(seconds: 5),
    );
    expect(result, isEmpty);
  });

  test('scanForPrinters decodes printer list from channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'scanForPrinters') {
            return <Object?>[
              <String, Object?>{
                'id': 'dev-1',
                'name': 'POS Printer',
                'macAddress': '11:22:33:44:55:66',
                'signalStrength': -60,
                'isPaired': true,
                'connectionState': 2,
              },
            ];
          }
          return null;
        });
    final result = await platform.scanForPrinters(
      timeout: Duration(seconds: 1),
    );
    expect(result.length, 1);
    expect(result[0].id, 'dev-1');
    expect(result[0].name, 'POS Printer');
    expect(result[0].macAddress, '11:22:33:44:55:66');
    expect(result[0].signalStrength, -60);
    expect(result[0].isPaired, true);
    expect(result[0].connectionState, ConnectionState.connected);
  });

  test('pairDevice sends printer map and decodes PairingResult', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'pairDevice') {
            final args = methodCall.arguments as Map<Object?, Object?>;
            final printerMap = Map<Object?, Object?>.from(args)
              ..['isPaired'] = true;
            return <String, Object?>{'isPaired': true, 'printer': printerMap};
          }
          return null;
        });
    final printer = BluetoothPrinter(
      id: 'p1',
      name: 'POS',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      signalStrength: -50,
      isPaired: false,
      connectionState: ConnectionState.disconnected,
      capabilities: null,
    );
    final result = await platform.pairDevice(printer);
    expect(result.isPaired, true);
    expect(result.printer?.id, 'p1');
    expect(result.printer?.isPaired, true);
  });

  test('connectToDevice decodes ConnectionResult', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'connectToDevice') {
            return <String, Object?>{'isConnected': true};
          }
          return null;
        });
    final printer = BluetoothPrinter(
      id: 'p1',
      name: 'POS',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      signalStrength: -50,
      isPaired: true,
      connectionState: ConnectionState.disconnected,
      capabilities: null,
    );
    final result = await platform.connectToDevice(printer);
    expect(result.isConnected, true);
  });

  test('getConnectionState returns state from channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getConnectionState') return 2;
          return null;
        });
    final printer = BluetoothPrinter(
      id: 'p1',
      name: 'POS',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      signalStrength: -50,
      isPaired: true,
      connectionState: ConnectionState.disconnected,
      capabilities: null,
    );
    final state = await platform.getConnectionState(printer);
    expect(state, ConnectionState.connected);
  });
}
