import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/receipt/receipt_document.dart';
import 'package:struk_bangunan/output/esc_pos_renderer.dart';

/// Posisi kemunculan pertama [pola] di dalam [sumber], atau -1.
int _cariUrutan(List<int> sumber, List<int> pola, [int mulai = 0]) {
  for (var i = mulai; i + pola.length <= sumber.length; i++) {
    var cocok = true;
    for (var j = 0; j < pola.length; j++) {
      if (sumber[i + j] != pola[j]) {
        cocok = false;
        break;
      }
    }
    if (cocok) return i;
  }
  return -1;
}

/// Parameter perintah ESC E (tebal) terakhir sebelum [batas]: 1 tebal, 0
/// biasa, -1 bila tidak ada sama sekali.
int _tebalSebelum(List<int> bytes, int batas) {
  for (var i = batas - 3; i >= 0; i--) {
    if (bytes[i] == 0x1B && bytes[i + 1] == 0x45) return bytes[i + 2];
  }
  return -1;
}

ReceiptDocument _contoh({int lebar = 32}) => ReceiptDocument(
  lebar: lebar,
  baris: [
    BarisStruk(
      'TB. SINAR BANGUNAN'.padLeft(25).padRight(lebar),
      gaya: GayaBaris.tebal,
    ),
    BarisStruk('-' * lebar, gaya: GayaBaris.pemisah),
    BarisStruk('Semen Tiga Roda'.padRight(lebar)),
    BarisStruk(
      'TOTAL'.padRight(lebar - 13) + 'Rp 1.825.000'.padLeft(13),
      gaya: GayaBaris.tebal,
    ),
  ],
);

void main() {
  late CapabilityProfile profil;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    profil = await CapabilityProfile.load();
  });

  test('diawali perintah reset', () {
    final bytes = susunEscPos(dokumen: _contoh(), profil: profil);
    expect(bytes.take(2).toList(), [0x1B, 0x40]);
  });

  test('setiap baris muncul utuh dan berurutan', () {
    final dokumen = _contoh();
    final bytes = susunEscPos(dokumen: dokumen, profil: profil);

    var dari = 0;
    for (final baris in dokumen.baris) {
      final posisi = _cariUrutan(bytes, latin1.encode(baris.teks), dari);
      expect(posisi, greaterThanOrEqualTo(0), reason: 'hilang: ${baris.teks}');
      dari = posisi + baris.teks.length;
    }
  });

  test('baris tebal ditandai tebal, baris lain tidak', () {
    final dokumen = _contoh();
    final bytes = susunEscPos(dokumen: dokumen, profil: profil);

    var dari = 0;
    for (final baris in dokumen.baris) {
      final posisi = _cariUrutan(bytes, latin1.encode(baris.teks), dari);
      expect(
        _tebalSebelum(bytes, posisi),
        baris.gaya == GayaBaris.tebal ? 1 : 0,
        reason: 'gaya salah pada: ${baris.teks}',
      );
      dari = posisi + baris.teks.length;
    }
  });

  test('memotong kertas bila diminta', () {
    final bytes = susunEscPos(dokumen: _contoh(), profil: profil);
    expect(_cariUrutan(bytes, [0x1D, 0x56]), greaterThanOrEqualTo(0));
  });

  test('tidak memotong kertas bila tidak diminta', () {
    final bytes = susunEscPos(
      dokumen: _contoh(),
      profil: profil,
      potongKertas: false,
    );
    expect(_cariUrutan(bytes, [0x1D, 0x56]), -1);
  });

  test('struk 48 kolom keluar utuh tanpa terpotong', () {
    final dokumen = _contoh(lebar: 48);
    final bytes = susunEscPos(dokumen: dokumen, profil: profil);

    for (final baris in dokumen.baris) {
      expect(baris.teks.length, 48);
      expect(_cariUrutan(bytes, latin1.encode(baris.teks)), isNonNegative);
    }
  });

  test('struk tanpa baris tetap menghasilkan reset dan potong', () {
    final bytes = susunEscPos(
      dokumen: ReceiptDocument(lebar: 32, baris: const []),
      profil: profil,
    );
    expect(bytes.take(2).toList(), [0x1B, 0x40]);
    expect(_cariUrutan(bytes, [0x1D, 0x56]), greaterThanOrEqualTo(0));
  });
}
