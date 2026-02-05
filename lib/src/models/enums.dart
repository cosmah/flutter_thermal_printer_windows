/// Text alignment for receipt content.
enum TextAlignment {
  left,
  center,
  right,
}

/// Font size for thermal printer text.
enum FontSize {
  small,
  normal,
  large,
}

/// Barcode format for thermal printers.
enum BarcodeType {
  code128,
  code39,
  ean13,
  ean8,
  qrCode,
}

/// Type of item in a receipt.
enum ReceiptItemType {
  text,
  image,
  barcode,
  qrCode,
  line,
  spacer,
}
