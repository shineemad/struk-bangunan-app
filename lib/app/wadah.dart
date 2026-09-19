import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/basisdata.dart';
import '../data/draf_repository.dart';
import '../data/favorit_repository.dart';
import '../data/pengaturan_keluaran_repository.dart';
import '../data/profil_repository.dart';
import '../data/transaksi_repository.dart';

/// Satu-satunya tempat basis data dan preferensi dibuka, supaya tidak ada
/// layar yang diam-diam membuka koneksinya sendiri.
class Wadah {
  final Database db;
  final SharedPreferences prefs;

  Wadah(this.db, this.prefs);

  static Future<Wadah> buat() async {
    final db = await bukaBasisdata();
    final prefs = await SharedPreferences.getInstance();
    final wadah = Wadah(db, prefs);
    await wadah.siapkan();
    return wadah;
  }

  late final ProfilRepository profil = ProfilRepository(prefs);
  late final PengaturanKeluaranRepository pengaturan =
      PengaturanKeluaranRepository(prefs);
  late final DrafRepository draf = DrafRepository(prefs);
  late final TransaksiRepository transaksi = TransaksiRepository(db);
  late final FavoritRepository favorit = FavoritRepository(db);

  /// Aman dipanggil berulang: isian bawaan hanya masuk saat tabelnya kosong.
  Future<void> siapkan() => favorit.isiBawaanBilaKosong();
}
