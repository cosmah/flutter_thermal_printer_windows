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
