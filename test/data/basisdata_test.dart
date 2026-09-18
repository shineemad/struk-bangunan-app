import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/basisdata.dart';

import '../bantuan_basisdata.dart';

void main() {
  test('skema membuat keempat tabel', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    final tabel = (await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    )).map((b) => b['name'] as String).toSet();

    expect(tabel, containsAll(['meta', 'transaksi', 'item', 'favorit']));
  });

  test('versi skema tercatat di meta', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['versi_skema'],
    );
    expect(baris.first['nilai'], versiSkema.toString());
  });

  test('nomor nota mulai dari 0001 dan naik satu per satu', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    expect(await ambilNomorNotaBerikutnya(db), '0001');
    expect(await ambilNomorNotaBerikutnya(db), '0002');
    expect(await ambilNomorNotaBerikutnya(db), '0003');
  });

  test('nomor nota melewati empat digit tetap utuh', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);
    await db.update(
      'meta',
      {'nilai': '9999'},
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );

    expect(await ambilNomorNotaBerikutnya(db), '9999');
    expect(await ambilNomorNotaBerikutnya(db), '10000');
  });

  test(
    'nomor nota tidak pernah terpakai dua kali meski dipanggil serentak',
    () async {
      final db = await bukaBasisdataUji();
      addTearDown(db.close);
      await siapkanSkema(db);

      // Semua pemanggilan dimulai sebelum satu pun ditunggu, sehingga baca dan
      // tulis pencacah benar-benar berebut.
      final hasil = await Future.wait([
        for (var i = 0; i < 50; i++) ambilNomorNotaBerikutnya(db),
      ]);

      expect(hasil.toSet(), hasLength(50));
    },
  );

  test('menjalankan skema dua kali tidak melempar', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);
    await siapkanSkema(db);

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris, hasLength(1));
  });

  test('menjalankan skema ulang tidak mereset pencacah nota', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);

    expect(await ambilNomorNotaBerikutnya(db), '0001');
    await siapkanSkema(db);

    // Bila baris pencacah memakai ConflictAlgorithm.replace, angka ini kembali
    // ke '0001' dan aplikasi menerbitkan ulang nomor yang sudah tercetak.
    // Menghitung jumlah baris saja tidak menangkapnya.
    expect(await ambilNomorNotaBerikutnya(db), '0002');
  });

  test(
    'nomor nota bisa diambil dari dalam transaksi yang sudah terbuka',
    () async {
      final db = await bukaBasisdataUji();
      addTearDown(db.close);
      await siapkanSkema(db);

      final hasil = await db.transaction((txn) async {
        return [
          await ambilNomorNotaBerikutnyaDalam(txn),
          await ambilNomorNotaBerikutnyaDalam(txn),
        ];
      });

      expect(hasil, ['0001', '0002']);
    },
  );

  test('menghapus transaksi ikut menghapus itemnya', () async {
    final db = await bukaBasisdataUji();
    addTearDown(db.close);
    await siapkanSkema(db);
    await db.execute('PRAGMA foreign_keys = ON');

    final id = await db.insert('transaksi', {
      'nomor_nota': '0001',
      'waktu_ms': 1000,
      'total': 5000,
    });
    await db.insert('item', {
      'transaksi_id': id,
      'nama': 'Semen',
      'qty': 1.0,
      'satuan': 'sak',
      'harga_satuan': 5000,
      'subtotal': 5000,
      'urutan': 0,
    });

    await db.delete('transaksi', where: 'id = ?', whereArgs: [id]);
    expect(await db.query('item'), isEmpty);
  });

  test('basis data versi lama tetap terbuka dan datanya utuh', () async {
    sqfliteFfiInit();
    final folder = await Directory.systemTemp.createTemp('strukbangunan_uji');
    addTearDown(() => folder.delete(recursive: true));
    final jalur = p.join(folder.path, 'coba.db');

    final lama = await databaseFactoryFfi.openDatabase(
      jalur,
      options: opsiBasisdata(versi: 1),
    );
    await lama.insert('transaksi', {
      'nomor_nota': '0001',
      'waktu_ms': 1000,
      'total': 5000,
    });
    await lama.close();

    // Tanpa onUpgrade, membuka berkas yang sama dengan versi lebih tinggi
    // melempar dan pengguna kehilangan seluruh datanya.
    final baru = await databaseFactoryFfi.openDatabase(
      jalur,
      options: opsiBasisdata(versi: versiSkema + 1),
    );
    addTearDown(baru.close);

    expect(await baru.query('transaksi'), hasLength(1));
  });
}
