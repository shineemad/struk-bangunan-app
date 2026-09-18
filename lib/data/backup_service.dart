import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/profil_toko.dart';
import 'profil_repository.dart';

const int versiBackup = 1;

/// Batas ukuran berkas cadangan: 16 MiB dalam kode-unit, sesuai spec bagian 4
/// (berkas berasal dari luar aplikasi, jadi ukurannya harus dibatasi sebelum
/// diuraikan).
const int _batasUkuranBerkasCadangan = 16 * 1024 * 1024;

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
    if (teks.length > _batasUkuranBerkasCadangan) {
      throw const BackupRusak(
        'Berkas cadangan melebihi batas ukuran yang diizinkan.',
      );
    }

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
    final nomorNotaBerikutnya = int.tryParse(
      meta['nomor_nota_berikutnya']?.toString() ?? '',
    );
    if (nomorNotaBerikutnya == null || nomorNotaBerikutnya < 1) {
      throw const BackupRusak(
        'Berkas cadangan tidak memuat pencacah nomor nota yang sah.',
      );
    }

    _wajib(transaksi, {
      'id': int,
      'nomor_nota': String,
      'waktu_ms': int,
      'total': int,
    });
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
    _wajibItemSah(item);
    _wajibSetiapTransaksiPunyaItem(transaksi, item);

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

  /// Menegakkan invarian yang dituntut konstruktor [ItemBelanja] (kuantitas
  /// positif, nama tidak kosong) sebelum baris masuk transaksi, sehingga
  /// baris yang melanggarnya ditolak sebagai satu galat alih-alih menjatuhkan
  /// seluruh daftar riwayat saat dirakit ulang.
  void _wajibItemSah(List<Map<Object?, Object?>> item) {
    for (final b in item) {
      final qty = b['qty'] as num;
      if (qty <= 0) {
        throw const BackupRusak(
          'Kolom "qty" pada berkas cadangan harus lebih besar dari nol.',
        );
      }
      final nama = b['nama'] as String;
      if (nama.trim().isEmpty) {
        throw const BackupRusak(
          'Kolom "nama" pada berkas cadangan tidak boleh kosong.',
        );
      }
    }
  }

  /// Menegakkan bahwa setiap `item.transaksi_id` menunjuk nota yang benar-benar
  /// ikut dipulihkan, dan setiap nota punya sekurangnya satu barang — tanpa
  /// ini nota bisa pulih dengan total Rp 0 secara diam-diam.
  void _wajibSetiapTransaksiPunyaItem(
    List<Map<Object?, Object?>> transaksi,
    List<Map<Object?, Object?>> item,
  ) {
    final idTransaksi = transaksi.map((b) => b['id'] as int).toSet();
    final idPunyaItem = <int>{};
    for (final b in item) {
      final transaksiId = b['transaksi_id'] as int;
      if (!idTransaksi.contains(transaksiId)) {
        throw const BackupRusak(
          'Ada baris "item" yang menunjuk nota yang tidak ada di berkas cadangan.',
        );
      }
      idPunyaItem.add(transaksiId);
    }
    for (final id in idTransaksi) {
      if (!idPunyaItem.contains(id)) {
        throw const BackupRusak(
          'Ada nota pada berkas cadangan yang tidak punya satu pun barang.',
        );
      }
    }
  }

  Map<String, Object?> _profilKePeta(ProfilToko p) => {
    ProfilRepository.kunciNama: p.namaToko,
    ProfilRepository.kunciAlamat: p.alamat,
    ProfilRepository.kunciNoHp: p.noHp,
    ProfilRepository.kunciCatatan: p.catatan,
    ProfilRepository.kunciKasir: p.namaKasir,
    ProfilRepository.kunciLebar: p.lebarKertas,
  };

  ProfilToko _petaKeProfil(Map<Object?, Object?> p) => ProfilToko(
    namaToko: p[ProfilRepository.kunciNama] as String? ?? '',
    alamat: p[ProfilRepository.kunciAlamat] as String? ?? '',
    noHp: p[ProfilRepository.kunciNoHp] as String? ?? '',
    catatan: p[ProfilRepository.kunciCatatan] as String? ?? '',
    namaKasir: p[ProfilRepository.kunciKasir] as String? ?? '',
    lebarKertas: p[ProfilRepository.kunciLebar] as int? ?? 58,
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
