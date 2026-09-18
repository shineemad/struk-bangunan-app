import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:struk_bangunan/data/pengaturan_keluaran_repository.dart';

Future<PengaturanKeluaranRepository> _siap() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  return PengaturanKeluaranRepository(await SharedPreferences.getInstance());
}

void main() {
  test('bawaan memakai PNG dan belum punya printer', () async {
    final repo = await _siap();
    final hasil = await repo.muat();

    expect(hasil.formatKiriman, FormatKiriman.png);
    expect(hasil.printerMac, '');
    expect(hasil.printerNama, '');
  });

  test('menyimpan lalu memuat kembali seluruh kolom', () async {
    final repo = await _siap();
    await repo.simpan(
      const PengaturanKeluaran(
        formatKiriman: FormatKiriman.pdf,
        printerMac: '66:22:11:AA:BB:CC',
        printerNama: 'RPP02N',
      ),
    );

    final hasil = await repo.muat();
    expect(hasil.formatKiriman, FormatKiriman.pdf);
    expect(hasil.printerMac, '66:22:11:AA:BB:CC');
    expect(hasil.printerNama, 'RPP02N');
  });

  test('ingatPrinter tidak mengubah format kiriman', () async {
    final repo = await _siap();
    await repo.simpan(
      const PengaturanKeluaran(formatKiriman: FormatKiriman.pdf),
    );
    await repo.ingatPrinter('66:22:11:AA:BB:CC', 'RPP02N');

    final hasil = await repo.muat();
    expect(hasil.formatKiriman, FormatKiriman.pdf);
    expect(hasil.printerMac, '66:22:11:AA:BB:CC');
  });

  test('nilai format yang tidak dikenal jatuh ke PNG', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'format_kiriman': 'faks'});
    final repo = PengaturanKeluaranRepository(
      await SharedPreferences.getInstance(),
    );

    expect((await repo.muat()).formatKiriman, FormatKiriman.png);
  });
}
