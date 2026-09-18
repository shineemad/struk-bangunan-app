import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../data/pengaturan_keluaran_repository.dart';
import 'berkas_sementara.dart';

/// Cara berkas keluar dari aplikasi. Disuntikkan supaya seluruh logika
/// penulisan dan pembersihan bisa diuji tanpa share sheet sungguhan.
typedef PengirimBerkas = Future<void> Function(String jalur, String? teks);

String namaBerkasStruk(String nomorNota, FormatKiriman format) =>
    'struk-$nomorNota.${format == FormatKiriman.pdf ? 'pdf' : 'png'}';

/// Nama yang diminta spec bagian 4, supaya pengguna mengenali berkasnya
/// sendiri di antara ratusan berkas WhatsApp.
String namaBerkasCadangan(DateTime waktu) {
  final bulan = waktu.month.toString().padLeft(2, '0');
  final hari = waktu.day.toString().padLeft(2, '0');
  return 'strukbangunan-backup-${waktu.year}$bulan$hari.json';
}

class ShareService {
  final BerkasSementara _berkas;
  final PengirimBerkas _kirim;

  ShareService(this._berkas, {PengirimBerkas? kirim})
    : _kirim = kirim ?? _lewatShareSheet;

  Future<void> bagikan({
    required String nama,
    required List<int> isi,
    String? teks,
  }) async {
    await _berkas.bersihkanLebihTuaDari(const Duration(hours: 1));
    final berkas = await _berkas.tulis(nama, isi);
    await _kirim(berkas.path, teks);
  }

  static Future<void> _lewatShareSheet(String jalur, String? teks) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(jalur)], text: teks),
    );
  }
}

/// Folder cache tempat berkas struk dan cadangan ditulis sebelum dibagikan.
Future<BerkasSementara> berkasSementaraCache() async {
  final cache = await getTemporaryDirectory();
  return BerkasSementara(Directory(p.join(cache.path, 'struk')));
}
