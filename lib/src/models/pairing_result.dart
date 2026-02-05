import 'bluetooth_printer.dart';
import 'exceptions.dart';

/// Result of a pairing operation (used by PairingManager).
class PairingResult {
  const PairingResult({
    required this.isPaired,
    this.printer,
    this.error,
  });

  final bool isPaired;
  final BluetoothPrinter? printer;
  final ThermalPrinterException? error;
}
