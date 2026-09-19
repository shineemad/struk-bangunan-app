import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../data/pengaturan_keluaran_repository.dart';
import '../domain/transaksi.dart';
import '../output/pdf_renderer.dart';
import '../output/png_renderer.dart';
import '../output/share_service.dart';

/// Mengubah struk yang sedang tampil menjadi berkas, lalu menyerahkannya ke
/// share sheet. Format berkasnya mengikuti setelan pengguna; tidak ada
/// pilihan format di layar, karena percabangan di titik tersibuk justru
/// memperlambat.
abstract interface class PengirimStrukKontrak {
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  });
}

class PengirimStruk implements PengirimStrukKontrak {
  final PengaturanKeluaranRepository _pengaturan;
  final ShareService _berbagi;

  PengirimStruk(this._pengaturan, this._berbagi);

  @override
  Future<void> kirim({
    required GlobalKey kunciBoundary,
    required Transaksi nota,
    required int lebarKolom,
  }) async {
    final Uint8List png = await ambilPng(kunciBoundary);
    final setelan = await _pengaturan.muat();
    final isi = setelan.formatKiriman == FormatKiriman.pdf
        ? await susunPdf(png: png, lebarKolom: lebarKolom)
        : png;

    await _berbagi.bagikan(
      nama: namaBerkasStruk(nota.nomorNota, setelan.formatKiriman),
      isi: isi,
      teks: 'Struk #${nota.nomorNota}',
    );
  }
}
