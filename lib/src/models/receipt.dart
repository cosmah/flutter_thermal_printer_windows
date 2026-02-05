import 'dart:typed_data';

import 'enums.dart';
import 'exceptions.dart';

/// Header section of a receipt (e.g. logo, store name).
class ReceiptHeader {
  const ReceiptHeader({this.text, this.imageData});

  final String? text;
  final Uint8List? imageData;
}

/// Footer section of a receipt (e.g. thank you message).
class ReceiptFooter {
  const ReceiptFooter({this.text});

  final String? text;
}

/// Text style for a receipt item.
class TextStyle {
  const TextStyle({
    this.bold = false,
    this.underline = false,
    this.fontSize = FontSize.normal,
    this.alignment = TextAlignment.left,
  });

  final bool bold;
  final bool underline;
  final FontSize fontSize;
  final TextAlignment alignment;
}

/// Barcode data for receipt items.
class BarcodeData {
  const BarcodeData({
    required this.data,
    required this.type,
    this.height,
    this.width,
  });

  final String data;
  final BarcodeType type;
  final int? height;
  final int? width;
}

/// A single item in a receipt (text, image, barcode, etc.).
class ReceiptItem {
  const ReceiptItem({
    required this.type,
    this.text,
    this.style,
    this.imageData,
    this.barcodeData,
  });

  final ReceiptItemType type;
  final String? text;
  final TextStyle? style;
  final Uint8List? imageData;
  final BarcodeData? barcodeData;

  /// Validates item; throws [ValidationException] if type and content mismatch.
  void validate() {
    switch (type) {
      case ReceiptItemType.text:
        if (text == null && (imageData != null || barcodeData != null)) {
          throw ValidationException(
            'ReceiptItem type is text but imageData or barcodeData is set',
          );
        }
        break;
      case ReceiptItemType.image:
        if (imageData == null || imageData!.isEmpty) {
          throw ValidationException(
            'ReceiptItem type is image but imageData is null or empty',
          );
        }
        break;
      case ReceiptItemType.barcode:
      case ReceiptItemType.qrCode:
        if (barcodeData == null || barcodeData!.data.isEmpty) {
          throw ValidationException(
            'ReceiptItem type $type requires barcodeData with non-empty data',
          );
        }
        break;
      case ReceiptItemType.line:
      case ReceiptItemType.spacer:
        break;
    }
  }
}

/// Receipt print settings.
class ReceiptSettings {
  const ReceiptSettings({
    this.paperWidth = 58,
    this.autoCut = true,
    this.feedLinesAfterCut = 3,
    this.defaultAlignment = TextAlignment.left,
  });

  final int paperWidth;
  final bool autoCut;
  final int feedLinesAfterCut;
  final TextAlignment defaultAlignment;

  /// Validates settings; throws [ValidationException] if invalid.
  void validate() {
    if (paperWidth <= 0 || paperWidth > 256) {
      throw ValidationException(
        'paperWidth must be between 1 and 256, got $paperWidth',
      );
    }
    if (feedLinesAfterCut < 0 || feedLinesAfterCut > 255) {
      throw ValidationException(
        'feedLinesAfterCut must be between 0 and 255, got $feedLinesAfterCut',
      );
    }
  }
}

/// Structured representation of receipt content for printing.
class Receipt {
  const Receipt({
    required this.items,
    this.header,
    this.footer,
    this.settings = const ReceiptSettings(),
  });

  final List<ReceiptItem> items;
  final ReceiptHeader? header;
  final ReceiptFooter? footer;
  final ReceiptSettings settings;

  /// Validates receipt; throws [ValidationException] if invalid.
  void validate() {
    settings.validate();
    for (var i = 0; i < items.length; i++) {
      try {
        items[i].validate();
      } on ValidationException catch (e) {
        throw ValidationException('Item $i: ${e.message}');
      }
    }
  }
}
