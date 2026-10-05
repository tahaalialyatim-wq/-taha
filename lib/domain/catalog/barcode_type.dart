/// Supported barcode symbologies.
///
/// This only classifies the value; there is no scanner, camera or checksum
/// validation.
enum BarcodeType { ean13, ean8, upcA, upcE, code128, code39, itf, qr, other }
