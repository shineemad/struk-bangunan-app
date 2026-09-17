import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';

void main() {
  test('gaya bawaan adalah biasa', () {
    const baris = BarisStruk('Semen Tiga Roda');
    expect(baris.gaya, GayaBaris.biasa);
  });

  test('teksPolos menggabungkan baris dengan newline', () {
    final dokumen = ReceiptDocument(
      lebar: 32,
      baris: const [
        BarisStruk('TB. SINAR BANGUNAN', gaya: GayaBaris.tebal),
        BarisStruk('--------', gaya: GayaBaris.pemisah),
        BarisStruk('Semen'),
      ],
    );
    expect(dokumen.teksPolos, 'TB. SINAR BANGUNAN\n--------\nSemen');
  });

  test('daftar baris tidak bisa diubah dari luar', () {
    final dokumen = ReceiptDocument(
      lebar: 32,
      baris: const [BarisStruk('Semen')],
    );
    expect(
      () => dokumen.baris.add(const BarisStruk('Paku')),
      throwsUnsupportedError,
    );
  });
}
