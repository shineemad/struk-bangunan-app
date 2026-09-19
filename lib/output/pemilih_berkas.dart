import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../data/backup_service.dart';

/// Pembungkus tipis ke pemilih berkas bawaan sistem. Dipisah karena
/// `FilePicker` seluruhnya statis dan tidak bisa dipalsukan — pola yang sama
/// dipakai `PrinterBluetooth` terhadap `PrintBluetoothThermal`.
abstract interface class PemilihBerkas {
  /// `null` bila pengguna menutup pemilih tanpa memilih apa pun.
  Future<String?> pilihTeks();
}

class PemilihBerkasAsli implements PemilihBerkas {
  const PemilihBerkasAsli();

  @override
  Future<String?> pilihTeks() async {
    // `FileType.any`, bukan saringan ekstensi: saringan di Android bekerja
    // lewat tipe MIME, dan berkas cadangan yang sudah singgah di WhatsApp
    // atau Drive kerap kehilangan tipe MIME-nya sehingga tidak bisa dipilih
    // sama sekali. Isi berkas divalidasi penuh oleh `BackupService.impor`.
    final berkas = await FilePicker.pickFile();
    if (berkas == null) return null;

    // Ukuran diperiksa sebelum isinya dibaca; membaca berkas sebesar apa pun
    // ke memori lebih dulu bisa membuat aplikasi mati kehabisan memori.
    final ukuran = await berkas.length();
    if (ukuran == null) {
      throw const BackupRusak('Berkas yang dipilih tidak bisa dibaca.');
    }
    if (ukuran > batasUkuranBerkasCadangan) {
      throw const BackupRusak(
        'Berkas ini terlalu besar untuk sebuah cadangan. '
        'Pastikan Anda memilih berkas cadangan Notaku.',
      );
    }

    try {
      return utf8.decode(await berkas.readAsBytes());
    } on FormatException {
      throw const BackupRusak('Berkas ini bukan berkas cadangan yang sah.');
    }
  }
}
