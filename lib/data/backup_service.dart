import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/profil_toko.dart';
import 'profil_repository.dart';

const int versiBackup = 1;

class BackupRusak implements Exception {
  final String pesan;

  const BackupRusak(this.pesan);

  @override
  String toString() => pesan;
}

/// Cadangkan seluruh data toko ke satu berkas JSON, dan pulihkan dengan
/// menimpa — bukan menggabungkan, karena penggabungan bisa menghasilkan nomor
/// nota ganda.
class BackupService {
  final Database _db;
  final ProfilRepository _profil;

  BackupService(this._db, this._profil);

  Future<String> ekspor() async {
    final profil = await _profil.muat();
    final meta = await _db.query('meta');

    return jsonEncode({
      'versi': versiBackup,
      'dibuat_ms': DateTime.now().millisecondsSinceEpoch,
      'profil': profil == null ? null : _profilKePeta(profil),
      'meta': {
        for (final b in meta) b['kunci'] as String: b['nilai'] as String,
      },
      'transaksi': await _db.query('transaksi', orderBy: 'id ASC'),
      'item': await _db.query('item', orderBy: 'id ASC'),
      'favorit': await _db.query('favorit', orderBy: 'id ASC'),
    });
  }

  /// Validasi selesai sepenuhnya sebelum satu baris pun dihapus, sehingga
  /// berkas yang cacat tidak pernah merusak data yang sedang dipakai.
  Future<void> impor(String teks) async {
    final data = _bacaJson(teks);
    final transaksi = _ambilDaftar(data, 'transaksi');
    final item = _ambilDaftar(data, 'item');
    final favorit = _ambilDaftar(data, 'favorit');

    // Bagian yang hilang boleh dianggap kosong, kecuali `meta`: ia memuat
    // pencacah nomor nota, dan mengosongkannya membuat nota berikutnya gagal
    // terbit sama sekali.
    final meta = data['meta'];
    if (meta is! Map) {
      throw const BackupRusak('Berkas cadangan tidak memuat bagian "meta".');
    }

    _wajib(transaksi, {'nomor_nota': String, 'waktu_ms': int, 'total': int});
    _wajib(item, {
      'transaksi_id': int,
      'nama': String,
      'qty': num,
      'satuan': String,
      'harga_satuan': int,
      'subtotal': int,
      'urutan': int,
    });
    _wajib(favorit, {
      'nama': String,
      'satuan_terakhir': String,
      'jumlah_pakai': int,
      'terakhir_dipakai_ms': int,
      'bawaan': int,
      'disembunyikan': int,
    });

    // Profil dirakit sebelum transaksi dibuka. Bila dikerjakan setelahnya,
    // kolom yang bertipe salah meledak sebagai TypeError telanjang setelah
    // basis data terlanjur ditimpa — galat yang tidak akan tertangkap
    // pemanggil yang menunggu BackupRusak.
    final profil = _bacaProfil(data['profil']);

    await _db.transaction((txn) async {
      await txn.delete('item');
      await txn.delete('transaksi');
      await txn.delete('favorit');
      await txn.delete('meta');

      for (final baris in transaksi) {
        await txn.insert('transaksi', Map<String, Object?>.from(baris));
      }
      for (final baris in item) {
        await txn.insert('item', Map<String, Object?>.from(baris));
      }
      for (final baris in favorit) {
        await txn.insert('favorit', Map<String, Object?>.from(baris));
      }

      for (final entri in meta.entries) {
        await txn.insert('meta', {
          'kunci': entri.key.toString(),
          'nilai': entri.value.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    if (profil != null) {
      await _profil.simpan(profil);
    }
  }

  Map<String, Object?> _bacaJson(String teks) {
    Object? mentah;
    try {
      mentah = jsonDecode(teks);
    } on FormatException {
      throw const BackupRusak('Berkas ini bukan berkas cadangan yang sah.');
    }
    if (mentah is! Map<String, Object?>) {
      throw const BackupRusak('Isi berkas cadangan tidak dikenali.');
    }
    final versi = mentah['versi'];
    if (versi is! int) {
      throw const BackupRusak('Berkas cadangan tidak mencantumkan versi.');
    }
    if (versi > versiBackup) {
      throw const BackupRusak(
        'Berkas ini dibuat aplikasi versi lebih baru. Perbarui aplikasi dulu.',
      );
    }
    return mentah;
  }

  List<Map<Object?, Object?>> _ambilDaftar(
    Map<String, Object?> data,
    String kunci,
  ) {
    final nilai = data[kunci];
    if (nilai == null) return const [];
    if (nilai is! List) {
      throw BackupRusak('Bagian "$kunci" pada berkas cadangan rusak.');
    }
    return [
      for (final baris in nilai)
        if (baris is Map<Object?, Object?>)
          baris
        else
          throw BackupRusak('Bagian "$kunci" pada berkas cadangan rusak.'),
    ];
  }

  void _wajib(List<Map<Object?, Object?>> baris, Map<String, Type> kolom) {
    for (final b in baris) {
      for (final entri in kolom.entries) {
        final nilai = b[entri.key];
        final cocok = switch (entri.value) {
          const (String) => nilai is String,
          const (int) => nilai is int,
          const (num) => nilai is num,
          _ => false,
        };
        if (!cocok) {
          throw BackupRusak(
            'Kolom "${entri.key}" pada berkas cadangan tidak sesuai.',
          );
        }
      }
    }
  }

  Map<String, Object?> _profilKePeta(ProfilToko p) => {
    'nama_toko': p.namaToko,
    'alamat_toko': p.alamat,
    'nohp_toko': p.noHp,
    'catatan_toko': p.catatan,
    'nama_kasir': p.namaKasir,
    'lebar_kertas': p.lebarKertas,
  };

  ProfilToko _petaKeProfil(Map<Object?, Object?> p) => ProfilToko(
    namaToko: p['nama_toko'] as String? ?? '',
    alamat: p['alamat_toko'] as String? ?? '',
    noHp: p['nohp_toko'] as String? ?? '',
    catatan: p['catatan_toko'] as String? ?? '',
    namaKasir: p['nama_kasir'] as String? ?? '',
    lebarKertas: p['lebar_kertas'] as int? ?? 58,
  );

  /// Null berarti berkas cadangan memang tidak memuat profil — itu sah, dan
  /// profil yang sekarang dibiarkan apa adanya.
  ProfilToko? _bacaProfil(Object? data) {
    if (data == null) return null;
    if (data is! Map<Object?, Object?>) {
      throw const BackupRusak('Bagian "profil" pada berkas cadangan rusak.');
    }
    try {
      return _petaKeProfil(data);
    } on TypeError {
      // Cast yang gagal diterjemahkan menjadi galat domain, bukan ditelan:
      // pemanggil menunggu BackupRusak, dan ini masih di sisi validasi.
      throw const BackupRusak('Bagian "profil" pada berkas cadangan rusak.');
    }
  }
}
