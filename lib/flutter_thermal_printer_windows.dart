import 'flutter_thermal_printer_windows_platform_interface.dart';
import 'src/pairing_manager.dart';
import 'src/printer_scanner.dart';

export 'src/esc_pos_generator.dart';
export 'src/models/bluetooth_printer.dart';
export 'src/print_engine.dart';
export 'src/thermal_printer_windows.dart';
export 'src/models/connection_state.dart';
export 'src/models/connection_result.dart';
export 'src/models/enums.dart';
export 'src/models/exceptions.dart';
export 'src/models/pairing_result.dart';
export 'src/models/printer_capabilities.dart';
export 'src/models/printer_status.dart';
export 'src/models/receipt.dart';
export 'src/pairing_manager.dart';
export 'src/printer_scanner.dart';

class FlutterThermalPrinterWindows {
  FlutterThermalPrinterWindows();

  Future<String?> getPlatformVersion() {
    return FlutterThermalPrinterWindowsPlatform.instance.getPlatformVersion();
  }

  /// Returns a [PrinterScanner] for discovering Bluetooth thermal printers.
  PrinterScanner get scanner => PrinterScanner();

  /// Returns a [PairingManager] for pairing and connection management.
  PairingManager get pairingManager => PairingManager();
}
