import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profil_toko.dart';

class ProfilRepository {
  final SharedPreferences _prefs;

  ProfilRepository(this._prefs);

  static const _kunciNama = 'nama_toko';
  static const _kunciAlamat = 'alamat_toko';
  static const _kunciNoHp = 'nohp_toko';
  static const _kunciCatatan = 'catatan_toko';
  static const _kunciKasir = 'nama_kasir';
  static const _kunciLebar = 'lebar_kertas';

  /// Null berarti toko belum pernah diatur, yang memicu layar onboarding.
  Future<ProfilToko?> muat() async {
    final nama = _prefs.getString(_kunciNama);
    if (nama == null || nama.isEmpty) return null;
    return ProfilToko(
      namaToko: nama,
      alamat: _prefs.getString(_kunciAlamat) ?? '',
      noHp: _prefs.getString(_kunciNoHp) ?? '',
      catatan: _prefs.getString(_kunciCatatan) ?? '',
      namaKasir: _prefs.getString(_kunciKasir) ?? '',
      lebarKertas: _prefs.getInt(_kunciLebar) ?? 58,
    );
  }

  Future<void> simpan(ProfilToko profil) async {
    await _prefs.setString(_kunciNama, profil.namaToko);
    await _prefs.setString(_kunciAlamat, profil.alamat);
    await _prefs.setString(_kunciNoHp, profil.noHp);
    await _prefs.setString(_kunciCatatan, profil.catatan);
    await _prefs.setString(_kunciKasir, profil.namaKasir);
    await _prefs.setInt(_kunciLebar, profil.lebarKertas);
  }
}
