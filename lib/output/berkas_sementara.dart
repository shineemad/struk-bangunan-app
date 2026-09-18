import 'dart:io';

import 'package:path/path.dart' as p;

/// Berkas yang hanya perlu hidup sampai selesai dibagikan.
///
/// Struk sengaja tidak disimpan ke galeri: galeri pemilik toko tidak boleh
/// dipenuhi ratusan gambar struk.
class BerkasSementara {
  final Directory folder;

  BerkasSementara(this.folder);

  Future<File> tulis(String nama, List<int> isi) async {
    await folder.create(recursive: true);
    final berkas = File(p.join(folder.path, nama));
    await berkas.writeAsBytes(isi, flush: true);
    return berkas;
  }

  /// Membuang berkas yang lebih tua dari [umur] dan mengembalikan jumlahnya.
  ///
  /// Dipanggil sebelum menulis berkas baru, karena tidak ada saat lain yang
  /// dijamin terjadi: share sheet bisa ditutup kapan saja, dan aplikasi bisa
  /// dimatikan sebelum sempat membereskan.
  Future<int> bersihkanLebihTuaDari(Duration umur, {DateTime? sekarang}) async {
    if (!await folder.exists()) return 0;

    final batas = (sekarang ?? DateTime.now()).subtract(umur);
    var dibuang = 0;
    await for (final entri in folder.list()) {
      if (entri is! File) continue;
      if ((await entri.lastModified()).isBefore(batas)) {
        await entri.delete();
        dibuang++;
      }
    }
    return dibuang;
  }
}
