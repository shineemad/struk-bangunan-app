import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';
import 'package:struk_bangunan/output/printer_bluetooth.dart';
import 'package:struk_bangunan/output/printer_service.dart';

/// Printer palsu yang bisa disuruh gagal dengan cara apa pun yang nyata.
class _PrinterPalsu implements PrinterBluetooth {
  bool izin = true;
  bool menyala = true;
  bool tersambung = false;
  bool bisaSambung = true;
  bool bisaKirim = true;
  bool diamSelamanya = false;
  List<PrinterTerdeteksi> terpasang = const [];

  int jumlahSambung = 0;
  List<int>? terkirim;

  Future<T> _jawab<T>(T nilai) =>
      diamSelamanya ? Completer<T>().future : Future.value(nilai);

  @override
  Future<bool> izinDiberikan() async => izin;

  @override
  Future<bool> bluetoothMenyala() async => menyala;

  @override
  Future<List<PrinterTerdeteksi>> daftarTerpasang() async => terpasang;

  @override
  Future<bool> sudahTersambung() => _jawab(tersambung);

  @override
  Future<bool> sambung(String mac) {
    jumlahSambung++;
    return _jawab(bisaSambung);
  }

  @override
  Future<bool> kirim(List<int> bytes) {
    terkirim = bytes;
    return _jawab(bisaKirim);
  }

  @override
  Future<void> putus() async {}
}

Future<(_PrinterPalsu, PengaturanKeluaranRepository, PrinterService)> _siap({
  String mac = '66:22:11:AA:BB:CC',
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final pengaturan = PengaturanKeluaranRepository(
    await SharedPreferences.getInstance(),
  );
  if (mac.isNotEmpty) await pengaturan.ingatPrinter(mac, 'RPP02N');
  final perangkat = _PrinterPalsu();
  return (
    perangkat,
    pengaturan,
    PrinterService(
      perangkat,
      pengaturan,
      batasWaktu: const Duration(milliseconds: 50),
    ),
  );
}

void main() {
  test('mencetak dan mengirimkan byte yang sama persis', () async {
    final (perangkat, _, layanan) = await _siap();

    expect(await layanan.cetak([1, 2, 3]), HasilCetak.berhasil);
    expect(perangkat.terkirim, [1, 2, 3]);
  });

  test('izin belum diberikan dilaporkan tanpa mencoba mengirim', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.izin = false;

    expect(await layanan.cetak([1]), HasilCetak.izinBelumDiberikan);
    expect(perangkat.terkirim, isNull);
  });

  test('bluetooth mati dilaporkan tanpa mencoba mengirim', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.menyala = false;

    expect(await layanan.cetak([1]), HasilCetak.bluetoothMati);
    expect(perangkat.terkirim, isNull);
  });

  test('printer belum pernah dipilih dilaporkan tersendiri', () async {
    final (perangkat, _, layanan) = await _siap(mac: '');

    expect(await layanan.cetak([1]), HasilCetak.printerBelumDipilih);
    expect(perangkat.jumlahSambung, 0);
  });

  test('printer yang sudah tersambung tidak disambungkan ulang', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.tersambung = true;

    expect(await layanan.cetak([1]), HasilCetak.berhasil);
    expect(perangkat.jumlahSambung, 0);
  });

  test('printer yang menolak sambungan dilaporkan tidak menyahut', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.bisaSambung = false;

    expect(await layanan.cetak([1]), HasilCetak.tidakMenyahut);
  });

  test(
    'printer yang diam melebihi batas waktu dilaporkan tidak menyahut',
    () async {
      final (perangkat, _, layanan) = await _siap();
      perangkat.diamSelamanya = true;

      expect(await layanan.cetak([1]), HasilCetak.tidakMenyahut);
    },
  );

  test('pengiriman yang ditolak printer dilaporkan gagal kirim', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.bisaKirim = false;

    expect(await layanan.cetak([1]), HasilCetak.gagalKirim);
  });

  test('memilih printer mengingatnya untuk cetak berikutnya', () async {
    final (_, pengaturan, layanan) = await _siap(mac: '');
    await layanan.pilihPrinter(
      const PrinterTerdeteksi(nama: 'RPP02N', mac: '11:22:33:44:55:66'),
    );

    final hasil = await pengaturan.muat();
    expect(hasil.printerMac, '11:22:33:44:55:66');
    expect(hasil.printerNama, 'RPP02N');
  });

  test('daftar printer diteruskan apa adanya dari perangkat', () async {
    final (perangkat, _, layanan) = await _siap();
    perangkat.terpasang = const [
      PrinterTerdeteksi(nama: 'RPP02N', mac: '11:22:33:44:55:66'),
    ];

    expect((await layanan.daftarPrinter()).single.nama, 'RPP02N');
  });
}
