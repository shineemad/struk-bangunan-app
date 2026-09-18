import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profil_toko.dart';

class ProfilRepository {
  final SharedPreferences _prefs;

  ProfilRepository(this._prefs);

  // Publik agar BackupService bisa memakai kunci yang sama persis, alih-alih
  // mengetik ulang literalnya sendiri.
  static const kunciNama = 'nama_toko';
  static const kunciAlamat = 'alamat_toko';
  static const kunciNoHp = 'nohp_toko';
  static const kunciCatatan = 'catatan_toko';
  static const kunciKasir = 'nama_kasir';
  static const kunciLebar = 'lebar_kertas';

  /// Null berarti toko belum pernah diatur, yang memicu layar onboarding.
  Future<ProfilToko?> muat() async {
    final nama = _prefs.getString(kunciNama);
    if (nama == null || nama.isEmpty) return null;
    return ProfilToko(
      namaToko: nama,
      alamat: _prefs.getString(kunciAlamat) ?? '',
      noHp: _prefs.getString(kunciNoHp) ?? '',
      catatan: _prefs.getString(kunciCatatan) ?? '',
      namaKasir: _prefs.getString(kunciKasir) ?? '',
      lebarKertas: _prefs.getInt(kunciLebar) ?? 58,
    );
  }

  Future<void> simpan(ProfilToko profil) async {
    await _prefs.setString(kunciNama, profil.namaToko);
    await _prefs.setString(kunciAlamat, profil.alamat);
    await _prefs.setString(kunciNoHp, profil.noHp);
    await _prefs.setString(kunciCatatan, profil.catatan);
    await _prefs.setString(kunciKasir, profil.namaKasir);
    await _prefs.setInt(kunciLebar, profil.lebarKertas);
  }
}
