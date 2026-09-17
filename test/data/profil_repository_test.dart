import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('mengembalikan null bila toko belum pernah diatur', () async {
    final repo = ProfilRepository(await SharedPreferences.getInstance());
    expect(await repo.muat(), isNull);
  });

  test('menyimpan lalu memuat kembali seluruh kolom', () async {
    final repo = ProfilRepository(await SharedPreferences.getInstance());
    const asli = ProfilToko(
      namaToko: 'TB. SINAR BANGUNAN',
      alamat: 'Jl. Raya Merdeka No. 45',
      noHp: '0812-3456-7890',
      catatan: 'Barang yang sudah dibeli\ntidak dapat dikembalikan.',
      namaKasir: 'Admin',
      lebarKertas: 80,
    );

    await repo.simpan(asli);
    final hasil = (await repo.muat())!;

    expect(hasil.namaToko, asli.namaToko);
    expect(hasil.alamat, asli.alamat);
    expect(hasil.noHp, asli.noHp);
    expect(hasil.catatan, asli.catatan);
    expect(hasil.namaKasir, asli.namaKasir);
    expect(hasil.lebarKertas, 80);
  });

  test('kolom opsional yang kosong tetap kosong setelah dimuat', () async {
    final repo = ProfilRepository(await SharedPreferences.getInstance());
    await repo.simpan(const ProfilToko(namaToko: 'TB. MAJU JAYA'));
    final hasil = (await repo.muat())!;

    expect(hasil.namaToko, 'TB. MAJU JAYA');
    expect(hasil.alamat, '');
    expect(hasil.lebarKertas, 58);
  });
}
