import 'dart:convert';

import '../data/backup_service.dart';
import '../output/share_service.dart';

/// Menyusun cadangan data toko lalu membagikannya. Dipisah dari
/// `BackupService` supaya widget test bisa memakai pencadang palsu, persis
/// pola `PengirimStrukKontrak`.
abstract interface class PencadangKontrak {
  /// Mengembalikan nama berkas cadangan yang dibagikan.
  Future<String> cadangkan(DateTime sekarang);
}

class Pencadang implements PencadangKontrak {
  final BackupService _backup;
  final ShareService _berbagi;

  Pencadang(this._backup, this._berbagi);

  @override
  Future<String> cadangkan(DateTime sekarang) async {
    final isi = await _backup.ekspor();
    final nama = namaBerkasCadangan(sekarang);
    await _berbagi.bagikan(
      nama: nama,
      isi: utf8.encode(isi),
      teks: 'Cadangan data Notaku',
    );
    return nama;
  }
}
