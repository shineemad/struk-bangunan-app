import '../data/backup_service.dart';
import '../output/pemilih_berkas.dart';

/// Memilih berkas cadangan lalu menimpanya ke basis data. Dipisah dari
/// `BackupService` supaya widget test bisa memakai pemulih palsu, persis pola
/// `PencadangKontrak`.
abstract interface class PemulihKontrak {
  /// `false` bila pengguna menutup pemilih berkas tanpa memilih.
  /// Melempar [BackupRusak] bila berkasnya tidak sah — data lama tetap utuh.
  Future<bool> pulihkan();
}

class Pemulih implements PemulihKontrak {
  final BackupService _backup;
  final PemilihBerkas _pemilih;

  Pemulih(this._backup, this._pemilih);

  @override
  Future<bool> pulihkan() async {
    final isi = await _pemilih.pilihTeks();
    if (isi == null) return false;
    await _backup.impor(isi);
    return true;
  }
}
