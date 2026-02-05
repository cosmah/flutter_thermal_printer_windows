// Property 6: Error Information Consistency
// For any operation failure, the package should return a structured error
// object with appropriate error code, description, and error type classification.
// Validates: Requirements 1.4, 2.3, 3.4, 8.1, 8.4

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

void main() {
  group(
    'Feature: flutter-thermal-printer-windows, Property 6: Error Information Consistency',
    () {
      test('ThermalPrinterException has message and optional errorCode', () {
        const e = ConnectionFailedException(
          'Connection failed',
          errorCode: 'TIMEOUT',
        );
        expect(e.message, 'Connection failed');
        expect(e.errorCode, 'TIMEOUT');
        expect(e.toString(), contains('ConnectionFailedException'));
        expect(e.toString(), contains('Connection failed'));
        expect(e.toString(), contains('TIMEOUT'));
      });

      test('ValidationException has message', () {
        const e = ValidationException('Invalid paper width');
        expect(e.message, 'Invalid paper width');
        expect(e, isA<ThermalPrinterException>());
      });

      test('fromCode maps error codes to exception types', () {
        expect(
          ThermalPrinterException.fromCode(
            'Device not paired',
            errorCode: 'DEVICE_NOT_PAIRED',
          ),
          isA<DeviceNotPairedException>(),
        );
        expect(
          ThermalPrinterException.fromCode(
            'Timeout',
            errorCode: 'CONNECT_TIMEOUT',
          ),
          isA<ConnectionFailedException>(),
        );
        expect(
          ThermalPrinterException.fromCode(
            'Bluetooth off',
            errorCode: 'BLUETOOTH_UNAVAILABLE',
          ),
          isA<BluetoothNotAvailableException>(),
        );
      });

      test('exceptions support cause and context', () {
        const e = ConnectionFailedException(
          'Failed',
          errorCode: 'ERR',
          cause: 'Underlying',
          context: {'printerId': 'p1'},
        );
        expect(e.cause, 'Underlying');
        expect(e.context!['printerId'], 'p1');
      });
    },
  );
}
