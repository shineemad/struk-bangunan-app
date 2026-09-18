import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Lebar halaman PDF untuk struk selebar [lebarKolom] karakter, dalam poin.
double lebarHalamanPdf(int lebarKolom) =>
    lebarKolom >= 48 ? PdfPageFormat.roll80.width : PdfPageFormat.roll57.width;

/// Membungkus gambar struk menjadi PDF satu halaman setinggi gambarnya.
///
/// Tata letaknya tidak disusun ulang di sini: PDF memuat gambar yang sama
/// dengan yang dikirim ke WhatsApp, sehingga keduanya tidak mungkin berbeda.
/// Itu juga sebabnya tidak ada font apa pun di berkas ini.
Future<Uint8List> susunPdf({
  required Uint8List png,
  required int lebarKolom,
}) async {
  final gambar = pw.MemoryImage(png);
  final lebar = lebarHalamanPdf(lebarKolom);
  final tinggi = lebar * gambar.height! / gambar.width!;

  final dokumen = pw.Document();
  dokumen.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(lebar, tinggi),
      build: (_) => pw.Image(gambar, fit: pw.BoxFit.fitWidth),
    ),
  );
  return dokumen.save();
}
