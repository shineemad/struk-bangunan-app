import 'package:flutter_test/flutter_test.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

void main() {
  test('kertas 58mm memberi 32 kolom', () {
    const profil = ProfilToko(namaToko: 'TB. SINAR BANGUNAN');
    expect(profil.lebarKertas, 58);
    expect(profil.lebarKolom, 32);
  });

  test('kertas 80mm memberi 48 kolom', () {
    const profil = ProfilToko(namaToko: 'TB. SINAR BANGUNAN', lebarKertas: 80);
    expect(profil.lebarKolom, 48);
  });

  test('kolom opsional bernilai kosong secara bawaan', () {
    const profil = ProfilToko(namaToko: 'TB. SINAR BANGUNAN');
    expect(profil.alamat, '');
    expect(profil.noHp, '');
    expect(profil.catatan, '');
    expect(profil.namaKasir, '');
  });
}
