import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:struk_bangunan/data/backup_service.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/output/pemilih_berkas.dart';
import 'package:struk_bangunan/state/pemulih.dart';

import '../bantuan_basisdata.dart';

class _PemilihPalsu implements PemilihBerkas {
  _PemilihPalsu(this.isi);

  final String? isi;
  int dipanggil = 0;

  @override
  Future<String?> pilihTeks() async {
    dipanggil++;
    return isi;
  }
}

Future<Database> _dbBerisi(SharedPreferences prefs) async {
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  await TransaksiRepository(db).simpan(
    items: [
      ItemBelanja(nama: 'Semen', qty: 2, satuan: 'sak', hargaSatuan: 65000),
    ],
    waktu: DateTime(2026, 9, 19, 10),
  );
  return db;
}

void main() {
  test('berkas yang dipilih menimpa data lama', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final asal = await _dbBerisi(prefs);
    addTearDown(asal.close);
    final cadangan = await BackupService(
      asal,
      ProfilRepository(prefs),
      PengaturanKeluaranRepository(prefs),
    ).ekspor();

    final tujuan = await bukaBasisdataUji();
    await siapkanSkema(tujuan);
    addTearDown(tujuan.close);
    expect(await tujuan.query('transaksi'), isEmpty);

    final pemulih = Pemulih(
      BackupService(
        tujuan,
        ProfilRepository(prefs),
        PengaturanKeluaranRepository(prefs),
      ),
      _PemilihPalsu(cadangan),
    );

    expect(await pemulih.pulihkan(), isTrue);
    expect(await tujuan.query('transaksi'), hasLength(1));
  });

  test('pengguna yang membatalkan tidak kehilangan data lama', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = await _dbBerisi(prefs);
    addTearDown(db.close);

    final pemilih = _PemilihPalsu(null);
    final pemulih = Pemulih(
      BackupService(
        db,
        ProfilRepository(prefs),
        PengaturanKeluaranRepository(prefs),
      ),
      pemilih,
    );

    expect(await pemulih.pulihkan(), isFalse);
    expect(pemilih.dipanggil, 1);
    // Membatalkan harus benar-benar tidak menyentuh basis data.
    expect(await db.query('transaksi'), hasLength(1));
  });

  test('berkas yang bukan cadangan ditolak tanpa merusak data lama', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = await _dbBerisi(prefs);
    addTearDown(db.close);

    final pemulih = Pemulih(
      BackupService(
        db,
        ProfilRepository(prefs),
        PengaturanKeluaranRepository(prefs),
      ),
      _PemilihPalsu('ini foto, bukan cadangan'),
    );

    await expectLater(pemulih.pulihkan(), throwsA(isA<BackupRusak>()));
    expect(await db.query('transaksi'), hasLength(1));
  });
}
