import 'package:shared_preferences/shared_preferences.dart';

/// Berkas apa yang dikirim ke WhatsApp. Gambar menang sebagai bawaan karena
/// setiap HP bisa menampilkannya tanpa membuka aplikasi lain.
enum FormatKiriman { png, pdf }

class PengaturanKeluaran {
  final FormatKiriman formatKiriman;
  final String printerMac;
  final String printerNama;

  const PengaturanKeluaran({
    this.formatKiriman = FormatKiriman.png,
    this.printerMac = '',
    this.printerNama = '',
  });

  bool get punyaPrinter => printerMac.isNotEmpty;
}

class PengaturanKeluaranRepository {
  final SharedPreferences _prefs;

  PengaturanKeluaranRepository(this._prefs);

  static const kunciFormat = 'format_kiriman';
  static const kunciPrinterMac = 'printer_terakhir_mac';
  static const kunciPrinterNama = 'printer_terakhir_nama';

  Future<PengaturanKeluaran> muat() async {
    return PengaturanKeluaran(
      formatKiriman: formatDariNama(_prefs.getString(kunciFormat)),
      printerMac: _prefs.getString(kunciPrinterMac) ?? '',
      printerNama: _prefs.getString(kunciPrinterNama) ?? '',
    );
  }

  Future<void> simpan(PengaturanKeluaran pengaturan) async {
    await _prefs.setString(kunciFormat, pengaturan.formatKiriman.name);
    await _prefs.setString(kunciPrinterMac, pengaturan.printerMac);
    await _prefs.setString(kunciPrinterNama, pengaturan.printerNama);
  }

  /// Dipanggil setiap kali kasir memilih printer, sehingga tombol Cetak
  /// berikutnya tidak menanyakan apa pun.
  Future<void> ingatPrinter(String mac, String nama) async {
    await _prefs.setString(kunciPrinterMac, mac);
    await _prefs.setString(kunciPrinterNama, nama);
  }

  /// Nilai asing diperlakukan sebagai bawaan, bukan galat: berkas cadangan
  /// bisa datang dari versi aplikasi yang lebih baru. Publik karena
  /// [BackupService] memakainya saat memulihkan.
  static FormatKiriman formatDariNama(String? nilai) {
    for (final f in FormatKiriman.values) {
      if (f.name == nilai) return f;
    }
    return FormatKiriman.png;
  }
}
