import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../domain/receipt/receipt_document.dart';

/// Menerjemahkan struk yang sudah jadi menjadi perintah ESC/POS.
///
/// Tidak ada satu pun aturan bentuk struk di sini. [ReceiptDocument] sudah
/// rata sempurna pada lebarnya, jadi fitur kolom dan perataan milik
/// [Generator] sengaja tidak dipakai: memakainya berarti meratakan ulang apa
/// yang sudah rata, dan struk kertas bisa berbeda dari struk di layar.
List<int> susunEscPos({
  required ReceiptDocument dokumen,
  required CapabilityProfile profil,
  int barisKosongAkhir = 4,
  bool potongKertas = true,
}) {
  final generator = Generator(
    dokumen.lebar >= 48 ? PaperSize.mm80 : PaperSize.mm58,
    profil,
  );

  final bytes = <int>[...generator.reset()];
  for (final baris in dokumen.baris) {
    bytes.addAll(
      generator.text(
        baris.teks,
        styles: PosStyles(bold: baris.gaya == GayaBaris.tebal),
      ),
    );
  }

  // Kertas perlu maju agar baris terakhir lolos dari kepala cetak sebelum
  // dipotong atau disobek tangan.
  bytes.addAll(generator.feed(barisKosongAkhir));
  if (potongKertas) bytes.addAll(generator.cut());
  return bytes;
}
