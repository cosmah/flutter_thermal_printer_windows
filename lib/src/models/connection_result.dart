import 'exceptions.dart';

/// Result of a connection operation (used by PairingManager).
class ConnectionResult {
  const ConnectionResult({
    required this.isConnected,
    this.error,
  });

  final bool isConnected;
  final ThermalPrinterException? error;
}
