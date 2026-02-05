/// Status information for a thermal printer.
class PrinterStatus {
  const PrinterStatus({
    required this.isConnected,
    this.isPaperOut = false,
    this.isCoverOpen = false,
    this.isError = false,
    this.errorMessage,
  });

  final bool isConnected;
  final bool isPaperOut;
  final bool isCoverOpen;
  final bool isError;
  final String? errorMessage;
}
