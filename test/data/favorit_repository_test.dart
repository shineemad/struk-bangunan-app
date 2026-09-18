import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/favorit_bawaan.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';

import '../bantuan_basisdata.dart';

Future<(Database, FavoritRepository)> _siap() async {
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  return (db, FavoritRepository(db));
}

void main() {
  test('daftar bawaan tidak kosong dan tidak punya nama kembar', () {
    expect(favoritBawaan, isNotEmpty);
    final nama = favoritBawaan.map((f) => f.nama.toLowerCase()).toList();
    expect(nama.toSet(), hasLength(nama.length));
  });

  test('bawaan terisi saat basis data masih kosong', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.isiBawaanBilaKosong();
    final hasil = await repo.daftar(batas: 1000);

    expect(hasil, hasLength(favoritBawaan.length));
    expect(hasil.every((f) => f.bawaan), isTrue);
  });

  test('bawaan tidak diisi ulang bila sudah ada isinya', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.isiBawaanBilaKosong();
    await repo.catatPemakaian('Bahan Karangan', 'pcs', DateTime(2026, 9, 17));
    await repo.isiBawaanBilaKosong();

    final hasil = await repo.daftar(batas: 1000);
    expect(hasil, hasLength(favoritBawaan.length + 1));
  });

  test('nama baru masuk daftar saat dipakai', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Kawat Bendrat', 'kg', DateTime(2026, 9, 17));
    final hasil = await repo.daftar();

    expect(hasil.map((f) => f.nama), contains('Kawat Bendrat'));
    expect(hasil.first.satuanTerakhir, 'kg');
    expect(hasil.first.bawaan, isFalse);
  });

  test(
    'nama yang sama dengan beda besar-kecil huruf tidak digandakan',
    () async {
      final (db, repo) = await _siap();
      addTearDown(db.close);

      await repo.catatPemakaian('Semen Gresik', 'sak', DateTime(2026, 9, 17));
      await repo.catatPemakaian('semen gresik', 'sak', DateTime(2026, 9, 17));

      final hasil = await repo.daftar(batas: 1000);
      final cocok = hasil.where((f) => f.nama.toLowerCase() == 'semen gresik');
      expect(cocok, hasLength(1));
      expect(cocok.first.jumlahPakai, 2);
    },
  );

  test('yang paling sering dipakai naik ke atas', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Jarang', 'pcs', DateTime(2026, 9, 17, 8));
    for (var i = 0; i < 5; i++) {
      await repo.catatPemakaian('Sering', 'sak', DateTime(2026, 9, 17, 9));
    }

    final hasil = await repo.daftar();
    expect(hasil.first.nama, 'Sering');
    expect(hasil.first.jumlahPakai, 5);
  });

  test('satuan terakhir diperbarui tiap pemakaian', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Pasir', 'kubik', DateTime(2026, 9, 17, 8));
    await repo.catatPemakaian('Pasir', 'rit', DateTime(2026, 9, 17, 9));

    final hasil = await repo.daftar();
    expect(hasil.first.satuanTerakhir, 'rit');
  });

  test('yang disembunyikan tidak muncul di daftar', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
    await repo.sembunyikan('Semen');

    expect(await repo.daftar(), isEmpty);
  });

  test('menyembunyikan tidak menghapus datanya', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
    await repo.sembunyikan('Semen');
    await repo.munculkanSemua();

    final hasil = await repo.daftar();
    expect(hasil.first.nama, 'Semen');
    expect(hasil.first.jumlahPakai, 1);
  });

  test('daftar menghormati batas jumlah', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.isiBawaanBilaKosong();
    expect(await repo.daftar(batas: 5), hasLength(5));
  });

  test('nama kosong atau hanya spasi tidak dicatat', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.catatPemakaian('   ', 'sak', DateTime(2026, 9, 17));

    expect(await repo.daftar(), isEmpty);
  });
}
