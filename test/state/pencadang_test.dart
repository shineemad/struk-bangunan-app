import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:struk_bangunan/data/backup_service.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/output/berkas_sementara.dart';
import 'package:struk_bangunan/output/share_service.dart';
import 'package:struk_bangunan/state/pencadang.dart';

import '../bantuan_basisdata.dart';

class _Siap {
  final Database db;
  final Pencadang pencadang;
  final String Function() jalurTerakhir;

  _Siap(this.db, this.pencadang, this.jalurTerakhir);
}

Future<_Siap> _pasang(Directory folder) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  final prefs = await SharedPreferences.getInstance();

  String? jalur;
  final pencadang = Pencadang(
    BackupService(
      db,
      ProfilRepository(prefs),
      PengaturanKeluaranRepository(prefs),
    ),
    ShareService(
      BerkasSementara(Directory(p.join(folder.path, 'struk'))),
      kirim: (berkas, _) async => jalur = berkas,
    ),
  );
  return _Siap(db, pencadang, () => jalur!);
}

void main() {
  test('cadangkan membagikan berkas JSON bernama tanggal hari ini', () async {
    final folder = Directory.systemTemp.createTempSync('pencadang');
    addTearDown(() => folder.deleteSync(recursive: true));
    final siap = await _pasang(folder);
    addTearDown(siap.db.close);

    final nama = await siap.pencadang.cadangkan(DateTime(2026, 9, 19));

    expect(nama, 'strukbangunan-backup-20260919.json');
    expect(
      p.basename(siap.jalurTerakhir()),
      'strukbangunan-backup-20260919.json',
    );
  });

  test('isi cadangan memuat transaksi yang sudah tersimpan', () async {
    final folder = Directory.systemTemp.createTempSync('pencadang');
    addTearDown(() => folder.deleteSync(recursive: true));
    final siap = await _pasang(folder);
    addTearDown(siap.db.close);

    await TransaksiRepository(siap.db).simpan(
      items: [
        ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
      ],
      waktu: DateTime(2026, 9, 19, 10, 0),
    );

    await siap.pencadang.cadangkan(DateTime(2026, 9, 19));

    final isi = await File(siap.jalurTerakhir()).readAsString();
    expect(isi, contains('Semen'));
  });
}
