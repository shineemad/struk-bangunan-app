import 'package:sqflite/sqflite.dart';
import 'favorit_bawaan.dart';

class BahanFavorit {
  final String nama;
  final String satuanTerakhir;
  final int jumlahPakai;
  final bool bawaan;

  BahanFavorit({
    required this.nama,
    required this.satuanTerakhir,
    required this.jumlahPakai,
    required this.bawaan,
  });

  factory BahanFavorit.dariPetaDatabase(Map<String, dynamic> peta) =>
      BahanFavorit(
        nama: peta['nama'] as String,
        satuanTerakhir: peta['satuan_terakhir'] as String? ?? '',
        jumlahPakai: peta['jumlah_pakai'] as int? ?? 0,
        bawaan: (peta['bawaan'] as int? ?? 0) != 0,
      );
}

class FavoritRepository {
  final Database _db;

  FavoritRepository(this._db);

  /// Isi tabel dengan [favoritBawaan] jika masih kosong. Gunakan di saat
  /// pertama kali membuka aplikasi.
  Future<void> isiBawaanBilaKosong() async {
    final ada = await _db.query('favorit');
    if (ada.isNotEmpty) return;

    final batch = _db.batch();
    for (final f in favoritBawaan) {
      batch.insert('favorit', {
        'nama': f.nama,
        'satuan_terakhir': f.satuan,
        'jumlah_pakai': 0,
        'terakhir_dipakai_ms': 0,
        'bawaan': 1,
        'disembunyikan': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
  }

  /// Ambil daftar bahan favorit, diurutkan dari paling sering dipakai
  /// ke jarang, jika frekuensi sama maka dari paling baru ke tua, dan
  /// jika waktu sama maka alfabetik. Sembunyikan yang telah disembunyikan.
  Future<List<BahanFavorit>> daftar({int batas = 40}) async {
    final hasil = await _db.query(
      'favorit',
      where: 'disembunyikan = 0',
      orderBy:
          'jumlah_pakai DESC, terakhir_dipakai_ms DESC, nama COLLATE NOCASE ASC',
      limit: batas,
    );
    return hasil.map((r) => BahanFavorit.dariPetaDatabase(r)).toList();
  }

  /// Catat satu kali pemakaian nama bahan tersebut, dengan satuan dan waktu
  /// yang diberikan. Jika nama sudah ada (diabaikan besar-kecilnya), naikan
  /// jumlah_pakai dan perbarui satuan_terakhir dan terakhir_dipakai_ms.
  /// Kalau belum, sisipkan baris baru.
  Future<void> catatPemakaian(
    String nama,
    String satuan,
    DateTime waktu,
  ) async {
    return _db.transaction((txn) async {
      final ada = await txn.query(
        'favorit',
        where: 'UPPER(nama) = UPPER(?)',
        whereArgs: [nama],
      );
      if (ada.isNotEmpty) {
        await txn.update(
          'favorit',
          {
            'jumlah_pakai': (ada.first['jumlah_pakai'] as int) + 1,
            'satuan_terakhir': satuan,
            'terakhir_dipakai_ms': waktu.millisecondsSinceEpoch,
          },
          where: 'UPPER(nama) = UPPER(?)',
          whereArgs: [nama],
        );
      } else {
        await txn.insert('favorit', {
          'nama': nama,
          'satuan_terakhir': satuan,
          'jumlah_pakai': 1,
          'terakhir_dipakai_ms': waktu.millisecondsSinceEpoch,
          'bawaan': 0,
          'disembunyikan': 0,
        });
      }
    });
  }

  /// Sembunyikan satu bahan dari daftar favorit tanpa menghapusnya. Nama
  /// diabaikan besar-kecilnya.
  Future<void> sembunyikan(String nama) async {
    await _db.update(
      'favorit',
      {'disembunyikan': 1},
      where: 'UPPER(nama) = UPPER(?)',
      whereArgs: [nama],
    );
  }

  /// Munculkan kembali semua bahan yang disembunyikan.
  Future<void> munculkanSemua() async {
    await _db.update('favorit', {'disembunyikan': 0});
  }
}
