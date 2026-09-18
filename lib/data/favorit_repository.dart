import 'package:sqflite/sqflite.dart';

import 'favorit_bawaan.dart';

class BahanFavorit {
  final String nama;
  final String satuanTerakhir;
  final int jumlahPakai;
  final bool bawaan;

  const BahanFavorit({
    required this.nama,
    required this.satuanTerakhir,
    required this.jumlahPakai,
    required this.bawaan,
  });
}

/// Daftar bahan yang sering dijual. Urutannya ditentukan kebiasaan toko itu
/// sendiri, bukan oleh kami.
class FavoritRepository {
  final Database _db;

  FavoritRepository(this._db);

  Future<void> isiBawaanBilaKosong() async {
    final jumlah =
        Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM favorit'),
        ) ??
        0;
    if (jumlah > 0) return;

    final batch = _db.batch();
    for (final bahan in favoritBawaan) {
      batch.insert('favorit', {
        'nama': bahan.nama,
        'satuan_terakhir': bahan.satuan,
        'jumlah_pakai': 0,
        'terakhir_dipakai_ms': 0,
        'bawaan': 1,
        'disembunyikan': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<BahanFavorit>> daftar({int batas = 40}) async {
    final baris = await _db.query(
      'favorit',
      where: 'disembunyikan = 0',
      orderBy: 'jumlah_pakai DESC, terakhir_dipakai_ms DESC, nama ASC',
      limit: batas,
    );
    return [
      for (final b in baris)
        BahanFavorit(
          nama: b['nama'] as String,
          satuanTerakhir: b['satuan_terakhir'] as String,
          jumlahPakai: b['jumlah_pakai'] as int,
          bawaan: (b['bawaan'] as int) == 1,
        ),
    ];
  }

  /// Menaikkan hitungan pakai dan memperbarui satuan terakhir. Nama yang
  /// belum terdaftar ditambahkan sendiri — itulah cara daftar ini belajar.
  Future<void> catatPemakaian(
    String nama,
    String satuan,
    DateTime waktu,
  ) async {
    final namaRapi = nama.trim();
    if (namaRapi.isEmpty) return;

    await _db.transaction((txn) async {
      final terubah = await txn.rawUpdate(
        'UPDATE favorit SET jumlah_pakai = jumlah_pakai + 1, '
        'satuan_terakhir = ?, terakhir_dipakai_ms = ? '
        'WHERE nama = ? COLLATE NOCASE',
        [satuan.trim(), waktu.millisecondsSinceEpoch, namaRapi],
      );
      if (terubah > 0) return;

      await txn.insert('favorit', {
        'nama': namaRapi,
        'satuan_terakhir': satuan.trim(),
        'jumlah_pakai': 1,
        'terakhir_dipakai_ms': waktu.millisecondsSinceEpoch,
        'bawaan': 0,
        'disembunyikan': 0,
      });
    });
  }

  Future<void> sembunyikan(String nama) async {
    await _db.rawUpdate(
      'UPDATE favorit SET disembunyikan = 1 WHERE nama = ? COLLATE NOCASE',
      [nama.trim()],
    );
  }

  Future<void> munculkanSemua() async {
    await _db.update('favorit', {'disembunyikan': 0});
  }
}
