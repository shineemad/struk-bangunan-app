import 'dart:async';

import '../data/pengaturan_keluaran_repository.dart';
import 'printer_bluetooth.dart';

/// Setiap cara pencetakan bisa gagal, masing-masing punya jalan keluar
/// sendiri di layar. Satu pesan galat untuk semua keadaan akan membuat kasir
/// menebak-nebak.
enum HasilCetak {
  berhasil,
  izinBelumDiberikan,
  bluetoothMati,
  printerBelumDipilih,
  tidakMenyahut,
  gagalKirim,
}

class PrinterService {
  final PrinterBluetooth _perangkat;
  final PengaturanKeluaranRepository _pengaturan;

  /// Delapan detik diambil dari spec bagian 7. Lebih lama dari itu, kasir
  /// sudah menyerah lebih dulu daripada aplikasinya.
  final Duration batasWaktu;

  PrinterService(
    this._perangkat,
    this._pengaturan, {
    this.batasWaktu = const Duration(seconds: 8),
  });

  Future<List<PrinterTerdeteksi>> daftarPrinter() =>
      _perangkat.daftarTerpasang();

  Future<void> pilihPrinter(PrinterTerdeteksi printer) =>
      _pengaturan.ingatPrinter(printer.mac, printer.nama);

  /// Mengirim [bytes] ke printer yang terakhir dipilih.
  ///
  /// Tidak pernah melempar. Transaksi sudah tersimpan sebelum fungsi ini
  /// dipanggil, jadi kegagalan cetak tidak boleh sampai menjatuhkan apa pun.
  Future<HasilCetak> cetak(List<int> bytes) async {
    if (!await _perangkat.izinDiberikan()) {
      return HasilCetak.izinBelumDiberikan;
    }
    if (!await _perangkat.bluetoothMenyala()) {
      return HasilCetak.bluetoothMati;
    }

    final pengaturan = await _pengaturan.muat();
    if (!pengaturan.punyaPrinter) {
      return HasilCetak.printerBelumDipilih;
    }

    try {
      final tersambung = await _perangkat.sudahTersambung().timeout(batasWaktu);
      if (!tersambung) {
        final berhasil = await _perangkat
            .sambung(pengaturan.printerMac)
            .timeout(batasWaktu);
        if (!berhasil) return HasilCetak.tidakMenyahut;
      }

      final terkirim = await _perangkat.kirim(bytes).timeout(batasWaktu);
      return terkirim ? HasilCetak.berhasil : HasilCetak.gagalKirim;
    } on TimeoutException {
      return HasilCetak.tidakMenyahut;
    }
  }
}
