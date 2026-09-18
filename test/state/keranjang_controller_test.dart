import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/draf_repository.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/state/keranjang_controller.dart';

import '../bantuan_basisdata.dart';

ItemBelanja _semen({double qty = 3}) =>
    ItemBelanja(nama: 'Semen', qty: qty, satuan: 'sak', hargaSatuan: 65000);

Future<(Database, DrafRepository, KeranjangController)> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  addTearDown(db.close);
  final draf = DrafRepository(await SharedPreferences.getInstance());
  return (
    db,
    draf,
    KeranjangController(
      draf: draf,
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    ),
  );
}

void main() {
  test('menambah item memperbarui total dan memberi tahu pendengar', () async {
    final (_, _, keranjang) = await _siap();
    var pemberitahuan = 0;
    keranjang.addListener(() => pemberitahuan++);

    await keranjang.tambah(_semen());

    expect(keranjang.items, hasLength(1));
    expect(keranjang.total, 195000);
    expect(keranjang.kosong, isFalse);
    expect(pemberitahuan, 1);
  });

  test('item yang ditambahkan ikut tersimpan sebagai draf', () async {
    final (_, draf, keranjang) = await _siap();

    await keranjang.tambah(_semen());

    expect(await draf.muat(), hasLength(1));
  });

  test('draf dipulihkan saat aplikasi dibuka kembali', () async {
    final (db, draf, _) = await _siap();
    await draf.simpan([_semen()]);

    final lain = KeranjangController(
      draf: draf,
      transaksi: TransaksiRepository(db),
      favorit: FavoritRepository(db),
    );
    await lain.muatDraf();

    expect(lain.items.single.nama, 'Semen');
    expect(lain.total, 195000);
  });

  test('menghapus satu item menyisakan sisanya', () async {
    final (_, _, keranjang) = await _siap();
    await keranjang.tambah(_semen());
    await keranjang.tambah(
      ItemBelanja(nama: 'Pasir', qty: 1, satuan: 'rit', hargaSatuan: 850000),
    );

    await keranjang.hapusPada(0);

    expect(keranjang.items.single.nama, 'Pasir');
    expect(keranjang.total, 850000);
  });

  test('mengosongkan keranjang juga menghapus drafnya', () async {
    final (_, draf, keranjang) = await _siap();
    await keranjang.tambah(_semen());

    await keranjang.kosongkan();

    expect(keranjang.kosong, isTrue);
    expect(await draf.muat(), isEmpty);
  });

  test('menyimpan menghasilkan nota dan mengosongkan keranjang', () async {
    final (db, draf, keranjang) = await _siap();
    await keranjang.tambah(_semen());

    final nota = await keranjang.simpan(bayar: 200000);

    expect(nota.nomorNota, '0001');
    expect(nota.total, 195000);
    expect(nota.kembali, 5000);
    expect(keranjang.kosong, isTrue);
    expect(await draf.muat(), isEmpty);
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('menyimpan mencatat pemakaian favorit untuk setiap barang', () async {
    // `catatPemakaian` membuka transaksinya sendiri. Bila kelak ia dipanggil
    // dari dalam transaksi `simpan`, test ini tidak gagal — ia menggantung.
    final (db, _, keranjang) = await _siap();
    await keranjang.tambah(_semen());
    await keranjang.tambah(
      ItemBelanja(nama: 'Pasir', qty: 1, satuan: 'rit', hargaSatuan: 850000),
    );

    await keranjang.simpan();

    final favorit = await FavoritRepository(db).daftar();
    final nama = favorit.map((f) => f.nama).toList();
    expect(nama, containsAll(<String>['Semen', 'Pasir']));
  });

  test('keranjang kosong menolak disimpan tanpa memakai nomor nota', () async {
    final (db, _, keranjang) = await _siap();

    await expectLater(keranjang.simpan(), throwsArgumentError);

    final baris = await db.query(
      'meta',
      where: 'kunci = ?',
      whereArgs: ['nomor_nota_berikutnya'],
    );
    expect(baris.first['nilai'], '1');
  });
}
