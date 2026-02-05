import 'connection_state.dart';
import 'printer_capabilities.dart';

/// Represents a discovered or paired Bluetooth thermal printer.
class BluetoothPrinter {
  const BluetoothPrinter({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.signalStrength,
    required this.isPaired,
    required this.connectionState,
    this.capabilities,
  });

  final String id;
  final String name;
  final String macAddress;
  final int signalStrength;
  final bool isPaired;
  final ConnectionState connectionState;
  final PrinterCapabilities? capabilities;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothPrinter &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Encodes this printer for platform channel (e.g. method channel).
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'macAddress': macAddress,
    'signalStrength': signalStrength,
    'isPaired': isPaired,
    'connectionState': connectionState.index,
  };

  BluetoothPrinter copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? signalStrength,
    bool? isPaired,
    ConnectionState? connectionState,
    PrinterCapabilities? capabilities,
  }) {
    return BluetoothPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      signalStrength: signalStrength ?? this.signalStrength,
      isPaired: isPaired ?? this.isPaired,
      connectionState: connectionState ?? this.connectionState,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
