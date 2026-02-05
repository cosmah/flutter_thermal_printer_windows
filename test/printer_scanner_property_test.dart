// Property 1: Printer Discovery Completeness
// For any set of available Bluetooth thermal printers within range, the scanner
// should discover and return information for all of them including name,
// MAC address, and signal strength.
// Validates: Requirements 1.1, 1.2

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 1: Printer Discovery Completeness',
    () {
      test(
        'for any set of discovered printers, scanner returns all with name, macAddress, signalStrength',
        () async {
          const iterations = 100;
          for (var i = 0; i < iterations; i++) {
            final printers = _generatePrinterList(i);
            final mock = MockScanPlatform(printers);
            final scanner = PrinterScanner(platform: mock);
            final result = await scanner.scanForThermalPrinters(
              Duration(seconds: 1),
            );
            expect(result.length, printers.length, reason: 'iteration $i');
            for (var j = 0; j < result.length; j++) {
              expect(
                result[j].name,
                isNotEmpty,
                reason: 'iteration $i printer $j',
              );
              expect(
                result[j].macAddress,
                isNotEmpty,
                reason: 'iteration $i printer $j',
              );
              expect(
                result[j].signalStrength,
                isA<int>(),
                reason: 'iteration $i printer $j',
              );
              expect(result[j].name, printers[j].name);
              expect(result[j].macAddress, printers[j].macAddress);
              expect(result[j].signalStrength, printers[j].signalStrength);
            }
          }
        },
      );
    },
  );
}

List<BluetoothPrinter> _generatePrinterList(int seed) {
  final count = (seed % 5) + 1;
  return List.generate(count, (i) {
    final n = seed * 10 + i;
    return BluetoothPrinter(
      id: 'id-$n',
      name: 'Printer-$n',
      macAddress:
          '${_hex(n)}:${_hex(n + 1)}:${_hex(n + 2)}:${_hex(n + 3)}:${_hex(n + 4)}:${_hex(n + 5)}',
      signalStrength: -100 + (n % 50),
      isPaired: n % 2 == 0,
      connectionState:
          ConnectionState.values[n % ConnectionState.values.length],
      capabilities: null,
    );
  });
}

String _hex(int n) =>
    ((n % 256).abs()).toRadixString(16).padLeft(2, '0').toUpperCase();

class MockScanPlatform extends FlutterThermalPrinterWindowsPlatform
    with MockPlatformInterfaceMixin {
  MockScanPlatform(this._printers);

  final List<BluetoothPrinter> _printers;

  @override
  Future<String?> getPlatformVersion() => Future.value('Windows');

  @override
  Future<List<BluetoothPrinter>> scanForPrinters({Duration? timeout}) =>
      Future.value(List.from(_printers));
}
