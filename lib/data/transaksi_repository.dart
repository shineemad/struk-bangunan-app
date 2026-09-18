import 'package:sqflite/sqflite.dart';

import '../domain/item_belanja.dart';
import '../domain/transaksi.dart';
import 'basisdata.dart';

class RekapHarian {
  final int jumlahNota;
  final int totalRupiah;

  const RekapHarian({required this.jumlahNota, required this.totalRupiah});
}

class TransaksiRepository {
  final Database _db;

  TransaksiRepository(this._db);

  /// Menyimpan nota dan mengembalikannya lengkap dengan nomor nota yang baru
  /// dipesan. Nota yang sudah tersimpan tidak pernah diubah lagi.
  ///
  /// Nomor dipesan di dalam transaksi yang sama dengan penyisipan barisnya,
  /// sehingga nota yang gagal tersimpan tidak meninggalkan lubang di
  /// penomoran.
  Future<Transaksi> simpan({
    required List<ItemBelanja> items,
    required DateTime waktu,
    int? bayar,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'Nota harus punya sekurangnya satu item',
      );
    }

    return _db.transaction((txn) async {
      final nota = Transaksi(
        nomorNota: await ambilNomorNotaBerikutnyaDalam(txn),
        waktu: waktu,
        items: items,
        bayar: bayar,
      );

      final id = await txn.insert('transaksi', {
        'nomor_nota': nota.nomorNota,
        'waktu_ms': nota.waktu.millisecondsSinceEpoch,
        'total': nota.total,
        'bayar': nota.bayar,
        'kembali': nota.kembali,
      });

      for (var i = 0; i < nota.items.length; i++) {
        final item = nota.items[i];
        await txn.insert('item', {
          'transaksi_id': id,
          'nama': item.nama,
          'qty': item.qty,
          'satuan': item.satuan,
          'harga_satuan': item.hargaSatuan,
          'subtotal': item.subtotal,
          'urutan': i,
        });
      }

      return nota;
    });
  }

  Future<List<Transaksi>> terbaru({int batas = 50}) async {
    final baris = await _db.query(
      'transaksi',
      orderBy: 'waktu_ms DESC, id DESC',
      limit: batas,
    );
    return [for (final b in baris) await _rakit(b)];
  }

  Future<Transaksi?> ambil(String nomorNota) async {
    final baris = await _db.query(
      'transaksi',
      where: 'nomor_nota = ?',
      whereArgs: [nomorNota],
      limit: 1,
    );
    if (baris.isEmpty) return null;
    return _rakit(baris.first);
  }

  Future<RekapHarian> rekap(DateTime hari) async {
    final awal = DateTime(hari.year, hari.month, hari.day);
    final akhir = awal.add(const Duration(days: 1));

    final hasil = await _db.rawQuery(
      'SELECT COUNT(*) AS jumlah, COALESCE(SUM(total), 0) AS total '
      'FROM transaksi WHERE waktu_ms >= ? AND waktu_ms < ?',
      [awal.millisecondsSinceEpoch, akhir.millisecondsSinceEpoch],
    );

    return RekapHarian(
      jumlahNota: (hasil.first['jumlah'] as int?) ?? 0,
      totalRupiah: (hasil.first['total'] as int?) ?? 0,
    );
  }

  Future<Transaksi> _rakit(Map<String, Object?> baris) async {
    final barisItem = await _db.query(
      'item',
      where: 'transaksi_id = ?',
      whereArgs: [baris['id']],
      orderBy: 'urutan ASC',
    );

    return Transaksi(
      nomorNota: baris['nomor_nota'] as String,
      waktu: DateTime.fromMillisecondsSinceEpoch(baris['waktu_ms'] as int),
      bayar: baris['bayar'] as int?,
      items: [
        for (final i in barisItem)
          ItemBelanja(
            nama: i['nama'] as String,
            qty: (i['qty'] as num).toDouble(),
            satuan: i['satuan'] as String,
            hargaSatuan: i['harga_satuan'] as int,
          ),
      ],
    );
  }
}
