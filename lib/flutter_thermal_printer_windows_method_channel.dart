import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_thermal_printer_windows_platform_interface.dart';
import 'src/models/bluetooth_printer.dart';
import 'src/models/connection_result.dart';
import 'src/models/connection_state.dart';
import 'src/models/enums.dart';
import 'src/models/pairing_result.dart';
import 'src/models/printer_capabilities.dart';
import 'src/models/printer_status.dart';

/// An implementation of [FlutterThermalPrinterWindowsPlatform] that uses method channels.
class MethodChannelFlutterThermalPrinterWindows
    extends FlutterThermalPrinterWindowsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_thermal_printer_windows');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<List<BluetoothPrinter>> scanForPrinters({Duration? timeout}) async {
    debugPrint('[ThermalPlugin] scanForPrinters: calling native, timeout=$timeout');
    final timeoutMs = timeout?.inMilliseconds;
    try {
      final result = await methodChannel.invokeMethod<List<Object?>>(
        'scanForPrinters',
        <String, Object?>{'timeoutMs': timeoutMs},
      );
      debugPrint('[ThermalPlugin] scanForPrinters: native returned, result==null=${result == null}, length=${result?.length ?? 0}');
      if (result == null) return [];
      final decoded = _decodePrinters(result);
      debugPrint('[ThermalPlugin] scanForPrinters: decoded ${decoded.length} printers');
      return decoded;
    } catch (e, st) {
      debugPrint('[ThermalPlugin] scanForPrinters: ERROR $e');
      debugPrint('[ThermalPlugin] scanForPrinters: stack $st');
      rethrow;
    }
  }

  static List<BluetoothPrinter> _decodePrinters(List<Object?> list) {
    return list.whereType<Map<Object?, Object?>>().map(_decodePrinter).toList();
  }

  static BluetoothPrinter _decodePrinter(Map<Object?, Object?> map) {
    debugPrint('[ThermalPlugin] _decodePrinter: id=${map['id']} name=${map['name']}');
    Object? v(key) => map[key];
    String s(key) => (v(key) as String?) ?? '';
    int i(key) => (v(key) as int?) ?? 0;
    bool b(key) => (v(key) as bool?) ?? false;
    final connectionStateIndex = i('connectionState');
    final connectionState =
        ConnectionState.values[connectionStateIndex.clamp(
          0,
          ConnectionState.values.length - 1,
        )];
    return BluetoothPrinter(
      id: s('id').isEmpty ? s('macAddress') : s('id'),
      name: s('name'),
      macAddress: s('macAddress'),
      signalStrength: i('signalStrength'),
      isPaired: b('isPaired'),
      connectionState: connectionState,
      capabilities: null,
    );
  }

  @override
  Future<PairingResult> pairDevice(BluetoothPrinter printer) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'pairDevice',
      printer.toMap(),
    );
    return _decodePairingResult(result, printer);
  }

  @override
  Future<void> unpairDevice(BluetoothPrinter printer) async {
    await methodChannel.invokeMethod<void>('unpairDevice', printer.toMap());
  }

  @override
  Future<ConnectionResult> connectToDevice(BluetoothPrinter printer) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'connectToDevice',
      printer.toMap(),
    );
    return _decodeConnectionResult(result);
  }

  @override
  Future<void> disconnectFromDevice(BluetoothPrinter printer) async {
    await methodChannel.invokeMethod<void>(
      'disconnectFromDevice',
      printer.toMap(),
    );
  }

  @override
  Future<ConnectionState> getConnectionState(BluetoothPrinter printer) async {
    final index = await methodChannel.invokeMethod<int>(
      'getConnectionState',
      <String, Object?>{'printerId': printer.id},
    );
    return ConnectionState.values[(index ?? 0).clamp(
      0,
      ConnectionState.values.length - 1,
    )];
  }

  @override
  Stream<ConnectionState> watchConnectionState(
    BluetoothPrinter printer,
  ) async* {
    const period = Duration(seconds: 2);
    ConnectionState? last;
    while (true) {
      final state = await getConnectionState(printer);
      if (state != last) {
        last = state;
        yield state;
      }
      await Future<void>.delayed(period);
    }
  }

  static PairingResult _decodePairingResult(
    Map<Object?, Object?>? result,
    BluetoothPrinter fallbackPrinter,
  ) {
    if (result == null) {
      return PairingResult(isPaired: false, printer: null, error: null);
    }
    Object? v(key) => result[key];
    bool b(key) => (v(key) as bool?) ?? false;
    final isPaired = b('isPaired');
    BluetoothPrinter? printer;
    if (v('printer') is Map) {
      printer = _decodePrinter(v('printer')! as Map<Object?, Object?>);
    } else if (isPaired) {
      printer = fallbackPrinter.copyWith(isPaired: true);
    }
    return PairingResult(isPaired: isPaired, printer: printer, error: null);
  }

  static ConnectionResult _decodeConnectionResult(
    Map<Object?, Object?>? result,
  ) {
    if (result == null) {
      return ConnectionResult(isConnected: false, error: null);
    }
    final isConnected = (result['isConnected'] as bool?) ?? false;
    return ConnectionResult(isConnected: isConnected, error: null);
  }

  @override
  Future<void> sendRawCommands(
    BluetoothPrinter printer,
    Uint8List commands,
  ) async {
    await methodChannel.invokeMethod<void>('sendRawCommands', <String, Object?>{
      'printer': printer.toMap(),
      'bytes': commands.toList(),
    });
  }

  @override
  Future<List<BluetoothPrinter>> getPairedPrinters() async {
    final result = await methodChannel.invokeMethod<List<Object?>>(
      'getPairedPrinters',
    );
    if (result == null) return [];
    return result
        .whereType<Map<Object?, Object?>>()
        .map(_decodePrinter)
        .toList();
  }

  @override
  Future<PrinterCapabilities> getPrinterCapabilities(
    BluetoothPrinter printer,
  ) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getPrinterCapabilities',
      printer.toMap(),
    );
    return _decodeCapabilities(result);
  }

  @override
  Future<PrinterStatus> getPrinterStatus(BluetoothPrinter printer) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getPrinterStatus',
      printer.toMap(),
    );
    return _decodeStatus(result);
  }

  static PrinterCapabilities _decodeCapabilities(Map<Object?, Object?>? m) {
    if (m == null) {
      return PrinterCapabilities(
        maxPaperWidth: 58,
        supportsCutting: true,
        supportsImages: true,
        supportedBarcodes: BarcodeType.values,
        supportedFontSizes: FontSize.values,
      );
    }
    Object? v(key) => m[key];
    int i(key) => (v(key) as int?) ?? 58;
    bool b(key) => (v(key) as bool?) ?? false;
    List<BarcodeType> bar(List<Object?>? list) {
      if (list == null) return BarcodeType.values;
      return list
          .whereType<int>()
          .map(
            (e) =>
                BarcodeType.values[e.clamp(0, BarcodeType.values.length - 1)],
          )
          .toList();
    }

    List<FontSize> fonts(List<Object?>? list) {
      if (list == null) return FontSize.values;
      return list
          .whereType<int>()
          .map((e) => FontSize.values[e.clamp(0, FontSize.values.length - 1)])
          .toList();
    }

    return PrinterCapabilities(
      maxPaperWidth: i('maxPaperWidth'),
      supportsCutting: b('supportsCutting'),
      supportsImages: b('supportsImages'),
      supportedBarcodes: bar(v('supportedBarcodes') as List<Object?>?),
      supportedFontSizes: fonts(v('supportedFontSizes') as List<Object?>?),
      supportsPartialCut: b('supportsPartialCut'),
    );
  }

  static PrinterStatus _decodeStatus(Map<Object?, Object?>? m) {
    if (m == null) return PrinterStatus(isConnected: false);
    Object? v(key) => m[key];
    bool b(key) => (v(key) as bool?) ?? false;
    return PrinterStatus(
      isConnected: b('isConnected'),
      isPaperOut: b('isPaperOut'),
      isCoverOpen: b('isCoverOpen'),
      isError: b('isError'),
      errorMessage: v('errorMessage') as String?,
    );
  }
}
