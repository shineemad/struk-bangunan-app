import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';

import '../bantuan_basisdata.dart';

ItemBelanja _item(String nama, double qty, int harga) =>
    ItemBelanja(nama: nama, qty: qty, satuan: 'sak', hargaSatuan: harga);

Future<(Database, TransaksiRepository)> _siap() async {
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  return (db, TransaksiRepository(db));
}

void main() {
  test('menyimpan nota beserta itemnya dan memberi nomor nota', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final nota = await repo.simpan(
      items: [_item('Semen', 3, 65000), _item('Paku', 2, 20000)],
      waktu: DateTime(2026, 9, 17, 14, 30),
      bayar: 300000,
    );

    expect(nota.nomorNota, '0001');
    expect(nota.total, 235000);
    expect(nota.kembali, 65000);
    expect(nota.items, hasLength(2));
  });

  test('nomor nota tidak pernah terpakai dua kali', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final nomor = <String>[];
    for (var i = 0; i < 10; i++) {
      final nota = await repo.simpan(
        items: [_item('Semen', 1, 65000)],
        waktu: DateTime(2026, 9, 17, 9, i),
      );
      nomor.add(nota.nomorNota);
    }

    expect(nomor.toSet(), hasLength(10));
    expect(nomor.first, '0001');
    expect(nomor.last, '0010');
  });

  test('nota yang diambil kembali identik dengan yang disimpan', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final asli = await repo.simpan(
      items: [
        _item('Semen Tiga Roda', 3, 65000),
        ItemBelanja(
          nama: 'Pasir',
          qty: 1.5,
          satuan: 'rit',
          hargaSatuan: 850000,
        ),
      ],
      waktu: DateTime(2026, 9, 17, 14, 30),
      bayar: 2000000,
    );

    final hasil = (await repo.ambil(asli.nomorNota))!;

    expect(hasil.nomorNota, asli.nomorNota);
    expect(hasil.waktu, asli.waktu);
    expect(hasil.bayar, 2000000);
    expect(hasil.total, asli.total);
    expect(hasil.items.map((i) => i.nama), ['Semen Tiga Roda', 'Pasir']);
    expect(hasil.items[1].qty, 1.5);
    expect(hasil.items[1].subtotal, asli.items[1].subtotal);
  });

  test('urutan item dipertahankan saat dimuat ulang', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final asli = await repo.simpan(
      items: [
        _item('Pertama', 1, 1000),
        _item('Kedua', 1, 2000),
        _item('Ketiga', 1, 3000),
      ],
      waktu: DateTime(2026, 9, 17),
    );

    final hasil = (await repo.ambil(asli.nomorNota))!;
    expect(hasil.items.map((i) => i.nama), ['Pertama', 'Kedua', 'Ketiga']);
  });

  test('nomor nota yang tidak ada mengembalikan null', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    expect(await repo.ambil('9999'), isNull);
  });

  test('terbaru mengurutkan dari yang paling akhir', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.simpan(
      items: [_item('A', 1, 1000)],
      waktu: DateTime(2026, 9, 17, 8),
    );
    await repo.simpan(
      items: [_item('B', 1, 1000)],
      waktu: DateTime(2026, 9, 17, 10),
    );
    await repo.simpan(
      items: [_item('C', 1, 1000)],
      waktu: DateTime(2026, 9, 17, 9),
    );

    final hasil = await repo.terbaru();
    expect(hasil.map((n) => n.items.first.nama), ['B', 'C', 'A']);
  });

  test('terbaru menghormati batas jumlah', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    for (var i = 0; i < 5; i++) {
      await repo.simpan(
        items: [_item('Semen', 1, 1000)],
        waktu: DateTime(2026, 9, 17, 8, i),
      );
    }

    expect(await repo.terbaru(batas: 2), hasLength(2));
  });

  test('rekap harian hanya menghitung nota pada hari itu', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    await repo.simpan(
      items: [_item('Semen', 1, 100000)],
      waktu: DateTime(2026, 9, 16, 23, 59),
    );
    await repo.simpan(
      items: [_item('Semen', 1, 200000)],
      waktu: DateTime(2026, 9, 17, 0, 0),
    );
    await repo.simpan(
      items: [_item('Semen', 1, 300000)],
      waktu: DateTime(2026, 9, 17, 23, 59),
    );
    await repo.simpan(
      items: [_item('Semen', 1, 400000)],
      waktu: DateTime(2026, 9, 18, 0, 0),
    );

    final rekap = await repo.rekap(DateTime(2026, 9, 17, 13));
    expect(rekap.jumlahNota, 2);
    expect(rekap.totalRupiah, 500000);
  });

  test('rekap hari tanpa transaksi bernilai nol, bukan null', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    final rekap = await repo.rekap(DateTime(2026, 9, 17));
    expect(rekap.jumlahNota, 0);
    expect(rekap.totalRupiah, 0);
  });

  test(
    'nota tanpa uang bayar menyimpan bayar dan kembali sebagai null',
    () async {
      final (db, repo) = await _siap();
      addTearDown(db.close);

      final nota = await repo.simpan(
        items: [_item('Semen', 1, 65000)],
        waktu: DateTime(2026, 9, 17),
      );

      final hasil = (await repo.ambil(nota.nomorNota))!;
      expect(hasil.bayar, isNull);
      expect(hasil.kembali, isNull);
    },
  );

  test('nota yang gagal tersimpan tidak membakar nomor nota', () async {
    final (db, repo) = await _siap();
    addTearDown(db.close);

    // Baris ini menyerobot '0001', sehingga penyisipan di dalam simpan()
    // melanggar UNIQUE dan seluruh transaksinya dibatalkan.
    await db.insert('transaksi', {
      'nomor_nota': '0001',
      'waktu_ms': 1000,
      'total': 1000,
    });

    await expectLater(
      repo.simpan(
        items: [_item('Semen', 1, 65000)],
        waktu: DateTime(2026, 9, 17),
      ),
      throwsA(isA<DatabaseException>()),
    );

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris.first['nilai'], '1');
  });
}
