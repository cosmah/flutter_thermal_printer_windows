import 'package:flutter/services.dart';

/// Base exception for thermal printer operations.
///
/// On failure, async API methods throw a [ThermalPrinterException] (or subclass).
/// [errorCode] is optional (e.g. native Windows/Bluetooth error code).
/// [cause] and [context] support diagnostics.
abstract class ThermalPrinterException implements Exception {
  const ThermalPrinterException(
    this.message, {
    this.errorCode,
    this.cause,
    this.context,
  });

  final String message;
  final String? errorCode;
  final Object? cause;
  final Map<String, Object?>? context;

  /// User-facing message suitable for UI. Falls back to [message] if none set.
  String get userFriendlyMessage => message;

  /// Creates an exception from a [PlatformException].
  static ThermalPrinterException fromPlatform(PlatformException e) {
    final msg = _userMessageForCode(e.code) ?? e.message ?? 'Unknown error';
    return fromCode(msg, errorCode: e.code);
  }

  static String? _userMessageForCode(String? code) {
    if (code == null) return null;
    switch (code) {
      case 'ScanFailed':
        return 'Bluetooth scan failed. Ensure Bluetooth is on and try again.';
      case 'PairFailed':
        return 'Pairing failed. Accept the pairing request on the printer.';
      case 'UnpairFailed':
        return 'Unpairing failed. Try again or unpair from Windows Settings.';
      case 'ConnectFailed':
        return 'Connection failed. Ensure the printer is on and in range.';
      case 'SendFailed':
        return 'Print failed. Check printer connection and paper.';
      case 'InvalidArguments':
        return 'Invalid printer or arguments.';
      default:
        return null;
    }
  }

  /// Creates an appropriate exception from a native [errorCode] and [message].
  /// Maps common Windows/Bluetooth codes to subclass types.
  static ThermalPrinterException fromCode(String message, {String? errorCode}) {
    final code = errorCode?.toUpperCase() ?? '';
    if (code.contains('NOT_FOUND') ||
        code.contains('DEVICE') && code.contains('PAIR')) {
      return DeviceNotPairedException(message, errorCode: errorCode);
    }
    if (code.contains('CONNECT') ||
        code.contains('TIMEOUT') ||
        code.contains('REFUSED')) {
      return ConnectionFailedException(message, errorCode: errorCode);
    }
    if (code.contains('PRINT') ||
        code.contains('WRITE') ||
        code.contains('SEND')) {
      return PrintJobFailedException(message, errorCode: errorCode);
    }
    if (code.contains('BLUETOOTH') ||
        code.contains('UNAVAILABLE') ||
        code.contains('ADAPTER')) {
      return BluetoothNotAvailableException(message, errorCode: errorCode);
    }
    if (code.contains('UNSUPPORTED') || code.contains('NOT_IMPLEMENTED')) {
      return UnsupportedOperationException(message, errorCode: errorCode);
    }
    return ConnectionFailedException(message, errorCode: errorCode);
  }

  @override
  String toString() {
    final buf = StringBuffer('$runtimeType: $message');
    if (errorCode != null) buf.write(' (code: $errorCode)');
    if (cause != null) buf.write('; cause: $cause');
    return buf.toString();
  }
}

/// Thrown when Bluetooth is unavailable or disabled.
class BluetoothNotAvailableException extends ThermalPrinterException {
  const BluetoothNotAvailableException(
    super.message, {
    super.errorCode,
    super.cause,
    super.context,
  });
}

/// Thrown when the device is not paired.
class DeviceNotPairedException extends ThermalPrinterException {
  const DeviceNotPairedException(
    super.message, {
    super.errorCode,
    super.cause,
    super.context,
  });
}

/// Thrown when connection to the printer fails.
class ConnectionFailedException extends ThermalPrinterException {
  const ConnectionFailedException(
    super.message, {
    super.errorCode,
    super.cause,
    super.context,
  });
}

/// Thrown when a print job fails.
class PrintJobFailedException extends ThermalPrinterException {
  const PrintJobFailedException(
    super.message, {
    super.errorCode,
    super.cause,
    super.context,
  });
}

/// Thrown when an operation is not supported.
class UnsupportedOperationException extends ThermalPrinterException {
  const UnsupportedOperationException(
    super.message, {
    super.errorCode,
    super.cause,
    super.context,
  });
}

/// Thrown when input data is invalid (e.g. invalid receipt format).
class ValidationException extends ThermalPrinterException {
  const ValidationException(
    super.message, {
    super.errorCode,
    super.cause,
    super.context,
  });
}
