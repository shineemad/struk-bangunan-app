import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/app/wadah.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

import '../bantuan_basisdata.dart';

Future<Wadah> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  return Wadah(db, await SharedPreferences.getInstance());
}

void main() {
  test('menyiapkan favorit bawaan sekali saja', () async {
    final wadah = await _siap();

    await wadah.siapkan();
    final pertama = (await wadah.favorit.daftar()).length;
    await wadah.siapkan();

    expect(pertama, greaterThan(0));
    expect((await wadah.favorit.daftar()).length, pertama);
  });

  test('repository memakai basis data dan prefs yang sama', () async {
    final wadah = await _siap();
    await wadah.siapkan();

    await wadah.favorit.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 18));
    final daftar = await wadah.favorit.daftar();
    expect(daftar.first.nama, 'Semen');

    // Bila wadah.transaksi dibangun di atas koneksi db lain, baris ini tidak
    // akan pernah terlihat lewat query langsung ke wadah.db.
    await wadah.transaksi.simpan(
      items: [
        ItemBelanja(nama: 'Paku', qty: 1, satuan: 'kg', hargaSatuan: 20000),
      ],
      waktu: DateTime(2026, 9, 18),
    );
    expect(await wadah.db.query('transaksi'), isNotEmpty);

    // Bila wadah.draf memakai instance SharedPreferences lain, wadah.prefs
    // tetap kosong setelah ini.
    await wadah.draf.simpan([
      ItemBelanja(nama: 'Semen', qty: 1, satuan: 'sak', hargaSatuan: 65000),
    ]);
    expect(wadah.prefs.getKeys(), isNotEmpty);

    const profil = ProfilToko(namaToko: 'Toko Jaya Makmur');
    await wadah.profil.simpan(profil);
    expect(wadah.prefs.getString(ProfilRepository.kunciNama), profil.namaToko);

    const pengaturan = PengaturanKeluaran(printerMac: 'AA:BB:CC:DD:EE:FF');
    await wadah.pengaturan.simpan(pengaturan);
    final dibaca = await PengaturanKeluaranRepository(wadah.prefs).muat();
    expect(dibaca.printerMac, pengaturan.printerMac);
  });
}
