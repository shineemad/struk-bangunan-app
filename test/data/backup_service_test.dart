import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:struk_bangunan/data/backup_service.dart';
import 'package:struk_bangunan/data/basisdata.dart';
import 'package:struk_bangunan/data/favorit_repository.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/data/profil_repository.dart';
import 'package:struk_bangunan/data/transaksi_repository.dart';
import 'package:struk_bangunan/domain/item_belanja.dart';
import 'package:struk_bangunan/domain/profil_toko.dart';

import '../bantuan_basisdata.dart';

Future<
  (Database, BackupService, ProfilRepository, PengaturanKeluaranRepository)
>
_siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final db = await bukaBasisdataUji();
  await siapkanSkema(db);
  final prefs = await SharedPreferences.getInstance();
  final profil = ProfilRepository(prefs);
  final pengaturan = PengaturanKeluaranRepository(prefs);
  return (db, BackupService(db, profil, pengaturan), profil, pengaturan);
}

Future<void> _isiContoh(Database db, ProfilRepository profil) async {
  await profil.simpan(
    const ProfilToko(
      namaToko: 'TB. SINAR BANGUNAN',
      alamat: 'Jl. Raya Merdeka No. 45',
      lebarKertas: 80,
    ),
  );
  final transaksi = TransaksiRepository(db);
  await transaksi.simpan(
    items: [
      ItemBelanja(nama: 'Semen', qty: 3, satuan: 'sak', hargaSatuan: 65000),
    ],
    waktu: DateTime(2026, 9, 17, 14, 30),
    bayar: 200000,
  );
  await FavoritRepository(
    db,
  ).catatPemakaian('Semen', 'sak', DateTime(2026, 9, 17));
}

void main() {
  test('ekspor menghasilkan JSON bernomor versi', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final data = jsonDecode(await backup.ekspor()) as Map<String, Object?>;

    expect(data['versi'], versiBackup);
    expect(data['profil'], isA<Map<String, Object?>>());
    expect(data['transaksi'], isA<List<Object?>>());
    expect(data['favorit'], isA<List<Object?>>());
    expect(data['meta'], isA<Map<String, Object?>>());
  });

  test('ekspor lalu impor menghasilkan data yang sama', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final berkas = await backup.ekspor();
    await backup.impor(berkas);

    final nota = await TransaksiRepository(db).ambil('0001');
    expect(nota, isNotNull);
    expect(nota!.total, 195000);
    expect(nota.bayar, 200000);
    expect(nota.items.single.nama, 'Semen');

    final hasilProfil = (await profil.muat())!;
    expect(hasilProfil.namaToko, 'TB. SINAR BANGUNAN');
    expect(hasilProfil.lebarKertas, 80);

    final favorit = await FavoritRepository(db).daftar();
    expect(favorit.map((f) => f.nama), contains('Semen'));
  });

  test('impor menimpa, bukan menggabungkan', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    final berkas = await backup.ekspor();

    await TransaksiRepository(db).simpan(
      items: [
        ItemBelanja(nama: 'Paku', qty: 1, satuan: 'kg', hargaSatuan: 1000),
      ],
      waktu: DateTime(2026, 9, 18),
    );
    expect(await TransaksiRepository(db).terbaru(), hasLength(2));

    await backup.impor(berkas);
    expect(await TransaksiRepository(db).terbaru(), hasLength(1));
  });

  test('nomor nota berikutnya ikut terbawa', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final berkas = await backup.ekspor();
    await backup.impor(berkas);

    final nota = await TransaksiRepository(db).simpan(
      items: [
        ItemBelanja(nama: 'Paku', qty: 1, satuan: 'kg', hargaSatuan: 1000),
      ],
      waktu: DateTime(2026, 9, 18),
    );
    expect(nota.nomorNota, '0002');
  });

  test('teks yang bukan JSON ditolak', () async {
    final (db, backup, _, _) = await _siap();
    addTearDown(db.close);

    expect(() => backup.impor('bukan json'), throwsA(isA<BackupRusak>()));
  });

  test('JSON tanpa versi ditolak', () async {
    final (db, backup, _, _) = await _siap();
    addTearDown(db.close);

    expect(
      () => backup.impor(jsonEncode({'profil': {}, 'transaksi': []})),
      throwsA(isA<BackupRusak>()),
    );
  });

  test('versi yang lebih baru ditolak', () async {
    final (db, backup, _, _) = await _siap();
    addTearDown(db.close);

    expect(
      () => backup.impor(jsonEncode({'versi': versiBackup + 1})),
      throwsA(isA<BackupRusak>()),
    );
  });

  test('data lama tetap utuh bila berkas ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    await expectLater(
      backup.impor('berkas rusak'),
      throwsA(isA<BackupRusak>()),
    );

    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect((await profil.muat())!.namaToko, 'TB. SINAR BANGUNAN');
  });

  test('berkas dengan tipe kolom yang salah ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'profil': {'nama_toko': 'TB. X'},
      'meta': {'nomor_nota_berikutnya': '1'},
      'favorit': [],
      'transaksi': [
        {'nomor_nota': 123, 'waktu_ms': 'kemarin', 'total': 'banyak'},
      ],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));

    // Penolakan ini terjadi di tahap _wajib, bukan di pembacaan JSON, jadi ia
    // menjaga janji utama layanan ini: validasi selesai penuh sebelum satu
    // baris pun dihapus.
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect((await profil.muat())!.namaToko, 'TB. SINAR BANGUNAN');
  });

  test('baris favorit dengan tipe kolom yang salah ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {'nomor_nota_berikutnya': '1'},
      'transaksi': [],
      'item': [],
      'favorit': [
        {
          'nama': 'Semen',
          'satuan_terakhir': 'sak',
          'jumlah_pakai': 'banyak',
          'terakhir_dipakai_ms': 0,
          'bawaan': 0,
          'disembunyikan': 0,
        },
      ],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('profil dengan tipe kolom yang salah ditolak sebelum menimpa', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {'nomor_nota_berikutnya': '1'},
      'transaksi': [],
      'item': [],
      'favorit': [],
      'profil': {'nama_toko': 'TB. X', 'lebar_kertas': 'delapan puluh'},
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect((await profil.muat())!.namaToko, 'TB. SINAR BANGUNAN');
  });

  test('berkas tanpa bagian meta ditolak sebelum menghapus apa pun', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    await expectLater(
      backup.impor(
        jsonEncode({
          'versi': versiBackup,
          'transaksi': [],
          'item': [],
          'favorit': [],
        }),
      ),
      throwsA(isA<BackupRusak>()),
    );

    // Tanpa penjaga ini impor akan lulus, mengosongkan tabel meta, dan
    // pencacah nomor nota lenyap bersamanya.
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    final lanjut = await TransaksiRepository(db).simpan(
      items: [
        ItemBelanja(nama: 'Paku', qty: 1, satuan: 'kg', hargaSatuan: 1000),
      ],
      waktu: DateTime(2026, 9, 18),
    );
    expect(lanjut.nomorNota, '0002');
  });

  test('bagian meta kosong ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {},
      'transaksi': [],
      'item': [],
      'favorit': [],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('pencacah nomor nota yang bukan angka ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {'nomor_nota_berikutnya': 'abc'},
      'transaksi': [],
      'item': [],
      'favorit': [],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('nota tanpa item ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {'nomor_nota_berikutnya': '2'},
      'transaksi': [
        {'id': 1, 'nomor_nota': '0001', 'waktu_ms': 0, 'total': 10000},
      ],
      'item': [],
      'favorit': [],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('item yang menunjuk nota tak dikenal ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {'nomor_nota_berikutnya': '2'},
      'transaksi': [
        {'id': 1, 'nomor_nota': '0001', 'waktu_ms': 0, 'total': 10000},
      ],
      'item': [
        {
          'transaksi_id': 99,
          'nama': 'Semen',
          'qty': 1,
          'satuan': 'sak',
          'harga_satuan': 10000,
          'subtotal': 10000,
          'urutan': 0,
        },
      ],
      'favorit': [],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('item dengan kuantitas nol ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    final rusak = jsonEncode({
      'versi': versiBackup,
      'meta': {'nomor_nota_berikutnya': '2'},
      'transaksi': [
        {'id': 1, 'nomor_nota': '0001', 'waktu_ms': 0, 'total': 10000},
      ],
      'item': [
        {
          'transaksi_id': 1,
          'nama': 'Semen',
          'qty': 0,
          'satuan': 'sak',
          'harga_satuan': 10000,
          'subtotal': 0,
          'urutan': 0,
        },
      ],
      'favorit': [],
    });

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('berkas cadangan yang terlalu besar ditolak', () async {
    final (db, backup, profil, _) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);

    // Dibangun tanpa benar-benar menyusun JSON bermakna sebesar itu — hanya
    // untuk melewati batas ukuran sebelum jsonDecode sempat dipanggil.
    final rusak = 'x' * (16 * 1024 * 1024 + 1);

    await expectLater(backup.impor(rusak), throwsA(isA<BackupRusak>()));
    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
  });

  test('ekspor membawa pengaturan keluaran', () async {
    final (db, backup, profil, pengaturan) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    await pengaturan.simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.pdf,
        printerMac: '66:22:11:AA:BB:CC',
        printerNama: 'RPP02N',
      ),
    );

    final data = jsonDecode(await backup.ekspor()) as Map<String, Object?>;
    expect(data['versi'], 2);
    final keluaran = data['pengaturan']! as Map<String, Object?>;
    expect(keluaran['format_kiriman'], 'pdf');
    expect(keluaran['printer_terakhir_mac'], '66:22:11:AA:BB:CC');
    expect(keluaran['printer_terakhir_nama'], 'RPP02N');
  });

  test('impor memulihkan pengaturan keluaran', () async {
    final (db, backup, profil, pengaturan) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    await pengaturan.simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.pdf,
        printerMac: '66:22:11:AA:BB:CC',
        printerNama: 'RPP02N',
      ),
    );
    final berkas = await backup.ekspor();

    await pengaturan.simpan(const PengaturanKeluaran());
    await backup.impor(berkas);

    final hasil = await pengaturan.muat();
    expect(hasil.formatKiriman, FormatKiriman.pdf);
    expect(hasil.printerNama, 'RPP02N');
  });

  test('cadangan versi 1 tetap bisa dipulihkan', () async {
    final (db, backup, profil, pengaturan) = await _siap();
    addTearDown(db.close);
    await _isiContoh(db, profil);
    await pengaturan.simpan(
      const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf),
    );

    // Berkas versi 1 tidak punya bagian `pengaturan` sama sekali. Ia harus
    // diterima, dan pengaturan yang sedang dipakai tidak boleh ikut terhapus.
    final lama = jsonDecode(await backup.ekspor()) as Map<String, Object?>;
    lama['versi'] = 1;
    lama.remove('pengaturan');

    await backup.impor(jsonEncode(lama));

    expect(await TransaksiRepository(db).ambil('0001'), isNotNull);
    expect((await pengaturan.muat()).formatKiriman, FormatKiriman.pdf);
  });
}
