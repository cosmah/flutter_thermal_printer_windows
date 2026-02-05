import 'enums.dart';

/// Describes printer hardware capabilities.
class PrinterCapabilities {
  const PrinterCapabilities({
    required this.maxPaperWidth,
    required this.supportsCutting,
    required this.supportsImages,
    required this.supportedBarcodes,
    required this.supportedFontSizes,
    this.supportsPartialCut = false,
  });

  final int maxPaperWidth;
  final bool supportsCutting;
  final bool supportsImages;
  final List<BarcodeType> supportedBarcodes;
  final List<FontSize> supportedFontSizes;
  final bool supportsPartialCut;
}
